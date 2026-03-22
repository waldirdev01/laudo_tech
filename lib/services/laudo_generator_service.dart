import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cadaver_model.dart';
import '../models/crime_transito_model.dart';
import '../models/detatlhes_local.dart';
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
  /// [legendasFotos] opcional: descrição de cada foto na mesma ordem de [fotos] (ex.: "Vista ampla do local", "Vestígio: ...").
  Future<File> gerarLaudo({
    required FichaCompletaModel ficha,
    required PeritoModel perito,
    required String templatePath,
    List<File>? fotos,
    List<String>? legendasFotos,
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

    // Imagem do mapa (captura de tela do local), se houver
    File? imagemMapaLocal;
    final capturaPath = ficha.local?.capturaTelaLocalPath;
    if (capturaPath != null && capturaPath.isNotEmpty) {
      final f = File(capturaPath);
      if (await f.exists()) imagemMapaLocal = f;
    }

    // Processar relationships: imagem do mapa (rId maxId+1) + fotos do anexo (maxId+2, ...)
    String? relationshipsXml;
    int maxId = 0;
    List<String> nomesFotosDocx = const [];
    int? mapaRId;
    String? mapaFileName;
    final hasFotos = fotos != null && fotos.isNotEmpty;
    if (imagemMapaLocal != null || hasFotos) {
      final result = await _processarRelationships(
        archive,
        fotos ?? [],
        imagemMapaLocal: imagemMapaLocal,
      );
      relationshipsXml = result['xml'] as String;
      maxId = result['maxId'] as int;
      nomesFotosDocx = (result['fileNames'] as List<dynamic>).cast<String>();
      mapaRId = result['mapaRId'] as int?;
      mapaFileName = result['mapaFileName'] as String?;
    }

    // Gerar novo conteúdo do documento
    final novoConteudo = await _gerarConteudoLaudo(
      ficha,
      perito,
      documentContent,
      fotos: fotos,
      legendasFotos: legendasFotos,
      maxId: maxId,
      mapaRId: mapaRId,
    );

    // Nota de rodapé real (Feca Cult) quando há material sangue humano
    final materiaisApreendidos =
        ficha.evidenciasFurto?.materiaisApreendidos ?? [];
    final materialSangue = materiaisApreendidos
        .where((m) => m.descricao == 'Sangue humano')
        .firstOrNull;
    final precisaFootnotes = materialSangue != null;

    // Criar novo arquivo com o conteúdo atualizado
    final novoArchive = Archive();

    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        final novoDocBytes = Uint8List.fromList(utf8.encode(novoConteudo));
        novoArchive.addFile(
          ArchiveFile(file.name, novoDocBytes.length, novoDocBytes),
        );
      } else if (file.name == 'word/_rels/document.xml.rels') {
        String relsContent =
            relationshipsXml ?? utf8.decode((file.content as List<int>));
        if (precisaFootnotes) {
          final nextRId = _proximoRIdEmRels(relsContent);
          relsContent = relsContent.replaceFirst(
            '</Relationships>',
            '  <Relationship Id="rId$nextRId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/>\n</Relationships>',
          );
        }
        final relsBytes = Uint8List.fromList(utf8.encode(relsContent));
        novoArchive.addFile(
          ArchiveFile(file.name, relsBytes.length, relsBytes),
        );
      } else if (file.name == 'word/footnotes.xml' && precisaFootnotes) {
        // Substituiremos por nosso footnotes.xml abaixo; não copiar o do template
      } else {
        novoArchive.addFile(file);
      }
    }

    if (precisaFootnotes) {
      final footnotesXml = _gerarFootnotesXml();
      novoArchive.addFile(
        ArchiveFile(
          'word/footnotes.xml',
          footnotesXml.length,
          Uint8List.fromList(utf8.encode(footnotesXml)),
        ),
      );
    }

    // Adicionar imagens ao archive: primeiro a do mapa (se houver), depois as fotos do anexo
    if (imagemMapaLocal != null && mapaFileName != null) {
      final imageBytes = await imagemMapaLocal.readAsBytes();
      novoArchive.addFile(
        ArchiveFile('word/media/$mapaFileName', imageBytes.length, imageBytes),
      );
    }
    if (fotos != null && fotos.isNotEmpty) {
      final offset = mapaFileName != null ? 1 : 0;
      for (int i = 0; i < fotos.length; i++) {
        final idx = i + offset;
        if (idx >= nomesFotosDocx.length) continue;
        final foto = fotos[i];
        if (!await foto.exists()) continue;
        final imageBytes = await foto.readAsBytes();
        final imageName = 'word/media/${nomesFotosDocx[idx]}';
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
    List<String>? legendasFotos,
    int maxId = 0,
    int? mapaRId,
  }) async {
    // Extrair sectPr do documento original (contém referências a header/footer)
    final sectPr = _extrairSectPr(documentContent);

    // Gerar o conteúdo interno do body
    final buffer = StringBuffer();

    // Três linhas em branco antes do título (altura 22pt cada)
    buffer.writeln(_gerarLinhaEmBrancoTamanho22());
    buffer.writeln(_gerarLinhaEmBrancoTamanho22());
    buffer.writeln(_gerarLinhaEmBrancoTamanho22());

    // TÍTULO PRINCIPAL: "LAUDO DE PERÍCIA CRIMINAL"
    buffer.writeln(_gerarTituloPrincipal('LAUDO DE PERÍCIA CRIMINAL'));
    buffer.writeln(_gerarLinhaEmBranco());

    // SUBTÍTULO: Natureza do exame
    final subtitulo = _getSubtituloParaTipo(ficha.tipoOcorrencia);
    buffer.writeln(_gerarSubtitulo(subtitulo));
    buffer.writeln(_gerarLinhaEmBranco());

    // TABELA DE IDENTIFICAÇÃO DO LAUDO (preâmbulo)
    buffer.writeln(_gerarTabelaIdentificacao(ficha, perito));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 1. HISTÓRICO
    buffer.writeln(await _gerarSecaoHistorico(ficha, perito));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 2. OBJETIVOS (uma linha em branco antes de cada item principal)
    buffer.writeln(_gerarSecaoObjetivos());
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS
    buffer.writeln(_gerarSecaoIsolamentoPreservacao(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 4. DESCRIÇÃO DO LOCAL
    buffer.writeln(_gerarSecaoDescricaoLocal(ficha, mapaRId: mapaRId));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 5. EXAMES ou DAS IMAGENS (para CVLI)
    final qtdFotos = fotos?.length ?? 0;
    buffer.writeln(await _gerarSecaoExames(ficha, perito, qtdFotos: qtdFotos));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 6. ANÁLISE E INTERPRETAÇÃO DOS VESTÍGIOS ou DOS EXAMES (para CVLI)
    buffer.writeln(await _gerarSecaoAnaliseInterpretacao(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    // Para CVLI: seções 7-11 específicas
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
      // SEÇÃO 7. EXAMES COMPLEMENTARES
      buffer.writeln(_gerarSecaoExamesComplementaresCVLI(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 8. CONSIDERAÇÕES TÉCNICO-PERICIAIS
      buffer.writeln(_gerarSecaoConsideracoesTecnicoPericiais(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 9. RESPOSTA AOS QUESITOS
      buffer.writeln(_gerarSecaoRespostaQuesitos(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 10. CONCLUSÃO
      buffer.writeln(_gerarSecaoConclusaoCVLI(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 11. REFERÊNCIAS BIBLIOGRÁFICAS
      buffer.writeln(_gerarSecaoReferenciasBibliograficas(ficha));
      buffer.writeln(_gerarLinhaEmBranco());
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
        buffer.writeln(_gerarLinhaEmBranco());
      }

      // SEÇÃO 8. CONCLUSÃO
      buffer.writeln(_gerarSecaoConclusao(ficha));
      buffer.writeln(_gerarLinhaEmBranco());
    }

    // PARÁGRAFOS FINAIS
    final qtdFotosNoLaudo = fotos?.length ?? ficha.fotosLevantamento.length;
    buffer.writeln(_gerarParagrafosFinais(ficha, perito, qtdFotosNoLaudo));

    // LEVANTAMENTO FOTOGRÁFICO (se houver fotos)
    if (fotos != null && fotos.isNotEmpty) {
      buffer.writeln(
        _gerarLevantamentoFotografico(
          fotos,
          maxId,
          mapaRId: mapaRId,
          legendas: legendasFotos,
        ),
      );
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
      case TipoOcorrencia.crimeTransito:
        return 'CRIME DE TRÂNSITO';
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
    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito &&
        ficha.crimeTransitoCondicoes != null) {
      buffer.writeln(_gerarTituloSubSecao('4.3 Condições da Via'));
      final resumo = _textoCondicoesCrimeTransito(
        ficha.crimeTransitoCondicoes!,
      );
      buffer.writeln(
        _gerarParagrafoHistorico(resumo.isNotEmpty ? resumo : 'Não informado.'),
      );
    }

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

  static const List<String> _mesesPt = [
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

  String _formatarDataExame(FichaCompletaModel ficha) {
    final dataHoraInicio = ficha.dataHoraInicio;
    if (dataHoraInicio == null || dataHoraInicio.isEmpty) return '';

    final partes = dataHoraInicio.trim().split(RegExp(r'\s+'));
    final dataStr = partes[0].replaceAll('-', '/');
    if (dataStr.isEmpty) return '';

    DateTime? parsed;
    try {
      parsed = DateFormat('dd/MM/yyyy').parse(dataStr);
    } catch (_) {
      try {
        parsed = DateFormat('yyyy/MM/dd').parse(dataStr);
      } catch (_) {}
    }
    if (parsed == null) return dataStr;

    final d = parsed.day;
    final m = parsed.month;
    final y = parsed.year;
    if (m < 1 || m > 12) return dataStr;
    return '$d de ${_mesesPt[m - 1]} de $y';
  }

  /// Uma linha em branco (entre título/subtítulo/tabela e entre itens principais).
  /// Sem recuo, sem espaço antes/depois, para não somar com parágrafos do mesmo estilo.
  String _gerarLinhaEmBranco() {
    return '''    <w:p>
      <w:pPr>
        <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
      </w:pPr>
    </w:p>''';
  }

  /// Linha em branco com altura 22pt (para as três linhas iniciais antes do título).
  static const int _lineHeight22pt = 440; // 22pt em twips (22 * 20)

  String _gerarLinhaEmBrancoTamanho22() {
    return '''    <w:p>
      <w:pPr>
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight22pt" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:sz w:val="$_fontSizeTitulo"/>
          <w:szCs w:val="$_fontSizeTitulo"/>
        </w:rPr>
        <w:t></w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoVazio() {
    // Parágrafo vazio com entrelinhas padrão 1,25 e alinhamento justificado
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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

    // Condições meteorológicas
    final condicoesMeteo = _formatarCondicoesMeteorologicas(ficha.dadosFichaBase);
    if (condicoesMeteo.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'As condições meteorológicas no momento do exame apresentavam-se $condicoesMeteo.',
        ),
      );
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

  String _formatarCondicoesMeteorologicas(FichaBaseModel? fb) {
    if (fb == null) return '';
    final condicoes = <String>[];
    if (fb.condicoesEstavel == true) condicoes.add('tempo estável');
    if (fb.condicoesNublado == true) condicoes.add('tempo nublado');
    if (fb.condicoesParcialmenteNublado == true) {
      condicoes.add('tempo parcialmente nublado');
    }
    if (fb.condicoesChuvoso == true) condicoes.add('tempo chuvoso');
    if (condicoes.isEmpty) return '';
    return condicoes.join(', com ');
  }

  String _gerarTituloSecao(String titulo) {
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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
    // Parágrafo com recuo de primeira linha 1,25 cm, entrelinhas 1,25, justificado.
    // Sem espaço antes/depois para não adicionar espaço entre parágrafos do mesmo estilo.
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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
    // com parte do texto em vermelho. Sem espaço antes/depois (mesmo estilo).
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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
        membros.add(
          _textoMembroComMatricula(
            '${fotografo.cargo} ${fotografo.nome}',
            fotografo.matricula,
          ),
        );
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
        membros.add(
          _textoMembroComMatricula(
            '${membro.cargo} ${membro.nome}',
            membro.matricula,
          ),
        );
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
    if (pessoas == null || pessoas.isEmpty) return 'pessoa não identificada';

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

    return 'pessoa não identificada';
  }

  /// Inclui matrícula no texto do membro de forma fluida (ex.: "João Silva, matrícula 12345").
  String _textoMembroComMatricula(String nomeOuDescricao, String? matricula) {
    if (matricula == null || matricula.trim().isEmpty) {
      return nomeOuDescricao;
    }
    return '$nomeOuDescricao, matrícula ${matricula.trim()}';
  }

  String _formatarNomeCorreto(String nome) {
    // Converte de CAIXA ALTA para formato correto (primeira letra maiúscula, resto minúsculo)
    // Trata nomes compostos corretamente (ex: "MARIA DA SILVA" -> "Maria da Silva")
    // Preposições ficam minúsculas, exceto a primeira palavra
    final palavras = nome.toLowerCase().split(' ');
    const preposicoes = {'da', 'de', 'do', 'dos', 'das', 'e', 'a', 'o', 'os', 'as'};

    final palavrasFormatadas = <String>[];
    for (var i = 0; i < palavras.length; i++) {
      final palavra = palavras[i].trim();
      if (palavra.isEmpty) continue;

      // Primeira palavra sempre capitalizada, senão capitalizar só se não for preposição
      if (i == 0 || !preposicoes.contains(palavra)) {
        palavrasFormatadas.add(palavra[0].toUpperCase() + palavra.substring(1));
      } else {
        palavrasFormatadas.add(palavra);
      }
    }

    return palavrasFormatadas.join(' ');
  }

  String _formatarEquipesPoliciais(List<EquipePolicialFichaModel> equipes) {
    final partes = <String>[];

    for (final equipe in equipes) {
      final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
      final membros = equipe.membros
          .map((m) {
            // Patente na frente do nome (ex.: Cabo Xavier, Soldado Figueiredo)
            final textoMembro =
                m.postoGraduacao != null && m.postoGraduacao!.trim().isNotEmpty
                ? '${m.postoGraduacao} ${m.nome}'
                : m.nome;
            return _textoMembroComMatricula(textoMembro, m.matricula);
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
    final notasEquipes = <String>[];

    for (final equipe in equipes) {
      final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
      final membros = equipe.membros
          .map((m) {
            final partesMembro = <String>[];
            if (m.cargo != null) {
              partesMembro.add(m.cargo!);
            }
            partesMembro.add(m.nome);
            if (m.matricula != null && m.matricula!.trim().isNotEmpty) {
              partesMembro.add('matrícula ${m.matricula!.trim()}');
            }
            if (m.crm != null && m.crm!.trim().isNotEmpty) {
              partesMembro.add('CRM ${m.crm}');
            }
            return partesMembro.join(', ');
          })
          .join(', ');

      String textoEquipe = '$tipoNome: $membros';

      if (equipe.unidadeNumero != null) {
        textoEquipe += ' (Unidade n. ${equipe.unidadeNumero})';
      }

      partes.add(textoEquipe);

      // Se não estava no local, adicionar nota
      if (equipe.naoEstavaNoLocal) {
        notasEquipes.add('A equipe de $tipoNome esteve presente durante o atendimento à ocorrência, porém não se encontrava no local ao momento da perícia.');
      }
    }

    if (partes.isEmpty) return '';

    final texto = 'Equipe(s) de resgate presente(s): ${partes.join('; ')}.';

    // Adicionar notas se houver
    if (notasEquipes.isNotEmpty) {
      return '$texto Nota: ${notasEquipes.join(' ')}';
    }

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
            'Constatou-se que o local não se encontrava devidamente preservado quando da chegada desta equipe, com indícios de intervenções/alterações anteriores à perícia. Tais circunstâncias podem ter suprimido, deslocado ou modificado vestígios e sua distribuição espacial, afetando a possibilidade de correlação segura entre vestígios materiais e a dinâmica informada no histórico. Assim, os exames concentraram-se no registro técnico do cenário remanescente, com indicação expressa do grau de prejuízo decorrente das condições de preservação.',
          ),
        );
      } else if (fb?.preservacaoInidoneo == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Constatou-se que o local não se encontrava devidamente preservado quando da chegada desta equipe, com indícios de intervenções/alterações anteriores à perícia. Tais circunstâncias podem ter suprimido, deslocado ou modificado vestígios e sua distribuição espacial, afetando a possibilidade de correlação segura entre vestígios materiais e a dinâmica informada no histórico. Assim, os exames concentraram-se no registro técnico do cenário remanescente, com indicação expressa do grau de prejuízo decorrente das condições de preservação.',
          ),
        );
      }
    }

    return buffer.toString();
  }

  String _gerarSecaoDescricaoLocal(FichaCompletaModel ficha, {int? mapaRId}) {
    final buffer = StringBuffer();

    // Título da seção "4. DO LOCAL"
    buffer.writeln(_gerarTituloSecao('4. DO LOCAL'));

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
    enderecoCompleto += enderecoCompleto.endsWith('.') ? '' : '.';
    buffer.writeln(_gerarParagrafoHistorico(enderecoCompleto));

    // Coordenadas geográficas: (rótulo + valor em linha separada)
    final coordS = ficha.local?.coordenadasSFormatada;
    final coordW = ficha.local?.coordenadasWFormatada;
    final textoCoordenadas = (coordS != null && coordW != null)
        ? 'Coordenadas geográficas: $coordS $coordW.'
        : 'Coordenadas geográficas: Não obtidas.';
    buffer.writeln(_gerarParagrafoHistorico(textoCoordenadas));

    // Legenda e imagem do mapa (captura de tela do local), se houver
    if (mapaRId != null) {
      buffer.writeln(_gerarLegendaEImagemMapa(mapaRId));
    }

    // Conforme orientação: na seção 4 (DO LOCAL) constam apenas endereço e coordenadas
    // do Local Imediato. A descrição detalhada (Mediato, Imediato, Relacionado e vestígios)
    // fica na seção 6.1 (DOS EXAMES - Do Local).

    return buffer.toString();
  }

  String _gerarTituloSubSecao(String titulo) {
    // Subtítulo de seção (4.1, 4.2, etc.) - negrito, sem recuo. Sem espaço extra para ficar colado ao item pai (4 e 4.1).
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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

  Future<String> _gerarSecaoExames(
    FichaCompletaModel ficha,
    PeritoModel perito, {
    int qtdFotos = 0,
  }) async {
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

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      buffer.writeln(_gerarTituloSecao('5. EXAMES'));
      buffer.writeln(_gerarTituloSubSecao('5.1 Condições da Via'));
      final resumoCondicoes = ficha.crimeTransitoCondicoes != null
          ? _textoCondicoesCrimeTransito(ficha.crimeTransitoCondicoes!)
          : '';
      buffer.writeln(
        _gerarParagrafoHistorico(
          resumoCondicoes.isNotEmpty ? resumoCondicoes : 'Não informado.',
        ),
      );
      buffer.writeln(_gerarTituloSubSecao('5.2 Veículos e Danos'));
      final resumoVeiculos = _textoVeiculosCrimeTransito(ficha);
      buffer.writeln(
        _gerarParagrafoHistorico(
          resumoVeiculos.isNotEmpty ? resumoVeiculos : 'Não informado.',
        ),
      );
      buffer.writeln(_gerarTituloSubSecao('5.3 Envolvidos'));
      final resumoEnvolvidos = _textoEnvolvidosCrimeTransito(ficha);
      buffer.writeln(
        _gerarParagrafoHistorico(
          resumoEnvolvidos.isNotEmpty ? resumoEnvolvidos : 'Não informado.',
        ),
      );
      buffer.writeln(_gerarTituloSubSecao('5.4 Natureza da Ocorrência'));
      final resumoNatureza = _textoNaturezaCrimeTransito(
        ficha.crimeTransitoNatureza,
      );
      buffer.writeln(
        _gerarParagrafoHistorico(
          resumoNatureza.isNotEmpty ? resumoNatureza : 'Não informado.',
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
      _gerarParagrafoHistorico('Quando da Perícia Criminal, constatou-se:'),
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

    // 5.1.1 Vestígios do local (mediato, imediato, relacionado) – tela Detalhes do Local
    if (ficha.localFurto != null && _temVestigiosLocal(ficha.localFurto!)) {
      buffer.writeln(_gerarTituloSubSecao('5.1.1 Vestígios do local'));
      buffer.writeln(await _gerarSecaoExamesLocal(ficha));
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
      final nomeUnidade = (perito.unidadePericial).trim().isNotEmpty
          ? perito.unidadePericial
          : 'unidade';
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Os vestígios coletados foram devidamente acondicionados, identificados e encaminhados para processamento na $nomeUnidade, conforme rotina técnica.',
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

    // Nota de rodapé (Feca Cult) é gerada em word/footnotes.xml pelo gerarLaudo quando materialSangue != null.

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

  bool _temVestigiosLocal(LocalFurtoModel lf) {
    final mediato = lf.vestigiosMediato?.isNotEmpty ?? false;
    final imediato = lf.vestigiosImediato?.isNotEmpty ?? false;
    final relacionado = lf.vestigiosRelacionado?.isNotEmpty ?? false;
    return mediato || imediato || relacionado;
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
    final citacaoFotos = _formatarCitacaoFotosVestigio(
      vestigio.numerosFotografias,
    );
    if (citacaoFotos.isNotEmpty) {
      descricao = descricao.isEmpty
          ? 'Vestígio registrado ($citacaoFotos)'
          : '$descricao ($citacaoFotos)';
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
        try {
          if (vestigio.tipoDestino == TipoDestinoVestigio.unidade) {
            final unidades = await _unidadeService.listarUnidades();
            final unidade = unidades.firstWhere(
              (u) => u.id == vestigio.destinoId,
            );
            nomeDestino = unidade.nome;
          } else if (vestigio.tipoDestino == TipoDestinoVestigio.laboratorio) {
            final laboratorios = await _laboratorioService.listarLaboratorios();
            final laboratorio = laboratorios.firstWhere(
              (l) => l.id == vestigio.destinoId,
            );
            nomeDestino = laboratorio.nome;
          }
        } catch (_) {
          nomeDestino = vestigio.tipoDestino == TipoDestinoVestigio.unidade
              ? 'Unidade (não localizada)'
              : 'Laboratório (não localizado)';
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

  String _formatarCitacaoFotosVestigio(List<int> numeros) {
    if (numeros.isEmpty) return '';
    final unicosOrdenados = {...numeros}.where((n) => n > 0).toList()..sort();
    if (unicosOrdenados.isEmpty) return '';
    final numerosFmt = unicosOrdenados
        .map((n) => n.toString().padLeft(2, '0'))
        .toList();
    if (numerosFmt.length == 1) {
      return 'foto ${numerosFmt.first}';
    }
    if (numerosFmt.length == 2) {
      return 'fotos ${numerosFmt[0]} e ${numerosFmt[1]}';
    }
    final inicio = numerosFmt.sublist(0, numerosFmt.length - 1).join(', ');
    return 'fotos $inicio e ${numerosFmt.last}';
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

  /// Gera descrição de veículo em formato prosa fluida
  String _gerarTextoDescricaoVeiculo(VeiculoModel veiculo) {
    final partes = <String>[];

    // Tipo de veículo
    String tipo = 'um veículo';
    if (veiculo.tipoVeiculo != null) {
      tipo = veiculo.tipoVeiculo == TipoVeiculo.outro &&
              veiculo.tipoVeiculoOutro != null &&
              veiculo.tipoVeiculoOutro!.isNotEmpty
          ? veiculo.tipoVeiculoOutro!.toLowerCase()
          : veiculo.tipoVeiculo!.label.toLowerCase();
    }
    partes.add('um $tipo');

    // Marca e modelo
    if (veiculo.marcaModelo != null && veiculo.marcaModelo!.isNotEmpty) {
      partes.add(veiculo.marcaModelo!);
    }

    // Cor
    if (veiculo.cor != null && veiculo.cor!.isNotEmpty) {
      partes.add('cor ${veiculo.cor!.toLowerCase()}');
    }

    // Placa
    if (veiculo.placa != null && veiculo.placa!.isNotEmpty) {
      partes.add('placa ${veiculo.placa}');
    }

    // Anos de fabricação e modelo
    final anosInfo = <String>[];
    if (veiculo.anoFabricacao != null && veiculo.anoFabricacao!.isNotEmpty) {
      anosInfo.add('fabricação ${veiculo.anoFabricacao}');
    }
    if (veiculo.anoModelo != null && veiculo.anoModelo!.isNotEmpty) {
      anosInfo.add('modelo ${veiculo.anoModelo}');
    }
    if (anosInfo.isNotEmpty) {
      partes.add('ano de ${anosInfo.join(' e ')}');
    }

    // Localização
    if (veiculo.localizacaoAmbiente != null &&
        veiculo.localizacaoAmbiente!.isNotEmpty) {
      partes.add('localizado ${veiculo.localizacaoAmbiente!.toLowerCase()}');
    }

    if (partes.isEmpty) return '';

    // Constrói frase fluida: "Foi examinado um automóvel, marca Toyota Corolla, cor preta, placa ABC-1234, ano de fabricação 2015 e modelo 2015, localizado na garagem."
    return 'Foi examinado ${partes.join(', ')}.';
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

      // Descrição do veículo em formato prosa
      final textoVeiculo = _gerarTextoDescricaoVeiculo(veiculo);
      if (textoVeiculo.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(textoVeiculo));
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
    final citacaoFotosVeiculo = _formatarCitacaoFotosVestigio(
      vestigio.numerosFotografias ?? [],
    );
    if (citacaoFotosVeiculo.isNotEmpty) {
      descricao = descricao.isEmpty
          ? 'Vestígio registrado ($citacaoFotosVeiculo)'
          : '$descricao ($citacaoFotosVeiculo)';
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
        try {
          if (vestigio.tipoDestino == TipoDestinoVestigioVeiculo.unidade) {
            final unidades = await _unidadeService.listarUnidades();
            final unidade = unidades.firstWhere(
              (u) => u.id == vestigio.destinoId,
            );
            nomeDestino = unidade.nome;
          } else if (vestigio.tipoDestino ==
              TipoDestinoVestigioVeiculo.laboratorio) {
            final laboratorios = await _laboratorioService.listarLaboratorios();
            final laboratorio = laboratorios.firstWhere(
              (l) => l.id == vestigio.destinoId,
            );
            nomeDestino = laboratorio.nome;
          }
        } catch (_) {
          nomeDestino =
              vestigio.tipoDestino == TipoDestinoVestigioVeiculo.unidade
                  ? 'Unidade (não localizada)'
                  : 'Laboratório (não localizado)';
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

  /// Gera parágrafo com texto em negrito - mesmo entrelinhamento e sem espaço entre parágrafos do mesmo estilo.
  String _gerarParagrafoHistoricoNegrito(String texto) {
    final textoEscapado = _escapeXml(texto);
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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

  /// Gera título de sub-sub-seção (ex: 6.3.1, 4.1) - sem espaço antes/depois para não separar do item pai (6.3, 4).
  String _gerarTituloSubSubSecao(String titulo) {
    final textoEscapado = _escapeXml(titulo);
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:before="0" w:after="0" w:line="312" w:lineRule="auto"/>
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

  /// Gera texto de identificação do cadáver em formato pericial
  String _gerarIdentificacaoCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    // Parágrafo 1: Identificação básica (nome, documento, data nascimento, filiação)
    final textoIdentificacao = _gerarTextoIdentificacaoBasica(cadaver);
    if (textoIdentificacao.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(textoIdentificacao));
    }

    // Parágrafo 2: Características físicas
    final textoCaracteristicas = _gerarTextoCaracteristicasFisicas(cadaver);
    if (textoCaracteristicas.isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(textoCaracteristicas));
    }

    // Parágrafo 3: Tatuagens e marcas
    if (cadaver.tatuagensMarcas != null && cadaver.tatuagensMarcas!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Apresentava tatuagens/marcas: ${cadaver.tatuagensMarcas}.',
        ),
      );
    }

    if (buffer.isEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
    }

    return buffer.toString();
  }

  /// Gera texto de identificação básica (nome, documento, data nascimento, filiação)
  String _gerarTextoIdentificacaoBasica(CadaverModel cadaver) {
    final partes = <String>[];

    // Nome da vítima
    if (cadaver.nomeDaVitima != null && cadaver.nomeDaVitima!.isNotEmpty) {
      partes.add('identificado como ${_formatarNomeCorreto(cadaver.nomeDaVitima!)}');
    } else {
      partes.add('não identificado');
    }

    // Documento de identificação
    if (cadaver.documentoIdentificacao != null &&
        cadaver.documentoIdentificacao!.isNotEmpty) {
      partes.add(
        'portador do documento de identidade nº ${cadaver.documentoIdentificacao}',
      );
    }

    // Data de nascimento
    if (cadaver.dataNascimento != null && cadaver.dataNascimento!.isNotEmpty) {
      partes.add('nascido em ${cadaver.dataNascimento}');
    }

    // Filiação
    if (cadaver.filiacao != null && cadaver.filiacao!.isNotEmpty) {
      partes.add('filiação ${cadaver.filiacao}');
    }

    // Número do laudo cadavérico (adicionar ao final se houver)
    String texto = 'O cadáver foi ${partes.join(", ")}';
    if (texto.endsWith(',')) texto = texto.substring(0, texto.length - 1);
    texto += '.';

    if (cadaver.numeroLaudoCadaverico != null &&
        cadaver.numeroLaudoCadaverico!.isNotEmpty) {
      texto +=
          ' Laudo Cadavérico nº ${cadaver.numeroLaudoCadaverico} foi realizado.';
    }

    return texto;
  }

  /// Gera texto das características físicas em formato pericial
  String _gerarTextoCaracteristicasFisicas(CadaverModel cadaver) {
    final caracteristicas = <String>[];

    if (cadaver.sexo != null) {
      caracteristicas.add(cadaver.sexo!.label.toLowerCase());
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

    if (caracteristicas.isEmpty) return '';

    return 'Apresentava características de ${caracteristicas.join(", ")}.';
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

      // Citação das fotografias no anexo
      if (lesao.numerosFotografias != null &&
          lesao.numerosFotografias!.isNotEmpty) {
        final nums = lesao.numerosFotografias!
            .map((n) => n.toString().padLeft(2, '0'))
            .toList();
        if (nums.length == 1) {
          descricaoLesao += ' (Fotografia ${nums.first}).';
        } else if (nums.length == 2) {
          descricaoLesao += ' (Fotografias ${nums[0]} e ${nums[1]}).';
        } else {
          descricaoLesao +=
              ' (Fotografias ${nums.sublist(0, nums.length - 1).join(", ")} e ${nums.last}).';
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

  String _formatarListaTextoCrime<T>(
    Iterable<T>? valores,
    String Function(T) label,
  ) {
    if (valores == null || valores.isEmpty) return '';
    return valores.map(label).join(', ');
  }

  String _textoCondicoesCrimeTransito(CrimeTransitoCondicoesViaModel cond) {
    final partes = <String>[];
    final solo = _formatarListaTextoCrime(
      cond.condicoesSolo,
      (v) => switch (v) {
        CondicaoSoloLocal.seco => 'seco',
        CondicaoSoloLocal.umido => 'úmido',
        CondicaoSoloLocal.molhado => 'molhado',
      },
    );
    if (solo.isNotEmpty) {
      partes.add('O solo apresentava aspecto $solo');
    }

    final iluminacao = _formatarListaTextoCrime(
      cond.iluminacao,
      (v) => switch (v) {
        IluminacaoLocal.artificial => 'iluminação artificial',
        IluminacaoLocal.naturalDia => 'iluminação natural (diurna)',
        IluminacaoLocal.ausente => 'ausência de iluminação',
      },
    );
    if (iluminacao.isNotEmpty) {
      partes.add(iluminacao);
    }

    final tracado = _formatarListaTextoCrime(
      cond.tracados,
      (v) => switch (v) {
        TracadoPista.curvaEsquerda => 'curva à esquerda',
        TracadoPista.curvaDireita => 'curva à direita',
        TracadoPista.reto => 'trecho reto',
        TracadoPista.raioAmplo => 'raio amplo',
        TracadoPista.raioPequeno => 'raio pequeno',
        TracadoPista.cruzamento => 'cruzamento',
      },
    );
    if (tracado.isNotEmpty) {
      partes.add('com traçado $tracado');
    }

    final tipoPista = _formatarListaTextoCrime(
      cond.tiposPista,
      (v) => v == TipoPistaRodovia.simples ? 'simples' : 'dupla',
    );
    if (tipoPista.isNotEmpty) {
      partes.add('pista $tipoPista');
    }

    final sentidos = _formatarListaTextoCrime(
      cond.sentidos,
      (v) => v == SentidoPista.unico ? 'sentido único' : 'sentido duplo',
    );
    if (sentidos.isNotEmpty) {
      partes.add('com $sentidos');
    }

    final perfis = _formatarListaTextoCrime(
      cond.perfis,
      (v) => switch (v) {
        PerfilPista.plano => 'perfil plano',
        PerfilPista.suave => 'perfil suave',
        PerfilPista.declive => 'declive',
        PerfilPista.moderado => 'perfil moderado',
        PerfilPista.aclive => 'aclive',
        PerfilPista.acentuado => 'perfil acentuado',
      },
    );
    if (perfis.isNotEmpty) {
      partes.add(perfis);
    }

    if (cond.larguraPista != null && cond.larguraPista!.isNotEmpty) {
      partes.add('largura aproximada de ${cond.larguraPista} m');
    }

    final condVia = _formatarListaTextoCrime(
      cond.condicoesVia,
      (v) => switch (v) {
        CondicaoViaOpcao.seca => 'seca',
        CondicaoViaOpcao.molhada => 'molhada',
        CondicaoViaOpcao.semDefeito => 'sem defeitos aparentes',
        CondicaoViaOpcao.emObras => 'em obras',
        CondicaoViaOpcao.cascalho => 'revestida em cascalho',
        CondicaoViaOpcao.terra => 'revestida em terra',
        CondicaoViaOpcao.asfaltoRugoso => 'asfalto rugoso',
        CondicaoViaOpcao.buracos => 'com buracos',
        CondicaoViaOpcao.ondulacoes => 'com ondulações',
        CondicaoViaOpcao.contaminantes => 'com contaminantes',
        CondicaoViaOpcao.asfaltoLiso => 'asfalto liso',
        CondicaoViaOpcao.outro => 'em outra condição',
      },
    );
    if (condVia.isNotEmpty) {
      partes.add('via $condVia');
    }

    if (cond.regimeTrafego != null) {
      final regime = switch (cond.regimeTrafego!) {
        RegimeTrafego.intenso => 'regime de tráfego intenso',
        RegimeTrafego.moderado => 'regime moderado',
        RegimeTrafego.leve => 'regime leve',
        RegimeTrafego.outro => 'regime de tráfego atípico',
      };
      partes.add(regime);
    }
    if (cond.regimeTrafegoOutro != null &&
        cond.regimeTrafegoOutro!.isNotEmpty) {
      partes.add(cond.regimeTrafegoOutro!);
    }

    final visibilidade = cond.visibilidade == null
        ? ''
        : (cond.visibilidade == VisibilidadeTipo.boa
              ? 'visibilidade considerada boa'
              : 'visibilidade reduzida');
    if (visibilidade.isNotEmpty) {
      String texto = visibilidade;
      if (cond.visibilidadeReducaoDescricao != null &&
          cond.visibilidadeReducaoDescricao!.isNotEmpty) {
        texto += ' (${cond.visibilidadeReducaoDescricao})';
      }
      partes.add(texto);
    }

    if (cond.velocidadeMaxima != null && cond.velocidadeMaxima!.isNotEmpty) {
      partes.add('velocidade máxima sinalizada de ${cond.velocidadeMaxima}');
    }

    if (cond.velocidadePorSinalizacao == true ||
        cond.velocidadePorCTB == true) {
      final refs = <String>[];
      if (cond.velocidadePorSinalizacao == true) {
        refs.add('sinalização expressa');
      }
      if (cond.velocidadePorCTB == true) refs.add('CTB/1997');
      partes.add('considerando referências de ${refs.join(" e ")}');
    }

    if (cond.largurasFaixas != null && cond.largurasFaixas!.isNotEmpty) {
      partes.add(
        'faixas com larguras aproximadas de ${cond.largurasFaixas!.join(", ")} m',
      );
    }

    if (cond.observacoes != null && cond.observacoes!.isNotEmpty) {
      partes.add(cond.observacoes!);
    }

    return partes.join('. ').trim();
  }

  String _textoVeiculosCrimeTransito(FichaCompletaModel ficha) {
    final veiculos = ficha.veiculos;
    if (veiculos == null || veiculos.isEmpty) return '';
    final frases = <String>[];

    for (final veiculo in veiculos) {
      final detalhes = <String>[];
      if (veiculo.tipoVeiculo != null) {
        detalhes.add('tipo ${veiculo.tipoVeiculo!.label}');
      }
      if (veiculo.marcaModelo != null && veiculo.marcaModelo!.isNotEmpty) {
        detalhes.add(veiculo.marcaModelo!);
      }
      if (veiculo.placa != null && veiculo.placa!.isNotEmpty) {
        detalhes.add('placa ${veiculo.placa}');
      }
      if (veiculo.localizacaoAmbiente != null &&
          veiculo.localizacaoAmbiente!.isNotEmpty) {
        detalhes.add('localizado em ${veiculo.localizacaoAmbiente}');
      }
      final intensidade = veiculo.intensidadeDano == null
          ? ''
          : switch (veiculo.intensidadeDano!) {
              IntensidadeDano.leve => 'danos leves',
              IntensidadeDano.media => 'danos médios',
              IntensidadeDano.grave => 'danos graves',
              IntensidadeDano.gravissima => 'danos gravíssimos',
            };
      if (intensidade.isNotEmpty) detalhes.add(intensidade);

      final setores = _formatarListaTextoCrime(
        veiculo.setoresImpacto,
        (v) => switch (v) {
          SetorImpacto.anterior => 'no setor anterior',
          SetorImpacto.posterior => 'no setor posterior',
          SetorImpacto.lateralEsquerdo => 'na lateral esquerda',
          SetorImpacto.lateralDireito => 'na lateral direita',
          SetorImpacto.angularAnteriorEsquerdo => 'no ângulo anterior esquerdo',
          SetorImpacto.angularAnteriorDireito => 'no ângulo anterior direito',
          SetorImpacto.angularPosteriorEsquerdo =>
            'no ângulo posterior esquerdo',
          SetorImpacto.angularPosteriorDireito => 'no ângulo posterior direito',
        },
      );
      if (setores.isNotEmpty) detalhes.add(setores);

      if (veiculo.danosObservacoes != null &&
          veiculo.danosObservacoes!.isNotEmpty) {
        detalhes.add(veiculo.danosObservacoes!);
      }

      if (veiculo.tacografoStatus != null) {
        detalhes.add(
          'disco de tacógrafo ${veiculo.tacografoStatus == TacografoStatus.recolhido ? 'recolhido' : 'ausente'}',
        );
      }
      if (veiculo.frenagemMetros != null &&
          veiculo.frenagemMetros!.isNotEmpty) {
        detalhes.add(
          'marcas de frenagem próximas a ${veiculo.frenagemMetros} m',
        );
      }
      if (detalhes.isNotEmpty) {
        frases.add('Veículo ${veiculo.numero}: ${detalhes.join(', ')}.');
      }
    }

    return frases.join(' ').trim();
  }

  String _textoEnvolvidosCrimeTransito(FichaCompletaModel ficha) {
    final envolvidos = ficha.envolvidosTransito;
    if (envolvidos == null || envolvidos.isEmpty) return '';
    final partes = <String>[];
    for (final envolvido in envolvidos) {
      final detalhes = <String>[];
      final nome = envolvido.nome?.trim();
      if (nome != null && nome.isNotEmpty) detalhes.add(nome);
      if (envolvido.classificacao != null) {
        detalhes.add(switch (envolvido.classificacao!) {
          CrimeTransitoClassificacaoEnvolvido.condutor => 'condutor',
          CrimeTransitoClassificacaoEnvolvido.passageiro => 'passageiro',
          CrimeTransitoClassificacaoEnvolvido.pedestre => 'pedestre',
        });
      }
      if (envolvido.situacao != null) {
        detalhes.add(switch (envolvido.situacao!) {
          CrimeTransitoSituacaoEnvolvido.semFerimentos =>
            'sem ferimentos aparentes',
          CrimeTransitoSituacaoEnvolvido.feridoGrave => 'com ferimentos graves',
          CrimeTransitoSituacaoEnvolvido.obito => 'em óbito',
        });
      }
      if (envolvido.posicao != null) {
        detalhes.add(switch (envolvido.posicao!) {
          CrimeTransitoPosicaoEnvolvido.interiorVeiculo =>
            'no interior do veículo',
          CrimeTransitoPosicaoEnvolvido.leitoVia => 'no leito da via',
          CrimeTransitoPosicaoEnvolvido.exteriorPista => 'no exterior da pista',
        });
      }
      if (envolvido.posicaoDetalhe != null &&
          envolvido.posicaoDetalhe!.isNotEmpty) {
        detalhes.add(envolvido.posicaoDetalhe!);
      }
      final equipamentos = _formatarListaTextoCrime(
        envolvido.equipamentosSeguranca,
        (e) => switch (e) {
          CrimeTransitoEquipamentoSeguranca.cinto => 'cinto',
          CrimeTransitoEquipamentoSeguranca.capacete => 'capacete',
          CrimeTransitoEquipamentoSeguranca.nenhum => 'sem proteção',
          CrimeTransitoEquipamentoSeguranca.naoSeAplica => 'não se aplica',
        },
      );
      if (equipamentos.isNotEmpty) {
        detalhes.add('equipamento(s): $equipamentos');
      }
      if (detalhes.isNotEmpty) {
        partes.add('Envolvido: ${detalhes.join(', ')}.');
      }
    }

    return partes.join(' ').trim();
  }

  String _textoNaturezaCrimeTransito(CrimeTransitoNaturezaModel? natureza) {
    if (natureza == null) return '';
    final detalhes = <String>[];
    if (natureza.tipo != null) {
      detalhes.add(
        natureza.tipo == CrimeTransitoNaturezaTipo.simples
            ? 'ocorrência simples'
            : 'ocorrência composta',
      );
    }
    if (natureza.quantidadeUnidades != null) {
      detalhes.add('${natureza.quantidadeUnidades} unidade(s) envolvida(s)');
    }
    final formas = _formatarListaTextoCrime(
      natureza.formasInteracao,
      (f) => switch (f) {
        CrimeTransitoFormaInteracao.saidaPista => 'saída de pista',
        CrimeTransitoFormaInteracao.colisao => 'colisão',
        CrimeTransitoFormaInteracao.colisaoFrontal => 'colisão frontal',
        CrimeTransitoFormaInteracao.colisaoOposta =>
          'colisão em sentidos opostos',
        CrimeTransitoFormaInteracao.objetoFixo => 'choque contra objeto fixo',
        CrimeTransitoFormaInteracao.capotamento => 'capotamento',
        CrimeTransitoFormaInteracao.abalroamento => 'abalroamento',
        CrimeTransitoFormaInteracao.colisaoTraseira => 'colisão traseira',
        CrimeTransitoFormaInteracao.colisaoTransversal => 'colisão transversal',
        CrimeTransitoFormaInteracao.veiculoEstacionado =>
          'impacto em veículo estacionado',
        CrimeTransitoFormaInteracao.tombamento => 'tombamento',
        CrimeTransitoFormaInteracao.choque => 'choque',
        CrimeTransitoFormaInteracao.colisaoLateral => 'colisão lateral',
        CrimeTransitoFormaInteracao.colisaoObliqua => 'colisão oblíqua',
        CrimeTransitoFormaInteracao.veiculoParado =>
          'colisão com veículo parado',
        CrimeTransitoFormaInteracao.colisaoLongitudinal =>
          'colisão longitudinal',
        CrimeTransitoFormaInteracao.colisaoOrtogonal => 'colisão ortogonal',
        CrimeTransitoFormaInteracao.pedestre => 'atropelamento de pedestre',
        CrimeTransitoFormaInteracao.queda => 'queda de ocupante',
        CrimeTransitoFormaInteracao.atropelamento => 'atropelamento',
        CrimeTransitoFormaInteracao.animal => 'atropelamento de animal',
        CrimeTransitoFormaInteracao.outro => 'outra interação',
      },
    );
    if (formas.isNotEmpty) {
      detalhes.add('formas de interação: $formas');
    }
    if (natureza.materialRecolhido != null) {
      detalhes.add(
        natureza.materialRecolhido!
            ? 'houve recolhimento de material'
            : 'não houve recolhimento de material',
      );
    }
    if (natureza.materialDescricao != null &&
        natureza.materialDescricao!.isNotEmpty) {
      detalhes.add('material recolhido: ${natureza.materialDescricao}');
    }
    if (natureza.solicitacaoExamesComplementares != null) {
      detalhes.add(
        natureza.solicitacaoExamesComplementares!
            ? 'foram solicitados exames complementares'
            : 'não foram solicitados exames complementares',
      );
    }
    if (natureza.laboratorioDestino != null &&
        natureza.laboratorioDestino!.isNotEmpty) {
      detalhes.add('destinados à ${natureza.laboratorioDestino}');
    }
    if (natureza.examesDinamica != null &&
        natureza.examesDinamica!.isNotEmpty) {
      detalhes.add('dinâmica dos exames: ${natureza.examesDinamica}');
    }
    if (natureza.croquiObservacoes != null &&
        natureza.croquiObservacoes!.isNotEmpty) {
      detalhes.add('croqui: ${natureza.croquiObservacoes}');
    }
    return detalhes.join('. ');
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
            : 'Não foram observados indícios de destruição ou rompimento de obstáculos no local.',
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
            : 'Não foram detectados indícios de escalada ou destreza no local do exame.',
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
            : 'Não foram encontrados indícios compatíveis com o emprego de chave falsa.',
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
            : 'Os vestígios detectados não foram suficientes para concluir acerca da presença de dois ou mais indivíduos no local do fato.',
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
            : 'Os vestígios não apresentaram características que indicassem recenticidade.',
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

    if (ficha.modusOperandi != null && ficha.modusOperandi!.trim().isNotEmpty) {
      buffer.writeln(_gerarParagrafoHistorico(ficha.modusOperandi!.trim()));
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          '[Inserir descrição da dinâmica parcial mais provável do evento]',
        ),
      );
    }

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

    // (6) QUEM (é/são o/os autor/es)
    buffer.writeln(
      _gerarParagrafoHistorico(
        '(6) QUEM (é/são o/os autor/es): A ser apurado mediante investigação policial.',
      ),
    );

    // (7) POR QUÊ (motivação)
    buffer.writeln(
      _gerarParagrafoHistorico(
        '(7) POR QUÊ (motivação): A ser apurado mediante investigação policial.',
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

  /// Retorna o próximo rId disponível no XML de relationships (ex.: para adicionar footnotes).
  int _proximoRIdEmRels(String relsContent) {
    final idRegex = RegExp(r'Id="rId(\d+)"');
    int maxId = 0;
    idRegex.allMatches(relsContent).forEach((m) {
      final id = int.tryParse(m.group(1) ?? '0') ?? 0;
      if (id > maxId) maxId = id;
    });
    return maxId + 1;
  }

  /// Gera o XML de word/footnotes.xml com a nota do Feca Cult (w:id="1").
  String _gerarFootnotesXml() {
    const textoFecaCult =
        'Feca Cult One Step Teste é um teste imunocromatográfico rápido que detecta qualitativamente e especificamente a hemoglobina humana (hHb). O teste é sensível a concentrações de hHb iguais ou superiores a 40ng/mL, mas, em alguns casos, pode detectar resultados positivos em concentrações menores.';
    const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:footnotes xmlns:w="$ns">
  <w:footnote w:type="separator" w:id="-1">
    <w:p>
      <w:r>
        <w:separator/>
      </w:r>
    </w:p>
  </w:footnote>
  <w:footnote w:type="continuationSeparator" w:id="0">
    <w:p>
      <w:r>
        <w:continuationSeparator/>
      </w:r>
    </w:p>
  </w:footnote>
  <w:footnote w:id="1">
    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="220" w:lineRule="auto"/>
        <w:ind w:left="284" w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:sz w:val="18"/>
          <w:szCs w:val="18"/>
          <w:i/>
        </w:rPr>
        <w:t>${_escapeXml(textoFecaCult)}</w:t>
      </w:r>
    </w:p>
  </w:footnote>
</w:footnotes>''';
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
    // Parágrafo para lista com recuo pendente. Se texto contiver '¹', usa nota de rodapé real (footnoteReference).
    final partes = texto.split('¹');
    if (partes.length == 2) {
      // Nota de rodapé real: referência no corpo e conteúdo em word/footnotes.xml
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
          <w:sz w:val="20"/>
          <w:szCs w:val="20"/>
          <w:vertAlign w:val="superscript"/>
        </w:rPr>
        <w:footnoteReference w:id="1"/>
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
      return _gerarParagrafoLista(texto);
    }
  }

  String _gerarLevantamentoFotografico(
    List<File> fotos,
    int maxId, {
    int? mapaRId,
    List<String>? legendas,
  }) {
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

    // Quando há mapa (seção 4.1), ele usa maxId+1; as fotos do anexo começam em maxId+2.
    // No anexo exibimos só as fotos (Fotografia 01 = primeira foto, etc.).
    final rIdOffset = mapaRId != null ? 1 : 0;
    for (int i = 0; i < fotos.length; i++) {
      final numeroFoto = (i + 1).toString().padLeft(2, '0');
      final rId = maxId + 1 + rIdOffset + i;
      final legendaDescricao = (legendas != null && i < legendas.length)
          ? legendas[i]
          : null;
      buffer.writeln(
        _gerarFotografia(numeroFoto, rId, legendaDescricao: legendaDescricao),
      );

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

  /// Legenda (Imagem 01 + texto) e imagem do mapa do local para a seção 4.1.
  /// Fonte 10 (20 half-points), centralizado, espaçamento simples.
  String _gerarLegendaEImagemMapa(int rId) {
    const emuPorCm = 914400 / 2.54;
    final larguraEmu = (16.0 * emuPorCm).round();
    final alturaEmu = (9.9 * emuPorCm).round();

    const legenda = 'Imagem 01: Captura de tela indicando o local periciado.';
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
            <wp:docPr id="$rId" name="Imagem mapa"/>
            <wp:cNvGraphicFramePr>
              <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
            </wp:cNvGraphicFramePr>
            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:nvPicPr>
                    <pic:cNvPr id="$rId" name="Imagem mapa"/>
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

  String _gerarFotografia(
    String numeroFoto,
    int rId, {
    String? legendaDescricao,
  }) {
    // Legenda ANTES da foto - 10pt, centralizado. Ex.: "Fotografia 01: Vista ampla do local (fachada)."
    final legenda = legendaDescricao != null && legendaDescricao.isNotEmpty
        ? 'Fotografia $numeroFoto: $legendaDescricao'
        : 'Fotografia $numeroFoto:';

    // Tamanho da imagem: 16 cm x 9,9 cm (fixo para todas as fotos do anexo)
    // Em EMUs (English Metric Units): 1 polegada = 914400 EMUs, 1 pol = 2,54 cm
    const emuPorCm = 914400 / 2.54;
    final larguraEmu = (16.0 * emuPorCm).round();
    final alturaEmu = (9.9 * emuPorCm).round();

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
    List<File> fotos, {
    File? imagemMapaLocal,
  }) async {
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
      relationshipsContent =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
    }

    final regex = RegExp(
      r'<Relationships[^>]*>(.*?)</Relationships>',
      dotAll: true,
    );
    final match = regex.firstMatch(relationshipsContent);
    int maxId = 0;
    final existingRels = match != null ? (match.group(1) ?? '') : '';

    if (match != null) {
      final idRegex = RegExp(r'Id="rId(\d+)"');
      idRegex.allMatches(existingRels).forEach((m) {
        final id = int.tryParse(m.group(1) ?? '0') ?? 0;
        if (id > maxId) maxId = id;
      });
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    buffer.write(existingRels);

    final fileNames = <String>[];
    int? mapaRId;
    String? mapaFileName;

    // Imagem do mapa (captura de tela do local) em primeiro, rId = maxId+1
    if (imagemMapaLocal != null && await imagemMapaLocal.exists()) {
      final ext = imagemMapaLocal.path.split('.').last.toLowerCase();
      mapaFileName = 'mapa_local_${DateTime.now().microsecondsSinceEpoch}.$ext';
      mapaRId = maxId + 1;
      buffer.writeln(
        '  <Relationship Id="rId$mapaRId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$mapaFileName"/>',
      );
      fileNames.add(mapaFileName);
    }

    // Fotos do anexo (rId = maxId+2, maxId+3, ...)
    int imageCounter = fileNames.length + 1;
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
    return {
      'xml': buffer.toString(),
      'maxId': maxId,
      'fileNames': fileNames,
      'mapaRId': mapaRId,
      'mapaFileName': mapaFileName,
    };
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
