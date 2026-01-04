import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ficha_completa_model.dart';
import '../models/ficha_base_model.dart';
import '../models/pessoa_envolvida_model.dart';
import '../models/perito_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/membro_equipe_model.dart';
import '../models/equipe_policial_ficha_model.dart';
import '../services/equipe_service.dart';

/// Serviço responsável por gerar documentos de LAUDO em formato Word (DOCX)
/// a partir de uma FichaCompletaModel
class LaudoGeneratorService {
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
  }) async {
    // Ler o template
    final templateFile = File(templatePath);
    if (!await templateFile.exists()) {
      throw Exception('Template não encontrado: $templatePath');
    }

    final templateBytes = await templateFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // Encontrar e processar document.xml
    final documentXmlIndex = archive.files.indexWhere((f) => f.name == 'word/document.xml');
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

    // Gerar novo conteúdo do documento
    final novoConteudo = await _gerarConteudoLaudo(ficha, perito, documentContent);

    // Criar novo arquivo com o conteúdo atualizado
    final novoArchive = Archive();
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        final novoDocBytes = Uint8List.fromList(utf8.encode(novoConteudo));
        novoArchive.addFile(ArchiveFile(file.name, novoDocBytes.length, novoDocBytes));
      } else {
        novoArchive.addFile(file);
      }
    }

    final zipBytes = ZipEncoder().encode(novoArchive);

    // Salvar o arquivo
    final directory = await getApplicationDocumentsDirectory();
    final dadosSol = ficha.dadosSolicitacao;
    final numeroOcorrencia = (dadosSol.numeroOcorrencia ?? 'sem_numero').replaceAll('/', '-');
    final fileName = 'Laudo_${numeroOcorrencia}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final outputFile = File('${directory.path}/$fileName');
    await outputFile.writeAsBytes(zipBytes);

    return outputFile;
  }

  Future<String> _gerarConteudoLaudo(FichaCompletaModel ficha, PeritoModel perito, String documentContent) async {
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
    // Subtítulo centralizado, entrelinhas simples (240 = 1.0)
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeSubtitulo"/>
          <w:szCs w:val="$_fontSizeSubtitulo"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarTabelaIdentificacao(FichaCompletaModel ficha, PeritoModel perito) {
    final buffer = StringBuffer();
    final sol = ficha.dadosSolicitacao;

    // Construir as linhas da tabela
    final linhas = <List<String>>[
      ['Procedimento:', sol.raiNumero ?? ''],
      ['Requisitante:', sol.unidadeOrigem ?? ''],
      ['Delegacia Afeta:', sol.unidadeAfeta ?? ''],
      ['Pessoas Envolvidas:', _formatarPessoasEnvolvidas(sol.pessoasEnvolvidas)],
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
      final nome = pessoa.nome;
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

  Future<String> _gerarSecaoHistorico(FichaCompletaModel ficha, PeritoModel perito) async {
    final buffer = StringBuffer();
    final equipeService = EquipeService();

    // Título da seção "1. HISTÓRICO"
    buffer.writeln(_gerarTituloSecao('1. HISTÓRICO'));

    // Primeiro parágrafo
    final horaInicio = _extrairHoraInicio(ficha.dataHoraInicio);
    final membrosEquipe = await _formatarMembrosEquipe(ficha, equipeService);
    buffer.writeln(_gerarParagrafoHistorico(
      'Após solicitação via Sistema ODIN, o(a) Perito(a) Criminal supracitado(a) procedeu ao local às $horaInicio, na data preambular, acompanhado do(s) $membrosEquipe e realizou o levantamento pericial requisitado.',
    ));

    // Segundo parágrafo
    final vitimaComunicante = _obterVitimaComunicante(ficha.dadosSolicitacao.pessoasEnvolvidas);
    final historico = ficha.dadosFichaBase?.historico ?? '';
    buffer.writeln(_gerarParagrafoHistorico(
      'No local, a equipe de Polícia Científica foi recebida por $vitimaComunicante e conforme relatos $historico',
    ));

    // Terceiro parágrafo (se houver equipes policiais)
    if (ficha.equipesPoliciais != null && ficha.equipesPoliciais!.isNotEmpty) {
      final equipesTexto = _formatarEquipesPoliciais(ficha.equipesPoliciais!);
      buffer.writeln(_gerarParagrafoHistorico(
        'Faziam-se presentes no local a(s) $equipesTexto.',
      ));
    }

    // Quarto parágrafo (término das atividades)
    final horaTermino = _extrairHoraTermino(ficha.dataHoraTermino);
    buffer.writeln(_gerarParagrafoHistorico(
      'Ao término das atividades periciais, aproximadamente às $horaTermino, a equipe procedeu à liberação do local para o(s) responsável(is) designado(s). Essa ação foi realizada após a conclusão de todos os procedimentos requisitados.',
    ));

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

  Future<String> _formatarMembrosEquipe(FichaCompletaModel ficha, EquipeService equipeService) async {
    if (ficha.equipe == null) return 'equipe de perícia';
    
    final todosMembros = await equipeService.listarEquipe();
    final membros = <String>[];

    // Fotógrafo
    if (ficha.equipe!.fotografoCriminalisticoId != null) {
      final fotografo = todosMembros.firstWhere(
        (m) => m.id == ficha.equipe!.fotografoCriminalisticoId,
        orElse: () => MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
      );
      if (fotografo.nome.isNotEmpty) {
        membros.add('${fotografo.cargo} ${fotografo.nome}');
      }
    }

    // Demais servidores
    for (final id in ficha.equipe!.demaisServidoresIds) {
      final membro = todosMembros.firstWhere(
        (m) => m.id == id,
        orElse: () => MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
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
    
    final vitimaComunicante = pessoas.firstWhere(
      (p) => p.tipo == TipoPessoa.vitimaComunicante,
      orElse: () => PessoaEnvolvidaModel(nome: '', tipo: TipoPessoa.outro),
    );
    
    if (vitimaComunicante.nome.isNotEmpty) {
      return _formatarNomeCorreto(vitimaComunicante.nome);
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
      final membros = equipe.membros.map((m) {
        final posto = m.postoGraduacao != null ? ' (${m.postoGraduacao})' : '';
        return '${m.nome}$posto';
      }).join(', ');
      
      partes.add('$tipoNome: $membros');
    }
    
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes[0];
    if (partes.length == 2) return '${partes[0]} e ${partes[1]}';
    
    final ultimo = partes.removeLast();
    return '${partes.join(', ')}, e $ultimo';
  }

  String _gerarSecaoObjetivos() {
    final buffer = StringBuffer();
    
    // Título da seção "2. OBJETIVOS"
    buffer.writeln(_gerarTituloSecao('2. OBJETIVOS'));
    
    // Parágrafo com o texto dos objetivos
    buffer.writeln(_gerarParagrafoHistorico(
      'Estabelecer a materialidade dos fatos, buscando os elementos comprobatórios e os meios e/ou instrumentos utilizados na perpetração do ato delituoso e, se possível, os vestígios materiais que contribuam com a elucidação da autoria.',
    ));
    
    return buffer.toString();
  }

  String _gerarSecaoIsolamentoPreservacao(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    final fb = ficha.dadosFichaBase;
    
    // Título da seção "3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS"
    buffer.writeln(_gerarTituloSecao('3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS'));
    
    // ISOLAMENTO
    if (fb?.isolamentoNao == true) {
      buffer.writeln(_gerarParagrafoHistorico(
        'O local do fato não contava com medidas oficiais de isolamento.',
      ));
    } else if (fb?.isolamentoSim == true) {
      final meios = _formatarMeiosIsolamento(fb!);
      buffer.writeln(_gerarParagrafoHistorico(
        'O local encontrava-se isolado por $meios.',
      ));
    }
    
    // PRESERVAÇÃO
    if (fb?.preservacaoSim == true) {
      buffer.writeln(_gerarParagrafoHistorico(
        'Quanto à Preservação, não foram relatadas e/ou constatadas alterações aparentes no estado geral das coisas, o que possibilitou o levantamento.',
      ));
    } else if (fb?.preservacaoNao == true) {
      if (fb?.preservacaoParcialmenteIdoneo == true) {
        final alteracoes = fb?.preservacaoAlteracoesDetectadas ?? '';
        buffer.writeln(_gerarParagrafoHistorico(
          'Quanto à Preservação, que ficou a cargo da própria vítima, houve alteração no estado geral das coisas $alteracoes',
        ));
        buffer.writeln(_gerarParagrafoHistorico(
          'Apesar disso, havia no local vestígios que puderam estar relacionados à ação delituosa o que permitiu a realização do levantamento pericial nas condições apresentadas.',
        ));
      } else if (fb?.preservacaoInidoneo == true) {
        buffer.writeln(_gerarParagrafoHistorico(
          'Devido à ausência de Preservação do local, não foram encontrados vestígios relacionados aos fatos apontados no histórico, não sendo possível realizar qualquer análise e/ou emitir conclusão segura relativa ao fato.',
        ));
      }
    }
    
    return buffer.toString();
  }

  String _formatarMeiosIsolamento(FichaBaseModel fb) {
    final meios = <String>[];
    
    if (fb.isolamentoViatura == true) meios.add('viatura');
    if (fb.isolamentoCones == true) meios.add('cones');
    if (fb.isolamentoFitaZebrada == true) meios.add('fita zebrada');
    if (fb.isolamentoPresencaFisica == true) meios.add('presença física');
    if (fb.isolamentoCuriososVoltaCorpo == true) meios.add('curiosos ao redor do corpo');
    if (fb.isolamentoCorpoCobertoMovimentado == true) meios.add('corpo coberto/movimentado');
    if (fb.isolamentoDocumentosManuseados == true) meios.add('documentos manuseados');
    if (fb.isolamentoVestigiosRecolhidos == true) meios.add('vestígios recolhidos');
    if (fb.isolamentoAmpliacaoPerimetro == true) meios.add('ampliação do perímetro');
    
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

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

