import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cadaver_model.dart';
import '../models/causas_determinantes_transito.dart';
import '../models/crime_transito_model.dart';
import '../models/evidencia_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/marco_zero_local_model.dart';
import '../models/membro_equipe_model.dart';
import '../models/perito_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/equipe_service.dart';
import '../services/laboratorio_service.dart';
import '../services/perito_service.dart';
import '../services/unidade_service.dart';

/// Serviço para gerar documentos Word a partir de templates
/// Preserva cabeçalho/rodapé do template e gera o conteúdo programaticamente
class WordGeneratorService {
  final _peritoService = PeritoService();
  final _equipeService = EquipeService();
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();

  // Configurações de formatação
  static const String _fontName = 'GADUGI';
  static const String _fontSize = '24'; // 12pt em half-points
  static const String _fontSizeTitulo = '28'; // 14pt

  // Imagens do corpo na ficha (CVLI) — rIds usados em document.xml.rels
  static const String _rIdCorpoMasculino = 'rIdCorpoM';
  static const String _rIdCorpoFeminino = 'rIdCorpoF';
  static const String _assetCorpoMasculino = 'assets/images/corpo_homem.png';
  static const String _assetCorpoFeminino = 'assets/images/corpo_mulher.png';

  /// Gera um documento Word preenchendo o template com os dados da ficha
  Future<File> gerarDocumentoWord(FichaCompletaModel ficha) async {
    // Obter o perito e o caminho do template
    final perito = await _peritoService.obterPerito();
    if (perito == null || perito.caminhoTemplate == null) {
      throw Exception(
        'Perito não cadastrado ou template não encontrado. Vá em Configurações > Editar Perito e selecione o template novamente.',
      );
    }

    final templateFile = File(perito.caminhoTemplate!);
    if (!await templateFile.exists()) {
      throw Exception(
        'O arquivo template não foi encontrado. Por favor, vá em Configurações > Editar Perito e selecione o template novamente.',
      );
    }

    // Ler o template
    final templateBytes = await templateFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // Carregar imagens do corpo para CVLI (cadaveres)
    final temCadaveres =
        ficha.tipoOcorrencia == TipoOcorrencia.cvli &&
        ficha.cadaveres != null &&
        ficha.cadaveres!.isNotEmpty;
    Uint8List? bytesCorpoMasculino;
    Uint8List? bytesCorpoFeminino;
    if (temCadaveres) {
      try {
        bytesCorpoMasculino = (await rootBundle.load(
          _assetCorpoMasculino,
        )).buffer.asUint8List();
      } catch (_) {}
      try {
        bytesCorpoFeminino = (await rootBundle.load(
          _assetCorpoFeminino,
        )).buffer.asUint8List();
      } catch (_) {}
    }

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

      // Incluir relações das imagens do corpo (CVLI) em document.xml.rels
      if (temCadaveres &&
          arquivo.name == 'word/_rels/document.xml.rels' &&
          (bytesCorpoMasculino != null || bytesCorpoFeminino != null)) {
        String relsXml;
        if (conteudo is List<int>) {
          relsXml = utf8.decode(conteudo);
        } else {
          relsXml = conteudo.toString();
        }
        final sb = StringBuffer();
        if (bytesCorpoMasculino != null) {
          sb.writeln(
            '<Relationship Id="$_rIdCorpoMasculino" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/corpo_homem.png"/>',
          );
        }
        if (bytesCorpoFeminino != null) {
          sb.writeln(
            '<Relationship Id="$_rIdCorpoFeminino" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/corpo_mulher.png"/>',
          );
        }
        relsXml = relsXml.replaceFirst(
          '</Relationships>',
          '$sb</Relationships>',
        );
        conteudo = Uint8List.fromList(utf8.encode(relsXml));
      }

      // Registrar imagens do corpo em [Content_Types].xml
      if (temCadaveres && arquivo.name == '[Content_Types].xml') {
        String ctXml;
        if (conteudo is List<int>) {
          ctXml = utf8.decode(conteudo);
        } else {
          ctXml = conteudo.toString();
        }
        final sb = StringBuffer();
        if (bytesCorpoMasculino != null) {
          sb.writeln(
            '<Override PartName="/word/media/corpo_homem.png" ContentType="image/png"/>',
          );
        }
        if (bytesCorpoFeminino != null) {
          sb.writeln(
            '<Override PartName="/word/media/corpo_mulher.png" ContentType="image/png"/>',
          );
        }
        ctXml = ctXml.replaceFirst('</Types>', '$sb</Types>');
        conteudo = Uint8List.fromList(utf8.encode(ctXml));
      }

      // Adicionar ao novo arquivo
      final tamanho = conteudo is List<int>
          ? conteudo.length
          : (conteudo is String ? conteudo.length : arquivo.size);

      novoArchive.addFile(ArchiveFile(arquivo.name, tamanho, conteudo));
    }

    // Incluir os arquivos de imagem do corpo no pacote Word (CVLI)
    if (temCadaveres && bytesCorpoMasculino != null) {
      novoArchive.addFile(
        ArchiveFile(
          'word/media/corpo_homem.png',
          bytesCorpoMasculino.length,
          bytesCorpoMasculino,
        ),
      );
    }
    if (temCadaveres && bytesCorpoFeminino != null) {
      novoArchive.addFile(
        ArchiveFile(
          'word/media/corpo_mulher.png',
          bytesCorpoFeminino.length,
          bytesCorpoFeminino,
        ),
      );
    }

    // Criar o novo arquivo Word
    final encoder = ZipEncoder();
    final novoBytes = encoder.encode(novoArchive);

    // Salvar em um local temporário
    final diretorio = await getApplicationDocumentsDirectory();
    final raiNumeroSaneado = (ficha.dadosSolicitacao.raiNumero ?? ficha.id)
        .replaceAll('/', '-');
    final nomeArquivo =
        'Ficha_${raiNumeroSaneado}_${DateTime.now().millisecondsSinceEpoch}.docx';
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
  Future<String> _gerarConteudoDocumento(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) async {
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
    // ou se houver equipes de resgate
    if (ficha.naoHaviaEquipesPoliciais == true ||
        (ficha.equipesPoliciais != null &&
            ficha.equipesPoliciais!.isNotEmpty) ||
        (ficha.equipesResgate != null && ficha.equipesResgate!.isNotEmpty)) {
      buffer.writeln(_gerarTabelaEquipesPoliciais(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    // TABELA 4: LOCAL
    buffer.writeln(_gerarTabelaLocal(ficha));
    buffer.writeln(_gerarParagrafoVazio());

    // TABELA 5: HISTÓRICO
    if (ficha.dadosFichaBase?.historico != null &&
        ficha.dadosFichaBase!.historico!.isNotEmpty) {
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

    // TABELA 9: LOCAL (para FURTO/DANO e CVLI)
    if (ficha.localFurto != null &&
        (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
            ficha.tipoOcorrencia == TipoOcorrencia.cvli)) {
      buffer.writeln(_gerarTabelaLocalFurto(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito &&
        ficha.crimeTransitoCondicoes != null) {
      final tabelaCondicoes = _gerarTabelaCondicoesCrimeTransito(ficha);
      if (tabelaCondicoes.isNotEmpty) {
        buffer.writeln(tabelaCondicoes);
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    // TABELA 10: VEÍCULOS (apenas para CVLI)
    if (ficha.veiculos != null && ficha.veiculos!.isNotEmpty) {
      final tipo = ficha.tipoOcorrencia;
      if (tipo == TipoOcorrencia.cvli || tipo == TipoOcorrencia.crimeTransito) {
        buffer.writeln(await _gerarTabelaVeiculos(ficha));
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    // TABELA 11: CADÁVERES (apenas para CVLI)
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli &&
        ficha.cadaveres != null &&
        ficha.cadaveres!.isNotEmpty) {
      buffer.writeln(await _gerarTabelaCadaveres(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito &&
        ficha.envolvidosTransito != null &&
        ficha.envolvidosTransito!.isNotEmpty) {
      buffer.writeln(_gerarTabelaEnvolvidosCrimeTransito(ficha));
      buffer.writeln(_gerarParagrafoVazio());
    }

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito &&
        ficha.crimeTransitoNatureza != null) {
      final tabelaNatureza = _gerarTabelaNaturezaCrimeTransito(ficha);
      if (tabelaNatureza.isNotEmpty) {
        buffer.writeln(tabelaNatureza);
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    // TABELA 12: EXAMES COMPLEMENTARES (vestígios coletados)
    final tabelaExamesComplementares = await _gerarTabelaExamesComplementares(
      ficha,
    );
    if (tabelaExamesComplementares.isNotEmpty) {
      buffer.writeln(tabelaExamesComplementares);
      buffer.writeln(_gerarParagrafoVazio());
    }

    // Se for FURTO/DANO, adicionar tabelas específicas
    if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
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

    // Mensagem final sobre croquis
    buffer.writeln(_gerarParagrafoVazio());
    buffer.writeln('''    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:color w:val="FF0000"/>
          <w:sz w:val="20"/>
        </w:rPr>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>
          <w:b/>
          <w:color w:val="FF0000"/>
          <w:sz w:val="20"/>
        </w:rPr>
        <w:t>⚠️ OBSERVAÇÃO: Não esqueça de incluir o croqui de local e o croqui de evidências no(s) corpo(s).</w:t>
      </w:r>
    </w:p>''');

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

  /// Gera um parágrafo com imagem inline (figura do corpo) para a ficha Word.
  /// [rId] deve ser o Id do relacionamento em document.xml.rels (ex.: rIdCorpoM, rIdCorpoF).
  String _gerarParagrafoImagemCorpo(String rId) {
    // Tamanho em EMUs (1 polegada ≈ 914400): ~2" x 2,5" para a figura
    const cx = 1828800;
    const cy = 2286000;
    return '''    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0">
            <wp:extent cx="$cx" cy="$cy"/>
            <wp:effectExtent l="0" t="0" r="0" b="0"/>
            <wp:docPr id="1" name="Figura corpo"/>
            <wp:cNvGraphicFramePr/>
            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:nvPicPr>
                    <pic:cNvPr id="0" name="Corpo"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>
                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
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

  Future<String> _gerarTabelaEquipePericia(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) async {
    final linhas = <List<String>>[];

    // Perito Criminal (sempre o dono do app)
    linhas.add(['Perito Criminal', '${perito.nome} - ${perito.matricula}']);

    // Fotógrafo e outros membros
    if (ficha.equipe != null) {
      final membros = await _equipeService.listarEquipe();

      if (ficha.equipe!.fotografoCriminalisticoId != null) {
        final fotografo = membros.firstWhere(
          (m) => m.id == ficha.equipe!.fotografoCriminalisticoId,
          orElse: () =>
              MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
        );
        if (fotografo.nome.isNotEmpty) {
          linhas.add([
            'Fotógrafo Criminalístico',
            '${fotografo.nome} - ${fotografo.matricula}',
          ]);
        }
      }

      if (ficha.equipe!.demaisServidoresIds.isNotEmpty) {
        final demais = ficha.equipe!.demaisServidoresIds
            .map(
              (id) => membros.firstWhere(
                (m) => m.id == id,
                orElse: () => MembroEquipeModel(
                  id: '',
                  cargo: '',
                  nome: '',
                  matricula: '',
                ),
              ),
            )
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
    } else {
      // Equipes Policiais
      if (ficha.equipesPoliciais != null &&
          ficha.equipesPoliciais!.isNotEmpty) {
        for (final equipe in ficha.equipesPoliciais!) {
          String tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
          if (equipe.viaturaNumero != null &&
              equipe.viaturaNumero!.trim().isNotEmpty) {
            tipoNome += ' - Viatura n. ${equipe.viaturaNumero}';
          }
          final membrosTexto = equipe.membros
              .map((m) {
                final posto = m.postoGraduacao != null
                    ? ' (${m.postoGraduacao})'
                    : '';
                return '${m.nome}$posto - ${m.matricula}';
              })
              .join('\n');

          linhas.add([tipoNome, membrosTexto]);
        }
      }

      // Equipes de Resgate (Socorristas)
      if (ficha.equipesResgate != null && ficha.equipesResgate!.isNotEmpty) {
        for (final equipe in ficha.equipesResgate!) {
          final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;

          // Formatar membros com cargo, nome, CRM e matrícula
          final membrosTexto = equipe.membros
              .map((m) {
                final partes = <String>[];
                if (m.cargo != null && m.cargo!.isNotEmpty) {
                  partes.add(m.cargo!);
                }
                partes.add(m.nome);
                if (m.crm != null && m.crm!.isNotEmpty) {
                  partes.add('CRM ${m.crm}');
                }
                if (m.matricula != null && m.matricula!.isNotEmpty) {
                  partes.add('Mat. ${m.matricula}');
                }
                return partes.join(' - ');
              })
              .join('\n');

          // Adicionar informação sobre "não estava no local"
          String observacao = '';
          if (equipe.naoEstavaNoLocal) {
            observacao = ' (não estava no local, mas esteve presente)';
          }
          if (equipe.unidadeNumero != null &&
              equipe.unidadeNumero!.isNotEmpty) {
            observacao += ' - Unidade n. ${equipe.unidadeNumero}';
          }

          linhas.add(['$tipoNome$observacao', membrosTexto]);
        }
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

    linhas.add([
      'Endereço',
      local?.endereco ?? ficha.dadosSolicitacao.endereco ?? '',
    ]);
    linhas.add([
      'Município',
      local?.municipio ?? ficha.dadosSolicitacao.municipio ?? '',
    ]);

    // Usar APENAS as coordenadas GPS obtidas na tela LOCAL (não as do PDF)
    // Formato único: graus decimais com 6 casas (igual ao levantamento da via)
    if (local?.latitude != null && local?.longitude != null) {
      final coordS = local!.coordenadasSFormatada ?? '';
      final coordW = local.coordenadasWFormatada ?? '';
      if (coordS.isNotEmpty && coordW.isNotEmpty) {
        linhas.add([
          'Coordenadas GPS',
          'Latitude: $coordS\nLongitude: $coordW',
        ]);
      } else {
        linhas.add([
          'Coordenadas GPS',
          'Latitude: ${local.latitude}, Longitude: ${local.longitude}',
        ]);
      }
    } else {
      // Se não houver coordenadas GPS, deixar em branco (não usar as do PDF)
      linhas.add(['Coordenadas GPS', 'Não obtidas']);
    }

    return _gerarTabela(cabecalho: 'LOCAL', linhas: linhas);
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

    if (fb?.isolamentoObservacoes != null &&
        fb!.isolamentoObservacoes!.isNotEmpty) {
      linhas.add(['Observações', fb.isolamentoObservacoes!]);
    }

    return _gerarTabela(cabecalho: 'ISOLAMENTO', linhas: linhas);
  }

  String _gerarTabelaCondicoesAmbientais(FichaCompletaModel ficha) {
    final fb = ficha.dadosFichaBase;
    final linhas = <List<String>>[];

    // Condições
    String condicoes = '';
    if (fb?.condicoesEstavel == true) condicoes = 'Estável';
    if (fb?.condicoesNublado == true) condicoes = 'Nublado';
    if (fb?.condicoesParcialmenteNublado == true) {
      condicoes = 'Parcialmente nublado';
    }
    if (fb?.condicoesChuvoso == true) condicoes = 'Chuvoso';
    linhas.add(['Condições Meteorológicas', condicoes]);

    if (fb?.demaisObservacoes != null && fb!.demaisObservacoes!.isNotEmpty) {
      linhas.add(['Demais Observações', fb.demaisObservacoes!]);
    }

    return _gerarTabela(cabecalho: 'CONDIÇÕES AMBIENTAIS', linhas: linhas);
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
      if (fb?.preservacaoParcialmenteIdoneo == true) {
        tipo = 'Parcialmente Idôneo';
      }
      linhas.add(['Tipo', tipo]);
    }

    // Curiosos no perímetro
    if (fb?.preservacaoCuriososNoPerimetro == true) {
      linhas.add(['Curiosos no perímetro', 'Sim']);
    }

    // Pessoas que acessaram
    if (fb?.preservacaoPessoasAcessaram != null &&
        fb!.preservacaoPessoasAcessaram!.isNotEmpty) {
      linhas.add(['Pessoas que acessaram', fb.preservacaoPessoasAcessaram!]);
    }

    // Alterações observadas
    if (fb?.preservacaoAlteracoesDetectadas != null &&
        fb!.preservacaoAlteracoesDetectadas!.isNotEmpty) {
      linhas.add([
        'Alterações observadas',
        fb.preservacaoAlteracoesDetectadas!,
      ]);
    }

    return _gerarTabela(cabecalho: 'PRESERVAÇÃO', linhas: linhas);
  }

  String _gerarTabelaLocalFurto(FichaCompletaModel ficha) {
    final lf = ficha.localFurto!;
    final buffer = StringBuffer();

    // Se não houver nenhuma classificação selecionada, não gerar tabela
    if (lf.classificacaoMediato != true &&
        lf.classificacaoImediato != true &&
        lf.classificacaoRelacionado != true) {
      return '';
    }

    // Ajustar cabeçalho conforme tipo de ocorrência
    final cabecalhoBase = ficha.tipoOcorrencia == TipoOcorrencia.cvli
        ? 'LOCAL'
        : 'LOCAL (FURTO/DANO)';

    // Informações gerais (vias de acesso, sinais de arrombamento, observações)
    final linhasGerais = <List<String>>[];
    if (lf.descricaoViasAcesso != null && lf.descricaoViasAcesso!.isNotEmpty) {
      linhasGerais.add(['Vias de Acesso', lf.descricaoViasAcesso!]);
    }

    // Sinais de arrombamento
    String arrombamento = '';
    if (lf.sinaisArrombamentoSim == true) arrombamento = 'Sim';
    if (lf.sinaisArrombamentoNao == true) arrombamento = 'Não';
    if (lf.sinaisArrombamentoNaoSeAplica == true) {
      arrombamento = 'Não se aplica';
    }
    if (arrombamento.isNotEmpty) {
      linhasGerais.add(['Sinais de Arrombamento', arrombamento]);
    }

    if (lf.sinaisArrombamentoSim == true &&
        lf.sinaisArrombamentoDescricao != null) {
      linhasGerais.add([
        'Descrição do Arrombamento',
        lf.sinaisArrombamentoDescricao!,
      ]);
    }

    if (lf.demaisObservacoes != null && lf.demaisObservacoes!.isNotEmpty) {
      linhasGerais.add(['Demais Observações', lf.demaisObservacoes!]);
    }

    // Se houver informações gerais, gerar tabela inicial
    if (linhasGerais.isNotEmpty) {
      buffer.writeln(
        _gerarTabela(cabecalho: cabecalhoBase, linhas: linhasGerais),
      );
      buffer.writeln(_gerarParagrafoVazio());
    }

    // Gerar seção para cada local (Mediato, Imediato, Relacionado)
    if (lf.classificacaoMediato == true) {
      buffer.writeln(
        _gerarSecaoLocalComVestigios(
          ficha: ficha,
          nomeLocal: 'LOCAL MEDIATO',
          classificacao: true,
          pisoSeco: lf.pisoSecoMediato,
          pisoUmido: lf.pisoUmidoMediato,
          pisoMolhado: lf.pisoMolhadoMediato,
          iluminacaoArtificial: lf.iluminacaoArtificialMediato,
          iluminacaoNatural: lf.iluminacaoNaturalMediato,
          iluminacaoAusente: lf.iluminacaoAusenteMediato,
          descricaoLocal: lf.descricaoLocalMediato,
          vestigios: lf.vestigiosMediato ?? [],
          semVestigios: lf.semVestigiosMediato ?? false,
          marcoZero: lf.marcoZeroMediato,
        ),
      );
      buffer.writeln(_gerarParagrafoVazio());
    }

    if (lf.classificacaoImediato == true) {
      buffer.writeln(
        _gerarSecaoLocalComVestigios(
          ficha: ficha,
          nomeLocal: 'LOCAL IMEDIATO',
          classificacao: true,
          pisoSeco: lf.pisoSecoImediato,
          pisoUmido: lf.pisoUmidoImediato,
          pisoMolhado: lf.pisoMolhadoImediato,
          iluminacaoArtificial: lf.iluminacaoArtificialImediato,
          iluminacaoNatural: lf.iluminacaoNaturalImediato,
          iluminacaoAusente: lf.iluminacaoAusenteImediato,
          descricaoLocal: lf.descricaoLocalImediato,
          vestigios: lf.vestigiosImediato ?? [],
          semVestigios: lf.semVestigiosImediato ?? false,
          marcoZero: lf.marcoZeroImediato,
        ),
      );
      buffer.writeln(_gerarParagrafoVazio());
    }

    if (lf.classificacaoRelacionado == true) {
      buffer.writeln(
        _gerarSecaoLocalComVestigios(
          ficha: ficha,
          nomeLocal: 'LOCAL RELACIONADO',
          classificacao: true,
          pisoSeco: lf.pisoSecoRelacionado,
          pisoUmido: lf.pisoUmidoRelacionado,
          pisoMolhado: lf.pisoMolhadoRelacionado,
          iluminacaoArtificial: lf.iluminacaoArtificialRelacionado,
          iluminacaoNatural: lf.iluminacaoNaturalRelacionado,
          iluminacaoAusente: lf.iluminacaoAusenteRelacionado,
          descricaoLocal: lf.descricaoLocalRelacionado,
          vestigios: lf.vestigiosRelacionado ?? [],
          semVestigios: lf.semVestigiosRelacionado ?? false,
          marcoZero: lf.marcoZeroRelacionado,
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoLocalComVestigios({
    required FichaCompletaModel ficha,
    required String nomeLocal,
    required bool classificacao,
    bool? pisoSeco,
    bool? pisoUmido,
    bool? pisoMolhado,
    bool? iluminacaoArtificial,
    bool? iluminacaoNatural,
    bool? iluminacaoAusente,
    String? descricaoLocal,
    required List<VestigioLocalModel> vestigios,
    required bool semVestigios,
    MarcoZeroLocalModel? marcoZero,
  }) {
    final buffer = StringBuffer();
    final linhas = <List<String>>[];

    // Classificação
    linhas.add(['Classificação', nomeLocal.replaceAll('LOCAL ', '')]);

    // Piso
    final piso = <String>[];
    if (pisoSeco == true) piso.add('Seco');
    if (pisoUmido == true) piso.add('Úmido');
    if (pisoMolhado == true) piso.add('Molhado');
    if (piso.isNotEmpty) {
      linhas.add(['Condições do Piso', piso.join(', ')]);
    }

    // Iluminação
    final iluminacao = <String>[];
    if (iluminacaoArtificial == true) iluminacao.add('Artificial');
    if (iluminacaoNatural == true) iluminacao.add('Natural');
    if (iluminacaoAusente == true) iluminacao.add('Ausente');
    if (iluminacao.isNotEmpty) {
      linhas.add(['Iluminação', iluminacao.join(', ')]);
    }

    // Descrição do local
    if (descricaoLocal != null && descricaoLocal.isNotEmpty) {
      linhas.add(['Descrição do Local', descricaoLocal]);
    }

    // Marco Zero
    if (marcoZero != null) {
      final marcoZeroTexto = <String>[];
      if (marcoZero.descricao != null && marcoZero.descricao!.isNotEmpty) {
        marcoZeroTexto.add('Descrição: ${marcoZero.descricao}');
      }
      if (marcoZero.coordenadaX != null && marcoZero.coordenadaX!.isNotEmpty) {
        marcoZeroTexto.add('X: ${marcoZero.coordenadaX}');
      }
      if (marcoZero.coordenadaY != null && marcoZero.coordenadaY!.isNotEmpty) {
        marcoZeroTexto.add('Y: ${marcoZero.coordenadaY}');
      }
      if (marcoZeroTexto.isNotEmpty) {
        linhas.add(['Marco Zero', marcoZeroTexto.join(', ')]);
      }
    }

    // Gerar tabela de informações do local
    buffer.writeln(_gerarTabela(cabecalho: nomeLocal, linhas: linhas));

    // Gerar tabela de vestígios
    if (semVestigios) {
      buffer.writeln(_gerarParagrafoVazio());
      buffer.writeln(
        _gerarTabelaVestigios(
          cabecalho: 'EVIDÊNCIAS',
          vestigios: [],
          semVestigios: true,
        ),
      );
    } else if (vestigios.isNotEmpty) {
      buffer.writeln(_gerarParagrafoVazio());
      buffer.writeln(
        _gerarTabelaVestigios(
          cabecalho: 'EVIDÊNCIAS',
          vestigios: vestigios,
          semVestigios: false,
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarTabelaVestigios({
    required String cabecalho,
    required List<VestigioLocalModel> vestigios,
    required bool semVestigios,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    // Grade de colunas: Identificação, Descrição, Coord. 1, Coord. 2, Recolhido
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Identificação
    buffer.writeln('        <w:gridCol w:w="3000"/>'); // Descrição
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Coord. 1
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Coord. 2
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Recolhido
    buffer.writeln('      </w:tblGrid>');

    // Cabeçalho da tabela
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="7000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="5"/>');
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(cabecalho)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');

    // Linha de cabeçalho das colunas
    buffer.writeln('      <w:tr>');
    _adicionarCelulaTabela(buffer, 'Identificação', bold: true);
    _adicionarCelulaTabela(
      buffer,
      'Descrição\n(tamanho, cor, recenticidade, sentido de produção, área)',
      bold: true,
    );
    _adicionarCelulaTabela(buffer, 'Coord. 1', bold: true);
    _adicionarCelulaTabela(buffer, 'Coord. 2', bold: true);
    _adicionarCelulaTabela(buffer, 'Recolhido', bold: true);
    buffer.writeln('      </w:tr>');

    // Linhas de vestígios
    if (semVestigios) {
      buffer.writeln('      <w:tr>');
      buffer.writeln('        <w:tc>');
      buffer.writeln('          <w:tcPr>');
      buffer.writeln('            <w:tcW w:w="7000" w:type="dxa"/>');
      buffer.writeln('            <w:gridSpan w:val="5"/>');
      buffer.writeln('          </w:tcPr>');
      buffer.writeln('          <w:p>');
      buffer.writeln('            <w:r>');
      buffer.writeln('              <w:rPr>');
      buffer.writeln(
        '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
      );
      buffer.writeln('                <w:sz w:val="$_fontSize"/>');
      buffer.writeln('              </w:rPr>');
      buffer.writeln(
        '              <w:t>Não foram encontrados vestígios neste local.</w:t>',
      );
      buffer.writeln('            </w:r>');
      buffer.writeln('          </w:p>');
      buffer.writeln('        </w:tc>');
      buffer.writeln('      </w:tr>');
    } else {
      for (var i = 0; i < vestigios.length; i++) {
        final vestigio = vestigios[i];
        buffer.writeln('      <w:tr>');

        // Identificação (número sequencial)
        _adicionarCelulaTabela(buffer, 'V${i + 1}');

        // Descrição (inclui nome opcional)
        String descricao = vestigio.rotuloNomeDescricao;
        if (vestigio.isSangueHumano) {
          descricao =
              '${descricao.isNotEmpty ? '$descricao - ' : ''}Sangue humano';
        }
        if (vestigio.alturaRelacaoPiso != null &&
            vestigio.alturaRelacaoPiso!.isNotEmpty) {
          descricao =
              '${descricao.isNotEmpty ? '$descricao - ' : ''}Altura: ${vestigio.alturaRelacaoPiso}';
        }
        _adicionarCelulaTabela(buffer, descricao);

        // Coord. 1 (X)
        _adicionarCelulaTabela(buffer, vestigio.coordenadaX ?? '');

        // Coord. 2 (Y)
        _adicionarCelulaTabela(buffer, vestigio.coordenadaY ?? '');

        // Recolhido (Sim/Não)
        final recolhido = vestigio.tipoAcao == TipoAcaoVestigio.coletado
            ? 'Sim'
            : 'Não';
        _adicionarCelulaTabela(buffer, recolhido);

        buffer.writeln('      </w:tr>');
      }
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  void _adicionarCelulaTabela(
    StringBuffer buffer,
    String texto, {
    bool bold = false,
  }) {
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="1400" w:type="dxa"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    if (bold) {
      buffer.writeln('            <w:pPr>');
      buffer.writeln('              <w:jc w:val="center"/>');
      buffer.writeln('            </w:pPr>');
    }
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    if (bold) {
      buffer.writeln('                <w:b/>');
    }
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(texto)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
  }

  String _formatarListaTexto<T>(
    Iterable<T>? valores,
    String Function(T) label,
  ) {
    if (valores == null || valores.isEmpty) return '';
    return valores.map(label).join(', ');
  }

  String _labelCondicaoSolo(CondicaoSoloLocal valor) => switch (valor) {
    CondicaoSoloLocal.seco => 'Seco',
    CondicaoSoloLocal.umido => 'Úmido',
    CondicaoSoloLocal.molhado => 'Molhado',
  };

  String _labelIluminacao(IluminacaoLocal valor) => switch (valor) {
    IluminacaoLocal.artificial => 'Artificial',
    IluminacaoLocal.naturalDia => 'Natural (Dia)',
    IluminacaoLocal.ausente => 'Ausente (Noturno)',
  };

  String _labelTracado(TracadoPista valor) => switch (valor) {
    TracadoPista.curvaEsquerda => 'Curva à esquerda',
    TracadoPista.curvaDireita => 'Curva à direita',
    TracadoPista.reto => 'Reto',
    TracadoPista.raioAmplo => 'Raio amplo',
    TracadoPista.raioPequeno => 'Raio pequeno',
    TracadoPista.cruzamento => 'Cruzamento',
  };

  String _labelTipoPista(TipoPistaRodovia valor) =>
      valor == TipoPistaRodovia.simples ? 'Simples' : 'Dupla';
  String _labelSentido(SentidoPista valor) =>
      valor == SentidoPista.unico ? 'Único' : 'Duplo';

  String _labelPerfil(PerfilPista valor) => switch (valor) {
    PerfilPista.plano => 'Plano',
    PerfilPista.suave => 'Suave',
    PerfilPista.declive => 'Declive',
    PerfilPista.moderado => 'Moderado',
    PerfilPista.aclive => 'Aclive',
    PerfilPista.acentuado => 'Acentuado',
  };

  String _labelCondicaoVia(CondicaoViaOpcao valor) => switch (valor) {
    CondicaoViaOpcao.seca => 'Seca',
    CondicaoViaOpcao.umida => 'Úmida',
    CondicaoViaOpcao.molhada => 'Molhada',
    CondicaoViaOpcao.semDefeito => 'Sem defeito',
    CondicaoViaOpcao.comBuracos => 'Com buracos',
    CondicaoViaOpcao.comOndulacoes => 'Com ondulações',
    CondicaoViaOpcao.emObras => 'Em obras',
    CondicaoViaOpcao.escorregadia => 'Escorregadia',
    CondicaoViaOpcao.comContaminantes => 'Com contaminantes',
    CondicaoViaOpcao.outro => 'Outro',
  };

  String _labelRegime(RegimeTrafego? valor) => switch (valor) {
    RegimeTrafego.intenso => 'Intenso',
    RegimeTrafego.moderado => 'Moderado',
    RegimeTrafego.leve => 'Leve',
    RegimeTrafego.outro => 'Outro',
    null => '',
  };

  String _labelVisibilidade(VisibilidadeTipo? valor) => switch (valor) {
    VisibilidadeTipo.boa => 'Boa',
    VisibilidadeTipo.reduzida => 'Reduzida',
    null => '',
  };

  String _labelSeparacaoFaixa(SeparacaoFaixasOpcao valor) => switch (valor) {
    SeparacaoFaixasOpcao.simplesContinua => 'Simples contínua',
    SeparacaoFaixasOpcao.duplaContinua => 'Dupla contínua',
    SeparacaoFaixasOpcao.simplesSeccionada => 'Simples seccionada',
    SeparacaoFaixasOpcao.duplaContinuaSeccionada => 'Dupla contínua/seccionada',
  };

  String _labelCorFaixa(CorFaixa valor) =>
      valor == CorFaixa.amarela ? 'Amarela' : 'Branca';

  String _labelSeparacaoPista(SeparacaoPistasOpcao valor) => switch (valor) {
    SeparacaoPistasOpcao.canteiro => 'Canteiro',
    SeparacaoPistasOpcao.muretaConcreto => 'Mureta de concreto',
    SeparacaoPistasOpcao.tachoes => 'Tachões',
    SeparacaoPistasOpcao.defensa => 'Defensa / Guard rail',
    SeparacaoPistasOpcao.nenhum => 'Nenhum',
    SeparacaoPistasOpcao.outro => 'Outro',
  };

  String _labelElementoLateral(ElementoLateral valor) => switch (valor) {
    ElementoLateral.meioFio => 'Meio-fio',
    ElementoLateral.faixaPintada => 'Faixa pintada',
    ElementoLateral.acostamento => 'Acostamento',
    ElementoLateral.muretaConcreto => 'Mureta de concreto',
    ElementoLateral.outro => 'Outro',
  };

  String _labelConservacao(ConservacaoEstado? valor) => switch (valor) {
    ConservacaoEstado.boa => 'Boa',
    ConservacaoEstado.ruim => 'Ruim',
    null => '',
  };

  String _labelIntensidadeDano(IntensidadeDano? valor) => switch (valor) {
    IntensidadeDano.leve => 'Leve',
    IntensidadeDano.media => 'Média',
    IntensidadeDano.grave => 'Grave',
    IntensidadeDano.gravissima => 'Gravíssima',
    null => '',
  };

  String _labelSetorImpacto(SetorImpacto valor) => switch (valor) {
    SetorImpacto.anterior => 'Anterior',
    SetorImpacto.posterior => 'Posterior',
    SetorImpacto.lateralEsquerdo => 'Lateral esquerdo',
    SetorImpacto.lateralDireito => 'Lateral direito',
    SetorImpacto.angularAnteriorEsquerdo => 'Angular anterior esquerdo',
    SetorImpacto.angularAnteriorDireito => 'Angular anterior direito',
    SetorImpacto.angularPosteriorEsquerdo => 'Angular posterior esquerdo',
    SetorImpacto.angularPosteriorDireito => 'Angular posterior direito',
  };

  String _labelTipificacao(TipificacaoDeformacao valor) => switch (valor) {
    TipificacaoDeformacao.amassamento => 'Amassamento',
    TipificacaoDeformacao.cisalhamento => 'Cisalhamento',
    TipificacaoDeformacao.arrastamento => 'Arrastamento',
    TipificacaoDeformacao.empenamento => 'Empenamento',
    TipificacaoDeformacao.arrancamento => 'Arrancamento',
    TipificacaoDeformacao.estampamento => 'Estampamento',
    TipificacaoDeformacao.quebramento => 'Quebramento',
    TipificacaoDeformacao.esmagamento => 'Esmagamento',
    TipificacaoDeformacao.sanfonamento => 'Sanfonamento',
    TipificacaoDeformacao.mossa => 'Mossa',
    TipificacaoDeformacao.atritamento => 'Atritamento',
    TipificacaoDeformacao.afundamento => 'Afundamento',
  };

  String _labelOrientacao(OrientacaoDeformacao valor) => switch (valor) {
    OrientacaoDeformacao.direitaParaEsquerda => 'Direita → Esquerda',
    OrientacaoDeformacao.esquerdaParaDireita => 'Esquerda → Direita',
    OrientacaoDeformacao.dianteiraParaTraseira => 'Dianteira → Traseira',
    OrientacaoDeformacao.traseiraParaDianteira => 'Traseira → Dianteira',
  };

  String _labelStatusComponente(StatusComponenteVeiculo? status) =>
      switch (status) {
        StatusComponenteVeiculo.funcionando => 'Funcionando',
        StatusComponenteVeiculo.naoFuncionando => 'Não funcionando',
        StatusComponenteVeiculo.prejudicado => 'Prejudicado',
        null => '',
      };

  String _labelEstadoPneu(EstadoPneumaticos? estado) => switch (estado) {
    EstadoPneumaticos.novos => 'Novos',
    EstadoPneumaticos.meiaVida => 'Meia vida',
    EstadoPneumaticos.desgastados => 'Desgastados',
    null => '',
  };

  String _labelAirbag(AirbagStatus? status) => switch (status) {
    AirbagStatus.acionado => 'Acionado',
    AirbagStatus.naoAcionado => 'Não acionado',
    AirbagStatus.ausente => 'Ausente',
    null => '',
  };

  String _labelRetrovisor(RetrovisorStatus? status) => switch (status) {
    RetrovisorStatus.presente => 'Presente',
    RetrovisorStatus.ausente => 'Ausente',
    null => '',
  };

  String _labelTacografo(TacografoStatus? status) => switch (status) {
    TacografoStatus.ausente => 'Ausente',
    TacografoStatus.recolhido => 'Recolhido',
    TacografoStatus.naoSeAplica => 'Não se aplica',
    null => '',
  };

  String _labelClassificacaoEnvolvido(
    CrimeTransitoClassificacaoEnvolvido? valor,
  ) => switch (valor) {
    CrimeTransitoClassificacaoEnvolvido.condutor => 'Condutor',
    CrimeTransitoClassificacaoEnvolvido.passageiro => 'Passageiro',
    CrimeTransitoClassificacaoEnvolvido.pedestre => 'Pedestre',
    null => '',
  };

  String _labelEquipamento(CrimeTransitoEquipamentoSeguranca valor) =>
      switch (valor) {
        CrimeTransitoEquipamentoSeguranca.cinto => 'Cinto',
        CrimeTransitoEquipamentoSeguranca.capacete => 'Capacete',
        CrimeTransitoEquipamentoSeguranca.nenhum => 'Nenhum',
        CrimeTransitoEquipamentoSeguranca.naoSeAplica => 'Não se aplica',
      };

  String _labelSituacaoEnvolvido(CrimeTransitoSituacaoEnvolvido? valor) =>
      switch (valor) {
        CrimeTransitoSituacaoEnvolvido.semFerimentos => 'Sem ferimentos',
        CrimeTransitoSituacaoEnvolvido.feridoGrave => 'Ferido grave (hospital)',
        CrimeTransitoSituacaoEnvolvido.obito => 'Óbito',
        null => '',
      };

  String _labelPosicaoEnvolvido(CrimeTransitoPosicaoEnvolvido? valor) =>
      switch (valor) {
        CrimeTransitoPosicaoEnvolvido.interiorVeiculo => 'Interior do veículo',
        CrimeTransitoPosicaoEnvolvido.leitoVia => 'Leito da via',
        CrimeTransitoPosicaoEnvolvido.exteriorPista => 'Exterior à pista',
        null => '',
      };

  String _labelNaturezaTipo(CrimeTransitoNaturezaTipo? tipo) => switch (tipo) {
    CrimeTransitoNaturezaTipo.simples => 'Simples (1 unidade)',
    CrimeTransitoNaturezaTipo.composta => 'Composta (2 ou mais unidades)',
    null => '',
  };

  String _labelFormaInteracao(CrimeTransitoFormaInteracao valor) =>
      switch (valor) {
        CrimeTransitoFormaInteracao.saidaPista => 'Saída de pista',
        CrimeTransitoFormaInteracao.colisao => 'Colisão',
        CrimeTransitoFormaInteracao.colisaoFrontal => 'Colisão frontal',
        CrimeTransitoFormaInteracao.colisaoOposta => 'Colisão oposta',
        CrimeTransitoFormaInteracao.objetoFixo => 'Objeto fixo',
        CrimeTransitoFormaInteracao.capotamento => 'Capotamento',
        CrimeTransitoFormaInteracao.abalroamento => 'Abalroamento',
        CrimeTransitoFormaInteracao.colisaoTraseira => 'Colisão traseira',
        CrimeTransitoFormaInteracao.colisaoTransversal => 'Colisão transversal',
        CrimeTransitoFormaInteracao.veiculoEstacionado => 'Veículo estacionado',
        CrimeTransitoFormaInteracao.tombamento => 'Tombamento',
        CrimeTransitoFormaInteracao.choque => 'Choque',
        CrimeTransitoFormaInteracao.colisaoLateral => 'Colisão lateral',
        CrimeTransitoFormaInteracao.colisaoObliqua => 'Colisão oblíqua',
        CrimeTransitoFormaInteracao.veiculoParado => 'Veículo parado',
        CrimeTransitoFormaInteracao.colisaoLongitudinal =>
          'Colisão longitudinal',
        CrimeTransitoFormaInteracao.colisaoOrtogonal => 'Colisão ortogonal',
        CrimeTransitoFormaInteracao.pedestre => 'Pedestre',
        CrimeTransitoFormaInteracao.queda => 'Queda',
        CrimeTransitoFormaInteracao.atropelamento => 'Atropelamento',
        CrimeTransitoFormaInteracao.animal => 'Animal',
        CrimeTransitoFormaInteracao.outro => 'Outro',
      };

  String _textoIntegridade(String titulo, IntegridadeItemModel? item) {
    if (item == null) return '';
    final status = item.integro == null
        ? 'Não informado'
        : (item.integro! ? 'Íntegros' : 'Não íntegros');
    final obs = item.observacoes?.trim().isNotEmpty == true
        ? ' (${item.observacoes})'
        : '';
    return '$titulo: $status$obs';
  }

  Future<String> _gerarTabelaVeiculos(FichaCompletaModel ficha) async {
    final buffer = StringBuffer();
    final veiculos = ficha.veiculos!;
    final isCrimeTransito =
        ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito;

    for (var i = 0; i < veiculos.length; i++) {
      final veiculo = veiculos[i];
      final linhas = <List<String>>[];

      // Identificação básica
      String tipoVeiculo = '';
      if (veiculo.tipoVeiculo != null) {
        tipoVeiculo = veiculo.tipoVeiculo!.label;
        if (veiculo.tipoVeiculo == TipoVeiculo.outro &&
            veiculo.tipoVeiculoOutro != null &&
            veiculo.tipoVeiculoOutro!.isNotEmpty) {
          tipoVeiculo = veiculo.tipoVeiculoOutro!;
        }
      }
      if (tipoVeiculo.isNotEmpty) {
        linhas.add(['Tipo de Veículo', tipoVeiculo]);
      }

      if (veiculo.marcaModelo != null && veiculo.marcaModelo!.isNotEmpty) {
        linhas.add(['Marca/Modelo', veiculo.marcaModelo!]);
      }

      String anos = '';
      if (veiculo.anoFabricacao != null && veiculo.anoFabricacao!.isNotEmpty) {
        anos = 'Fabricação: ${veiculo.anoFabricacao}';
      }
      if (veiculo.anoModelo != null && veiculo.anoModelo!.isNotEmpty) {
        if (anos.isNotEmpty) anos += ' / ';
        anos += 'Modelo: ${veiculo.anoModelo}';
      }
      if (anos.isNotEmpty) {
        linhas.add(['Ano', anos]);
      }

      if (veiculo.cor != null && veiculo.cor!.isNotEmpty) {
        linhas.add(['Cor', veiculo.cor!]);
      }

      if (veiculo.placa != null && veiculo.placa!.isNotEmpty) {
        linhas.add(['Placa', veiculo.placa!]);
      }
      if (isCrimeTransito &&
          veiculo.chassiAparente != null &&
          veiculo.chassiAparente!.isNotEmpty) {
        linhas.add(['Chassi Aparente', veiculo.chassiAparente!]);
      }

      // Localização no ambiente
      if (veiculo.localizacaoAmbiente != null &&
          veiculo.localizacaoAmbiente!.isNotEmpty) {
        linhas.add(['Localização no Ambiente', veiculo.localizacaoAmbiente!]);
      }

      // Coordenadas
      String coordenadas = '';
      if (veiculo.coordenadaFrenteX != null &&
          veiculo.coordenadaFrenteX!.isNotEmpty &&
          veiculo.coordenadaFrenteY != null &&
          veiculo.coordenadaFrenteY!.isNotEmpty) {
        coordenadas =
            'Frente: X=${veiculo.coordenadaFrenteX}, Y=${veiculo.coordenadaFrenteY}';
        if (veiculo.alturaFrente != null && veiculo.alturaFrente!.isNotEmpty) {
          coordenadas += ', Altura=${veiculo.alturaFrente}';
        }
      }
      if (veiculo.coordenadaTraseiraX != null &&
          veiculo.coordenadaTraseiraX!.isNotEmpty &&
          veiculo.coordenadaTraseiraY != null &&
          veiculo.coordenadaTraseiraY!.isNotEmpty) {
        if (coordenadas.isNotEmpty) coordenadas += '\n';
        coordenadas +=
            'Traseira: X=${veiculo.coordenadaTraseiraX}, Y=${veiculo.coordenadaTraseiraY}';
        if (veiculo.alturaTraseira != null &&
            veiculo.alturaTraseira!.isNotEmpty) {
          coordenadas += ', Altura=${veiculo.alturaTraseira}';
        }
      }
      if (veiculo.coordenadaCentroX != null &&
          veiculo.coordenadaCentroX!.isNotEmpty &&
          veiculo.coordenadaCentroY != null &&
          veiculo.coordenadaCentroY!.isNotEmpty) {
        if (coordenadas.isNotEmpty) coordenadas += '\n';
        coordenadas +=
            'Centro: X=${veiculo.coordenadaCentroX}, Y=${veiculo.coordenadaCentroY}';
        if (veiculo.alturaCentro != null && veiculo.alturaCentro!.isNotEmpty) {
          coordenadas += ', Altura=${veiculo.alturaCentro}';
        }
      }
      if (coordenadas.isNotEmpty) {
        linhas.add(['Coordenadas', coordenadas]);
      }

      // Posição
      if (veiculo.posicao != null) {
        String posicao = veiculo.posicao!.label;
        if (veiculo.posicao == PosicaoVeiculo.outra &&
            veiculo.posicaoLivre != null &&
            veiculo.posicaoLivre!.isNotEmpty) {
          posicao = veiculo.posicaoLivre!;
        }
        linhas.add(['Posição', posicao]);
      }

      // Condição geral
      if (veiculo.condicaoGeral != null && veiculo.condicaoGeral!.isNotEmpty) {
        linhas.add(['Condição Geral', veiculo.condicaoGeral!]);
      }

      // Relação com o caso
      if (veiculo.relacao != null) {
        linhas.add(['Relação com o Caso', veiculo.relacao!.label]);
      }

      if (isCrimeTransito) {
        final intensidade = _labelIntensidadeDano(veiculo.intensidadeDano);
        if (intensidade.isNotEmpty) {
          linhas.add(['Intensidade dos Danos', intensidade]);
        }
        final setores = _formatarListaTexto(
          veiculo.setoresImpacto,
          _labelSetorImpacto,
        );
        if (setores.isNotEmpty) {
          linhas.add(['Setor de Impacto', setores]);
        }
        final tipificacoes = _formatarListaTexto(
          veiculo.tipificacoesDeformacoes,
          _labelTipificacao,
        );
        if (tipificacoes.isNotEmpty) {
          linhas.add(['Tipificação das Deformações', tipificacoes]);
        }
        final orientacoes = _formatarListaTexto(
          veiculo.orientacoesDeformacoes,
          _labelOrientacao,
        );
        if (orientacoes.isNotEmpty) {
          linhas.add(['Orientação das Deformações', orientacoes]);
        }
        if (veiculo.danosObservacoes != null &&
            veiculo.danosObservacoes!.isNotEmpty) {
          linhas.add(['Observações sobre os danos', veiculo.danosObservacoes!]);
        }
        final farois = _labelStatusComponente(veiculo.faroisLanternas);
        if (farois.isNotEmpty) {
          linhas.add(['Faróis/Lanternas', farois]);
        }
        final cintos = _labelStatusComponente(veiculo.cintosSeguranca);
        if (cintos.isNotEmpty) {
          linhas.add(['Cintos de Segurança', cintos]);
        }
        final pneus = _labelEstadoPneu(veiculo.estadoPneumaticos);
        if (pneus.isNotEmpty) {
          linhas.add(['Pneumáticos', pneus]);
        }
        final freios = _labelStatusComponente(veiculo.freios);
        if (freios.isNotEmpty) {
          linhas.add(['Freios', freios]);
        }
        final direcao = _labelStatusComponente(veiculo.direcao);
        if (direcao.isNotEmpty) {
          linhas.add(['Direção', direcao]);
        }
        final airbag = _labelAirbag(veiculo.airbag);
        if (airbag.isNotEmpty) {
          linhas.add(['Airbag', airbag]);
        }
        final retrovisor = _labelRetrovisor(veiculo.retrovisor);
        if (retrovisor.isNotEmpty) {
          linhas.add(['Retrovisor', retrovisor]);
        }
        final tacografo = _labelTacografo(veiculo.tacografoStatus);
        if (tacografo.isNotEmpty) {
          linhas.add(['Disco de Tacógrafo', tacografo]);
        }
        if (veiculo.frenagemMetros != null &&
            veiculo.frenagemMetros!.isNotEmpty) {
          linhas.add(['Frenagem (m)', veiculo.frenagemMetros!]);
        }

        final detalhesBicicleta = <String>[];
        if (veiculo.bicicletaCor != null && veiculo.bicicletaCor!.isNotEmpty) {
          detalhesBicicleta.add('Cor: ${veiculo.bicicletaCor}');
        }
        if (veiculo.bicicletaMarcaModelo != null &&
            veiculo.bicicletaMarcaModelo!.isNotEmpty) {
          detalhesBicicleta.add(
            'Marca/Modelo: ${veiculo.bicicletaMarcaModelo}',
          );
        }
        if (veiculo.bicicletaElementosSinalizacao != null &&
            veiculo.bicicletaElementosSinalizacao!.isNotEmpty) {
          detalhesBicicleta.add(
            'Elementos de sinalização: ${veiculo.bicicletaElementosSinalizacao}',
          );
        }
        if (veiculo.bicicletaPossuiCampainha != null) {
          detalhesBicicleta.add(
            'Campainha: ${veiculo.bicicletaPossuiCampainha! ? 'Sim' : 'Não'}',
          );
        }
        if (detalhesBicicleta.isNotEmpty) {
          linhas.add(['Bicicleta', detalhesBicicleta.join('\\n')]);
        }
      }

      // Observações
      if (veiculo.observacoes != null && veiculo.observacoes!.isNotEmpty) {
        linhas.add(['Observações', veiculo.observacoes!]);
      }

      // Gerar tabela de informações do veículo
      buffer.writeln(
        _gerarTabela(cabecalho: 'VEÍCULO ${veiculo.numero}', linhas: linhas),
      );

      // Gerar tabela de vestígios do veículo
      if (veiculo.vestigios != null && veiculo.vestigios!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoVazio());
        buffer.writeln(
          _gerarTabelaVestigiosVeiculo(
            cabecalho: 'EVIDÊNCIAS - VEÍCULO ${veiculo.numero}',
            vestigios: veiculo.vestigios!,
          ),
        );
      }

      // Espaço entre veículos (exceto no último)
      if (i < veiculos.length - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  String _gerarTabelaCondicoesCrimeTransito(FichaCompletaModel ficha) {
    final cond = ficha.crimeTransitoCondicoes;
    if (cond == null) return '';
    final linhas = <List<String>>[];

    final solo = _formatarListaTexto(cond.condicoesSolo, _labelCondicaoSolo);
    if (solo.isNotEmpty) linhas.add(['Condições do Solo', solo]);

    final iluminacao = _formatarListaTexto(cond.iluminacao, _labelIluminacao);
    if (iluminacao.isNotEmpty) {
      linhas.add(['Iluminação', iluminacao]);
    }

    final tracado = _formatarListaTexto(cond.tracados, _labelTracado);
    if (tracado.isNotEmpty) {
      linhas.add(['Traçado da Pista', tracado]);
    }

    final tiposPista = _formatarListaTexto(cond.tiposPista, _labelTipoPista);
    if (tiposPista.isNotEmpty) {
      linhas.add(['Tipo de Pista', tiposPista]);
    }

    final sentidos = _formatarListaTexto(cond.sentidos, _labelSentido);
    if (sentidos.isNotEmpty) linhas.add(['Sentido da Via', sentidos]);

    final perfis = _formatarListaTexto(cond.perfis, _labelPerfil);
    if (perfis.isNotEmpty) linhas.add(['Perfil da Via', perfis]);

    if (cond.larguraPista != null && cond.larguraPista!.isNotEmpty) {
      linhas.add(['Largura da Pista', '${cond.larguraPista} m']);
    }

    if (cond.intensidadePerfil != null && cond.intensidadePerfil!.isNotEmpty) {
      linhas.add(['Intensidade (Aclive/Declive)', cond.intensidadePerfil!]);
    }

    final condicoesVia = _formatarListaTexto(
      cond.condicoesVia,
      _labelCondicaoVia,
    );
    if (condicoesVia.isNotEmpty) {
      linhas.add(['Condições da Via', condicoesVia]);
    }

    if (cond.condicaoViaOutroDescricao != null &&
        cond.condicaoViaOutroDescricao!.isNotEmpty) {
      linhas.add(['Observações da Via', cond.condicaoViaOutroDescricao!]);
    }

    if (cond.sinalizacao != null) {
      final sin = cond.sinalizacao!;
      final partes = <String>[];
      final placasV = _formatarListaTexto(
        sin.placasVerticais,
        (p) => switch (p) {
          PlacaVertical.paradaObrigatoria => 'Parada obrigatória',
          PlacaVertical.deAPreferencia => 'Dê a preferência',
          PlacaVertical.advertencia => 'Placa de advertência',
        },
      );
      if (placasV.isNotEmpty) {
        var textoV = 'Vertical: $placasV';
        if (sin.placaAdvertenciaDescricao != null &&
            sin.placaAdvertenciaDescricao!.isNotEmpty) {
          textoV += ' (${sin.placaAdvertenciaDescricao})';
        }
        if (sin.conservacaoVertical != null) {
          final cons = switch (sin.conservacaoVertical!) {
            ConservacaoSinalizacao.boa => 'Boa (nova)',
            ConservacaoSinalizacao.regular => 'Regular',
            ConservacaoSinalizacao.ruim => 'Ruim',
          };
          textoV += ' — conservação: $cons';
        }
        partes.add(textoV);
      }
      final marcacoes = _formatarListaTexto(
        sin.separacoesFaixas,
        _labelSeparacaoFaixa,
      );
      final cores = _formatarListaTexto(sin.corFaixas, _labelCorFaixa);
      if (marcacoes.isNotEmpty || cores.isNotEmpty) {
        var textoH = 'Horizontal:';
        if (marcacoes.isNotEmpty) textoH += ' $marcacoes';
        if (cores.isNotEmpty) textoH += ' — cor: $cores';
        partes.add(textoH);
      }
      if (partes.isNotEmpty) {
        linhas.add(['Sinalização', partes.join('\\n')]);
      }
    }

    final regime = _labelRegime(cond.regimeTrafego);
    if (regime.isNotEmpty) {
      linhas.add(['Regime de Tráfego', regime]);
    }

    if (cond.regimeTrafegoOutro != null &&
        cond.regimeTrafegoOutro!.isNotEmpty) {
      linhas.add(['Descrição do Tráfego', cond.regimeTrafegoOutro!]);
    }

    final velocidades = <String>[];
    if (cond.velocidadePorSinalizacao == true) {
      velocidades.add('Por sinalização expressa');
    }
    if (cond.velocidadePorCTB == true) {
      velocidades.add('Conforme Art. 61, §1º, CTB/1997');
    }
    if (cond.velocidadeMaxima != null && cond.velocidadeMaxima!.isNotEmpty) {
      velocidades.add('Velocidade máxima: ${cond.velocidadeMaxima}');
    }
    if (velocidades.isNotEmpty) {
      linhas.add(['Velocidade', velocidades.join('\\n')]);
    }

    if (cond.numeroFaixas != null) {
      linhas.add(['Número de Faixas', cond.numeroFaixas.toString()]);
    }

    if (cond.largurasFaixas != null && cond.largurasFaixas!.isNotEmpty) {
      linhas.add([
        'Largura das Faixas',
        cond.largurasFaixas!.map((e) => '$e m').join(', '),
      ]);
    }

    final visibilidade = _labelVisibilidade(cond.visibilidade);
    if (visibilidade.isNotEmpty) {
      String texto = visibilidade;
      if (cond.visibilidadeReducaoDescricao != null &&
          cond.visibilidadeReducaoDescricao!.isNotEmpty) {
        texto += ' (${cond.visibilidadeReducaoDescricao})';
      }
      linhas.add(['Visibilidade', texto]);
    }

    final separacaoPistas = _formatarListaTexto(
      cond.separacoesPistas,
      _labelSeparacaoPista,
    );
    if (separacaoPistas.isNotEmpty) {
      linhas.add(['Separação das Pistas', separacaoPistas]);
    }

    void adicionarLateral(String titulo, CrimeTransitoLateralInfo? lateral) {
      if (lateral == null) return;
      final partes = <String>[];
      final elementos = _formatarListaTexto(
        lateral.elementos,
        _labelElementoLateral,
      );
      if (elementos.isNotEmpty) partes.add('Elementos: $elementos');
      if (lateral.largura != null && lateral.largura!.isNotEmpty) {
        partes.add('Largura: ${lateral.largura} m');
      }
      final conservacao = _labelConservacao(lateral.conservacao);
      if (conservacao.isNotEmpty) partes.add('Conservação: $conservacao');
      if (lateral.observacoes != null && lateral.observacoes!.isNotEmpty) {
        partes.add('Obs.: ${lateral.observacoes}');
      }
      if (partes.isNotEmpty) {
        linhas.add([titulo, partes.join('\\n')]);
      }
    }

    adicionarLateral('Lateral Direita', cond.lateralDireita);
    adicionarLateral('Lateral Esquerda', cond.lateralEsquerda);

    if (cond.observacoes != null && cond.observacoes!.isNotEmpty) {
      linhas.add(['Observações', cond.observacoes!]);
    }

    if (linhas.isEmpty) return '';
    return _gerarTabela(
      cabecalho: 'CONDIÇÕES DA VIA - CRIME DE TRÂNSITO',
      linhas: linhas,
    );
  }

  String _gerarTabelaEnvolvidosCrimeTransito(FichaCompletaModel ficha) {
    final envolvidos = ficha.envolvidosTransito;
    if (envolvidos == null || envolvidos.isEmpty) return '';
    final buffer = StringBuffer();

    for (var i = 0; i < envolvidos.length; i++) {
      final envolvido = envolvidos[i];
      final linhas = <List<String>>[];

      if (envolvido.nome != null && envolvido.nome!.isNotEmpty) {
        linhas.add(['Nome', envolvido.nome!]);
      }
      if (envolvido.cnh != null && envolvido.cnh!.isNotEmpty) {
        linhas.add(['CNH', envolvido.cnh!]);
      }
      if (envolvido.cnhValidade != null && envolvido.cnhValidade!.isNotEmpty) {
        linhas.add(['Validade CNH', envolvido.cnhValidade!]);
      }
      if (envolvido.cnhCategoria != null &&
          envolvido.cnhCategoria!.isNotEmpty) {
        linhas.add(['Categoria CNH', envolvido.cnhCategoria!]);
      }
      if (envolvido.rg != null && envolvido.rg!.isNotEmpty) {
        linhas.add(['RG', envolvido.rg!]);
      }
      if (envolvido.dataNascimento != null &&
          envolvido.dataNascimento!.isNotEmpty) {
        linhas.add(['Data de Nascimento', envolvido.dataNascimento!]);
      }
      final classificacao = _labelClassificacaoEnvolvido(
        envolvido.classificacao,
      );
      if (classificacao.isNotEmpty) {
        linhas.add(['Classificação', classificacao]);
      }
      final equipamentos = _formatarListaTexto(
        envolvido.equipamentosSeguranca,
        _labelEquipamento,
      );
      if (equipamentos.isNotEmpty) {
        linhas.add(['Equipamentos de Segurança', equipamentos]);
      }
      final situacao = _labelSituacaoEnvolvido(envolvido.situacao);
      if (situacao.isNotEmpty) linhas.add(['Situação', situacao]);
      final posicao = _labelPosicaoEnvolvido(envolvido.posicao);
      if (posicao.isNotEmpty) {
        String texto = posicao;
        if (envolvido.posicaoDetalhe != null &&
            envolvido.posicaoDetalhe!.isNotEmpty) {
          texto += ' (${envolvido.posicaoDetalhe})';
        }
        linhas.add(['Posição', texto]);
      }

      // Vestes: apenas descrição (sem íntegro/não íntegro)
      if (envolvido.vestes != null &&
          envolvido.vestes!.observacoes != null &&
          envolvido.vestes!.observacoes!.trim().isNotEmpty) {
        linhas.add(['Vestes', envolvido.vestes!.observacoes!.trim()]);
      }
      final calcados = _textoIntegridade('Calçados', envolvido.calcados);
      if (calcados.isNotEmpty) linhas.add(['Calçados', calcados]);
      if (envolvido.pertencesEncontrados == true) {
        final partesPertences = <String>[];
        if (envolvido.pertencesDescricao != null &&
            envolvido.pertencesDescricao!.trim().isNotEmpty) {
          partesPertences.add(envolvido.pertencesDescricao!.trim());
        }
        if (envolvido.destinoPertences != null) {
          partesPertences.add(switch (envolvido.destinoPertences!) {
            DestinoPertences.recolhido => 'Recolhido',
            DestinoPertences.entregueAPessoa =>
              'Entregue a: ${envolvido.pertencesEntregueIdentificacao ?? ''}',
          });
        }
        linhas.add([
          'Pertences',
          partesPertences.isNotEmpty
              ? partesPertences.join(' — ')
              : 'Encontrados',
        ]);
      }

      if (envolvido.observacoes != null && envolvido.observacoes!.isNotEmpty) {
        linhas.add(['Observações', envolvido.observacoes!]);
      }

      buffer.writeln(
        _gerarTabela(cabecalho: 'ENVOLVIDO ${i + 1}', linhas: linhas),
      );
      if (i < envolvidos.length - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  String _gerarTabelaNaturezaCrimeTransito(FichaCompletaModel ficha) {
    final natureza = ficha.crimeTransitoNatureza;
    if (natureza == null) return '';
    final linhas = <List<String>>[];

    final tipo = _labelNaturezaTipo(natureza.tipo);
    if (tipo.isNotEmpty) linhas.add(['Tipo', tipo]);
    if (natureza.quantidadeUnidades != null) {
      linhas.add([
        'Quantidade de unidades',
        natureza.quantidadeUnidades.toString(),
      ]);
    }
    final formas = _formatarListaTexto(
      natureza.formasInteracao,
      _labelFormaInteracao,
    );
    if (formas.isNotEmpty) {
      linhas.add(['Formas de interação', formas]);
    }
    if (natureza.materialRecolhido != null) {
      linhas.add([
        'Material recolhido',
        natureza.materialRecolhido! ? 'Sim' : 'Não',
      ]);
    }
    if (natureza.materialDescricao != null &&
        natureza.materialDescricao!.isNotEmpty) {
      linhas.add(['Material (descrição)', natureza.materialDescricao!]);
    }
    if (natureza.solicitacaoExamesComplementares != null) {
      linhas.add([
        'Exames complementares',
        natureza.solicitacaoExamesComplementares! ? 'Sim' : 'Não',
      ]);
    }
    if (natureza.laboratorioDestino != null &&
        natureza.laboratorioDestino!.isNotEmpty) {
      linhas.add(['Laboratório/Seção', natureza.laboratorioDestino!]);
    }
    if (natureza.examesDinamica != null &&
        natureza.examesDinamica!.isNotEmpty) {
      linhas.add(['Exames / Dinâmica', natureza.examesDinamica!]);
    }
    if (natureza.croquiObservacoes != null &&
        natureza.croquiObservacoes!.isNotEmpty) {
      linhas.add(['Croqui', natureza.croquiObservacoes!]);
    }
    if (natureza.observacoes != null &&
        natureza.observacoes!.trim().isNotEmpty) {
      linhas.add(['Observações', natureza.observacoes!.trim()]);
    }
    if (natureza.complementoDinamicaFato != null &&
        natureza.complementoDinamicaFato!.trim().isNotEmpty) {
      linhas.add([
        'Complemento / Dinâmica do fato',
        natureza.complementoDinamicaFato!.trim(),
      ]);
    }
    final idsCausas = natureza.causasDeterminantesIds;
    if (idsCausas != null && idsCausas.isNotEmpty) {
      final d =
          ficha.crimeTransitoLevantamento?.dinamica ??
          CausasDeterminantesCatalogo.derivarDinamica(natureza.formasInteracao);
      if (d != null) {
        final map = {
          for (final c in CausasDeterminantesCatalogo.opcoesPara(d))
            c.id: '${c.referencia} — ${c.titulo}',
        };
        final texto = idsCausas.map((id) => map[id] ?? id).join('; ');
        linhas.add(['Modelos de causa (SDT)', texto]);
      }
    }

    if (linhas.isEmpty) return '';
    return _gerarTabela(
      cabecalho: 'NATUREZA DA OCORRÊNCIA - CRIME DE TRÂNSITO',
      linhas: linhas,
    );
  }

  String _gerarTabelaVestigiosVeiculo({
    required String cabecalho,
    required List<VestigioVeiculoModel> vestigios,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    // Grade de colunas: Identificação, Descrição, Localização, Recolhido
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Identificação
    buffer.writeln('        <w:gridCol w:w="3000"/>'); // Descrição
    buffer.writeln('        <w:gridCol w:w="2000"/>'); // Localização
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Recolhido
    buffer.writeln('      </w:tblGrid>');

    // Cabeçalho da tabela
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="7000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="4"/>');
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(cabecalho)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');

    // Linha de cabeçalho das colunas
    buffer.writeln('      <w:tr>');
    _adicionarCelulaTabelaVestigioVeiculo(buffer, 'Identificação', bold: true);
    _adicionarCelulaTabelaVestigioVeiculo(buffer, 'Descrição', bold: true);
    _adicionarCelulaTabelaVestigioVeiculo(
      buffer,
      'Localização no Veículo',
      bold: true,
    );
    _adicionarCelulaTabelaVestigioVeiculo(buffer, 'Recolhido', bold: true);
    buffer.writeln('      </w:tr>');

    // Linhas de vestígios
    for (var i = 0; i < vestigios.length; i++) {
      final vestigio = vestigios[i];
      buffer.writeln('      <w:tr>');

      // Identificação (número sequencial)
      _adicionarCelulaTabelaVestigioVeiculo(buffer, 'V${i + 1}');

      // Descrição (nome opcional + descrição técnica; sangue na mesma célula)
      String descricao = vestigio.rotuloNomeDescricao;
      if (vestigio.isSangueHumano) {
        descricao = descricao.isEmpty
            ? 'Sangue humano'
            : '$descricao — Sangue humano';
      }
      _adicionarCelulaTabelaVestigioVeiculo(buffer, descricao);

      _adicionarCelulaTabelaVestigioVeiculo(buffer, vestigio.localizacao ?? '');

      // Recolhido (Sim/Não)
      final recolhido = vestigio.tipoAcao == TipoAcaoVestigioVeiculo.coletado
          ? 'Sim'
          : 'Não';
      _adicionarCelulaTabelaVestigioVeiculo(buffer, recolhido);

      buffer.writeln('      </w:tr>');
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  void _adicionarCelulaTabelaVestigioVeiculo(
    StringBuffer buffer,
    String texto, {
    bool bold = false,
  }) {
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="1750" w:type="dxa"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    if (bold) {
      buffer.writeln('            <w:pPr>');
      buffer.writeln('              <w:jc w:val="center"/>');
      buffer.writeln('            </w:pPr>');
    }
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    if (bold) {
      buffer.writeln('                <w:b/>');
    }
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(texto)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
  }

  String _gerarTabelaEvidencias(FichaCompletaModel ficha) {
    final ev = ficha.evidenciasFurto!;
    final buffer = StringBuffer();

    // Marco Zero
    if (ev.marcoZero != null) {
      buffer.writeln(
        _gerarTabela(
          cabecalho: 'MARCO ZERO',
          linhas: [
            ['Descrição', ev.marcoZero!.descricao ?? ''],
            ['Coordenada X', ev.marcoZero!.coordenadaX ?? ''],
            ['Coordenada Y', ev.marcoZero!.coordenadaY ?? ''],
          ],
        ),
      );
      buffer.writeln(_gerarParagrafoVazio());
    }

    // Funções auxiliares (mesma lógica do laudo)
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

    // Evidências - sempre mostrar EV01-EV07 (mesma lógica do laudo)
    final evidencias = ev.evidencias;
    final linhasEvidencias = <List<String>>[];

    // Buscar evidências fixas (EV01-EV07)
    final ev01 = getEvidenciaPorId(evidencias, 'EV01');
    final ev02 = getEvidenciaPorId(evidencias, 'EV02');
    final ev03 = getEvidenciaPorId(evidencias, 'EV03');
    final ev04 = getEvidenciaPorId(evidencias, 'EV04');
    final ev05 = getEvidenciaPorId(evidencias, 'EV05');
    final ev06 = getEvidenciaPorId(evidencias, 'EV06');
    final ev07 = getEvidenciaPorId(evidencias, 'EV07');

    // Adicionar evidências fixas sempre (com textos padrão quando vazias)
    linhasEvidencias.add([
      'EV01',
      textoFixoNatural(
        ev01,
        'Houve destruição ou rompimento de obstáculo à subtração da coisa.',
        'Não foram observados vestígios de destruição ou rompimento de obstáculo à subtração da coisa.',
      ),
    ]);
    linhasEvidencias.add([
      'EV02',
      textoFixoNatural(
        ev02,
        'Houve indícios compatíveis com escalada ou destreza.',
        'Não foram observados vestígios compatíveis com escalada ou destreza.',
      ),
    ]);
    linhasEvidencias.add([
      'EV03',
      textoFixoNatural(
        ev03,
        'Houve indícios de uso de instrumentos.',
        'Não foram observados vestígios de uso de instrumentos.',
      ),
    ]);
    linhasEvidencias.add([
      'EV04',
      textoFixoNatural(
        ev04,
        'Houve indícios de emprego de chave falsa.',
        'Não foram observados vestígios de emprego de chave falsa.',
      ),
    ]);
    linhasEvidencias.add([
      'EV05',
      textoFixoNatural(
        ev05,
        'Houve indícios compatíveis com concurso de duas ou mais pessoas.',
        'Os vestígios detectados não foram suficientes para concluir acerca do concurso de duas ou mais pessoas.',
      ),
    ]);
    linhasEvidencias.add([
      'EV06',
      textoFixoNatural(
        ev06,
        'Constatou-se ausência de fechaduras (ou similares).',
        'Não foi constatada ausência de fechaduras (ou similares).',
      ),
    ]);
    linhasEvidencias.add([
      'EV07',
      textoFixoNatural(
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
    buffer.writeln(
      _gerarTabela(cabecalho: 'EVIDÊNCIAS', linhas: linhasEvidencias),
    );
    buffer.writeln(_gerarParagrafoVazio());

    // Materiais Apreendidos
    if (ev.materiaisApreendidos.isNotEmpty) {
      final linhasMateriais = ev.materiaisApreendidos.map((m) {
        String info = m.descricao;
        if (m.quantidade != null) info += ' (Qtd: ${m.quantidade})';
        if (m.descricaoDetalhada != null) info += '\n${m.descricaoDetalhada}';
        return [m.descricao, info];
      }).toList();

      buffer.writeln(
        _gerarTabela(
          cabecalho: 'MATERIAIS APREENDIDOS/ENCAMINHADOS',
          linhas: linhasMateriais,
        ),
      );
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
    if (dano.valorEstimadoPrejuizos != null &&
        dano.valorEstimadoPrejuizos!.isNotEmpty) {
      linhas.add([
        'Valor estimado dos prejuízos',
        dano.valorEstimadoPrejuizos!,
      ]);
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

    return _gerarTabela(cabecalho: 'DANO (Art. 163 - CP/1940)', linhas: linhas);
  }

  // ============ FUNÇÃO GENÉRICA PARA GERAR TABELAS ============

  String _gerarTabela({
    required String cabecalho,
    required List<List<String>> linhas,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
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
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
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
        buffer.writeln(
          '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
        );
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
          buffer.writeln(
            '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
          );
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

  Future<String> _gerarTabelaCadaveres(FichaCompletaModel ficha) async {
    final buffer = StringBuffer();
    final cadaveres = ficha.cadaveres!;

    for (var i = 0; i < cadaveres.length; i++) {
      final cadaver = cadaveres[i];
      final linhas = <List<String>>[];

      // Identificação
      if (cadaver.numeroLaudoCadaverico != null &&
          cadaver.numeroLaudoCadaverico!.isNotEmpty) {
        linhas.add([
          'Número do Laudo Cadavérico',
          cadaver.numeroLaudoCadaverico!,
        ]);
      }

      if (cadaver.nomeDaVitima != null && cadaver.nomeDaVitima!.isNotEmpty) {
        linhas.add(['Nome da Vítima', cadaver.nomeDaVitima!]);
      }

      if (cadaver.documentoIdentificacao != null &&
          cadaver.documentoIdentificacao!.isNotEmpty) {
        linhas.add([
          'Documento de Identificação',
          cadaver.documentoIdentificacao!,
        ]);
      }

      if (cadaver.dataNascimento != null &&
          cadaver.dataNascimento!.isNotEmpty) {
        linhas.add(['Data de Nascimento', cadaver.dataNascimento!]);
      }

      if (cadaver.filiacao != null && cadaver.filiacao!.isNotEmpty) {
        linhas.add(['Filiação', cadaver.filiacao!]);
      }

      // Características físicas
      if (cadaver.faixaEtaria != null) {
        linhas.add(['Faixa Etária', cadaver.faixaEtaria!.label]);
      }

      if (cadaver.sexo != null) {
        linhas.add(['Sexo', cadaver.sexo!.label]);
      }

      if (cadaver.compleicao != null) {
        linhas.add(['Compleição', cadaver.compleicao!.label]);
      }

      // Cabelo
      String cabelo = '';
      if (cadaver.corCabelo != null) {
        if (cadaver.corCabelo == CorCabelo.outro &&
            cadaver.corCabeloOutro != null &&
            cadaver.corCabeloOutro!.isNotEmpty) {
          cabelo = cadaver.corCabeloOutro!;
        } else {
          cabelo = cadaver.corCabelo!.label;
        }
      }
      if (cadaver.tipoCabelo != null) {
        String tipo = '';
        if (cadaver.tipoCabelo == TipoCabelo.outro &&
            cadaver.tipoCabeloOutro != null &&
            cadaver.tipoCabeloOutro!.isNotEmpty) {
          tipo = cadaver.tipoCabeloOutro!;
        } else {
          tipo = cadaver.tipoCabelo!.label;
        }
        if (cabelo.isNotEmpty) cabelo += ', ';
        cabelo += tipo;
      }
      if (cadaver.tamanhoCabelo != null) {
        String tamanho = '';
        if (cadaver.tamanhoCabelo == TamanhoCabelo.outro &&
            cadaver.tamanhoCabeloOutro != null &&
            cadaver.tamanhoCabeloOutro!.isNotEmpty) {
          tamanho = cadaver.tamanhoCabeloOutro!;
        } else {
          tamanho = cadaver.tamanhoCabelo!.label;
        }
        if (cabelo.isNotEmpty) cabelo += ', ';
        cabelo += tamanho;
      }
      if (cabelo.isNotEmpty) {
        linhas.add(['Cabelo', cabelo]);
      }

      // Barba
      String barba = '';
      if (cadaver.tipoBarba != null) {
        if (cadaver.tipoBarba == TipoBarba.outro &&
            cadaver.tipoBarbaOutro != null &&
            cadaver.tipoBarbaOutro!.isNotEmpty) {
          barba = cadaver.tipoBarbaOutro!;
        } else {
          barba = cadaver.tipoBarba!.label;
        }
      }
      if (cadaver.corBarba != null && barba.isNotEmpty) {
        String cor = '';
        if (cadaver.corBarba == CorBarba.outra &&
            cadaver.corBarbaOutra != null &&
            cadaver.corBarbaOutra!.isNotEmpty) {
          cor = cadaver.corBarbaOutra!;
        } else {
          cor = cadaver.corBarba!.label;
        }
        barba += ', $cor';
      }
      if (cadaver.tamanhoBarba != null && barba.isNotEmpty) {
        String tamanho = '';
        if (cadaver.tamanhoBarba == TamanhoBarba.outro &&
            cadaver.tamanhoBarbaOutro != null &&
            cadaver.tamanhoBarbaOutro!.isNotEmpty) {
          tamanho = cadaver.tamanhoBarbaOutro!;
        } else {
          tamanho = cadaver.tamanhoBarba!.label;
        }
        barba += ', $tamanho';
      }
      if (barba.isNotEmpty) {
        linhas.add(['Barba', barba]);
      }

      // Localização no ambiente
      if (cadaver.localizacaoAmbiente != null &&
          cadaver.localizacaoAmbiente!.isNotEmpty) {
        linhas.add(['Localização no Ambiente', cadaver.localizacaoAmbiente!]);
      }

      // Coordenadas
      String coordenadas = '';
      if (cadaver.coordenadaCabecaX != null &&
          cadaver.coordenadaCabecaX!.isNotEmpty &&
          cadaver.coordenadaCabecaY != null &&
          cadaver.coordenadaCabecaY!.isNotEmpty) {
        coordenadas =
            'Cabeça: X=${cadaver.coordenadaCabecaX}, Y=${cadaver.coordenadaCabecaY}';
        if (cadaver.alturaCabeca != null && cadaver.alturaCabeca!.isNotEmpty) {
          coordenadas += ', Altura=${cadaver.alturaCabeca}';
        }
      }
      if (cadaver.coordenadaPesX != null &&
          cadaver.coordenadaPesX!.isNotEmpty &&
          cadaver.coordenadaPesY != null &&
          cadaver.coordenadaPesY!.isNotEmpty) {
        if (coordenadas.isNotEmpty) coordenadas += '\n';
        coordenadas +=
            'Pés: X=${cadaver.coordenadaPesX}, Y=${cadaver.coordenadaPesY}';
        if (cadaver.alturaPes != null && cadaver.alturaPes!.isNotEmpty) {
          coordenadas += ', Altura=${cadaver.alturaPes}';
        }
      }
      if (cadaver.coordenadaCentroTroncoX != null &&
          cadaver.coordenadaCentroTroncoX!.isNotEmpty &&
          cadaver.coordenadaCentroTroncoY != null &&
          cadaver.coordenadaCentroTroncoY!.isNotEmpty) {
        if (coordenadas.isNotEmpty) coordenadas += '\n';
        coordenadas +=
            'Centro do Tronco: X=${cadaver.coordenadaCentroTroncoX}, Y=${cadaver.coordenadaCentroTroncoY}';
        if (cadaver.alturaCentroTronco != null &&
            cadaver.alturaCentroTronco!.isNotEmpty) {
          coordenadas += ', Altura=${cadaver.alturaCentroTronco}';
        }
      }
      if (coordenadas.isNotEmpty) {
        linhas.add(['Coordenadas', coordenadas]);
      }

      // Posição do corpo
      if (cadaver.posicaoCorpoPreset != null &&
          cadaver.posicaoCorpoPreset!.isNotEmpty) {
        String posicao = '';
        switch (cadaver.posicaoCorpoPreset) {
          case 'decubito_dorsal':
            posicao = 'Decúbito Dorsal';
            break;
          case 'decubito_ventral':
            posicao = 'Decúbito Ventral';
            break;
          case 'decubito_lateral_direito':
            posicao = 'Decúbito Lateral Direito';
            break;
          case 'decubito_lateral_esquerdo':
            posicao = 'Decúbito Lateral Esquerdo';
            break;
          case 'sentado':
            posicao = 'Sentado';
            break;
          case 'em_pe':
            posicao = 'Em Pé';
            break;
          case 'outra':
            posicao = cadaver.posicaoCorpoLivre ?? 'Outra';
            break;
          default:
            posicao = cadaver.posicaoCorpoPreset!;
        }
        linhas.add(['Posição do Corpo', posicao]);
      }

      // Exames - Rigidez
      String rigidez = '';
      if (cadaver.rigidezMandibula != null) {
        rigidez = 'Mandíbula: ${cadaver.rigidezMandibula!.label}';
      }
      if (cadaver.rigidezMemSuperior != null) {
        if (rigidez.isNotEmpty) rigidez += '\n';
        rigidez += 'Membros Superiores: ${cadaver.rigidezMemSuperior!.label}';
      }
      if (cadaver.rigidezMemInferior != null) {
        if (rigidez.isNotEmpty) rigidez += '\n';
        rigidez += 'Membros Inferiores: ${cadaver.rigidezMemInferior!.label}';
      }
      if (rigidez.isNotEmpty) {
        linhas.add(['Rigidez Cadavérica', rigidez]);
      }

      // Exames - Manchas de Hipóstase
      String hipostase = '';
      if (cadaver.hipostasePosicao != null &&
          cadaver.hipostasePosicao!.isNotEmpty) {
        hipostase = 'Posição: ${cadaver.hipostasePosicao}';
      }
      if (cadaver.hipostaseEstado != null) {
        if (hipostase.isNotEmpty) hipostase += '\n';
        hipostase += 'Estado: ${cadaver.hipostaseEstado!.label}';
      }
      if (cadaver.hipostaseCompativeis != null) {
        if (hipostase.isNotEmpty) hipostase += '\n';
        hipostase +=
            'Compatíveis: ${cadaver.hipostaseCompativeis! ? "Sim" : "Não"}';
      }
      if (hipostase.isNotEmpty) {
        linhas.add(['Manchas de Hipóstase', hipostase]);
      }

      // Exames - Secreções
      String secrecoes = '';
      if (cadaver.secrecaoNasal == true) {
        secrecoes = 'Nasal: ${cadaver.secrecaoNasalTipo ?? "Presente"}';
      }
      if (cadaver.secrecaoOral == true) {
        if (secrecoes.isNotEmpty) secrecoes += '\n';
        secrecoes += 'Oral: ${cadaver.secrecaoOralTipo ?? "Presente"}';
      }
      if (cadaver.secrecaoAnal == true) {
        if (secrecoes.isNotEmpty) secrecoes += '\n';
        secrecoes += 'Anal: ${cadaver.secrecaoAnalTipo ?? "Presente"}';
      }
      if (cadaver.secrecaoPenianaVaginal == true) {
        if (secrecoes.isNotEmpty) secrecoes += '\n';
        secrecoes +=
            'Peniana/Vaginal: ${cadaver.secrecaoPenianaVaginalTipo ?? "Presente"}';
      }
      if (secrecoes.isNotEmpty) {
        linhas.add(['Secreções', secrecoes]);
      }

      // Tatuagens e marcas corporais
      if (cadaver.tatuagensMarcas != null &&
          cadaver.tatuagensMarcas!.isNotEmpty) {
        linhas.add(['Tatuagens e Marcas Corporais', cadaver.tatuagensMarcas!]);
      }

      // Pertences
      if (cadaver.pertences != null && cadaver.pertences!.isNotEmpty) {
        linhas.add(['Pertences', cadaver.pertences!]);
      }

      // Outras observações
      if (cadaver.outrasObservacoes != null &&
          cadaver.outrasObservacoes!.isNotEmpty) {
        linhas.add(['Outras Observações', cadaver.outrasObservacoes!]);
      }

      // Gerar tabela de informações do cadáver
      buffer.writeln(
        _gerarTabela(cabecalho: 'CADÁVER ${cadaver.numero}', linhas: linhas),
      );

      // Gerar tabela de lesões se houver
      if (cadaver.lesoes != null && cadaver.lesoes!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoVazio());
        buffer.writeln(
          _gerarTabelaLesoesCadaver(
            cabecalho: 'LESÕES - CADÁVER ${cadaver.numero}',
            lesoes: cadaver.lesoes!,
          ),
        );
      }

      // Figura do corpo (masculino/feminino) conforme sexo do cadáver — após tabela de lesões
      buffer.writeln(_gerarParagrafoVazio());
      final rIdCorpo = cadaver.sexo == SexoCadaver.feminino
          ? _rIdCorpoFeminino
          : _rIdCorpoMasculino;
      buffer.writeln(_gerarParagrafoImagemCorpo(rIdCorpo));
      buffer.writeln(_gerarParagrafoVazio());

      // Gerar tabela de vestes se houver
      if (cadaver.vestes != null && cadaver.vestes!.isNotEmpty) {
        buffer.writeln(_gerarParagrafoVazio());
        buffer.writeln(
          _gerarTabelaVestesCadaver(
            cabecalho: 'VESTES - CADÁVER ${cadaver.numero}',
            vestes: cadaver.vestes!,
          ),
        );
      }

      // Espaço entre cadáveres (exceto no último)
      if (i < cadaveres.length - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  String _gerarTabelaLesoesCadaver({
    required String cabecalho,
    required List<LesaoCadaverModel> lesoes,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    // Grade de colunas: Identificação, Região, Descrição
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="1000"/>'); // Identificação
    buffer.writeln('        <w:gridCol w:w="2000"/>'); // Região
    buffer.writeln('        <w:gridCol w:w="4000"/>'); // Descrição
    buffer.writeln('      </w:tblGrid>');

    // Cabeçalho da tabela
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="7000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="3"/>');
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(cabecalho)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');

    // Linha de cabeçalho das colunas
    buffer.writeln('      <w:tr>');
    _adicionarCelulaTabelaLesao(buffer, 'Identificação', bold: true);
    _adicionarCelulaTabelaLesao(buffer, 'Região', bold: true);
    _adicionarCelulaTabelaLesao(buffer, 'Descrição', bold: true);
    buffer.writeln('      </w:tr>');

    // Linhas de lesões
    for (var i = 0; i < lesoes.length; i++) {
      final lesao = lesoes[i];
      buffer.writeln('      <w:tr>');

      // Identificação (número sequencial + nome opcional)
      final nomeL = lesao.nome?.trim();
      final idCell = (nomeL != null && nomeL.isNotEmpty)
          ? 'L${i + 1} — $nomeL'
          : 'L${i + 1}';
      _adicionarCelulaTabelaLesao(buffer, idCell);

      // Região
      _adicionarCelulaTabelaLesao(buffer, lesao.regiao);

      // Descrição: mesma lógica do laudo (PAF gerada, senão descricao ou fallback)
      String descricaoCelula;
      if (lesao.descricao != null && lesao.descricao!.trim().isNotEmpty) {
        descricaoCelula = lesao.descricao!;
        if (lesao.tipo != null &&
            lesao.tipo!.trim().isNotEmpty &&
            !lesao.isPaf) {
          descricaoCelula = '${lesao.tipo}: $descricaoCelula';
        }
      } else if (lesao.isPaf && lesao.paf != null) {
        descricaoCelula = gerarDescricaoPAF(
          regiao: lesao.regiao,
          tipo: lesao.paf!.tipo,
          distancia: lesao.paf!.distancia,
          diametro: lesao.paf!.diametro,
          sinais: lesao.paf!.sinais,
        );
      } else {
        descricaoCelula = lesao.tipo != null && lesao.tipo!.trim().isNotEmpty
            ? '${lesao.tipo}: Lesão em ${lesao.regiao}'
            : 'Lesão em ${lesao.regiao}';
      }
      _adicionarCelulaTabelaLesao(buffer, descricaoCelula);

      buffer.writeln('      </w:tr>');
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  String _gerarTabelaVestesCadaver({
    required String cabecalho,
    required List<VesteCadaverModel> vestes,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    // Grade de colunas: Tipo, Descrição, Lesões
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="2000"/>'); // Tipo
    buffer.writeln('        <w:gridCol w:w="3000"/>'); // Descrição
    buffer.writeln('        <w:gridCol w:w="2000"/>'); // Lesões
    buffer.writeln('      </w:tblGrid>');

    // Cabeçalho da tabela
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="7000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="3"/>');
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(cabecalho)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');

    // Linha de cabeçalho das colunas
    buffer.writeln('      <w:tr>');
    _adicionarCelulaTabelaVeste(buffer, 'Tipo', bold: true);
    _adicionarCelulaTabelaVeste(buffer, 'Descrição', bold: true);
    _adicionarCelulaTabelaVeste(buffer, 'Lesões', bold: true);
    buffer.writeln('      </w:tr>');

    // Linhas de vestes
    for (final veste in vestes) {
      buffer.writeln('      <w:tr>');

      // Tipo/Marca
      _adicionarCelulaTabelaVeste(buffer, veste.tipoMarca ?? '');

      // Descrição (cor, sujidades, sangue, bolsos, notas)
      String descricao = '';
      if (veste.cor != null && veste.cor!.isNotEmpty) {
        descricao = 'Cor: ${veste.cor}';
      }
      if (veste.sujidades == true) {
        if (descricao.isNotEmpty) descricao += '\n';
        descricao += 'Sujidades: Sim';
      }
      if (veste.sangue == true) {
        if (descricao.isNotEmpty) descricao += '\n';
        descricao += 'Sangue: Sim';
      }
      if (veste.bolsos == true) {
        if (descricao.isNotEmpty) descricao += '\n';
        descricao +=
            'Bolsos: ${veste.bolsosVazios == true ? "Vazios" : "Presentes"}';
      }
      if (veste.notas != null && veste.notas!.isNotEmpty) {
        if (descricao.isNotEmpty) descricao += '\n';
        descricao += 'Notas: ${veste.notas}';
      }
      _adicionarCelulaTabelaVeste(buffer, descricao);

      // Não há campo de lesões em VesteCadaverModel, deixar vazio
      _adicionarCelulaTabelaVeste(buffer, '');

      buffer.writeln('      </w:tr>');
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  void _adicionarCelulaTabelaLesao(
    StringBuffer buffer,
    String texto, {
    bool bold = false,
  }) {
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="2333" w:type="dxa"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    if (bold) {
      buffer.writeln('            <w:pPr>');
      buffer.writeln('              <w:jc w:val="center"/>');
      buffer.writeln('            </w:pPr>');
    }
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    if (bold) {
      buffer.writeln('                <w:b/>');
    }
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(texto)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
  }

  void _adicionarCelulaTabelaVeste(
    StringBuffer buffer,
    String texto, {
    bool bold = false,
  }) {
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="2333" w:type="dxa"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    if (bold) {
      buffer.writeln('            <w:pPr>');
      buffer.writeln('              <w:jc w:val="center"/>');
      buffer.writeln('            </w:pPr>');
    }
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    if (bold) {
      buffer.writeln('                <w:b/>');
    }
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(texto)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
  }

  /// Gera a tabela de Exames Complementares com vestígios coletados
  Future<String> _gerarTabelaExamesComplementares(
    FichaCompletaModel ficha,
  ) async {
    // Coletar todos os vestígios que foram coletados
    final vestigiosColetados = <_VestigioColetadoInfo>[];

    // Buscar listas de unidades e laboratórios
    final unidades = await _unidadeService.listarUnidades();
    final laboratorios = await _laboratorioService.listarLaboratorios();

    // Vestígios dos locais
    if (ficha.localFurto != null) {
      final lf = ficha.localFurto!;

      // Local Mediato
      if (lf.vestigiosMediato != null) {
        for (final v in lf.vestigiosMediato!) {
          if (v.tipoAcao == TipoAcaoVestigio.coletado) {
            vestigiosColetados.add(
              _VestigioColetadoInfo(
                descricao: v.rotuloNomeDescricao,
                origem: 'Local Mediato',
                tipoDestino: v.tipoDestino,
                destinoId: v.destinoId,
                numeroLacre: v.numeroLacre,
                isSangueHumano: v.isSangueHumano,
              ),
            );
          }
        }
      }

      // Local Imediato
      if (lf.vestigiosImediato != null) {
        for (final v in lf.vestigiosImediato!) {
          if (v.tipoAcao == TipoAcaoVestigio.coletado) {
            vestigiosColetados.add(
              _VestigioColetadoInfo(
                descricao: v.rotuloNomeDescricao,
                origem: 'Local Imediato',
                tipoDestino: v.tipoDestino,
                destinoId: v.destinoId,
                numeroLacre: v.numeroLacre,
                isSangueHumano: v.isSangueHumano,
              ),
            );
          }
        }
      }

      // Local Relacionado
      if (lf.vestigiosRelacionado != null) {
        for (final v in lf.vestigiosRelacionado!) {
          if (v.tipoAcao == TipoAcaoVestigio.coletado) {
            vestigiosColetados.add(
              _VestigioColetadoInfo(
                descricao: v.rotuloNomeDescricao,
                origem: 'Local Relacionado',
                tipoDestino: v.tipoDestino,
                destinoId: v.destinoId,
                numeroLacre: v.numeroLacre,
                isSangueHumano: v.isSangueHumano,
              ),
            );
          }
        }
      }
    }

    // Vestígios dos veículos
    if (ficha.veiculos != null) {
      for (final veiculo in ficha.veiculos!) {
        if (veiculo.vestigios != null) {
          for (final v in veiculo.vestigios!) {
            if (v.tipoAcao == TipoAcaoVestigioVeiculo.coletado) {
              vestigiosColetados.add(
                _VestigioColetadoInfo(
                  descricao: v.textoDescricaoLocalWord,
                  origem: 'Veículo ${veiculo.numero}',
                  tipoDestinoVeiculo: v.tipoDestino,
                  destinoId: v.destinoId,
                  numeroLacre: v.numeroLacre,
                  isSangueHumano: v.isSangueHumano,
                ),
              );
            }
          }
        }
      }
    }

    // Se não houver vestígios coletados, retornar vazio
    if (vestigiosColetados.isEmpty) {
      return '';
    }

    // Função auxiliar para buscar nome do destino
    String obterNomeDestino(_VestigioColetadoInfo info) {
      if (info.destinoId == null) return '';

      // Vestígio de local
      if (info.tipoDestino != null) {
        if (info.tipoDestino == TipoDestinoVestigio.unidade) {
          final unidade = unidades
              .where((u) => u.id == info.destinoId)
              .firstOrNull;
          return unidade?.nome ?? '';
        } else if (info.tipoDestino == TipoDestinoVestigio.laboratorio) {
          final lab = laboratorios
              .where((l) => l.id == info.destinoId)
              .firstOrNull;
          return lab?.nome ?? '';
        }
      }

      // Vestígio de veículo
      if (info.tipoDestinoVeiculo != null) {
        if (info.tipoDestinoVeiculo == TipoDestinoVestigioVeiculo.unidade) {
          final unidade = unidades
              .where((u) => u.id == info.destinoId)
              .firstOrNull;
          return unidade?.nome ?? '';
        } else if (info.tipoDestinoVeiculo ==
            TipoDestinoVestigioVeiculo.laboratorio) {
          final lab = laboratorios
              .where((l) => l.id == info.destinoId)
              .firstOrNull;
          return lab?.nome ?? '';
        }
      }

      return '';
    }

    // Gerar tabela
    final buffer = StringBuffer();

    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblStyle w:val="TableGrid"/>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln(
      '          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln(
      '          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>',
    );
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    // Grade de colunas: Vestígio, Origem, Destino, Lacre
    buffer.writeln('      <w:tblGrid>');
    buffer.writeln('        <w:gridCol w:w="3000"/>'); // Vestígio
    buffer.writeln('        <w:gridCol w:w="2000"/>'); // Origem
    buffer.writeln('        <w:gridCol w:w="2500"/>'); // Destino
    buffer.writeln('        <w:gridCol w:w="1500"/>'); // Lacre
    buffer.writeln('      </w:tblGrid>');

    // Cabeçalho da tabela
    buffer.writeln('      <w:tr>');
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="9000" w:type="dxa"/>');
    buffer.writeln('            <w:gridSpan w:val="4"/>');
    buffer.writeln(
      '            <w:shd w:val="clear" w:color="auto" w:fill="404040"/>',
    );
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    buffer.writeln('            <w:pPr>');
    buffer.writeln('              <w:jc w:val="center"/>');
    buffer.writeln('            </w:pPr>');
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    buffer.writeln('                <w:b/>');
    buffer.writeln('                <w:color w:val="FFFFFF"/>');
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>EXAMES COMPLEMENTARES</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
    buffer.writeln('      </w:tr>');

    // Linha de cabeçalho das colunas
    buffer.writeln('      <w:tr>');
    _adicionarCelulaExameComplementar(buffer, 'Vestígio', bold: true);
    _adicionarCelulaExameComplementar(buffer, 'Origem', bold: true);
    _adicionarCelulaExameComplementar(buffer, 'Destino', bold: true);
    _adicionarCelulaExameComplementar(buffer, 'Lacre', bold: true);
    buffer.writeln('      </w:tr>');

    // Linhas de vestígios
    for (final info in vestigiosColetados) {
      buffer.writeln('      <w:tr>');

      // Vestígio (descrição)
      String descricao = info.descricao;
      if (info.isSangueHumano) {
        descricao =
            '${descricao.isNotEmpty ? '$descricao - ' : ''}Sangue humano';
      }
      _adicionarCelulaExameComplementar(buffer, descricao);

      // Origem
      _adicionarCelulaExameComplementar(buffer, info.origem);

      // Destino
      _adicionarCelulaExameComplementar(buffer, obterNomeDestino(info));

      // Lacre (mesmo que vazio)
      _adicionarCelulaExameComplementar(buffer, info.numeroLacre ?? '');

      buffer.writeln('      </w:tr>');
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  void _adicionarCelulaExameComplementar(
    StringBuffer buffer,
    String texto, {
    bool bold = false,
  }) {
    buffer.writeln('        <w:tc>');
    buffer.writeln('          <w:tcPr>');
    buffer.writeln('            <w:tcW w:w="2250" w:type="dxa"/>');
    buffer.writeln('          </w:tcPr>');
    buffer.writeln('          <w:p>');
    if (bold) {
      buffer.writeln('            <w:pPr>');
      buffer.writeln('              <w:jc w:val="center"/>');
      buffer.writeln('            </w:pPr>');
    }
    buffer.writeln('            <w:r>');
    buffer.writeln('              <w:rPr>');
    buffer.writeln(
      '                <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName"/>',
    );
    if (bold) {
      buffer.writeln('                <w:b/>');
    }
    buffer.writeln('                <w:sz w:val="$_fontSize"/>');
    buffer.writeln('              </w:rPr>');
    buffer.writeln('              <w:t>${_escapeXml(texto)}</w:t>');
    buffer.writeln('            </w:r>');
    buffer.writeln('          </w:p>');
    buffer.writeln('        </w:tc>');
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

/// Classe auxiliar para armazenar informações de vestígio coletado
class _VestigioColetadoInfo {
  final String descricao;
  final String origem;
  final TipoDestinoVestigio? tipoDestino;
  final TipoDestinoVestigioVeiculo? tipoDestinoVeiculo;
  final String? destinoId;
  final String? numeroLacre;
  final bool isSangueHumano;

  _VestigioColetadoInfo({
    required this.descricao,
    required this.origem,
    this.tipoDestino,
    this.tipoDestinoVeiculo,
    this.destinoId,
    this.numeroLacre,
    this.isSangueHumano = false,
  });
}
