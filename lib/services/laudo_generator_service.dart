import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cadaver_model.dart';
import '../models/equipe_policial_ficha_model.dart';
import '../models/equipe_resgate_model.dart';
import '../models/evidencia_model.dart';
import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/membro_equipe_model.dart';
import '../models/perito_model.dart';
import '../models/pessoa_envolvida_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/equipe_service.dart';
import '../services/laboratorio_service.dart';
import '../services/unidade_service.dart';

/// Serviço responsável por gerar documentos de LAUDO em formato Word (DOCX)
/// a partir de uma FichaCompletaModel
class LaudoGeneratorService {
  // Serviços para resolver nomes de destino
  final UnidadeService _unidadeService = UnidadeService();
  final LaboratorioService _laboratorioService = LaboratorioService();

  // Configurações de fonte
  static const String _fontName = 'Gadugi';
  static const String _fontSizeTitulo = '44'; // 22pt = 44 half-points
  static const String _fontSizeSubtitulo = '28'; // 14pt = 28 half-points
  static const String _fontSizeNormal = '24'; // 12pt = 24 half-points

  /// Gera o documento Word do laudo
  Future<File> gerarLaudo({
    required FichaCompletaModel ficha,
    required PeritoModel perito,
    required String templatePath,
    List<File>? fotos,
  }) async {
    // Ler o template
    final templateFile = File(templatePath);
    if (!await templateFile.exists()) {
      throw Exception('Template não encontrado: $templatePath');
    }

    final templateBytes = await templateFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // Encontrar e processar document.xml
    final documentXmlIndex = archive.files.indexWhere(
      (f) => f.name == 'word/document.xml',
    );
    if (documentXmlIndex == -1) {
      throw Exception('Arquivo document.xml não encontrado no template');
    }

    final documentXml = archive.files[documentXmlIndex];
    final conteudoOriginal = documentXml.content as List<int>;
    String documentContent;
    try {
      documentContent = utf8.decode(conteudoOriginal);
    } catch (e) {
      documentContent = String.fromCharCodes(conteudoOriginal);
    }

    // Processar relationships se houver fotos e preparar nomes únicos (evita sobrescrever imagens do template)
    String? relationshipsXml;
    int maxId = 0;
    List<String> nomesFotosDocx = const [];
    if (fotos != null && fotos.isNotEmpty) {
      final result = await _processarRelationships(archive, fotos);
      relationshipsXml = result['xml'] as String;
      maxId = result['maxId'] as int;
      nomesFotosDocx = (result['fileNames'] as List<dynamic>).cast<String>();
    }

    // Gerar novo conteúdo do documento
    final novoConteudo = await _gerarConteudoLaudo(
      ficha,
      perito,
      documentContent,
      fotos: fotos,
      maxId: maxId,
    );

    // Criar novo arquivo com o conteúdo atualizado
    final novoArchive = Archive();
    // (contador não necessário aqui; mantemos por clareza apenas se precisarmos de logs)

    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        final novoDocBytes = Uint8List.fromList(utf8.encode(novoConteudo));
        novoArchive.addFile(
          ArchiveFile(file.name, novoDocBytes.length, novoDocBytes),
        );
      } else if (file.name == 'word/_rels/document.xml.rels' &&
          relationshipsXml != null) {
        // Atualizar relationships com as novas imagens
        final relsBytes = Uint8List.fromList(utf8.encode(relationshipsXml));
        novoArchive.addFile(
          ArchiveFile(file.name, relsBytes.length, relsBytes),
        );
      } else {
        novoArchive.addFile(file);
      }
    }

    // Adicionar imagens ao archive com nomes únicos (não colide com imagens do template)
    if (fotos != null && fotos.isNotEmpty) {
      for (int i = 0; i < fotos.length; i++) {
        final foto = fotos[i];
        if (!await foto.exists()) continue;
        if (i >= nomesFotosDocx.length) continue;
        final imageBytes = await foto.readAsBytes();
        final imageName = 'word/media/${nomesFotosDocx[i]}';
        novoArchive.addFile(
          ArchiveFile(imageName, imageBytes.length, imageBytes),
        );
      }
    }

    final zipBytes = ZipEncoder().encode(novoArchive);

    // Salvar o arquivo
    final directory = await getApplicationDocumentsDirectory();
    final dadosSol = ficha.dadosSolicitacao;
    final numeroOcorrencia = (dadosSol.numeroOcorrencia ?? 'sem_numero')
        .replaceAll('/', '-');
    final fileName =
        'Laudo_${numeroOcorrencia}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final outputFile = File('${directory.path}/$fileName');
    await outputFile.writeAsBytes(zipBytes);

    return outputFile;
  }

  Future<String> _gerarConteudoLaudo(
    FichaCompletaModel ficha,
    PeritoModel perito,
    String documentContent, {
    List<File>? fotos,
    int maxId = 0,
  }) async {
    // Extrair sectPr do documento original (contém referências a header/footer)
    final sectPr = _extrairSectPr(documentContent);

    // Gerar o conteúdo interno do body
    final buffer = StringBuffer();

    // TÍTULO PRINCIPAL: "LAUDO DE PERÍCIA CRIMINAL"
    buffer.writeln(_gerarTituloPrincipal('LAUDO DE PERÍCIA CRIMINAL'));

    // SUBTÍTULO: Natureza do exame
    final subtitulo = _getSubtituloParaTipo(ficha.tipoOcorrencia);
    buffer.writeln(_gerarSubtitulo(subtitulo));
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA DE IDENTIFICAÇÃO DO LAUDO
    buffer.writeln(_gerarTabelaIdentificacao(ficha, perito));
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 1. HISTÓRICO
    buffer.writeln(await _gerarSecaoHistorico(ficha, perito));
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 2. OBJETIVOS
    buffer.writeln(_gerarSecaoObjetivos());
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS
    buffer.writeln(_gerarSecaoIsolamentoPreservacao(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 4. DESCRIÇÃO DO LOCAL
    buffer.writeln(_gerarSecaoDescricaoLocal(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 5. EXAMES ou DAS IMAGENS (para CVLI)
    final qtdFotos = fotos?.length ?? 0;
    buffer.writeln(_gerarSecaoExames(ficha, qtdFotos: qtdFotos));
    buffer.writeln(_gerarParagrafoVazio());

    // SEÇÃO 6. ANÁLISE E INTERPRETAÇÃO DOS VESTÍGIOS ou DOS EXAMES (para CVLI)
    buffer.writeln(await _gerarSecaoAnaliseInterpretacao(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // Para CVLI: seções 7-11 específicas
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
      // SEÇÃO 7. EXAMES COMPLEMENTARES
      buffer.writeln(_gerarSecaoExamesComplementaresCVLI(ficha));
      buffer.writeln(_gerarParagrafoVazio());

      // SEÇÃO 8. CONSIDERAÇÕES TÉCNICO-PERICIAIS
      buffer.writeln(_gerarSecaoConsideracoesTecnicoPericiais(ficha));
      buffer.writeln(_gerarParagrafoVazio());

      // SEÇÃO 9. RESPOSTA AOS QUESITOS
      buffer.writeln(_gerarSecaoRespostaQuesitos(ficha));
      buffer.writeln(_gerarParagrafoVazio());

      // SEÇÃO 10. CONCLUSÃO
      buffer.writeln(_gerarSecaoConclusaoCVLI(ficha));
      buffer.writeln(_gerarParagrafoVazio());

      // SEÇÃO 11. REFERÊNCIAS BIBLIOGRÁFICAS
      buffer.writeln(_gerarSecaoReferenciasBibliograficas(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    } else {
      // Para outros casos (Furto/Dano)
      // SEÇÃO 7. QUESITOS (obrigatório para casos de Furto ou Dano)
      if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
        // Se tem dados de dano realmente preenchidos, usar quesitos de dano; caso contrário, quesitos de furto
        if (_temDadosDanoPreenchidos(ficha)) {
          buffer.writeln(_gerarSecaoQuesitosDano(ficha));
        } else {
          buffer.writeln(_gerarSecaoQuesitosFurto(ficha));
        }
        buffer.writeln(_gerarParagrafoVazio());
      }

      // SEÇÃO 8. CONCLUSÃO
      buffer.writeln(_gerarSecaoConclusao(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    // PARÁGRAFOS FINAIS
    final qtdFotosNoLaudo = fotos?.length ?? ficha.fotosLevantamento.length;
    buffer.writeln(_gerarParagrafosFinais(ficha, perito, qtdFotosNoLaudo));

    // LEVANTAMENTO FOTOGRÁFICO (se houver fotos)
    if (fotos != null && fotos.isNotEmpty) {
      buffer.writeln(_gerarLevantamentoFotografico(fotos, maxId));
    }

    // Montar o documento completo com namespaces e sectPr
    return _montarDocumentoCompleto(buffer.toString(), sectPr);
  }

  String _extrairSectPr(String xml) {
    final regex = RegExp(r'<w:sectPr[^>]*>.*?</w:sectPr>', dotAll: true);
    final match = regex.firstMatch(xml);
    if (match != null) {
      return match.group(0)!;
    }
    // SectPr padrão com margens ajustadas
    // Margens: Esquerda 3,0 cm (1701 twips), Direita 1,5 cm (850 twips)
    return '''<w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1417" w:right="850" w:bottom="1417" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>
      <w:cols w:space="708"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>''';
  }

  String _montarDocumentoCompleto(String conteudoXml, String sectPr) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" 
            xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" 
            xmlns:v="urn:schemas-microsoft-com:vml" 
            xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" 
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" 
            xmlns:w10="urn:schemas-microsoft-com:office:word" 
            xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" 
            xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" 
            xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" 
            xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" 
            xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" 
            xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
  <w:body>
    $conteudoXml
    $sectPr
  </w:body>
</w:document>''';
  }

  String _getSubtituloParaTipo(TipoOcorrencia? tipo) {
    switch (tipo) {
      case TipoOcorrencia.furtoDanoExameLocal:
        return 'LOCAL DE CRIME CONTRA O PATRIMÔNIO';
      case TipoOcorrencia.cvli:
        return 'CRIMES VIOLENTOS LETAIS INTENCIONAIS';
      default:
        return 'EXAME PERICIAL';
    }
  }

  String _gerarTituloPrincipal(String texto) {
    // Título centralizado, entrelinhas simples (240 = 1.0)
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeTitulo"/>
          <w:szCs w:val="$_fontSizeTitulo"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarSubtitulo(String texto) {
    // Subtítulo centralizado, entrelinhas simples (240 = 1.0), sem negrito
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeSubtitulo"/>
          <w:szCs w:val="$_fontSizeSubtitulo"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarTabelaIdentificacao(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) {
    final buffer = StringBuffer();
    final sol = ficha.dadosSolicitacao;

    // Construir as linhas da tabela
    final linhas = <List<String>>[
      ['Procedimento:', sol.raiNumero ?? ''],
      ['Requisitante:', sol.unidadeOrigem ?? ''],
      ['Delegacia Afeta:', sol.unidadeAfeta ?? ''],
      [
        'Pessoas Envolvidas:',
        _formatarPessoasEnvolvidas(sol.pessoasEnvolvidas),
      ],
      ['Unidade Pericial:', perito.unidadePericial],
      ['Perito(s) Criminal(is):', perito.nome],
      ['Data do Exame:', _formatarDataExame(ficha)],
    ];

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblW w:w="9000" w:type="dxa"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln('          <w:top w:val="none"/>');
    buffer.writeln('          <w:left w:val="none"/>');
    buffer.writeln('          <w:bottom w:val="none"/>');
    buffer.writeln('          <w:right w:val="none"/>');
    buffer.writeln('          <w:insideH w:val="none"/>');
    buffer.writeln('          <w:insideV w:val="none"/>');
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="2500"/>');
    buffer.writeln('        <w:gridCol w:w="6500"/>');
    buffer.writeln('      </w:tblGrid>');

    for (final linha in linhas) {
      buffer.writeln(_gerarLinhaIdentificacao(linha[0], linha[1]));
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  String _gerarLinhaIdentificacao(String rotulo, String valor) {
    // Rótulo e valor em preto, formato normal (sem itálico)
    final valorFormatado = valor.isNotEmpty ? valor : '';
    final temValor = valor.isNotEmpty;

    return '''      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="2500" w:type="dxa"/>
            <w:vAlign w:val="top"/>
          </w:tcPr>
          <w:p>
            <w:pPr>
              <w:jc w:val="both"/>
              <w:spacing w:after="120" w:line="240" w:lineRule="auto"/>
              <w:ind w:firstLine="0"/>
            </w:pPr>
            <w:r>
              <w:rPr>
                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
                <w:sz w:val="$_fontSizeNormal"/>
                <w:szCs w:val="$_fontSizeNormal"/>
              </w:rPr>
              <w:t>${_escapeXml(rotulo)}</w:t>
            </w:r>
          </w:p>
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6500" w:type="dxa"/>
            <w:vAlign w:val="top"/>
          </w:tcPr>
          <w:p>
            <w:pPr>
              <w:jc w:val="both"/>
              <w:spacing w:after="120" w:line="240" w:lineRule="auto"/>
              <w:ind w:firstLine="0"/>
            </w:pPr>
            ${temValor ? '''<w:r>
              <w:rPr>
                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
                <w:sz w:val="$_fontSizeNormal"/>
                <w:szCs w:val="$_fontSizeNormal"/>
              </w:rPr>
              <w:t>${_escapeXml(valorFormatado)}</w:t>
            </w:r>''' : ''}
          </w:p>
        </w:tc>
      </w:tr>''';
  }

  String _formatarPessoasEnvolvidas(List<PessoaEnvolvidaModel>? pessoas) {
    if (pessoas == null || pessoas.isEmpty) return '';

    final partes = <String>[];
    for (final pessoa in pessoas) {
      final tipo = _formatarTipoPessoa(pessoa.tipo);
      final nome = _formatarNomeCorreto(pessoa.nome);
      if (nome.isNotEmpty) {
        partes.add('$tipo: $nome');
      }
    }
    return partes.join(' / ');
  }

  String _formatarTipoPessoa(TipoPessoa tipo) {
    switch (tipo) {
      case TipoPessoa.autor:
        return 'Autor';
      case TipoPessoa.vitima:
        return 'Vítima';
      case TipoPessoa.vitimaComunicante:
        return 'Vítima Comunicante';
      case TipoPessoa.comunicante:
        return 'Comunicante';
      case TipoPessoa.outro:
        return 'Outro';
    }
  }

  String _formatarDataExame(FichaCompletaModel ficha) {
    // Usar a data de início do exame
    final dataHoraInicio = ficha.dataHoraInicio;
    if (dataHoraInicio != null && dataHoraInicio.isNotEmpty) {
      // Extrair apenas a data (assumindo formato dd/MM/yyyy HH:mm)
      final partes = dataHoraInicio.split(' ');
      if (partes.isNotEmpty) {
        return partes[0]; // Retorna apenas a data
      }
    }
    return '';
  }

  String _gerarParagrafoVazio() {
    // Parágrafo vazio com entrelinhas padrão 1,25 e alinhamento justificado
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="708"/>
      </w:pPr>
    </w:p>''';
  }

  Future<String> _gerarSecaoHistorico(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) async {
    final buffer = StringBuffer();
    final equipeService = EquipeService();

    // Título da seção "1. HISTÓRICO"
    buffer.writeln(_gerarTituloSecao('1. HISTÓRICO'));

    // Primeiro parágrafo
    final horaInicio = _extrairHoraInicio(ficha.dataHoraInicio);
    final membrosEquipe = await _formatarMembrosEquipe(ficha, equipeService);
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Após solicitação via Sistema ODIN, o(a) Perito(a) Criminal supracitado(a) procedeu ao local às $horaInicio, na data preambular, acompanhado do(s) $membrosEquipe e realizou o levantamento pericial requisitado.',
      ),
    );

    // Segundo parágrafo
    final historico = ficha.dadosFichaBase?.historico ?? '';

    // Para CVLI: formato diferente (recebidos pelas equipes policiais)
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli &&
        ficha.equipesPoliciais != null &&
        ficha.equipesPoliciais!.isNotEmpty) {
      final equipesTexto = _formatarEquipesPoliciais(ficha.equipesPoliciais!);
      buffer.writeln(
        _gerarParagrafoHistorico(
          'No local, a equipe de Polícia Científica foi recebida pelas equipes policiais: $equipesTexto e segundo apurados pelos policiais $historico',
        ),
      );
    } else {
      // Para outros casos: formato tradicional (recebidos por vítima/comunicante)
      final vitimaComunicante = _obterVitimaComunicante(
        ficha.dadosSolicitacao.pessoasEnvolvidas,
      );
      buffer.writeln(
        _gerarParagrafoHistorico(
          'No local, a equipe de Polícia Científica foi recebida por $vitimaComunicante e conforme relatos $historico',
        ),
      );
    }

    // Terceiro parágrafo (se houver equipes policiais) - apenas para casos não-CVLI
    if (ficha.tipoOcorrencia != TipoOcorrencia.cvli &&
        ficha.equipesPoliciais != null &&
        ficha.equipesPoliciais!.isNotEmpty) {
      final equipesTexto = _formatarEquipesPoliciais(ficha.equipesPoliciais!);
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Faziam-se presentes no local a(s) $equipesTexto.',
        ),
      );
    }

    // Parágrafo sobre equipes de resgate (especialmente para CVLI)
    if (ficha.equipesResgate != null && ficha.equipesResgate!.isNotEmpty) {
      final equipesResgateTexto = _formatarEquipesResgate(
        ficha.equipesResgate!,
      );
      buffer.writeln(_gerarParagrafoHistorico(equipesResgateTexto));
    }

    // Parágrafo sobre recolhimento do(s) cadáver(es) ao IML (apenas para CVLI)
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli &&
        ficha.cadaveres != null &&
        ficha.cadaveres!.isNotEmpty) {
      final horaTermino = _extrairHoraTermino(ficha.dataHoraTermino);
      final cidade = perito.cidade.isNotEmpty ? perito.cidade : 'Cidade';
      final quantidadeCadaveres = ficha.cadaveres!.length;

      String textoRecolhimento;
      if (quantidadeCadaveres == 1) {
        textoRecolhimento =
            'Ao término do processamento do local, por volta de $horaTermino, o corpo foi recolhido e encaminhado, em viatura própria, ao necrotério do Instituto de Medicina Legal (IML) de $cidade, onde fora submetido a Exame Médico-Legal Cadavérico.';
      } else {
        textoRecolhimento =
            'Ao término do processamento do local, por volta de $horaTermino, os corpos foram recolhidos e encaminhados, em viatura própria, ao necrotério do Instituto de Medicina Legal (IML) de $cidade, onde foram submetidos a Exame Médico-Legal Cadavérico.';
      }
      buffer.writeln(_gerarParagrafoHistorico(textoRecolhimento));
    }

    // Quarto parágrafo (término das atividades) - apenas para casos não-CVLI
    if (ficha.tipoOcorrencia != TipoOcorrencia.cvli) {
      final horaTermino = _extrairHoraTermino(ficha.dataHoraTermino);
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Ao término das atividades periciais, aproximadamente às $horaTermino, a equipe procedeu à liberação do local para o(s) responsável(is) designado(s). Essa ação foi realizada após a conclusão de todos os procedimentos requisitados.',
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarTituloSecao(String titulo) {
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(titulo)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoHistorico(String texto) {
    // Parágrafo com recuo de primeira linha 1,25 cm, entrelinhas 1,25, justificado
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="708"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoHistoricoComTextoColorido(
    String textoAntes,
    String textoColorido,
    String textoDepois,
  ) {
    // Parágrafo com recuo de primeira linha 1,25 cm, entrelinhas 1,25, justificado
    // com parte do texto em vermelho
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="708"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(textoAntes)}</w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
          <w:color w:val="FF0000"/>
        </w:rPr>
        <w:t>${_escapeXml(textoColorido)}</w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(textoDepois)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _extrairHoraInicio(String? dataHoraInicio) {
    if (dataHoraInicio == null || dataHoraInicio.isEmpty) return 'XXhXXmin';
    // Assumindo formato dd/MM/yyyy HH:mm
    final partes = dataHoraInicio.split(' ');
    if (partes.length >= 2) {
      final hora = partes[1]; // Formato HH:mm
      return _formatarHora(hora);
    }
    return 'XXhXXmin';
  }

  String _extrairHoraTermino(String? dataHoraTermino) {
    if (dataHoraTermino == null || dataHoraTermino.isEmpty) return 'XXhXXmin';
    // Assumindo formato dd/MM/yyyy HH:mm
    final partes = dataHoraTermino.split(' ');
    if (partes.length >= 2) {
      final hora = partes[1]; // Formato HH:mm
      return _formatarHora(hora);
    }
    return 'XXhXXmin';
  }

  String _formatarHora(String hora) {
    // Converte de HH:mm para HHhMMmin
    // Exemplo: "15:43" -> "15h43min"
    final partes = hora.split(':');
    if (partes.length >= 2) {
      return '${partes[0]}h${partes[1]}min';
    }
    return hora; // Retorna como está se não conseguir formatar
  }

  Future<String> _formatarMembrosEquipe(
    FichaCompletaModel ficha,
    EquipeService equipeService,
  ) async {
    if (ficha.equipe == null) return 'equipe de perícia';

    final todosMembros = await equipeService.listarEquipe();
    final membros = <String>[];

    // Fotógrafo
    if (ficha.equipe!.fotografoCriminalisticoId != null) {
      final fotografo = todosMembros.firstWhere(
        (m) => m.id == ficha.equipe!.fotografoCriminalisticoId,
        orElse: () =>
            MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
      );
      if (fotografo.nome.isNotEmpty) {
        membros.add('${fotografo.cargo} ${fotografo.nome}');
      }
    }

    // Demais servidores
    for (final id in ficha.equipe!.demaisServidoresIds) {
      final membro = todosMembros.firstWhere(
        (m) => m.id == id,
        orElse: () =>
            MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
      );
      if (membro.nome.isNotEmpty) {
        membros.add('${membro.cargo} ${membro.nome}');
      }
    }

    if (membros.isEmpty) {
      return 'equipe de perícia';
    }

    if (membros.length == 1) {
      return membros[0];
    } else if (membros.length == 2) {
      return '${membros[0]} e ${membros[1]}';
    } else {
      final ultimo = membros.removeLast();
      return '${membros.join(', ')}, e $ultimo';
    }
  }

  String _obterVitimaComunicante(List<PessoaEnvolvidaModel>? pessoas) {
    if (pessoas == null || pessoas.isEmpty) return 'XXXXXXXXXXXXXX';

    PessoaEnvolvidaModel? selecionada;

    selecionada = pessoas.firstWhere(
      (p) => p.tipo == TipoPessoa.vitimaComunicante,
      orElse: () => PessoaEnvolvidaModel(nome: '', tipo: TipoPessoa.outro),
    );

    if (selecionada.nome.isEmpty) {
      selecionada = pessoas.firstWhere(
        (p) => p.tipo == TipoPessoa.vitima,
        orElse: () => PessoaEnvolvidaModel(nome: '', tipo: TipoPessoa.outro),
      );
    }

    if (selecionada.nome.isEmpty) {
      selecionada = pessoas.firstWhere(
        (p) => p.tipo == TipoPessoa.comunicante,
        orElse: () => PessoaEnvolvidaModel(nome: '', tipo: TipoPessoa.outro),
      );
    }

    if (selecionada.nome.isNotEmpty) {
      return _formatarNomeCorreto(selecionada.nome);
    }

    return 'XXXXXXXXXXXXXX';
  }

  String _formatarNomeCorreto(String nome) {
    // Converte de CAIXA ALTA para formato correto (primeira letra maiúscula, resto minúsculo)
    // Trata nomes compostos corretamente (ex: "MARIA DA SILVA" -> "Maria da Silva")
    final palavras = nome.toLowerCase().split(' ');
    final palavrasFormatadas = palavras.map((palavra) {
      if (palavra.isEmpty) return palavra;
      // Primeira letra maiúscula
      return palavra[0].toUpperCase() + palavra.substring(1);
    }).toList();

    return palavrasFormatadas.join(' ');
  }

  String _formatarEquipesPoliciais(List<EquipePolicialFichaModel> equipes) {
    final partes = <String>[];

    for (final equipe in equipes) {
      final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
      final membros = equipe.membros
          .map((m) {
            final posto = m.postoGraduacao != null
                ? ' (${m.postoGraduacao})'
                : '';
            return '${m.nome}$posto';
          })
          .join(', ');

      partes.add('$tipoNome: $membros');
    }

    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes[0];
    if (partes.length == 2) return '${partes[0]} e ${partes[1]}';

    final ultimo = partes.removeLast();
    return '${partes.join(', ')}, e $ultimo';
  }

  String _formatarEquipesResgate(List<EquipeResgateModel> equipes) {
    final partes = <String>[];

    for (final equipe in equipes) {
      final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
      final membros = equipe.membros
          .map((m) {
            final partesMembro = <String>[];
            if (m.cargo != null) {
              partesMembro.add(m.cargo!);
            }
            partesMembro.add(m.nome);
            if (m.crm != null) {
              partesMembro.add('CRM ${m.crm}');
            }
            return partesMembro.join(' ');
          })
          .join(', ');

      String textoEquipe;
      if (equipe.naoEstavaNoLocal) {
        textoEquipe =
            '$tipoNome (não estava no local, mas esteve presente): $membros';
      } else {
        textoEquipe = '$tipoNome: $membros';
      }

      if (equipe.unidadeNumero != null) {
        textoEquipe += ' (Unidade n. ${equipe.unidadeNumero})';
      }

      partes.add(textoEquipe);
    }

    if (partes.isEmpty) return '';

    final texto = 'Equipe(s) de resgate presente(s): ${partes.join('; ')}.';
    return texto;
  }

  String _gerarSecaoObjetivos() {
    final buffer = StringBuffer();

    // Título da seção "2. OBJETIVOS"
    buffer.writeln(_gerarTituloSecao('2. OBJETIVOS'));

    // Parágrafo com o texto dos objetivos
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Estabelecer a materialidade dos fatos, buscando os elementos comprobatórios e os meios e/ou instrumentos utilizados na perpetração do ato delituoso e, se possível, os vestígios materiais que contribuam com a elucidação da autoria.',
      ),
    );

    return buffer.toString();
  }

  String _gerarSecaoIsolamentoPreservacao(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    final fb = ficha.dadosFichaBase;

    // Título da seção "3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS"
    buffer.writeln(
      _gerarTituloSecao('3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS'),
    );

    // ISOLAMENTO
    if (fb?.isolamentoNao == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'O local do fato não contava com medidas oficiais de isolamento.',
        ),
      );
    } else if (fb?.isolamentoSim == true) {
      final meios = _formatarMeiosIsolamento(fb!);
      buffer.writeln(
        _gerarParagrafoHistorico('O local encontrava-se isolado por $meios.'),
      );
    }

    // PRESERVAÇÃO
    if (fb?.preservacaoSim == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quanto à Preservação, não foram relatadas e/ou constatadas alterações aparentes no estado geral das coisas, o que possibilitou o levantamento.',
        ),
      );
    } else if (fb?.preservacaoNao == true) {
      if (fb?.preservacaoParcialmenteIdoneo == true) {
        final alteracoes = fb?.preservacaoAlteracoesDetectadas ?? '';
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Quanto à Preservação, que ficou a cargo da própria vítima, houve alteração no estado geral das coisas $alteracoes',
          ),
        );
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Apesar disso, havia no local vestígios que puderam estar relacionados à ação delituosa o que permitiu a realização do levantamento pericial nas condições apresentadas.',
          ),
        );
      } else if (fb?.preservacaoInidoneo == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Devido à ausência de Preservação do local, não foram encontrados vestígios relacionados aos fatos apontados no histórico, não sendo possível realizar qualquer análise e/ou emitir conclusão segura relativa ao fato.',
          ),
        );
      }
    }

    return buffer.toString();
  }

  String _gerarSecaoDescricaoLocal(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    // Título da seção "4. DESCRIÇÃO DO LOCAL"
    buffer.writeln(_gerarTituloSecao('4. DESCRIÇÃO DO LOCAL'));

    // 4.1 Endereço
    buffer.writeln(_gerarTituloSubSecao('4.1 Endereço'));
    final endereco =
        ficha.local?.endereco ?? ficha.dadosSolicitacao.endereco ?? '';
    final municipio =
        ficha.local?.municipio ?? ficha.dadosSolicitacao.municipio ?? '';

    String enderecoCompleto = endereco;
    if (municipio.isNotEmpty) {
      if (enderecoCompleto.isNotEmpty) {
        enderecoCompleto += ', $municipio';
      } else {
        enderecoCompleto = municipio;
      }
    }

    if (enderecoCompleto.isEmpty) {
      enderecoCompleto = 'Não informado';
    }

    // Adicionar coordenadas no mesmo formato da ficha (DMS)
    final coordS = ficha.local?.coordenadasSFormatada;
    final coordW = ficha.local?.coordenadasWFormatada;

    if (coordS != null && coordW != null) {
      // Adicionar vírgula no final do endereço, depois as coordenadas e ponto final
      enderecoCompleto += ', $coordS $coordW.';
    } else {
      // Se não houver coordenadas, apenas adicionar ponto final
      if (enderecoCompleto != 'Não informado') {
        enderecoCompleto += '.';
      }
    }

    buffer.writeln(_gerarParagrafoHistorico(enderecoCompleto));

    // 4.2 Descrição
    buffer.writeln(_gerarTituloSubSecao('4.2 Descrição'));

    // Para CVLI: incluir descrições de todos os locais selecionados (mediato, imediato, relacionado)
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli &&
        ficha.localFurto != null) {
      final lf = ficha.localFurto!;
      final descricoes = <String>[];

      // Local Mediato
      if (lf.classificacaoMediato == true &&
          lf.descricaoLocalMediato != null &&
          lf.descricaoLocalMediato!.isNotEmpty) {
        descricoes.add('Mediato: ${lf.descricaoLocalMediato}');
      }

      // Local Imediato
      if (lf.classificacaoImediato == true &&
          lf.descricaoLocalImediato != null &&
          lf.descricaoLocalImediato!.isNotEmpty) {
        descricoes.add('Imediato: ${lf.descricaoLocalImediato}');
      }

      // Local Relacionado
      if (lf.classificacaoRelacionado == true &&
          lf.descricaoLocalRelacionado != null &&
          lf.descricaoLocalRelacionado!.isNotEmpty) {
        descricoes.add('Relacionado: ${lf.descricaoLocalRelacionado}');
      }

      if (descricoes.isEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Não informado'));
      } else {
        // Separar cada descrição em um parágrafo
        for (final descricao in descricoes) {
          buffer.writeln(_gerarParagrafoHistorico(descricao));
        }
      }
    } else {
      // Para outros casos: usar descrição geral
      final descricaoLocal = ficha.localFurto?.descricaoLocal ?? '';

      if (descricaoLocal.isEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Não informado'));
      } else {
        buffer.writeln(_gerarParagrafoHistorico(descricaoLocal));
      }
    }

    return buffer.toString();
  }

  String _gerarTituloSubSecao(String titulo) {
    // Subtítulo de seção (4.1, 4.2, etc.) - negrito, sem recuo
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(titulo)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _formatarMeiosIsolamento(FichaBaseModel fb) {
    final meios = <String>[];

    if (fb.isolamentoViatura == true) meios.add('viatura');
    if (fb.isolamentoCones == true) meios.add('cones');
    if (fb.isolamentoFitaZebrada == true) meios.add('fita zebrada');
    if (fb.isolamentoPresencaFisica == true) meios.add('presença física');
    if (fb.isolamentoCuriososVoltaCorpo == true) {
      meios.add('curiosos ao redor do corpo');
    }
    if (fb.isolamentoCorpoCobertoMovimentado == true) {
      meios.add('corpo coberto/movimentado');
    }
    if (fb.isolamentoDocumentosManuseados == true) {
      meios.add('documentos manuseados');
    }
    if (fb.isolamentoVestigiosRecolhidos == true) {
      meios.add('vestígios recolhidos');
    }
    if (fb.isolamentoAmpliacaoPerimetro == true) {
      meios.add('ampliação do perímetro');
    }

    if (meios.isEmpty) {
      return 'meios não especificados';
    }

    if (meios.length == 1) {
      return meios[0];
    } else if (meios.length == 2) {
      return '${meios[0]} e ${meios[1]}';
    } else {
      final ultimo = meios.removeLast();
      return '${meios.join(', ')}, e $ultimo';
    }
  }

  String _gerarSecaoExames(FichaCompletaModel ficha, {int qtdFotos = 0}) {
    final buffer = StringBuffer();

    // Para CVLI: seção "5. DAS IMAGENS"
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
      buffer.writeln(_gerarTituloSecao('5. DAS IMAGENS'));

      // Converter quantidade para número por extenso
      String qtdPorExtenso = _numeroPorExtenso(qtdFotos);
      String qtdNumerica = qtdFotos.toString().padLeft(2, '0');

      // Gerar parágrafo com "XX" em vermelho
      buffer.writeln(
        _gerarParagrafoHistoricoComTextoColorido(
          'Integra o presente laudo o levantamento fotográfico composto por $qtdNumerica ($qtdPorExtenso) imagens, todas produzidas pelo próprio Perito Criminal responsável pela elaboração deste documento. As fotografias encontram-se organizadas e inseridas a partir da página ',
          'XX',
          ', destinando-se à documentação objetiva do local, dos vestígios e das condições observadas durante a realização dos exames periciais.',
        ),
      );

      return buffer.toString();
    }

    // Para outros casos: seção "5. EXAMES" (comportamento original)
    buffer.writeln(_gerarTituloSecao('5. EXAMES'));

    // Subtítulo "5.1 No Local"
    buffer.writeln(_gerarTituloSubSecao('5.1 No Local'));

    // Texto introdutório
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Quando da Perícia Criminal, constatou-se que havia:',
      ),
    );

    bool evidenciaPresente(EvidenciaModel e) {
      final coord1 = (e.coordenada1 ?? '').trim();
      final coord2 = (e.coordenada2 ?? '').trim();
      final desc = (e.descricao ?? '').trim();
      final obs = (e.observacoesEspeciais ?? '').trim();
      final recolhidoSim = e.recolhidoSim == true;
      return coord1.isNotEmpty ||
          coord2.isNotEmpty ||
          desc.isNotEmpty ||
          obs.isNotEmpty ||
          recolhidoSim;
    }

    String detalhesEvidencia(EvidenciaModel e) {
      final partes = <String>[];
      final obs = (e.observacoesEspeciais ?? '').trim();
      final desc = (e.descricao ?? '').trim();
      if (obs.isNotEmpty) partes.add(obs);
      if (desc.isNotEmpty) partes.add(desc);
      if (partes.isEmpty) return '';
      return partes.join('. ');
    }

    EvidenciaModel? getEvidenciaPorId(List<EvidenciaModel> evids, String id) {
      for (final e in evids) {
        if (e.id == id) return e;
      }
      return null;
    }

    String textoFixoNatural(EvidenciaModel? e, String simBase, String naoBase) {
      if (e == null) return naoBase;
      if (evidenciaPresente(e)) {
        final detalhes = detalhesEvidencia(e);
        return detalhes.isEmpty ? simBase : '$simBase $detalhes.';
      }
      return naoBase;
    }

    // Listar evidências da ficha (EV01–EV07 sempre aparecem, em texto natural)
    final evidencias = ficha.evidenciasFurto?.evidencias ?? [];
    final evidenciasListadas = <String>[];

    final ev01 = getEvidenciaPorId(evidencias, 'EV01');
    final ev02 = getEvidenciaPorId(evidencias, 'EV02');
    final ev03 = getEvidenciaPorId(evidencias, 'EV03');
    final ev04 = getEvidenciaPorId(evidencias, 'EV04');
    final ev05 = getEvidenciaPorId(evidencias, 'EV05');
    final ev06 = getEvidenciaPorId(evidencias, 'EV06');
    final ev07 = getEvidenciaPorId(evidencias, 'EV07');

    evidenciasListadas.add(
      textoFixoNatural(
        ev01,
        'Houve destruição ou rompimento de obstáculo à subtração da coisa.',
        'Não foram observados vestígios de destruição ou rompimento de obstáculo à subtração da coisa.',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev02,
        'Houve indícios compatíveis com escalada ou destreza.',
        'Não foram observados vestígios compatíveis com escalada ou destreza.',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev03,
        'Houve indícios de uso de instrumentos.',
        'Não foram observados vestígios de uso de instrumentos.',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev04,
        'Houve indícios de emprego de chave falsa.',
        'Não foram observados vestígios de emprego de chave falsa.',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev05,
        'Houve indícios compatíveis com concurso de duas ou mais pessoas.',
        'Os vestígios detectados não foram suficientes para concluir acerca do concurso de duas ou mais pessoas.',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev06,
        'Constatou-se ausência de fechaduras (ou similares).',
        'Não foi constatada ausência de fechaduras (ou similares).',
      ),
    );
    evidenciasListadas.add(
      textoFixoNatural(
        ev07,
        'Foram observados vestígios de recenticidade.',
        'Não foram observados vestígios de recenticidade.',
      ),
    );

    // Evidências dinâmicas (EV08+) entram sempre (se existirem)
    final dinamicas = <EvidenciaModel>[];
    for (final e in evidencias) {
      final numId = int.tryParse(e.id.replaceAll('EV', '')) ?? 0;
      final isFixa = numId > 0 && numId <= 7;
      if (!isFixa) dinamicas.add(e);
    }
    dinamicas.sort((a, b) {
      final numA = int.tryParse(a.id.replaceAll('EV', '')) ?? 0;
      final numB = int.tryParse(b.id.replaceAll('EV', '')) ?? 0;
      return numA.compareTo(numB);
    });

    // Verificar materiais apreendidos (sangue humano e impressões papilares são evidências)
    final materiaisApreendidos =
        ficha.evidenciasFurto?.materiaisApreendidos ?? [];
    final materialSangue = materiaisApreendidos
        .where((m) => m.descricao == 'Sangue humano')
        .firstOrNull;
    final materialImpressoes = materiaisApreendidos
        .where((m) => m.descricao == 'Fragmentos de impressões papilares')
        .firstOrNull;

    int numeroRodape = 1;
    int contadorItem = 1; // Para letras a), b), c), etc.

    // Listar evidências (texto natural)
    for (final texto in evidenciasListadas) {
      final letra = String.fromCharCode(96 + contadorItem); // a, b, c, etc.
      buffer.writeln(_gerarParagrafoLista('$letra) $texto'));
      contadorItem++;
    }

    // Listar evidências dinâmicas (se houver)
    for (final evidencia in dinamicas) {
      final letra = String.fromCharCode(96 + contadorItem); // a, b, c, etc.
      final desc = (evidencia.descricao ?? '').trim();
      final base = evidencia.identificacao.trim().isEmpty
          ? 'Evidência'
          : evidencia.identificacao.trim();
      final textoItem = desc.isEmpty ? base : '$base: $desc';
      buffer.writeln(_gerarParagrafoLista('$letra) $textoItem'));
      contadorItem++;
    }

    // Adicionar Sangue humano como evidência (se estiver na lista de materiais)
    if (materialSangue != null) {
      final letra = String.fromCharCode(96 + contadorItem);
      final localSangue =
          materialSangue.descricaoDetalhada ?? 'não especificado';
      // Texto específico para sangue humano conforme solicitado
      final textoComRodape =
          '$letra) Constatou-se a presença de manchas com aspecto hemático na superfície $localSangue. Procedeu-se a teste imunocromatográfico rápido para hemoglobina humana (hHb), com resultado positivo, compatível com a presença de sangue humano.¹';

      buffer.writeln(
        _gerarParagrafoComSobrescritoLista(textoComRodape, numeroRodape),
      );

      numeroRodape++;
      contadorItem++;
    }

    // Adicionar Fragmentos de impressões papilares como evidência (se estiver na lista)
    if (materialImpressoes != null) {
      final letra = String.fromCharCode(96 + contadorItem);
      String textoItem = '$letra) ${materialImpressoes.descricao}';

      // Adicionar descrição detalhada se houver
      if (materialImpressoes.descricaoDetalhada != null &&
          materialImpressoes.descricaoDetalhada!.isNotEmpty) {
        textoItem += ': ${materialImpressoes.descricaoDetalhada}';
      }

      buffer.writeln(_gerarParagrafoLista(textoItem));
      contadorItem++;
    }

    // Se não houver impressões papilares, adicionar como último item
    if (materialImpressoes == null) {
      final letra = String.fromCharCode(96 + contadorItem);
      buffer.writeln(
        _gerarParagrafoLista(
          '$letra) Foi realizada pesquisa de Impressões Papilares no local, entretanto, não foi encontrada nenhuma Impressão e/ou fragmento apropriado para confronto.',
        ),
      );
    }

    // 5.2 EXAMES COMPLEMENTARES (automatizado a partir de Materiais Apreendidos/Encaminhados)
    buffer.writeln(_gerarTituloSubSecao('5.2 Exames Complementares'));

    String? getQuantidadeMaterial(String descricao) {
      final m = materiaisApreendidos
          .where((x) => x.descricao == descricao)
          .firstOrNull;
      final q = m?.quantidade?.trim();
      return (q == null || q.isEmpty) ? null : q;
    }

    String formatarQtdComUnidade(
      String quantidade,
      List<String> palavrasUnidade,
    ) {
      final qLower = quantidade.toLowerCase();
      final jaTemUnidade = palavrasUnidade.any((p) => qLower.contains(p));
      if (jaTemUnidade) return quantidade;
      // Se for apenas número/abreviação, colamos a unidade por fora.
      // Ex.: "02" -> "02 suabes"
      return quantidade;
    }

    bool descricaoPareceTecnicaPapilo(String? texto) {
      if (texto == null) return false;
      final t = texto.toLowerCase();
      return t.contains('reveladas por') ||
          t.contains('pó regular') ||
          t.contains('po regular') ||
          t.contains('aplicação de pó') ||
          t.contains('aplicacao de po');
    }

    final qtdSuabesRaw = getQuantidadeMaterial('Suabe');
    final qtdLevantadoresRaw = getQuantidadeMaterial(
      'Levantador papiloscópico',
    );
    final qtdGlossyRaw = getQuantidadeMaterial('Papel glossy');

    final temBiologicoComplementar =
        materialSangue != null || (qtdSuabesRaw != null);
    final temPapiloComplementar =
        materialImpressoes != null ||
        (qtdLevantadoresRaw != null) ||
        (qtdGlossyRaw != null);

    if (!temBiologicoComplementar && !temPapiloComplementar) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não houve coleta de vestígios biológicos e/ou levantamento papiloscópico que demandassem exames complementares.',
        ),
      );
    } else {
      // 5.2.1 Exames na Unidade
      buffer.writeln(_gerarTituloSubSecao('5.2.1 Exames na Unidade'));
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Os vestígios coletados foram devidamente acondicionados, identificados e encaminhados para processamento na unidade, conforme rotina técnica.',
        ),
      );

      // 5.2.2 Levantamento Papiloscópico
      if (temPapiloComplementar) {
        buffer.writeln(
          _gerarTituloSubSecao('5.2.2 Levantamento Papiloscópico'),
        );

        final superfPapiloRaw = materialImpressoes?.descricaoDetalhada?.trim();
        final superfPapilo =
            (superfPapiloRaw == null ||
                superfPapiloRaw.isEmpty ||
                descricaoPareceTecnicaPapilo(superfPapiloRaw))
            ? 'não especificadas'
            : superfPapiloRaw;

        final partesMeios = <String>[];
        if (qtdLevantadoresRaw != null) {
          final qtd = formatarQtdComUnidade(qtdLevantadoresRaw, [
            'levantador',
            'levantadores',
          ]);
          partesMeios.add('$qtd levantadores');
        }
        if (qtdGlossyRaw != null) {
          final qtd = formatarQtdComUnidade(qtdGlossyRaw, ['glossy', 'papel']);
          // Mantém o termo como o usuário usa no app
          partesMeios.add('$qtd papel glossy');
        }

        final meiosTexto = partesMeios.isEmpty
            ? 'através de levantadores e/ou suportes'
            : 'através de ${partesMeios.join(' e ')}';

        buffer.writeln(
          _gerarParagrafoHistorico(
            'Foram coletados no local fragmentos de Impressões Papilares, $meiosTexto, nas superfícies $superfPapilo, que foram encaminhados ao Laboratório de Papiloscopia Forense – LAPAP/DPTEC, para exame de análise de Impressões Papilares.',
          ),
        );
      }

      // 5.2.3 Levantamento de Material Biológico
      if (temBiologicoComplementar) {
        buffer.writeln(
          _gerarTituloSubSecao('5.2.3 Levantamento de Material Biológico'),
        );

        final localSangue =
            (materialSangue?.descricaoDetalhada?.trim().isNotEmpty ?? false)
            ? materialSangue!.descricaoDetalhada!.trim()
            : 'não especificado';

        final qtdSuabes = qtdSuabesRaw != null
            ? formatarQtdComUnidade(qtdSuabesRaw, ['suabe', 'suabes'])
            : null;

        final porMeioTexto = qtdSuabes == null
            ? 'por meio de suabe(s)'
            : 'por meio de $qtdSuabes suabes';

        buffer.writeln(
          _gerarParagrafoHistorico(
            'Foi coletado, $porMeioTexto, material na superfície $localSangue, o qual foi encaminhado ao Laboratório de Biologia e DNA Forense – LBDF/DALF, para pesquisa de material genético.',
          ),
        );
      }
    }

    // Adicionar rodapés no final da seção (se houver sangue humano)
    if (materialSangue != null) {
      buffer.writeln(_gerarParagrafoVazio());
      buffer.writeln(
        _gerarRodape(
          numeroRodape - 1, // Já foi incrementado antes
          'Feca Cult One Step Teste é um teste imunocromatográfico rápido que detecta qualitativamente e especificamente a hemoglobina humana (hHb). O teste é sensível a concentrações de hHb iguais ou superiores a 40ng/mL, mas, em alguns casos, pode detectar resultados positivos em concentrações menores.',
        ),
      );
    }

    return buffer.toString();
  }

  Future<String> _gerarSecaoAnaliseInterpretacao(
    FichaCompletaModel ficha,
  ) async {
    final buffer = StringBuffer();

    // Para CVLI: seção "6. DOS EXAMES"
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
      buffer.writeln(_gerarTituloSecao('6. DOS EXAMES'));

      // 6.1 Do Local
      buffer.writeln(_gerarTituloSubSecao('6.1 Do Local'));
      buffer.writeln(await _gerarSecaoExamesLocal(ficha));

      // 6.2 Do(s) Veículo(s)
      if (ficha.veiculos != null && ficha.veiculos!.isNotEmpty) {
        buffer.writeln(_gerarTituloSubSecao('6.2 Do(s) Veículo(s)'));
        buffer.writeln(await _gerarSecaoExamesVeiculos(ficha));
      }

      // 6.3 Do(s) Cadáver(es)
      if (ficha.cadaveres != null && ficha.cadaveres!.isNotEmpty) {
        buffer.writeln(await _gerarSecaoExamesCadaveres(ficha));
      }

      return buffer.toString();
    }

    // Para outros casos: seção "6. ANÁLISE E INTERPRETAÇÃO DOS VESTÍGIOS" (comportamento original)
    buffer.writeln(
      _gerarTituloSecao('6. ANÁLISE E INTERPRETAÇÃO DOS VESTÍGIOS'),
    );

    // Texto introdutório
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Com base nos vestígios supracitados, o Perito Criminal Relator aponta que a dinâmica mais provável foi a seguinte:',
      ),
    );

    // Dinâmica do modus operandi
    final dinamica = ficha.modusOperandi?.trim();
    if (dinamica != null && dinamica.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(dinamica));
    } else {
      // Se não houver dinâmica, deixar em branco ou colocar texto padrão
      buffer.writeln(_gerarParagrafoHistorico(''));
    }

    return buffer.toString();
  }

  Future<String> _gerarSecaoExamesLocal(FichaCompletaModel ficha) async {
    final buffer = StringBuffer();

    if (ficha.localFurto == null) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
      return buffer.toString();
    }

    final lf = ficha.localFurto!;

    // Local Mediato
    if (lf.classificacaoMediato == true) {
      buffer.writeln(_gerarParagrafoHistorico('Local Mediato:'));

      // Descrição do local mediato
      if (lf.descricaoLocalMediato != null &&
          lf.descricaoLocalMediato!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(lf.descricaoLocalMediato!));
      }

      // Listar vestígios
      if (lf.vestigiosMediato != null && lf.vestigiosMediato!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var i = 0; i < lf.vestigiosMediato!.length; i++) {
          final vestigio = lf.vestigiosMediato![i];
          final textoVestigio = await _gerarTextoVestigioLocal(vestigio, i);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
      } else if (lf.semVestigiosMediato == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Não foram encontrados vestígios neste local.',
          ),
        );
      }

      buffer.writeln(_gerarParagrafoVazio());
    }

    // Local Imediato
    if (lf.classificacaoImediato == true) {
      buffer.writeln(_gerarParagrafoHistorico('Local Imediato:'));

      // Descrição do local imediato
      if (lf.descricaoLocalImediato != null &&
          lf.descricaoLocalImediato!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(lf.descricaoLocalImediato!));
      }

      // Listar vestígios
      if (lf.vestigiosImediato != null && lf.vestigiosImediato!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var i = 0; i < lf.vestigiosImediato!.length; i++) {
          final vestigio = lf.vestigiosImediato![i];
          final textoVestigio = await _gerarTextoVestigioLocal(vestigio, i);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
      } else if (lf.semVestigiosImediato == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Não foram encontrados vestígios neste local.',
          ),
        );
      }

      buffer.writeln(_gerarParagrafoVazio());
    }

    // Local Relacionado
    if (lf.classificacaoRelacionado == true) {
      buffer.writeln(_gerarParagrafoHistorico('Local Relacionado:'));

      // Descrição do local relacionado
      if (lf.descricaoLocalRelacionado != null &&
          lf.descricaoLocalRelacionado!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(lf.descricaoLocalRelacionado!));
      }

      // Listar vestígios
      if (lf.vestigiosRelacionado != null &&
          lf.vestigiosRelacionado!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var i = 0; i < lf.vestigiosRelacionado!.length; i++) {
          final vestigio = lf.vestigiosRelacionado![i];
          final textoVestigio = await _gerarTextoVestigioLocal(vestigio, i);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
      } else if (lf.semVestigiosRelacionado == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Não foram encontrados vestígios neste local.',
          ),
        );
      }
    }

    return buffer.toString();
  }

  /// Gera o texto de um vestígio de local com letra e informações de cadeia de custódia
  Future<String> _gerarTextoVestigioLocal(
    VestigioLocalModel vestigio,
    int indice,
  ) async {
    final letra = _indicePraLetra(indice);
    final partes = <String>[];

    // Descrição do vestígio
    String descricao = vestigio.descricao ?? '';
    if (vestigio.isSangueHumano) {
      descricao = '${descricao.isNotEmpty ? '$descricao - ' : ''}Sangue humano';
    }
    if (descricao.isNotEmpty) {
      partes.add(descricao);
    }

    // Coordenadas (se houver)
    if (vestigio.coordenadaX != null &&
        vestigio.coordenadaX!.isNotEmpty &&
        vestigio.coordenadaY != null &&
        vestigio.coordenadaY!.isNotEmpty) {
      partes.add(
        'Coordenadas: X=${vestigio.coordenadaX}, Y=${vestigio.coordenadaY}',
      );
    }

    // Altura (se houver)
    if (vestigio.alturaRelacaoPiso != null &&
        vestigio.alturaRelacaoPiso!.isNotEmpty) {
      partes.add('Altura: ${vestigio.alturaRelacaoPiso}');
    }

    // Informações de Cadeia de Custódia
    if (vestigio.tipoAcao == TipoAcaoVestigio.coletado) {
      // Coletado
      final partesColeta = <String>[];
      partesColeta.add('Coletado');

      if (vestigio.coletadoPor != null && vestigio.coletadoPor!.isNotEmpty) {
        partesColeta.add('por ${vestigio.coletadoPor}');
      }

      if (vestigio.dataHoraColeta != null &&
          vestigio.dataHoraColeta!.isNotEmpty) {
        final horarioFormatado = _formatarHorario(vestigio.dataHoraColeta);
        partesColeta.add('às $horarioFormatado');
      }

      partes.add(partesColeta.join(' '));

      // Encaminhamento (destino)
      if (vestigio.tipoDestino != null && vestigio.destinoId != null) {
        String nomeDestino = '';
        if (vestigio.tipoDestino == TipoDestinoVestigio.unidade) {
          final unidades = await _unidadeService.listarUnidades();
          final unidade = unidades.firstWhere(
            (u) => u.id == vestigio.destinoId,
            orElse: () => throw Exception('Unidade não encontrada'),
          );
          nomeDestino = unidade.nome;
        } else if (vestigio.tipoDestino == TipoDestinoVestigio.laboratorio) {
          final laboratorios = await _laboratorioService.listarLaboratorios();
          final laboratorio = laboratorios.firstWhere(
            (l) => l.id == vestigio.destinoId,
            orElse: () => throw Exception('Laboratório não encontrado'),
          );
          nomeDestino = laboratorio.nome;
        }

        if (nomeDestino.isNotEmpty) {
          String textoEncaminhamento = 'Encaminhado para $nomeDestino';
          if (vestigio.numeroLacre != null &&
              vestigio.numeroLacre!.isNotEmpty) {
            textoEncaminhamento += ', Lacre nº ${vestigio.numeroLacre}';
          }
          partes.add(textoEncaminhamento);
        }
      }
    } else {
      // Apenas registrado
      partes.add('Apenas registrado');
    }

    return '$letra) ${partes.join('. ')}.';
  }

  /// Converte índice (0, 1, 2...) para letra (a, b, c...)
  String _indicePraLetra(int indice) {
    if (indice < 26) {
      return String.fromCharCode(97 + indice); // a-z
    } else {
      // Para mais de 26 itens: aa, ab, ac...
      final primeiro = indice ~/ 26 - 1;
      final segundo = indice % 26;
      return '${String.fromCharCode(97 + primeiro)}${String.fromCharCode(97 + segundo)}';
    }
  }

  /// Formata horário para o padrão institucional (xxhxxmin)
  /// Aceita formatos como "14:30", "14:30:00", "2024-01-15 14:30:00"
  String _formatarHorario(String? dataHora) {
    if (dataHora == null || dataHora.isEmpty) return '';

    // Tentar extrair apenas a parte do horário
    String horario = dataHora;

    // Se contém espaço, pegar a parte depois do espaço (assumindo formato "data hora")
    if (dataHora.contains(' ')) {
      final partes = dataHora.split(' ');
      if (partes.length >= 2) {
        horario = partes[1];
      }
    }

    // Se contém ":", formatar para xxhxxmin
    if (horario.contains(':')) {
      final partes = horario.split(':');
      if (partes.length >= 2) {
        final horas = partes[0].padLeft(2, '0');
        final minutos = partes[1].padLeft(2, '0');
        return '${horas}h${minutos}min';
      }
    }

    // Se não conseguir formatar, retornar o valor original
    return dataHora;
  }

  Future<String> _gerarSecaoExamesVeiculos(FichaCompletaModel ficha) async {
    final buffer = StringBuffer();

    if (ficha.veiculos == null || ficha.veiculos!.isEmpty) {
      return buffer.toString();
    }

    for (var i = 0; i < ficha.veiculos!.length; i++) {
      final veiculo = ficha.veiculos![i];

      // Título do veículo
      if (ficha.veiculos!.length > 1) {
        buffer.writeln(_gerarParagrafoHistorico('Veículo ${veiculo.numero}:'));
      }

      // Descrição do veículo
      final partesDescricao = <String>[];

      if (veiculo.tipoVeiculo != null) {
        String tipo = veiculo.tipoVeiculo!.label;
        if (veiculo.tipoVeiculo == TipoVeiculo.outro &&
            veiculo.tipoVeiculoOutro != null &&
            veiculo.tipoVeiculoOutro!.isNotEmpty) {
          tipo = veiculo.tipoVeiculoOutro!;
        }
        partesDescricao.add(tipo);
      }

      if (veiculo.marcaModelo != null && veiculo.marcaModelo!.isNotEmpty) {
        partesDescricao.add(veiculo.marcaModelo!);
      }

      if (veiculo.anoFabricacao != null && veiculo.anoFabricacao!.isNotEmpty) {
        partesDescricao.add('Ano Fabricação: ${veiculo.anoFabricacao}');
      }

      if (veiculo.anoModelo != null && veiculo.anoModelo!.isNotEmpty) {
        partesDescricao.add('Ano Modelo: ${veiculo.anoModelo}');
      }

      if (veiculo.cor != null && veiculo.cor!.isNotEmpty) {
        partesDescricao.add('Cor: ${veiculo.cor}');
      }

      if (veiculo.placa != null && veiculo.placa!.isNotEmpty) {
        partesDescricao.add('Placa: ${veiculo.placa}');
      }

      if (veiculo.localizacaoAmbiente != null &&
          veiculo.localizacaoAmbiente!.isNotEmpty) {
        partesDescricao.add('Localização: ${veiculo.localizacaoAmbiente}');
      }

      if (partesDescricao.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(partesDescricao.join(', ')));
      }

      // Listar vestígios do veículo
      if (veiculo.vestigios != null && veiculo.vestigios!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var j = 0; j < veiculo.vestigios!.length; j++) {
          final vestigio = veiculo.vestigios![j];
          final textoVestigio = await _gerarTextoVestigioVeiculo(vestigio, j);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
      }

      // Espaço entre veículos (exceto no último)
      if (i < ficha.veiculos!.length - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  /// Gera o texto de um vestígio de veículo com letra e informações de cadeia de custódia
  Future<String> _gerarTextoVestigioVeiculo(
    VestigioVeiculoModel vestigio,
    int indice,
  ) async {
    final letra = _indicePraLetra(indice);
    final partes = <String>[];

    // Descrição do vestígio
    String descricao = vestigio.descricao ?? '';
    if (vestigio.isSangueHumano) {
      descricao = '${descricao.isNotEmpty ? '$descricao - ' : ''}Sangue humano';
    }
    if (descricao.isNotEmpty) {
      partes.add(descricao);
    }

    // Localização no veículo
    if (vestigio.localizacao != null && vestigio.localizacao!.isNotEmpty) {
      partes.add('Localização no veículo: ${vestigio.localizacao}');
    }

    // Informações de Cadeia de Custódia
    if (vestigio.tipoAcao == TipoAcaoVestigioVeiculo.coletado) {
      // Coletado
      final partesColeta = <String>[];
      partesColeta.add('Coletado');

      if (vestigio.coletadoPor != null && vestigio.coletadoPor!.isNotEmpty) {
        partesColeta.add('por ${vestigio.coletadoPor}');
      }

      if (vestigio.dataHoraColeta != null &&
          vestigio.dataHoraColeta!.isNotEmpty) {
        final horarioFormatado = _formatarHorario(vestigio.dataHoraColeta);
        partesColeta.add('às $horarioFormatado');
      }

      partes.add(partesColeta.join(' '));

      // Encaminhamento (destino)
      if (vestigio.tipoDestino != null && vestigio.destinoId != null) {
        String nomeDestino = '';
        if (vestigio.tipoDestino == TipoDestinoVestigioVeiculo.unidade) {
          final unidades = await _unidadeService.listarUnidades();
          final unidade = unidades.firstWhere(
            (u) => u.id == vestigio.destinoId,
            orElse: () => throw Exception('Unidade não encontrada'),
          );
          nomeDestino = unidade.nome;
        } else if (vestigio.tipoDestino ==
            TipoDestinoVestigioVeiculo.laboratorio) {
          final laboratorios = await _laboratorioService.listarLaboratorios();
          final laboratorio = laboratorios.firstWhere(
            (l) => l.id == vestigio.destinoId,
            orElse: () => throw Exception('Laboratório não encontrado'),
          );
          nomeDestino = laboratorio.nome;
        }

        if (nomeDestino.isNotEmpty) {
          String textoEncaminhamento = 'Encaminhado para $nomeDestino';
          if (vestigio.numeroLacre != null &&
              vestigio.numeroLacre!.isNotEmpty) {
            textoEncaminhamento += ', Lacre nº ${vestigio.numeroLacre}';
          }
          partes.add(textoEncaminhamento);
        }
      }
    } else {
      // Apenas registrado
      partes.add('Apenas registrado');
    }

    return '$letra) ${partes.join('. ')}.';
  }

  /// Gera a seção 6.3 Do(s) Cadáver(es) para o laudo CVLI
  Future<String> _gerarSecaoExamesCadaveres(FichaCompletaModel ficha) async {
    final buffer = StringBuffer();

    if (ficha.cadaveres == null || ficha.cadaveres!.isEmpty) {
      return buffer.toString();
    }

    final qtdCadaveres = ficha.cadaveres!.length;
    final singular = qtdCadaveres == 1;

    // Título da seção
    if (singular) {
      buffer.writeln(_gerarTituloSubSecao('6.3 Do Cadáver'));
    } else {
      buffer.writeln(_gerarTituloSubSecao('6.3 Dos Cadáveres'));
    }

    for (var i = 0; i < qtdCadaveres; i++) {
      final cadaver = ficha.cadaveres![i];
      final prefixo = singular ? '6.3' : '6.3.${i + 1}';

      // Se múltiplos cadáveres, adicionar título do cadáver
      if (!singular) {
        buffer.writeln(_gerarParagrafoHistorico(''));
        buffer.writeln(
          _gerarParagrafoHistoricoNegrito('Cadáver ${cadaver.numero}'),
        );
      }

      // 6.3.X.1 Identificação
      buffer.writeln(_gerarTituloSubSubSecao('$prefixo.1 Identificação'));
      buffer.writeln(_gerarIdentificacaoCadaver(cadaver));

      // 6.3.X.2 Localização e Posição
      buffer.writeln(
        _gerarTituloSubSubSecao('$prefixo.2 Localização e Posição'),
      );
      buffer.writeln(_gerarLocalizacaoPosicaoCadaver(cadaver));

      // 6.3.X.3 Vestes e Acessórios
      buffer.writeln(_gerarTituloSubSubSecao('$prefixo.3 Vestes e Acessórios'));
      buffer.writeln(_gerarVestesAcessoriosCadaver(cadaver));

      // 6.3.X.4 Lesões e Demais Vestígios
      buffer.writeln(
        _gerarTituloSubSubSecao('$prefixo.4 Lesões e Demais Vestígios'),
      );
      buffer.writeln(_gerarLesoesDemaisVestigiosCadaver(cadaver));

      // Espaço entre cadáveres
      if (i < qtdCadaveres - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  /// Gera parágrafo com texto em negrito
  String _gerarParagrafoHistoricoNegrito(String texto) {
    final textoEscapado = _escapeXml(texto);
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:line="360" w:lineRule="auto"/>
    <w:jc w:val="both"/>
    <w:rPr>
      <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
      <w:sz w:val="$_fontSizeNormal"/>
      <w:b/>
    </w:rPr>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
      <w:sz w:val="$_fontSizeNormal"/>
      <w:b/>
    </w:rPr>
    <w:t>$textoEscapado</w:t>
  </w:r>
</w:p>''';
  }

  /// Gera título de sub-sub-seção (ex: 6.3.1.1)
  String _gerarTituloSubSubSecao(String titulo) {
    final textoEscapado = _escapeXml(titulo);
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:before="200" w:after="100" w:line="360" w:lineRule="auto"/>
    <w:jc w:val="both"/>
    <w:rPr>
      <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
      <w:sz w:val="$_fontSizeNormal"/>
      <w:b/>
    </w:rPr>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
      <w:sz w:val="$_fontSizeNormal"/>
      <w:b/>
    </w:rPr>
    <w:t>$textoEscapado</w:t>
  </w:r>
</w:p>''';
  }

  /// Gera texto de identificação do cadáver
  String _gerarIdentificacaoCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();
    final partes = <String>[];

    // Nome da vítima
    if (cadaver.nomeDaVitima != null && cadaver.nomeDaVitima!.isNotEmpty) {
      partes.add('Nome: ${cadaver.nomeDaVitima}');
    } else {
      partes.add('Nome: Não identificado');
    }

    // Documento de identificação
    if (cadaver.documentoIdentificacao != null &&
        cadaver.documentoIdentificacao!.isNotEmpty) {
      partes.add('Documento: ${cadaver.documentoIdentificacao}');
    }

    // Data de nascimento
    if (cadaver.dataNascimento != null && cadaver.dataNascimento!.isNotEmpty) {
      partes.add('Data de Nascimento: ${cadaver.dataNascimento}');
    }

    // Filiação
    if (cadaver.filiacao != null && cadaver.filiacao!.isNotEmpty) {
      partes.add('Filiação: ${cadaver.filiacao}');
    }

    // Número do laudo cadavérico
    if (cadaver.numeroLaudoCadaverico != null &&
        cadaver.numeroLaudoCadaverico!.isNotEmpty) {
      partes.add('Laudo Cadavérico: ${cadaver.numeroLaudoCadaverico}');
    }

    // Características físicas
    final caracteristicas = <String>[];

    if (cadaver.sexo != null) {
      caracteristicas.add('Sexo ${cadaver.sexo!.label.toLowerCase()}');
    }

    if (cadaver.faixaEtaria != null) {
      caracteristicas.add(
        'faixa etária ${cadaver.faixaEtaria!.label.toLowerCase()}',
      );
    }

    if (cadaver.compleicao != null) {
      caracteristicas.add(
        'compleição ${cadaver.compleicao!.label.toLowerCase()}',
      );
    }

    // Cabelo
    if (cadaver.corCabelo != null ||
        cadaver.tipoCabelo != null ||
        cadaver.tamanhoCabelo != null) {
      final cabelo = <String>[];
      if (cadaver.tamanhoCabelo != null) {
        cabelo.add(
          cadaver.tamanhoCabelo == TamanhoCabelo.outro
              ? cadaver.tamanhoCabeloOutro ?? ''
              : cadaver.tamanhoCabelo!.label.toLowerCase(),
        );
      }
      if (cadaver.tipoCabelo != null) {
        cabelo.add(
          cadaver.tipoCabelo == TipoCabelo.outro
              ? cadaver.tipoCabeloOutro ?? ''
              : cadaver.tipoCabelo!.label.toLowerCase(),
        );
      }
      if (cadaver.corCabelo != null) {
        cabelo.add(
          cadaver.corCabelo == CorCabelo.outro
              ? cadaver.corCabeloOutro ?? ''
              : cadaver.corCabelo!.label.toLowerCase(),
        );
      }
      if (cabelo.isNotEmpty) {
        caracteristicas.add('cabelo ${cabelo.join(", ")}');
      }
    }

    // Barba (se aplicável)
    if (cadaver.tipoBarba != null &&
        cadaver.tipoBarba != TipoBarba.naoSeAplica) {
      final barba = <String>[];
      barba.add(
        cadaver.tipoBarba == TipoBarba.outro
            ? cadaver.tipoBarbaOutro ?? ''
            : cadaver.tipoBarba!.label.toLowerCase(),
      );
      if (cadaver.tamanhoBarba != null) {
        barba.add(
          cadaver.tamanhoBarba == TamanhoBarba.outro
              ? cadaver.tamanhoBarbaOutro ?? ''
              : cadaver.tamanhoBarba!.label.toLowerCase(),
        );
      }
      if (cadaver.corBarba != null) {
        barba.add(
          cadaver.corBarba == CorBarba.outra
              ? cadaver.corBarbaOutra ?? ''
              : cadaver.corBarba!.label.toLowerCase(),
        );
      }
      caracteristicas.add('barba ${barba.join(", ")}');
    }

    if (caracteristicas.isNotEmpty) {
      partes.add('Características: ${caracteristicas.join(", ")}');
    }

    // Tatuagens e marcas
    if (cadaver.tatuagensMarcas != null &&
        cadaver.tatuagensMarcas!.isNotEmpty) {
      partes.add('Tatuagens/Marcas: ${cadaver.tatuagensMarcas}');
    }

    // Gerar parágrafos
    for (final parte in partes) {
      buffer.writeln(_gerarParagrafoHistorico(parte));
    }

    if (partes.isEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
    }

    return buffer.toString();
  }

  /// Gera texto de localização e posição do cadáver
  String _gerarLocalizacaoPosicaoCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    // Localização no ambiente
    if (cadaver.localizacaoAmbiente != null &&
        cadaver.localizacaoAmbiente!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico('Localização: ${cadaver.localizacaoAmbiente}'),
      );
    }

    // Coordenadas (se houver)
    final coordenadas = <String>[];

    if (cadaver.coordenadaCabecaX != null &&
        cadaver.coordenadaCabecaX!.isNotEmpty &&
        cadaver.coordenadaCabecaY != null &&
        cadaver.coordenadaCabecaY!.isNotEmpty) {
      String cabeca =
          'Cabeça: X=${cadaver.coordenadaCabecaX}, Y=${cadaver.coordenadaCabecaY}';
      if (cadaver.alturaCabeca != null && cadaver.alturaCabeca!.isNotEmpty) {
        cabeca += ', Altura=${cadaver.alturaCabeca}';
      }
      coordenadas.add(cabeca);
    }

    if (cadaver.coordenadaCentroTroncoX != null &&
        cadaver.coordenadaCentroTroncoX!.isNotEmpty &&
        cadaver.coordenadaCentroTroncoY != null &&
        cadaver.coordenadaCentroTroncoY!.isNotEmpty) {
      String tronco =
          'Centro do Tronco: X=${cadaver.coordenadaCentroTroncoX}, Y=${cadaver.coordenadaCentroTroncoY}';
      if (cadaver.alturaCentroTronco != null &&
          cadaver.alturaCentroTronco!.isNotEmpty) {
        tronco += ', Altura=${cadaver.alturaCentroTronco}';
      }
      coordenadas.add(tronco);
    }

    if (cadaver.coordenadaPesX != null &&
        cadaver.coordenadaPesX!.isNotEmpty &&
        cadaver.coordenadaPesY != null &&
        cadaver.coordenadaPesY!.isNotEmpty) {
      String pes =
          'Pés: X=${cadaver.coordenadaPesX}, Y=${cadaver.coordenadaPesY}';
      if (cadaver.alturaPes != null && cadaver.alturaPes!.isNotEmpty) {
        pes += ', Altura=${cadaver.alturaPes}';
      }
      coordenadas.add(pes);
    }

    if (coordenadas.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Coordenadas:'));
      for (final coord in coordenadas) {
        buffer.writeln(_gerarParagrafoHistorico('  - $coord'));
      }
    }

    // Posição do corpo
    final posicaoTexto = gerarTextoPosicaoCorpo(
      preset: cadaver.posicaoCorpoPreset,
      textoLivre: cadaver.posicaoCorpoLivre,
    );
    if (posicaoTexto.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Posição: $posicaoTexto'));
    }

    // Se não houver nenhuma informação
    if (buffer.isEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
    }

    return buffer.toString();
  }

  /// Gera texto de vestes e acessórios do cadáver
  String _gerarVestesAcessoriosCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    if (cadaver.vestes == null || cadaver.vestes!.isEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
      return buffer.toString();
    }

    for (var i = 0; i < cadaver.vestes!.length; i++) {
      final veste = cadaver.vestes![i];
      final letra = _indicePraLetra(i);
      final partes = <String>[];

      // Tipo/Marca
      if (veste.tipoMarca != null && veste.tipoMarca!.isNotEmpty) {
        partes.add(veste.tipoMarca!);
      }

      // Cor
      if (veste.cor != null && veste.cor!.isNotEmpty) {
        partes.add('cor ${veste.cor}');
      }

      // Características
      final caracteristicas = <String>[];
      if (veste.sujidades == true) caracteristicas.add('com sujidades');
      if (veste.sangue == true) caracteristicas.add('com manchas de sangue');
      if (veste.bolsos == true) {
        if (veste.bolsosVazios == true) {
          caracteristicas.add('bolsos vazios');
        } else {
          caracteristicas.add('com bolsos');
        }
      }

      if (caracteristicas.isNotEmpty) {
        partes.add(caracteristicas.join(', '));
      }

      // Notas
      if (veste.notas != null && veste.notas!.isNotEmpty) {
        partes.add(veste.notas!);
      }

      final descricaoVeste = partes.isNotEmpty
          ? partes.join(', ')
          : 'Sem descrição';
      buffer.writeln(_gerarParagrafoLista('$letra) $descricaoVeste.'));
    }

    // Pertences
    if (cadaver.pertences != null && cadaver.pertences!.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(''));
      buffer.writeln(
        _gerarParagrafoHistorico('Pertences: ${cadaver.pertences}'),
      );
    }

    return buffer.toString();
  }

  /// Gera texto de lesões e demais vestígios do cadáver
  String _gerarLesoesDemaisVestigiosCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    if (cadaver.lesoes == null || cadaver.lesoes!.isEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foram observadas lesões aparentes no exame externo.',
        ),
      );
      return buffer.toString();
    }

    for (var i = 0; i < cadaver.lesoes!.length; i++) {
      final lesao = cadaver.lesoes![i];
      final letra = _indicePraLetra(i);

      String descricaoLesao;
      if (lesao.isPaf && lesao.paf != null) {
        // Gerar descrição PAF automática
        descricaoLesao = gerarDescricaoPAF(
          regiao: lesao.regiao,
          tipo: lesao.paf!.tipo,
          distancia: lesao.paf!.distancia,
          diametro: lesao.paf!.diametro,
          sinais: lesao.paf!.sinais,
        );
      } else {
        // Lesão normal
        descricaoLesao = lesao.descricao ?? 'Lesão em ${lesao.regiao}';
        if (lesao.tipo != null && lesao.tipo!.isNotEmpty) {
          descricaoLesao = '${lesao.tipo}: $descricaoLesao';
        }
      }

      buffer.writeln(_gerarParagrafoLista('$letra) $descricaoLesao'));
    }

    // Exames complementares do cadáver (rigidez, hipóstase, secreções)
    buffer.writeln(_gerarParagrafoHistorico(''));
    buffer.writeln(_gerarParagrafoHistoricoNegrito('Exames no Local:'));

    // Rigidez Cadavérica
    final rigidez = <String>[];
    if (cadaver.rigidezMandibula != null) {
      rigidez.add('Mandíbula: ${cadaver.rigidezMandibula!.label}');
    }
    if (cadaver.rigidezMemSuperior != null) {
      rigidez.add('Membros Superiores: ${cadaver.rigidezMemSuperior!.label}');
    }
    if (cadaver.rigidezMemInferior != null) {
      rigidez.add('Membros Inferiores: ${cadaver.rigidezMemInferior!.label}');
    }
    if (rigidez.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico('Rigidez Cadavérica: ${rigidez.join("; ")}'),
      );
    }

    // Manchas de Hipóstase
    if (cadaver.hipostaseEstado != null || cadaver.hipostasePosicao != null) {
      final hipostase = <String>[];
      if (cadaver.hipostaseEstado != null) {
        hipostase.add(cadaver.hipostaseEstado!.label);
      }
      if (cadaver.hipostasePosicao != null &&
          cadaver.hipostasePosicao!.isNotEmpty) {
        hipostase.add('em ${cadaver.hipostasePosicao}');
      }
      if (cadaver.hipostaseCompativeis == true) {
        hipostase.add('compatíveis com a posição');
      } else if (cadaver.hipostaseCompativeis == false) {
        hipostase.add('incompatíveis com a posição');
      }
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Manchas de Hipóstase: ${hipostase.join(", ")}',
        ),
      );
    }

    // Secreções
    final secrecoes = <String>[];
    if (cadaver.secrecaoNasal == true) {
      secrecoes.add(
        'Nasal${cadaver.secrecaoNasalTipo != null ? " (${cadaver.secrecaoNasalTipo})" : ""}',
      );
    }
    if (cadaver.secrecaoOral == true) {
      secrecoes.add(
        'Oral${cadaver.secrecaoOralTipo != null ? " (${cadaver.secrecaoOralTipo})" : ""}',
      );
    }
    if (cadaver.secrecaoAnal == true) {
      secrecoes.add(
        'Anal${cadaver.secrecaoAnalTipo != null ? " (${cadaver.secrecaoAnalTipo})" : ""}',
      );
    }
    if (cadaver.secrecaoPenianaVaginal == true) {
      secrecoes.add(
        'Genital${cadaver.secrecaoPenianaVaginalTipo != null ? " (${cadaver.secrecaoPenianaVaginalTipo})" : ""}',
      );
    }
    if (secrecoes.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico('Secreções: ${secrecoes.join(", ")}'),
      );
    } else {
      buffer.writeln(_gerarParagrafoHistorico('Secreções: Não observadas'));
    }

    // Outras observações
    if (cadaver.outrasObservacoes != null &&
        cadaver.outrasObservacoes!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico('Observações: ${cadaver.outrasObservacoes}'),
      );
    }

    return buffer.toString();
  }

  /// Verifica se há dados de dano realmente preenchidos (pelo menos um campo não nulo)
  bool _temDadosDanoPreenchidos(FichaCompletaModel ficha) {
    if (ficha.dano == null) return false;

    final dano = ficha.dano!;

    // Verificar campos booleanos (Sim/Não)
    if (dano.substanciaInflamavelExplosivaSim == true ||
        dano.substanciaInflamavelExplosivaNao == true) {
      return true;
    }
    if (dano.danoPatrimonioPublicoSim == true ||
        dano.danoPatrimonioPublicoNao == true) {
      return true;
    }
    if (dano.prejuizoConsideravelSim == true ||
        dano.prejuizoConsideravelNao == true) {
      return true;
    }
    if (dano.identificarInstrumentoSubstanciaSim == true ||
        dano.identificarInstrumentoSubstanciaNao == true) {
      return true;
    }
    if (dano.identificacaoVestigioSim == true ||
        dano.identificacaoVestigioNao == true) {
      return true;
    }
    if (dano.identificarNumeroPessoasSim == true ||
        dano.identificarNumeroPessoasNao == true) {
      return true;
    }
    if (dano.vestigiosAutoriaSim == true || dano.vestigiosAutoriaNao == true) {
      return true;
    }
    if (dano.identificarDinamicaSim == true ||
        dano.identificarDinamicaNao == true) {
      return true;
    }

    // Verificar campos de texto
    if (dano.qualInstrumentoSubstancia != null &&
        dano.qualInstrumentoSubstancia!.trim().isNotEmpty) {
      return true;
    }
    if (dano.qualVestigio != null && dano.qualVestigio!.trim().isNotEmpty) {
      return true;
    }
    if (dano.danoCausado != null && dano.danoCausado!.trim().isNotEmpty) {
      return true;
    }
    if (dano.valorEstimadoPrejuizos != null &&
        dano.valorEstimadoPrejuizos!.trim().isNotEmpty) {
      return true;
    }
    if (dano.numeroPessoas != null && dano.numeroPessoas!.trim().isNotEmpty) {
      return true;
    }
    if (dano.quaisVestigiosAutoria != null &&
        dano.quaisVestigiosAutoria!.trim().isNotEmpty) {
      return true;
    }
    if (dano.dinamicaEvento != null && dano.dinamicaEvento!.trim().isNotEmpty) {
      return true;
    }

    return false;
  }

  String _gerarSecaoQuesitosFurto(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    // Título da seção "7. QUESITOS"
    buffer.writeln(_gerarTituloSecao('7. QUESITOS'));
    buffer.writeln(_gerarParagrafoVazio());

    final evidencias = ficha.evidenciasFurto?.evidencias ?? [];

    EvidenciaModel? getEvidencia(String id) {
      for (final e in evidencias) {
        if (e.id == id) return e;
      }
      return null;
    }

    bool presente(EvidenciaModel? e) {
      if (e == null) return false;
      final coord1 = (e.coordenada1 ?? '').trim();
      final coord2 = (e.coordenada2 ?? '').trim();
      final desc = (e.descricao ?? '').trim();
      final obs = (e.observacoesEspeciais ?? '').trim();
      final recolhidoSim = e.recolhidoSim == true;
      return coord1.isNotEmpty ||
          coord2.isNotEmpty ||
          desc.isNotEmpty ||
          obs.isNotEmpty ||
          recolhidoSim;
    }

    String detalhes(EvidenciaModel? e) {
      if (e == null) return '';
      final partes = <String>[];
      final obs = (e.observacoesEspeciais ?? '').trim();
      final desc = (e.descricao ?? '').trim();
      if (obs.isNotEmpty) partes.add(obs);
      if (desc.isNotEmpty) partes.add(desc);
      if (partes.isEmpty) return '';
      return partes.join('. ');
    }

    String respostaSimComDetalhes(EvidenciaModel? e, String base) {
      final det = detalhes(e);
      if (det.isEmpty) return 'Sim. $base';
      return 'Sim. $base $det.';
    }

    // 7.1 – EV01
    final ev01 = getEvidencia('EV01');
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.1 Houve destruição ou rompimento de obstáculo à subtração da coisa?',
      ),
    );
    buffer.writeln(
      _gerarParagrafoHistorico(
        presente(ev01)
            ? respostaSimComDetalhes(
                ev01,
                'Houve destruição/rompimento de obstáculo.',
              )
            : 'Sem elementos materiais.',
      ),
    );

    // 7.2 – EV02
    final ev02 = getEvidencia('EV02');
    buffer.writeln(
      _gerarTituloSubSecao('7.2 Houve uso de escalada ou destreza?'),
    );
    buffer.writeln(
      _gerarParagrafoHistorico(
        presente(ev02)
            ? respostaSimComDetalhes(
                ev02,
                'Houve indícios compatíveis com escalada/destreza.',
              )
            : 'Sem elementos materiais.',
      ),
    );

    // 7.3 – EV04
    final ev04 = getEvidencia('EV04');
    buffer.writeln(_gerarTituloSubSecao('7.3 Houve emprego de chave falsa?'));
    buffer.writeln(
      _gerarParagrafoHistorico(
        presente(ev04)
            ? respostaSimComDetalhes(
                ev04,
                'Houve indícios compatíveis com emprego de chave falsa.',
              )
            : 'Sem elementos materiais.',
      ),
    );

    // 7.4 – EV05
    final ev05 = getEvidencia('EV05');
    buffer.writeln(
      _gerarTituloSubSecao('7.4 Houve concurso de duas ou mais pessoas?'),
    );
    buffer.writeln(
      _gerarParagrafoHistorico(
        presente(ev05)
            ? respostaSimComDetalhes(
                ev05,
                'Os vestígios são compatíveis com a presença de dois ou mais indivíduos no local do fato.',
              )
            : 'Sem elementos materiais. Os vestígios detectados não foram suficientes para concluir acerca da presença de dois ou mais indivíduos no local do fato.',
      ),
    );

    // 7.5 – EV07
    final ev07 = getEvidencia('EV07');
    buffer.writeln(
      _gerarTituloSubSecao('7.5 Os vestígios indicam recenticidade?'),
    );
    buffer.writeln(
      _gerarParagrafoHistorico(
        presente(ev07)
            ? respostaSimComDetalhes(
                ev07,
                'Os vestígios indicam recenticidade.',
              )
            : 'Sem elementos materiais.',
      ),
    );

    return buffer.toString();
  }

  String _gerarSecaoQuesitosDano(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    // Título da seção "7. QUESITOS"
    buffer.writeln(_gerarTituloSecao('7. QUESITOS'));
    buffer.writeln(_gerarParagrafoVazio());

    final dano = ficha.dano!;

    // 7.1 – Substância inflamável ou explosiva
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.1 Houve o emprego de substância inflamável ou explosiva?',
      ),
    );
    String resposta1 = 'Sem elementos materiais.';
    if (dano.substanciaInflamavelExplosivaSim == true) {
      resposta1 = 'Sim. Houve o emprego de substância inflamável ou explosiva.';
    } else if (dano.substanciaInflamavelExplosivaNao == true) {
      resposta1 =
          'Não. Não houve o emprego de substância inflamável ou explosiva.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta1));

    // 7.2 – Dano contra patrimônio público
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.2 O dano foi contra o patrimônio da União, Estado, Município, empresa concessionária de serviços públicos ou sociedade de economia mista?',
      ),
    );
    String resposta2 = 'Sem elementos materiais.';
    if (dano.danoPatrimonioPublicoSim == true) {
      resposta2 = 'Sim. O dano foi contra o patrimônio público.';
    } else if (dano.danoPatrimonioPublicoNao == true) {
      resposta2 = 'Não. O dano não foi contra o patrimônio público.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta2));

    // 7.3 – Prejuízo considerável
    buffer.writeln(
      _gerarTituloSubSecao('7.3 Houve prejuízo considerável para a vítima?'),
    );
    String resposta3 = 'Sem elementos materiais.';
    if (dano.prejuizoConsideravelSim == true) {
      resposta3 = 'Sim. Houve prejuízo considerável para a vítima.';
    } else if (dano.prejuizoConsideravelNao == true) {
      resposta3 = 'Não. Não houve prejuízo considerável para a vítima.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta3));

    // 7.4 – Identificar instrumento/substância
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.4 É possível identificar o instrumento e/ou substância empregados no evento?',
      ),
    );
    String resposta4 = 'Sem elementos materiais.';
    if (dano.identificarInstrumentoSubstanciaSim == true) {
      final qual = (dano.qualInstrumentoSubstancia ?? '').trim();
      resposta4 = qual.isNotEmpty
          ? 'Sim. Foi possível identificar o instrumento e/ou substância empregados: $qual.'
          : 'Sim. Foi possível identificar o instrumento e/ou substância empregados no evento.';
    } else if (dano.identificarInstrumentoSubstanciaNao == true) {
      resposta4 =
          'Não. Não foi possível identificar o instrumento e/ou substância empregados no evento.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta4));

    // 7.5 – Identificação de vestígio
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.5 O local examinado possibilitou a identificação de algum vestígio?',
      ),
    );
    String resposta5 = 'Sem elementos materiais.';
    if (dano.identificacaoVestigioSim == true) {
      final qual = (dano.qualVestigio ?? '').trim();
      resposta5 = qual.isNotEmpty
          ? 'Sim. O local examinado possibilitou a identificação de vestígios: $qual.'
          : 'Sim. O local examinado possibilitou a identificação de vestígios.';
    } else if (dano.identificacaoVestigioNao == true) {
      resposta5 =
          'Não. O local examinado não possibilitou a identificação de vestígios.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta5));

    // 7.6 – Dano causado e valor estimado
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.6 Qual foi o dano causado e qual é o valor estimado dos prejuízos?',
      ),
    );
    String resposta6 = 'Sem elementos materiais.';
    final danoCausado = (dano.danoCausado ?? '').trim();
    final valorEstimado = (dano.valorEstimadoPrejuizos ?? '').trim();
    if (danoCausado.isNotEmpty || valorEstimado.isNotEmpty) {
      final partes = <String>[];
      if (danoCausado.isNotEmpty) {
        partes.add('Dano causado: $danoCausado');
      }
      if (valorEstimado.isNotEmpty) {
        partes.add('Valor estimado dos prejuízos: R\$ $valorEstimado');
      }
      resposta6 = partes.join('. ');
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta6));

    // 7.7 – Número de pessoas
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.7 É possível identificar o número de pessoas que participaram do evento?',
      ),
    );
    String resposta7 = 'Sem elementos materiais.';
    if (dano.identificarNumeroPessoasSim == true) {
      final numero = (dano.numeroPessoas ?? '').trim();
      resposta7 = numero.isNotEmpty
          ? 'Sim. Foi possível identificar o número de pessoas que participaram do evento: $numero pessoa(s).'
          : 'Sim. Foi possível identificar o número de pessoas que participaram do evento.';
    } else if (dano.identificarNumeroPessoasNao == true) {
      resposta7 =
          'Não. Não foi possível identificar o número de pessoas que participaram do evento.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta7));

    // 7.8 – Vestígios de autoria
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.8 Existem vestígios no local que possam indicar a autoria do delito?',
      ),
    );
    String resposta8 = 'Sem elementos materiais.';
    if (dano.vestigiosAutoriaSim == true) {
      final quais = (dano.quaisVestigiosAutoria ?? '').trim();
      resposta8 = quais.isNotEmpty
          ? 'Sim. Existem vestígios no local que possam indicar a autoria do delito: $quais.'
          : 'Sim. Existem vestígios no local que possam indicar a autoria do delito.';
    } else if (dano.vestigiosAutoriaNao == true) {
      resposta8 =
          'Não. Não existem vestígios no local que possam indicar a autoria do delito.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta8));

    // 7.9 – Dinâmica do evento
    buffer.writeln(
      _gerarTituloSubSecao(
        '7.9 É possível identificar como foi a dinâmica do evento?',
      ),
    );
    String resposta9 = 'Sem elementos materiais.';
    if (dano.identificarDinamicaSim == true) {
      final dinamica = (dano.dinamicaEvento ?? '').trim();
      resposta9 = dinamica.isNotEmpty
          ? 'Sim. Foi possível identificar a dinâmica do evento: $dinamica.'
          : 'Sim. Foi possível identificar a dinâmica do evento.';
    } else if (dano.identificarDinamicaNao == true) {
      resposta9 = 'Não. Não foi possível identificar a dinâmica do evento.';
    }
    buffer.writeln(_gerarParagrafoHistorico(resposta9));

    return buffer.toString();
  }

  // ========== SEÇÕES ESPECÍFICAS PARA CVLI ==========

  /// Gera a seção 7. EXAMES COMPLEMENTARES para CVLI
  String _gerarSecaoExamesComplementaresCVLI(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('7. EXAMES COMPLEMENTARES'));

    // Texto introdutório
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Este campo destina-se à apresentação dos resultados de Exames solicitados aos '
        'Laboratórios de Polícia Científica ou realizados pelo próprio Perito Criminal de '
        'local, como: Balística Forense, Análise de Imagens de Vídeo, entre outros.',
      ),
    );

    // Verificar se há exames complementares registrados
    // Por enquanto, deixar campos para preenchimento manual
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarTituloSubSecao('7.1 Exame Balístico'));
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Aguardando resultado do Laudo de Exame Balístico nº ______.',
      ),
    );

    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarTituloSubSecao('7.2 Exame Necroscópico'));

    // Verificar se há número de laudo cadavérico nos cadáveres
    if (ficha.cadaveres != null && ficha.cadaveres!.isNotEmpty) {
      for (final cadaver in ficha.cadaveres!) {
        if (cadaver.numeroLaudoCadaverico != null &&
            cadaver.numeroLaudoCadaverico!.isNotEmpty) {
          buffer.writeln(
            _gerarParagrafoHistorico(
              'Cadáver ${cadaver.numero}: Laudo Cadavérico nº ${cadaver.numeroLaudoCadaverico}.',
            ),
          );
        } else {
          buffer.writeln(
            _gerarParagrafoHistorico(
              'Cadáver ${cadaver.numero}: Aguardando resultado do Laudo Cadavérico.',
            ),
          );
        }
      }
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Aguardando resultado do Laudo Cadavérico nº ______.',
        ),
      );
    }

    return buffer.toString();
  }

  /// Gera a seção 8. CONSIDERAÇÕES TÉCNICO-PERICIAIS para CVLI
  String _gerarSecaoConsideracoesTecnicoPericiais(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('8. CONSIDERAÇÕES TÉCNICO-PERICIAIS'));

    // 8.1 Análise e Interpretação dos Vestígios
    buffer.writeln(
      _gerarTituloSubSecao('8.1 Análise e Interpretação dos Vestígios'),
    );

    // Texto explicativo baseado na estrutura sugerida
    buffer.writeln(
      _gerarParagrafoHistorico(
        'A análise e interpretação dos vestígios seguem a ordem metodológica preconizada, '
        'considerando: (1) características físicas do cenário; (2) vias de acesso e '
        'posicionamentos de veículos; (3) discussão de cada evidência; (4) discussão '
        'acerca do cadáver e suas lesões; (5) elementos de autoria material; e '
        '(6) eventuais alterações na cena.',
      ),
    );

    buffer.writeln(_gerarParagrafoVazio());

    // Se houver modus operandi/dinâmica detalhada, usar
    if (ficha.modusOperandi != null && ficha.modusOperandi!.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(ficha.modusOperandi!));
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          '[Inserir análise e interpretação dos vestígios conforme metodologia sugerida]',
        ),
      );
    }

    buffer.writeln(_gerarParagrafoVazio());

    // 8.2 Dinâmica
    buffer.writeln(_gerarTituloSubSecao('8.2 Dinâmica'));

    buffer.writeln(
      _gerarParagrafoHistorico(
        'Com base na interpretação dos vestígios, descreve-se a(s) provável(is) maneira(s) '
        'como ocorreu o evento, indicando a sequência dos eventos decorrentes da(s) '
        'conduta(s) do(s) autor(es):',
      ),
    );

    buffer.writeln(_gerarParagrafoVazio());

    // Usar modus operandi se houver, ou placeholder
    // (A dinâmica pode ser derivada do modus operandi ou inserida manualmente)
    buffer.writeln(
      _gerarParagrafoHistorico(
        '[Inserir descrição da dinâmica parcial mais provável do evento]',
      ),
    );

    return buffer.toString();
  }

  /// Gera a seção 9. RESPOSTA AOS QUESITOS para CVLI
  String _gerarSecaoRespostaQuesitos(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('9. RESPOSTA AOS QUESITOS'));

    buffer.writeln(
      _gerarParagrafoHistorico(
        'Não foram apresentados quesitos pela Autoridade Requisitante até o momento '
        'da elaboração deste Laudo.',
      ),
    );

    // Nota: Se futuramente houver campo para quesitos na ficha, adicionar aqui
    // a lógica para transcrever e responder os quesitos

    return buffer.toString();
  }

  /// Gera a seção 10. CONCLUSÃO para CVLI
  String _gerarSecaoConclusaoCVLI(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('10. CONCLUSÃO'));

    buffer.writeln(
      _gerarParagrafoHistorico(
        'Em conformidade com o Heptâmero de Quintiliano, apresenta-se o diagnóstico '
        'diferencial:',
      ),
    );

    buffer.writeln(_gerarParagrafoVazio());

    // (1) O quê (aconteceu)
    String oQue = 'Morte violenta';
    if (ficha.cadaveres != null && ficha.cadaveres!.isNotEmpty) {
      final qtd = ficha.cadaveres!.length;
      oQue = qtd == 1
          ? 'Morte violenta de uma pessoa'
          : 'Morte violenta de $qtd pessoas';
    }
    buffer.writeln(_gerarParagrafoHistorico('(1) O QUÊ (aconteceu): $oQue.'));

    // (2) Onde (aconteceu)
    String onde = 'Local informado no histórico';
    if (ficha.dadosSolicitacao.endereco != null &&
        ficha.dadosSolicitacao.endereco!.isNotEmpty) {
      onde = ficha.dadosSolicitacao.endereco!;
      if (ficha.dadosSolicitacao.municipio != null &&
          ficha.dadosSolicitacao.municipio!.isNotEmpty) {
        onde = '$onde, ${ficha.dadosSolicitacao.municipio}';
      }
    } else if (ficha.local?.endereco != null &&
        ficha.local!.endereco!.isNotEmpty) {
      onde = ficha.local!.endereco!;
      if (ficha.local?.municipio != null &&
          ficha.local!.municipio!.isNotEmpty) {
        onde = '$onde, ${ficha.local!.municipio}';
      }
    }
    buffer.writeln(_gerarParagrafoHistorico('(2) ONDE (aconteceu): $onde.'));

    // (3) Quando (aconteceu)
    String quando = 'Data e hora conforme comunicação';
    if (ficha.dadosSolicitacao.dataHoraComunicacao != null &&
        ficha.dadosSolicitacao.dataHoraComunicacao!.isNotEmpty) {
      quando = ficha.dadosSolicitacao.dataHoraComunicacao!;
    }
    buffer.writeln(
      _gerarParagrafoHistorico('(3) QUANDO (aconteceu): $quando.'),
    );

    // (4) Como (aconteceu) - Dinâmica
    buffer.writeln(
      _gerarParagrafoHistorico(
        '(4) COMO (aconteceu): Conforme dinâmica descrita na seção 8.2.',
      ),
    );

    // (5) Com que meios (foi perpetrado)
    String meios = _identificarMeiosUtilizados(ficha);
    buffer.writeln(
      _gerarParagrafoHistorico('(5) COM QUE MEIOS (foi perpetrado): $meios.'),
    );

    // (6) Quem (é/são o/os autor/es)
    buffer.writeln(
      _gerarParagrafoHistorico(
        '(6) QUEM (é/são o/os autor/es): A ser apurado mediante investigação policial.',
      ),
    );

    return buffer.toString();
  }

  /// Identifica os meios utilizados com base nas lesões dos cadáveres
  String _identificarMeiosUtilizados(FichaCompletaModel ficha) {
    final meios = <String>{};

    if (ficha.cadaveres != null) {
      for (final cadaver in ficha.cadaveres!) {
        if (cadaver.lesoes != null) {
          for (final lesao in cadaver.lesoes!) {
            if (lesao.isPaf) {
              meios.add('Arma de fogo');
            } else if (lesao.tipo != null) {
              final tipo = lesao.tipo!.toLowerCase();
              if (tipo.contains('pab') || tipo.contains('arma branca')) {
                meios.add('Arma branca');
              } else if (tipo.contains('contus')) {
                meios.add('Instrumento contundente');
              } else if (tipo.contains('asfixia') ||
                  tipo.contains('estrangul')) {
                meios.add('Asfixia mecânica');
              }
            }
          }
        }
      }
    }

    if (meios.isEmpty) {
      return 'A ser determinado mediante exame necroscópico';
    }

    return meios.join(', ');
  }

  /// Gera a seção 11. REFERÊNCIAS BIBLIOGRÁFICAS para CVLI
  String _gerarSecaoReferenciasBibliograficas(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('11. REFERÊNCIAS BIBLIOGRÁFICAS'));

    buffer.writeln(
      _gerarParagrafoHistorico(
        'As referências bibliográficas utilizadas neste laudo seguem as normas da '
        'ABNT NBR 6023:',
      ),
    );

    buffer.writeln(_gerarParagrafoVazio());

    // Referências padrão comumente utilizadas em laudos de CVLI
    buffer.writeln(
      _gerarParagrafoHistorico(
        'BRASIL. Código de Processo Penal. Decreto-Lei nº 3.689, de 3 de outubro de 1941.',
      ),
    );

    buffer.writeln(
      _gerarParagrafoHistorico(
        'DOREA, Luiz Eduardo Carvalho; STUMVOLL, Victor Paulo; QUINTELA, Victor. '
        'Criminalística. 7. ed. Campinas: Millennium, 2017.',
      ),
    );

    buffer.writeln(
      _gerarParagrafoHistorico(
        'TOCCHETTO, Domingos; ESPINDULA, Alberi. Criminalística: Procedimentos e '
        'Metodologias. 3. ed. Campinas: Millennium, 2013.',
      ),
    );

    buffer.writeln(
      _gerarParagrafoHistorico(
        'VELHO, Jesus Antonio; GEISER, Gustavo Caminoto; ESPINDULA, Alberi. '
        'Ciências Forenses: Uma Introdução às Principais Áreas da Criminalística '
        'Moderna. 3. ed. Campinas: Millennium, 2017.',
      ),
    );

    return buffer.toString();
  }

  // ========== FIM DAS SEÇÕES ESPECÍFICAS PARA CVLI ==========

  String _gerarSecaoConclusao(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    // Título da seção "8. CONCLUSÃO"
    buffer.writeln(_gerarTituloSecao('8. CONCLUSÃO'));

    // Usar a escolha do perito (se não escolheu, usar conclusão negativa como padrão)
    final conclusaoPositiva = ficha.conclusaoPositiva ?? false;

    final textoConclusao = conclusaoPositiva
        ? 'Com base nos vestígios coletados e examinados, os elementos materiais encontrados no local do fato permitiram a identificação e análise dos indícios compatíveis com a dinâmica do evento delituoso. Os procedimentos periciais realizados, incluindo o levantamento dos vestígios, a documentação fotográfica e os exames complementares quando aplicáveis, forneceram subsídios técnicos suficientes para a elucidação dos fatos investigados.'
        : 'Diante da exiguidade de vestígios materiais encontrados no local do fato, não foi possível obter elementos suficientes para estabelecer conclusões técnicas mais precisas acerca da dinâmica do evento delituoso. Os procedimentos periciais foram realizados conforme a técnica, entretanto, a ausência ou insuficiência de vestígios relevantes limitou a capacidade de análise e interpretação dos indícios, não permitindo conclusões mais detalhadas sobre o modus operandi e demais aspectos técnicos do caso.';

    buffer.writeln(_gerarParagrafoHistorico(textoConclusao));

    return buffer.toString();
  }

  String _gerarParagrafosFinais(
    FichaCompletaModel ficha,
    PeritoModel perito,
    int qtdFotos,
  ) {
    final buffer = StringBuffer();

    // Parágrafo sobre fotografias
    final qtdFotosFormatada = qtdFotos.toString().padLeft(2, '0');
    buffer.writeln(
      _gerarParagrafoHistorico(
        'O presente Laudo contém $qtdFotosFormatada fotografias, dispostas no Anexo Fotográfico',
      ),
    );

    // Parágrafo sobre objetos (placeholder - pode ser ajustado depois)
    buffer.writeln(
      _gerarParagrafoHistorico(
        'O(s) objeto(s) descrito(s) no item 0.0 acompanha(m) este Laudo/encontra(m)-se disponível(is) para retirada com o Lacre n. ______.',
      ),
    );

    // "É o que se tem a relatar."
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarParagrafoHistorico('É o que se tem a relatar.'));

    // Data e cidade (alinhado à direita)
    buffer.writeln(_gerarParagrafoVazio());
    final dataExame = _formatarDataExame(ficha);
    final cidade = perito.cidade.isNotEmpty ? perito.cidade : 'Cidade';
    final dataFormatada = dataExame.isNotEmpty
        ? dataExame
        : DateTime.now().toString().substring(0, 10);

    // Extrair dia, mês e ano da data
    String dataFinal = dataFormatada;
    try {
      final partes = dataFormatada.split('/');
      if (partes.length == 3) {
        final dia = partes[0];
        final mes = partes[1];
        final ano = partes[2];
        final meses = [
          '',
          'janeiro',
          'fevereiro',
          'março',
          'abril',
          'maio',
          'junho',
          'julho',
          'agosto',
          'setembro',
          'outubro',
          'novembro',
          'dezembro',
        ];
        final mesNum = int.tryParse(mes) ?? 1;
        final mesNome = (mesNum >= 1 && mesNum <= 12) ? meses[mesNum] : mes;
        dataFinal = '$cidade, $dia de $mesNome de $ano.';
      }
    } catch (e) {
      dataFinal = '$cidade, $dataFormatada.';
    }

    buffer.writeln(_gerarParagrafoAlinhadoDireita(dataFinal));

    // Assinatura eletrônica (centralizado)
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln(
      _gerarParagrafoCentralizado('Documento assinado eletronicamente por'),
    );
    buffer.writeln(_gerarParagrafoCentralizado(perito.nome));
    buffer.writeln(_gerarParagrafoCentralizado('Perito(a) Criminal'));

    return buffer.toString();
  }

  String _gerarParagrafoAlinhadoDireita(String texto) {
    // Parágrafo alinhado à direita
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="right"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoCentralizado(String texto) {
    // Parágrafo centralizado
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarRodape(int numero, String texto) {
    // Rodapé com fonte Gadugi, tamanho 9, entrelinhas simples (1.0), justificado
    // Tamanho 9 = 18 half-points
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
        <w:ind w:firstLine="708"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="18"/>
          <w:szCs w:val="18"/>
        </w:rPr>
        <w:t>${_escapeXml('$numero $texto')}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoLista(String texto) {
    // Parágrafo para lista com recuo pendente (hanging indent)
    // A primeira linha fica mais à esquerda, linhas seguintes alinhadas com o texto após "a) "
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:left="0" w:hanging="283"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoComSobrescritoLista(String texto, int numeroRodape) {
    // Parágrafo para lista com sobrescrito e recuo pendente (hanging indent)
    final partes = texto.split('¹');
    if (partes.length == 2) {
      // Tem chamada de rodapé
      return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="312" w:lineRule="auto"/>
        <w:ind w:left="0" w:hanging="283"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(partes[0])}</w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
          <w:vertAlign w:val="superscript"/>
          <w:color w:val="FF0000"/>
        </w:rPr>
        <w:t>${_escapeXml(numeroRodape.toString())}</w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>${_escapeXml(partes[1])}</w:t>
      </w:r>
    </w:p>''';
    } else {
      // Sem chamada de rodapé, usar parágrafo de lista normal
      return _gerarParagrafoLista(texto);
    }
  }

  String _gerarLevantamentoFotografico(List<File> fotos, int maxId) {
    final buffer = StringBuffer();

    // Quebra de página
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:br w:type="page"/>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    // Título "LEVANTAMENTO FOTOGRÁFICO" - 14pt, negrito, centralizado, espaçamento 1.0
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln(
      '        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>',
    );
    buffer.writeln('        <w:ind w:firstLine="0"/>');
    buffer.writeln('      </w:pPr>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln(
      '          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>',
    );
    buffer.writeln('          <w:b/>');
    buffer.writeln('          <w:sz w:val="28"/>'); // 14pt = 28 half-points
    buffer.writeln('          <w:szCs w:val="28"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln(
      '        <w:t>${_escapeXml('LEVANTAMENTO FOTOGRÁFICO')}</w:t>',
    );
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    // Adicionar cada foto
    for (int i = 0; i < fotos.length; i++) {
      final numeroFoto = (i + 1).toString().padLeft(2, '0');
      final rId = maxId + i + 1; // IDs começam após o último existente
      buffer.writeln(_gerarFotografia(numeroFoto, rId));

      // Espaçamento entre fotos (exceto após a última)
      if (i < fotos.length - 1) {
        buffer.writeln('    <w:p>');
        buffer.writeln('      <w:pPr>');
        buffer.writeln(
          '        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>',
        );
        buffer.writeln('      </w:pPr>');
        buffer.writeln('    </w:p>');
      }
    }

    return buffer.toString();
  }

  String _gerarFotografia(String numeroFoto, int rId) {
    // Legenda ANTES da foto - 10pt, centralizado, espaçamento 1.0, sem espaço antes/depois
    final legenda = 'Fotografia $numeroFoto:';

    // Tamanho da imagem: 6.45 polegadas x 4.094 polegadas (10.4 cm)
    // Em EMUs (English Metric Units): 1 polegada = 914400 EMUs
    final larguraEmu = (6.45 * 914400).round(); // ~5896980 EMUs
    final alturaEmu = (4.094 * 914400).round(); // ~3742474 EMUs

    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="20"/>
          <w:szCs w:val="20"/>
        </w:rPr>
        <w:t>${_escapeXml(legenda)}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
            <wp:extent cx="$larguraEmu" cy="$alturaEmu"/>
            <wp:effectExtent l="0" t="0" r="0" b="0"/>
            <wp:docPr id="$rId" name="Imagem $rId"/>
            <wp:cNvGraphicFramePr>
              <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
            </wp:cNvGraphicFramePr>
            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:nvPicPr>
                    <pic:cNvPr id="$rId" name="Imagem $rId"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="rId$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                    <a:stretch>
                      <a:fillRect/>
                    </a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm>
                      <a:off x="0" y="0"/>
                      <a:ext cx="$larguraEmu" cy="$alturaEmu"/>
                    </a:xfrm>
                    <a:prstGeom prst="rect">
                      <a:avLst/>
                    </a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>''';
  }

  Future<Map<String, dynamic>> _processarRelationships(
    Archive archive,
    List<File> fotos,
  ) async {
    // Encontrar arquivo de relationships
    final relsIndex = archive.files.indexWhere(
      (f) => f.name == 'word/_rels/document.xml.rels',
    );

    String relationshipsContent;
    if (relsIndex != -1) {
      final relsFile = archive.files[relsIndex];
      final conteudo = relsFile.content as List<int>;
      try {
        relationshipsContent = utf8.decode(conteudo);
      } catch (e) {
        relationshipsContent = String.fromCharCodes(conteudo);
      }
    } else {
      // Criar novo arquivo de relationships se não existir
      relationshipsContent =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
    }

    // Extrair o conteúdo dentro de <Relationships>
    final regex = RegExp(
      r'<Relationships[^>]*>(.*?)</Relationships>',
      dotAll: true,
    );
    final match = regex.firstMatch(relationshipsContent);
    if (match == null) {
      return {'xml': relationshipsContent, 'maxId': 0};
    }

    final existingRels = match.group(1) ?? '';

    // Encontrar o próximo ID disponível (Id="rId123")
    final idRegex = RegExp(r'Id="rId(\d+)"');
    int maxId = 0;
    idRegex.allMatches(existingRels).forEach((m) {
      final id = int.tryParse(m.group(1) ?? '0') ?? 0;
      if (id > maxId) maxId = id;
    });

    // Adicionar relationships para as imagens (com nomes únicos)
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    buffer.write(existingRels);

    final fileNames = <String>[];
    int imageCounter = 1;
    for (final foto in fotos) {
      if (await foto.exists()) {
        final extension = foto.path.split('.').last.toLowerCase();
        final nomeUnico =
            'levantamento_${DateTime.now().microsecondsSinceEpoch}_$imageCounter.$extension';
        final rId = maxId + imageCounter;
        buffer.writeln(
          '  <Relationship Id="rId$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$nomeUnico"/>',
        );
        fileNames.add(nomeUnico);
        imageCounter++;
      }
    }

    buffer.writeln('</Relationships>');
    return {'xml': buffer.toString(), 'maxId': maxId, 'fileNames': fileNames};
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Converte um número para extenso em português (1 a 99)
  String _numeroPorExtenso(int numero) {
    if (numero <= 0) return 'zero';
    if (numero > 99) return numero.toString();

    final unidades = [
      '',
      'um',
      'dois',
      'três',
      'quatro',
      'cinco',
      'seis',
      'sete',
      'oito',
      'nove',
      'dez',
      'onze',
      'doze',
      'treze',
      'quatorze',
      'quinze',
      'dezesseis',
      'dezessete',
      'dezoito',
      'dezenove',
    ];

    final dezenas = [
      '',
      'dez',
      'vinte',
      'trinta',
      'quarenta',
      'cinquenta',
      'sessenta',
      'setenta',
      'oitenta',
      'noventa',
    ];

    if (numero < 20) {
      return unidades[numero];
    }

    final dezena = numero ~/ 10;
    final unidade = numero % 10;

    if (unidade == 0) {
      return dezenas[dezena];
    }

    return '${dezenas[dezena]} e ${unidades[unidade]}';
  }
}
