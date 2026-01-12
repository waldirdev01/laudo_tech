import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ficha_completa_model.dart';
import '../models/perito_model.dart';
import '../models/membro_equipe_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/evidencia_model.dart';
import '../services/perito_service.dart';
import '../services/equipe_service.dart';

/// Serviço para gerar documentos Word a partir de templates
/// Preserva cabeçalho/rodapé do template e gera o conteúdo programaticamente
class WordGeneratorService {
  final _peritoService = PeritoService();
  final _equipeService = EquipeService();

  // Configurações de formatação
  static const String _fontName = 'GADUGI';
  static const String _fontSize = '24'; // 12pt em half-points
  static const String _fontSizeTitulo = '28'; // 14pt

  /// Gera um documento Word preenchendo o template com os dados da ficha
  Future<File> gerarDocumentoWord(FichaCompletaModel ficha) async {
    // Obter o perito e o caminho do template
    final perito = await _peritoService.obterPerito();
    if (perito == null || perito.caminhoTemplate == null) {
      throw Exception('Perito não cadastrado ou template não encontrado. Vá em Configurações > Editar Perito e selecione o template novamente.');
    }

    final templateFile = File(perito.caminhoTemplate!);
    if (!await templateFile.exists()) {
      throw Exception('O arquivo template não foi encontrado. Por favor, vá em Configurações > Editar Perito e selecione o template novamente.');
    }

    // Ler o template
    final templateBytes = await templateFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // Gerar o conteúdo do documento
    final conteudoXml = await _gerarConteudoDocumento(ficha, perito);

    // Processar cada arquivo do ZIP
    final novoArchive = Archive();
    for (final arquivo in archive) {
      dynamic conteudo = arquivo.content;

      // Se for o documento principal, substituir pelo conteúdo gerado
      if (arquivo.name == 'word/document.xml') {
        // Ler o XML original para extrair a estrutura (sectPr com referências a header/footer)
        String xmlOriginal;
        if (conteudo is List<int>) {
          try {
            xmlOriginal = utf8.decode(conteudo);
          } catch (e) {
            xmlOriginal = String.fromCharCodes(conteudo);
          }
        } else {
          xmlOriginal = conteudo.toString();
        }

        // Extrair sectPr do documento original (contém referências a header/footer)
        final sectPr = _extrairSectPr(xmlOriginal);
        
        // Criar o novo documento com o conteúdo gerado
        final novoXml = _montarDocumentoCompleto(conteudoXml, sectPr);
        conteudo = Uint8List.fromList(utf8.encode(novoXml));
      }

      // Adicionar ao novo arquivo
      final tamanho = conteudo is List<int> 
          ? conteudo.length 
          : (conteudo is String 
              ? conteudo.length 
              : arquivo.size);
      
      novoArchive.addFile(ArchiveFile(
        arquivo.name,
        tamanho,
        conteudo,
      ));
    }

    // Criar o novo arquivo Word
    final encoder = ZipEncoder();
    final novoBytes = encoder.encode(novoArchive);

    // Salvar em um local temporário
    final diretorio = await getApplicationDocumentsDirectory();
    final raiNumeroSaneado = (ficha.dadosSolicitacao.raiNumero ?? ficha.id).replaceAll('/', '-');
    final nomeArquivo = 'Ficha_${raiNumeroSaneado}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final arquivoFinal = File('${diretorio.path}/$nomeArquivo');
    await arquivoFinal.writeAsBytes(novoBytes);

    return arquivoFinal;
  }

  /// Extrai o elemento sectPr do documento original (contém config de página, header/footer refs)
  String _extrairSectPr(String xml) {
    final regex = RegExp(r'<w:sectPr[^>]*>.*?</w:sectPr>', dotAll: true);
    final match = regex.firstMatch(xml);
    if (match != null) {
      return match.group(0)!;
    }
    // Se não encontrar, retornar um sectPr padrão
    return '''<w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1417" w:right="1701" w:bottom="1417" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>''';
  }

  /// Monta o documento completo com o conteúdo gerado e o sectPr original
  String _montarDocumentoCompleto(String conteudo, String sectPr) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" 
            xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex" 
            xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" 
            xmlns:o="urn:schemas-microsoft-com:office:office" 
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" 
            xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" 
            xmlns:v="urn:schemas-microsoft-com:vml" 
            xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" 
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" 
            xmlns:w10="urn:schemas-microsoft-com:office:word" 
            xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
            xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" 
            xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" 
            xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" 
            xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" 
            xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" 
            xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" 
            mc:Ignorable="w14 w15 wp14">
  <w:body>
$conteudo
    $sectPr
  </w:body>
</w:document>''';
  }

  /// Gera todo o conteúdo do documento em XML
  Future<String> _gerarConteudoDocumento(FichaCompletaModel ficha, PeritoModel perito) async {
    final buffer = StringBuffer();

    // TÍTULO
    buffer.writeln(_gerarTitulo('FICHA DE EXAME DE LOCAL'));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 1: SOLICITAÇÃO
    buffer.writeln(await _gerarTabelaSolicitacao(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 2: EQUIPE DE PERÍCIA CRIMINAL ACIONADA
    buffer.writeln(await _gerarTabelaEquipePericia(ficha, perito));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 3: DEMAIS EQUIPES POLICIAIS/DE SALVAMENTO
    // Mostrar sempre, mesmo se não houver equipes (pode ter marcado "Não havia equipes")
    if (ficha.naoHaviaEquipesPoliciais == true || 
        (ficha.equipesPoliciais != null && ficha.equipesPoliciais!.isNotEmpty)) {
      buffer.writeln(_gerarTabelaEquipesPoliciais(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    // TABELA 4: LOCAL
    buffer.writeln(_gerarTabelaLocal(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 5: HISTÓRICO
    if (ficha.dadosFichaBase?.historico != null && ficha.dadosFichaBase!.historico!.isNotEmpty) {
      buffer.writeln(_gerarTabelaHistorico(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    // TABELA 6: ISOLAMENTO
    buffer.writeln(_gerarTabelaIsolamento(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 7: PRESERVAÇÃO
    buffer.writeln(_gerarTabelaPreservacao(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 8: CONDIÇÕES AMBIENTAIS
    buffer.writeln(_gerarTabelaCondicoesAmbientais(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // Se for FURTO/DANO, adicionar tabelas específicas
    if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
      // TABELA 8: LOCAL (FURTO)
      if (ficha.localFurto != null) {
        buffer.writeln(_gerarTabelaLocalFurto(ficha));
        buffer.writeln(_gerarParagrafoVazio());
      }

      // TABELA 9: EVIDÊNCIAS
      if (ficha.evidenciasFurto != null) {
        buffer.writeln(_gerarTabelaEvidencias(ficha));
        // Alerta sobre croqui (obrigatório) - sempre aparece após evidências
        buffer.writeln(_gerarParagrafoVazio());
        buffer.writeln('''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:color w:val="FF0000"/>
          <w:sz w:val="$_fontSize"/>
        </w:rPr>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:color w:val="FF0000"/>
          <w:sz w:val="$_fontSize"/>
        </w:rPr>
        <w:t>⚠️ OBSERVAÇÃO: Faça seu croqui e adicione depois quando gerar a ficha.</w:t>
      </w:r>
    </w:p>''');
        buffer.writeln(_gerarParagrafoVazio());
      }

      // TABELA 10: MODUS OPERANDI
      if (ficha.modusOperandi != null && ficha.modusOperandi!.isNotEmpty) {
        buffer.writeln(_gerarTabelaModusOperandi(ficha));
        buffer.writeln(_gerarParagrafoVazio());
      }

      // TABELA 11: DANO
      if (ficha.dano != null) {
        buffer.writeln(_gerarTabelaDano(ficha));
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  // ============ GERADORES DE ELEMENTOS XML ============

  String _gerarTitulo(String texto) {
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeTitulo"/>
        </w:rPr>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeTitulo"/>
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoVazio() {
    return '''    <w:p>
      <w:pPr>
        <w:spacing w:after="0"/>
      </w:pPr>
    </w:p>''';
  }


  // ============ GERADORES DE TABELAS ============

  Future<String> _gerarTabelaSolicitacao(FichaCompletaModel ficha) async {
    final sol = ficha.dadosSolicitacao;
    
    return _gerarTabela(
      cabecalho: 'SOLICITAÇÃO',
      linhas: [
        ['RAI', sol.raiNumero ?? ''],
        ['Natureza da Ocorrência', sol.naturezaOcorrencia ?? ''],
        ['Data/Hora da Comunicação', sol.dataHoraComunicacao ?? ''],
        ['Unidade Requisitante', sol.unidadeOrigem ?? ''],
        ['Unidade Afeta', sol.unidadeAfeta ?? ''],
        ['Número da Ocorrência', sol.numeroOcorrencia ?? ''],
        ['Data/Hora Deslocamento', ficha.dataHoraDeslocamento ?? ''],
        ['Data/Hora Início', ficha.dataHoraInicio ?? ''],
        ['Data/Hora Término', ficha.dataHoraTermino ?? 'Em andamento'],
        ['Pedido de Dilação', ficha.pedidoDilacao ?? ''],
      ],
    );
  }

  Future<String> _gerarTabelaEquipePericia(FichaCompletaModel ficha, PeritoModel perito) async {
    final linhas = <List<String>>[];
    
    // Perito Criminal (sempre o dono do app)
    linhas.add(['Perito Criminal', '${perito.nome} - ${perito.matricula}']);

    // Fotógrafo e outros membros
    if (ficha.equipe != null) {
      final membros = await _equipeService.listarEquipe();
      
      if (ficha.equipe!.fotografoCriminalisticoId != null) {
        final fotografo = membros.firstWhere(
          (m) => m.id == ficha.equipe!.fotografoCriminalisticoId,
          orElse: () => MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
        );
        if (fotografo.nome.isNotEmpty) {
          linhas.add(['Fotógrafo Criminalístico', '${fotografo.nome} - ${fotografo.matricula}']);
        }
      }

      if (ficha.equipe!.demaisServidoresIds.isNotEmpty) {
        final demais = ficha.equipe!.demaisServidoresIds
            .map((id) => membros.firstWhere(
                  (m) => m.id == id,
                  orElse: () => MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
                ))
            .where((m) => m.nome.isNotEmpty)
            .map((m) => '${m.cargo}: ${m.nome} - ${m.matricula}')
            .join('\n');
        if (demais.isNotEmpty) {
          linhas.add(['Demais Servidores', demais]);
        }
      }
    }

    return _gerarTabela(
      cabecalho: 'EQUIPE DE PERÍCIA CRIMINAL ACIONADA',
      linhas: linhas,
    );
  }

  String _gerarTabelaEquipesPoliciais(FichaCompletaModel ficha) {
    final linhas = <List<String>>[];
    
    // Verificar se marcou "Não havia equipes no local"
    if (ficha.naoHaviaEquipesPoliciais == true) {
      linhas.add(['Observação', 'Não havia equipes no local']);
    } else if (ficha.equipesPoliciais != null && ficha.equipesPoliciais!.isNotEmpty) {
      for (final equipe in ficha.equipesPoliciais!) {
        final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
        final membrosTexto = equipe.membros.map((m) {
          final posto = m.postoGraduacao != null ? ' (${m.postoGraduacao})' : '';
          return '${m.nome}$posto - ${m.matricula}';
        }).join('\n');
        
        linhas.add([tipoNome, membrosTexto]);
      }
    }

    return _gerarTabela(
      cabecalho: 'DEMAIS EQUIPES POLICIAIS/DE SALVAMENTO',
      linhas: linhas,
    );
  }

  String _gerarTabelaLocal(FichaCompletaModel ficha) {
    final local = ficha.local;
    final linhas = <List<String>>[];
    
    linhas.add(['Endereço', local?.endereco ?? ficha.dadosSolicitacao.endereco ?? '']);
    linhas.add(['Município', local?.municipio ?? ficha.dadosSolicitacao.municipio ?? '']);
    
    // Usar APENAS as coordenadas GPS obtidas na tela LOCAL (não as do PDF)
    // As coordenadas do PDF (coordenadasS/coordenadasW) são ignoradas intencionalmente
    // Formatar no mesmo formato DMS que aparece no aplicativo
    if (local?.latitude != null && local?.longitude != null) {
      final coordS = local!.coordenadasSFormatada ?? '';
      final coordW = local.coordenadasWFormatada ?? '';
      if (coordS.isNotEmpty && coordW.isNotEmpty) {
        linhas.add(['Coordenadas GPS', '$coordS\n$coordW']);
      } else {
        linhas.add(['Coordenadas GPS', 'Lat: ${local.latitude}, Long: ${local.longitude}']);
      }
    } else {
      // Se não houver coordenadas GPS, deixar em branco (não usar as do PDF)
      linhas.add(['Coordenadas GPS', 'Não obtidas']);
    }

    return _gerarTabela(
      cabecalho: 'LOCAL',
      linhas: linhas,
    );
  }

  String _gerarTabelaHistorico(FichaCompletaModel ficha) {
    return _gerarTabela(
      cabecalho: 'HISTÓRICO',
      linhas: [
        ['Relato', ficha.dadosFichaBase?.historico ?? ''],
      ],
    );
  }

  String _gerarTabelaIsolamento(FichaCompletaModel ficha) {
    final fb = ficha.dadosFichaBase;
    final linhas = <List<String>>[];
    
    // Isolamento Sim/Não
    String isolamento = '';
    if (fb?.isolamentoSim == true) isolamento = 'Sim';
    if (fb?.isolamentoNao == true) isolamento = 'Não';
    linhas.add(['Isolamento', isolamento]);
    
    // Tipo
    if (fb?.isolamentoSim == true) {
      String tipo = '';
      if (fb?.isolamentoTotal == true) tipo = 'Total';
      if (fb?.isolamentoParcial == true) tipo = 'Parcial';
      linhas.add(['Tipo', tipo]);
      
      // Meios utilizados
      final meios = <String>[];
      if (fb?.isolamentoFitaZebrada == true) meios.add('Fita zebrada');
      if (fb?.isolamentoCones == true) meios.add('Cones');
      if (fb?.isolamentoViatura == true) meios.add('Viatura');
      if (fb?.isolamentoPresencaFisica == true) meios.add('Presença física');
      if (meios.isNotEmpty) {
        linhas.add(['Meios Utilizados', meios.join(', ')]);
      }
    }
    
    if (fb?.isolamentoObservacoes != null && fb!.isolamentoObservacoes!.isNotEmpty) {
      linhas.add(['Observações', fb.isolamentoObservacoes!]);
    }

    return _gerarTabela(
      cabecalho: 'ISOLAMENTO',
      linhas: linhas,
    );
  }

  String _gerarTabelaCondicoesAmbientais(FichaCompletaModel ficha) {
    final fb = ficha.dadosFichaBase;
    final linhas = <List<String>>[];
    
    // Condições
    String condicoes = '';
    if (fb?.condicoesEstavel == true) condicoes = 'Estável';
    if (fb?.condicoesNublado == true) condicoes = 'Nublado';
    if (fb?.condicoesParcialmenteNublado == true) condicoes = 'Parcialmente nublado';
    if (fb?.condicoesChuvoso == true) condicoes = 'Chuvoso';
    linhas.add(['Condições Meteorológicas', condicoes]);
    
    if (fb?.demaisObservacoes != null && fb!.demaisObservacoes!.isNotEmpty) {
      linhas.add(['Demais Observações', fb.demaisObservacoes!]);
    }

    return _gerarTabela(
      cabecalho: 'CONDIÇÕES AMBIENTAIS',
      linhas: linhas,
    );
  }

  String _gerarTabelaPreservacao(FichaCompletaModel ficha) {
    final fb = ficha.dadosFichaBase;
    final linhas = <List<String>>[];
    
    // Preservação Sim/Não
    String preservacao = '';
    if (fb?.preservacaoSim == true) preservacao = 'Sim';
    if (fb?.preservacaoNao == true) preservacao = 'Não';
    linhas.add(['Preservação', preservacao]);
    
    // Se não, tipo
    if (fb?.preservacaoNao == true) {
      String tipo = '';
      if (fb?.preservacaoInidoneo == true) tipo = 'Inidôneo';
      if (fb?.preservacaoParcialmenteIdoneo == true) tipo = 'Parcialmente Idôneo';
      linhas.add(['Tipo', tipo]);
    }
    
    // Curiosos no perímetro
    if (fb?.preservacaoCuriososNoPerimetro == true) {
      linhas.add(['Curiosos no perímetro', 'Sim']);
    }
    
    // Pessoas que acessaram
    if (fb?.preservacaoPessoasAcessaram != null && fb!.preservacaoPessoasAcessaram!.isNotEmpty) {
      linhas.add(['Pessoas que acessaram', fb.preservacaoPessoasAcessaram!]);
    }
    
    // Alterações observadas
    if (fb?.preservacaoAlteracoesDetectadas != null && fb!.preservacaoAlteracoesDetectadas!.isNotEmpty) {
      linhas.add(['Alterações observadas', fb.preservacaoAlteracoesDetectadas!]);
    }

    return _gerarTabela(
      cabecalho: 'PRESERVAÇÃO',
      linhas: linhas,
    );
  }

  String _gerarTabelaLocalFurto(FichaCompletaModel ficha) {
    final lf = ficha.localFurto!;
    final linhas = <List<String>>[];
    
    // Classificação
    final classificacao = <String>[];
    if (lf.classificacaoMediato == true) classificacao.add('Mediato');
    if (lf.classificacaoImediato == true) classificacao.add('Imediato');
    if (lf.classificacaoRelacionado == true) classificacao.add('Relacionado');
    linhas.add(['Classificação', classificacao.join(', ')]);
    
    // Piso
    final piso = <String>[];
    if (lf.pisoSeco == true) piso.add('Seco');
    if (lf.pisoUmido == true) piso.add('Úmido');
    if (lf.pisoMolhado == true) piso.add('Molhado');
    linhas.add(['Condições do Piso', piso.join(', ')]);
    
    // Iluminação
    final iluminacao = <String>[];
    if (lf.iluminacaoArtificial == true) iluminacao.add('Artificial');
    if (lf.iluminacaoNatural == true) iluminacao.add('Natural');
    if (lf.iluminacaoAusente == true) iluminacao.add('Ausente');
    linhas.add(['Iluminação', iluminacao.join(', ')]);
    
    if (lf.descricaoViasAcesso != null && lf.descricaoViasAcesso!.isNotEmpty) {
      linhas.add(['Vias de Acesso', lf.descricaoViasAcesso!]);
    }
    
    // Sinais de arrombamento
    String arrombamento = '';
    if (lf.sinaisArrombamentoSim == true) arrombamento = 'Sim';
    if (lf.sinaisArrombamentoNao == true) arrombamento = 'Não';
    if (lf.sinaisArrombamentoNaoSeAplica == true) arrombamento = 'Não se aplica';
    linhas.add(['Sinais de Arrombamento', arrombamento]);
    
    if (lf.sinaisArrombamentoSim == true && lf.sinaisArrombamentoDescricao != null) {
      linhas.add(['Descrição do Arrombamento', lf.sinaisArrombamentoDescricao!]);
    }
    
    if (lf.descricaoLocal != null && lf.descricaoLocal!.isNotEmpty) {
      linhas.add(['Descrição do Local', lf.descricaoLocal!]);
    }
    
    if (lf.demaisObservacoes != null && lf.demaisObservacoes!.isNotEmpty) {
      linhas.add(['Demais Observações', lf.demaisObservacoes!]);
    }

    return _gerarTabela(
      cabecalho: 'LOCAL (FURTO/DANO)',
      linhas: linhas,
    );
  }

  String _gerarTabelaEvidencias(FichaCompletaModel ficha) {
    final ev = ficha.evidenciasFurto!;
    final buffer = StringBuffer();
    
    // Marco Zero
    if (ev.marcoZero != null) {
      buffer.writeln(_gerarTabela(
        cabecalho: 'MARCO ZERO',
        linhas: [
          ['Descrição', ev.marcoZero!.descricao ?? ''],
          ['Coordenada X', ev.marcoZero!.coordenadaX ?? ''],
          ['Coordenada Y', ev.marcoZero!.coordenadaY ?? ''],
        ],
      ));
      buffer.writeln(_gerarParagrafoVazio());
    }
    
    // Funções auxiliares (mesma lógica do laudo)
    bool _evidenciaPresente(EvidenciaModel e) {
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

    String _detalhesEvidencia(EvidenciaModel e) {
      final partes = <String>[];
      final obs = (e.observacoesEspeciais ?? '').trim();
      final desc = (e.descricao ?? '').trim();
      if (obs.isNotEmpty) partes.add(obs);
      if (desc.isNotEmpty) partes.add(desc);
      if (partes.isEmpty) return '';
      return partes.join('. ');
    }

    EvidenciaModel? _getEvidenciaPorId(List<EvidenciaModel> evids, String id) {
      for (final e in evids) {
        if (e.id == id) return e;
      }
      return null;
    }

    String _textoFixoNatural(EvidenciaModel? e, String simBase, String naoBase) {
      if (e == null) return naoBase;
      if (_evidenciaPresente(e)) {
        final detalhes = _detalhesEvidencia(e);
        return detalhes.isEmpty ? simBase : '$simBase $detalhes.';
      }
      return naoBase;
    }
    
    // Evidências - sempre mostrar EV01-EV07 (mesma lógica do laudo)
    final evidencias = ev.evidencias;
    final linhasEvidencias = <List<String>>[];
    
    // Buscar evidências fixas (EV01-EV07)
    final ev01 = _getEvidenciaPorId(evidencias, 'EV01');
    final ev02 = _getEvidenciaPorId(evidencias, 'EV02');
    final ev03 = _getEvidenciaPorId(evidencias, 'EV03');
    final ev04 = _getEvidenciaPorId(evidencias, 'EV04');
    final ev05 = _getEvidenciaPorId(evidencias, 'EV05');
    final ev06 = _getEvidenciaPorId(evidencias, 'EV06');
    final ev07 = _getEvidenciaPorId(evidencias, 'EV07');
    
    // Adicionar evidências fixas sempre (com textos padrão quando vazias)
    linhasEvidencias.add([
      'EV01',
      _textoFixoNatural(
        ev01,
        'Houve destruição ou rompimento de obstáculo à subtração da coisa.',
        'Não foram observados vestígios de destruição ou rompimento de obstáculo à subtração da coisa.',
      ),
    ]);
    linhasEvidencias.add([
      'EV02',
      _textoFixoNatural(
        ev02,
        'Houve indícios compatíveis com escalada ou destreza.',
        'Não foram observados vestígios compatíveis com escalada ou destreza.',
      ),
    ]);
    linhasEvidencias.add([
      'EV03',
      _textoFixoNatural(
        ev03,
        'Houve indícios de uso de instrumentos.',
        'Não foram observados vestígios de uso de instrumentos.',
      ),
    ]);
    linhasEvidencias.add([
      'EV04',
      _textoFixoNatural(
        ev04,
        'Houve indícios de emprego de chave falsa.',
        'Não foram observados vestígios de emprego de chave falsa.',
      ),
    ]);
    linhasEvidencias.add([
      'EV05',
      _textoFixoNatural(
        ev05,
        'Houve indícios compatíveis com concurso de duas ou mais pessoas.',
        'Os vestígios detectados não foram suficientes para concluir acerca do concurso de duas ou mais pessoas.',
      ),
    ]);
    linhasEvidencias.add([
      'EV06',
      _textoFixoNatural(
        ev06,
        'Constatou-se ausência de fechaduras (ou similares).',
        'Não foi constatada ausência de fechaduras (ou similares).',
      ),
    ]);
    linhasEvidencias.add([
      'EV07',
      _textoFixoNatural(
        ev07,
        'Foram observados vestígios de recenticidade.',
        'Não foram observados vestígios de recenticidade.',
      ),
    ]);
    
    // Evidências dinâmicas (EV08+)
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
    
    // Adicionar evidências dinâmicas
    for (final evidencia in dinamicas) {
      final desc = (evidencia.descricao ?? '').trim();
      final base = evidencia.identificacao.trim().isEmpty
          ? 'Evidência'
          : evidencia.identificacao.trim();
      final textoItem = desc.isEmpty ? base : '$base: $desc';
      linhasEvidencias.add([evidencia.id, textoItem]);
    }
    
    // Sempre mostrar a tabela de evidências (mesmo que todas estejam vazias)
    buffer.writeln(_gerarTabela(
      cabecalho: 'EVIDÊNCIAS',
      linhas: linhasEvidencias,
    ));
    buffer.writeln(_gerarParagrafoVazio());
    
    // Materiais Apreendidos
    if (ev.materiaisApreendidos.isNotEmpty) {
      final linhasMateriais = ev.materiaisApreendidos.map((m) {
        String info = m.descricao;
        if (m.quantidade != null) info += ' (Qtd: ${m.quantidade})';
        if (m.descricaoDetalhada != null) info += '\n${m.descricaoDetalhada}';
        return [m.descricao, info];
      }).toList();
      
      buffer.writeln(_gerarTabela(
        cabecalho: 'MATERIAIS APREENDIDOS/ENCAMINHADOS',
        linhas: linhasMateriais,
      ));
    }
    
    return buffer.toString();
  }

  String _gerarTabelaModusOperandi(FichaCompletaModel ficha) {
    return _gerarTabela(
      cabecalho: 'MODUS OPERANDI',
      linhas: [
        ['Descrição', ficha.modusOperandi ?? ''],
      ],
    );
  }

  String _gerarTabelaDano(FichaCompletaModel ficha) {
    final dano = ficha.dano!;
    final linhas = <List<String>>[];
    
    // Questão 1
    String q1 = '';
    if (dano.substanciaInflamavelExplosivaSim == true) q1 = 'Sim';
    if (dano.substanciaInflamavelExplosivaNao == true) q1 = 'Não';
    linhas.add(['Utilização de substância inflamável ou explosiva', q1]);
    
    // Questão 2
    String q2 = '';
    if (dano.danoPatrimonioPublicoSim == true) q2 = 'Sim';
    if (dano.danoPatrimonioPublicoNao == true) q2 = 'Não';
    linhas.add(['Dano ao patrimônio público', q2]);
    
    // Questão 3
    String q3 = '';
    if (dano.prejuizoConsideravelSim == true) q3 = 'Sim';
    if (dano.prejuizoConsideravelNao == true) q3 = 'Não';
    linhas.add(['Prejuízo considerável', q3]);
    
    // Questão 4
    String q4 = '';
    if (dano.identificarInstrumentoSubstanciaSim == true) {
      q4 = 'Sim - ${dano.qualInstrumentoSubstancia ?? ""}';
    }
    if (dano.identificarInstrumentoSubstanciaNao == true) q4 = 'Não';
    linhas.add(['Possível identificar instrumento/substância', q4]);
    
    // Questão 5
    String q5 = '';
    if (dano.identificacaoVestigioSim == true) {
      q5 = 'Sim - ${dano.qualVestigio ?? ""}';
    }
    if (dano.identificacaoVestigioNao == true) q5 = 'Não';
    linhas.add(['Identificação de vestígio', q5]);
    
    // Questão 6
    if (dano.danoCausado != null && dano.danoCausado!.isNotEmpty) {
      linhas.add(['Dano causado', dano.danoCausado!]);
    }
    
    // Questão 7
    if (dano.valorEstimadoPrejuizos != null && dano.valorEstimadoPrejuizos!.isNotEmpty) {
      linhas.add(['Valor estimado dos prejuízos', dano.valorEstimadoPrejuizos!]);
    }
    
    // Questão 8
    String q8 = '';
    if (dano.identificarNumeroPessoasSim == true) {
      q8 = 'Sim - ${dano.numeroPessoas ?? ""}';
    }
    if (dano.identificarNumeroPessoasNao == true) q8 = 'Não';
    linhas.add(['Possível identificar número de pessoas', q8]);
    
    // Questão 9
    String q9 = '';
    if (dano.vestigiosAutoriaSim == true) {
      q9 = 'Sim - ${dano.quaisVestigiosAutoria ?? ""}';
    }
    if (dano.vestigiosAutoriaNao == true) q9 = 'Não';
    linhas.add(['Vestígios de autoria', q9]);

    return _gerarTabela(
      cabecalho: 'DANO (Art. 163 - CP/1940)',
      linhas: linhas,
    );
  }

  // ============ FUNÇÃO GENÉRICA PARA GERAR TABELAS ============

  String _gerarTabela({required String cabecalho, required List<List<String>> linhas}) {
    final buffer = StringBuffer();
    
    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln('          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');
    
    // Definir grade de colunas (essencial para gridSpan funcionar)
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="3000"/>');
    buffer.writeln('        <w:gridCol w:w="6000"/>');
    buffer.writeln('      </w:tblGrid>');
    
    // Cabeçalho da tabela (linha escura que ocupa as 2 colunas)
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="9000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="2"/>');
    buffer.writeln('            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln('                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>');
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(cabecalho)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');
    
    // Linhas de dados
    for (final linha in linhas) {
      if (linha.length >= 2) {
        buffer.writeln('      <w:tr>');
        
        // Coluna do rótulo
        buffer.writeln('        <w:tc>');
        buffer.writeln('          <w:tcPr>');
        buffer.writeln('            <w:tcW w:w="2000" w:type="pct"/>');
        buffer.writeln('          </w:tcPr>');
        buffer.writeln('          <w:p>');
        buffer.writeln('            <w:r>');
        buffer.writeln('              <w:rPr>');
        buffer.writeln('                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>');
        buffer.writeln('                <w:b/>');
        buffer.writeln('                <w:sz w:val="$_fontSize"/>');
        buffer.writeln('              </w:rPr>');
        buffer.writeln('              <w:t>${_escapeXml(linha[0])}</w:t>');
        buffer.writeln('            </w:r>');
        buffer.writeln('          </w:p>');
        buffer.writeln('        </w:tc>');
        
        // Coluna do valor
        buffer.writeln('        <w:tc>');
        buffer.writeln('          <w:tcPr>');
        buffer.writeln('            <w:tcW w:w="3000" w:type="pct"/>');
        buffer.writeln('          </w:tcPr>');
        
        // Tratar quebras de linha no valor
        final partes = linha[1].split('\n');
        for (final parte in partes) {
          buffer.writeln('          <w:p>');
          buffer.writeln('            <w:r>');
          buffer.writeln('              <w:rPr>');
          buffer.writeln('                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>');
          buffer.writeln('                <w:sz w:val="$_fontSize"/>');
          buffer.writeln('              </w:rPr>');
          buffer.writeln('              <w:t>${_escapeXml(parte)}</w:t>');
          buffer.writeln('            </w:r>');
          buffer.writeln('          </w:p>');
        }
        
        buffer.writeln('        </w:tc>');
        buffer.writeln('      </w:tr>');
      }
    }
    
    buffer.writeln('    </w:tbl>');
    
    return buffer.toString();
  }

  /// Escapa caracteres especiais do XML
  String _escapeXml(String texto) {
    return texto
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
