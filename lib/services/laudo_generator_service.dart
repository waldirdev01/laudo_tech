import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/atropelamento_calculo_model.dart';
import '../models/cadaver_model.dart';
import '../models/causas_determinantes_transito.dart';
import '../models/crime_transito_levantamento_model.dart';
import '../models/crime_transito_model.dart';
import '../models/detatlhes_local.dart';
import '../models/equipe_policial_ficha_model.dart';
import '../models/equipe_resgate_model.dart';
import '../models/evidencia_model.dart';
import '../models/exame_complementar_model.dart';
import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/marco_zero_local_model.dart';
import '../models/membro_equipe_model.dart';
import '../models/perito_model.dart';
import '../models/pessoa_envolvida_model.dart';
import '../models/tipo_equipe_policial.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/atropelamento_velocidade_service.dart';
import '../services/equipe_service.dart';
import '../services/laboratorio_service.dart';
import '../services/unidade_service.dart';
import '../utils/equipe_hierarchy.dart';

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
  static const int _lineHeight125 = 300; // 1,25

  /// Texto padrão antes da lista de vestígios quando há vestígios cadastrados.
  static const String _textoSistemaCoordenadasVestigios =
      'Para fins de posicionamento dos vestígios, foi adotado um sistema de '
      'coordenadas cartesianas bidimensionais (eixo X e Y), acrescido de '
      'referência altimétrica (eixo Z), definido especificamente para o '
      'local periciado.';

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
      imagemMapaLocal = await _resolverArquivoLocal(
        capturaPath,
        markers: const ['laudo_tech/captura_local/', 'captura_local/'],
      );
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
    final isTransitoFootnote =
        ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito;
    final isVistoriaVeiculoFootnote =
        ficha.tipoOcorrencia == TipoOcorrencia.vistoriaVeiculo;
    final precisaFootnotes = materialSangue != null ||
        isTransitoFootnote ||
        isVistoriaVeiculoFootnote;

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
      final footnotesXml = _gerarFootnotesXml(
        isTransito: isTransitoFootnote,
        isVistoriaVeiculo: isVistoriaVeiculoFootnote,
      );
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
    final numeroOcorrencia =
        (dadosSol.numeroOcorrencia ?? 'sem_numero').replaceAll('/', '-');
    final fileName =
        'Laudo_${numeroOcorrencia}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final outputFile = File('${directory.path}/$fileName');
    await outputFile.writeAsBytes(zipBytes);

    return outputFile;
  }

  Future<File?> _resolverArquivoLocal(
    String path, {
    required List<String> markers,
  }) async {
    final original = File(path);
    if (await original.exists()) return original;

    final docs = await getApplicationDocumentsDirectory();
    final candidatos = <String>{};
    for (final marker in markers) {
      final idx = path.indexOf(marker);
      if (idx < 0) continue;

      final relative = path.substring(idx);
      candidatos.add('${docs.path}/$relative');
      if (relative.startsWith('captura_local/')) {
        candidatos.add('${docs.path}/laudo_tech/$relative');
      }
    }

    for (final candidato in candidatos) {
      final arquivo = File(candidato);
      if (await arquivo.exists()) return arquivo;
    }

    return null;
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

    if (ficha.tipoOcorrencia == TipoOcorrencia.vistoriaVeiculo) {
      buffer.writeln(await _gerarConteudoVistoriaVeiculo(ficha, perito));

      final qtdFotosNoLaudo = fotos?.length ?? ficha.fotosLevantamento.length;
      buffer.writeln(_gerarParagrafosFinais(ficha, perito, qtdFotosNoLaudo));

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

      if (ficha.analisesManchasSangue.isNotEmpty) {
        buffer.writeln(_gerarAnexoAnalisesManchasSangue(ficha));
      }

      return _montarDocumentoCompleto(buffer.toString(), sectPr);
    }

    // SEÇÃO 1. HISTÓRICO
    buffer.writeln(await _gerarSecaoHistorico(ficha, perito));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 2. OBJETIVOS
    buffer.writeln(_gerarSecaoObjetivos(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS
    buffer.writeln(_gerarSecaoIsolamentoPreservacao(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 4. DESCRIÇÃO DO LOCAL
    buffer.writeln(await _gerarSecaoDescricaoLocal(ficha, mapaRId: mapaRId));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 5. EXAMES ou DAS IMAGENS (para CVLI)
    final qtdFotos = fotos?.length ?? 0;
    buffer.writeln(await _gerarSecaoExames(ficha, perito, qtdFotos: qtdFotos));
    buffer.writeln(_gerarLinhaEmBranco());

    // SEÇÃO 6. ANÁLISE E INTERPRETAÇÃO DOS VESTÍGIOS ou DOS EXAMES (para CVLI)
    buffer.writeln(await _gerarSecaoAnaliseInterpretacao(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    // Para CVLI e Morte a Esclarecer: seções 7-11 específicas
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
        ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
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
    } else if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      // SEÇÃO 7. CONSIDERAÇÕES TÉCNICAS
      buffer.writeln(_gerarSecaoConsideracoesTecnicasTransito(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 8. RESPOSTA A QUESITOS
      buffer.writeln(_gerarSecaoRespostaQuesitosTransito(ficha));
      buffer.writeln(_gerarLinhaEmBranco());

      // SEÇÃO 9. CONCLUSÃO
      buffer.writeln(_gerarSecaoConclusaoTransito(ficha));
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

    if (ficha.analisesManchasSangue.isNotEmpty) {
      buffer.writeln(_gerarAnexoAnalisesManchasSangue(ficha));
    }

    // Montar o documento completo com namespaces e sectPr
    return _montarDocumentoCompleto(buffer.toString(), sectPr);
  }

  Future<String> _gerarConteudoVistoriaVeiculo(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln(await _gerarSecaoHistoricoVistoriaVeiculo(ficha, perito));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoObjetivosVistoriaVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoIsolamentoPreservacaoVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoLocalVistoriaVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoDoVeiculoVistoria(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(await _gerarSecaoExamesVistoriaVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoAvaliacaoVistoriaVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());
    buffer.writeln(_gerarSecaoConclusaoVistoriaVeiculo(ficha));
    buffer.writeln(_gerarLinhaEmBranco());

    return buffer.toString();
  }

  Future<String> _gerarSecaoHistoricoVistoriaVeiculo(
    FichaCompletaModel ficha,
    PeritoModel perito,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('1. HISTÓRICO'));

    final unidade = perito.unidadePericial.isNotEmpty
        ? perito.unidadePericial
        : 'Unidade Pericial';
    final dataInicio = ficha.dataHoraInicio?.trim();
    final horaInicio = _extrairHoraInicio(ficha.dataHoraInicio);
    final local = _textoLocalSimples(ficha);
    final equipeTexto = await _formatarEquipeParaPrimeiroParagrafo(
      ficha,
      perito,
      EquipeService(),
    );

    final textoData = dataInicio?.isNotEmpty == true
        ? 'na data de $dataInicio'
        : 'na data do exame';
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Após solicitação via Sistema Odin, $equipeTexto procedeu à vistoria pericial veicular $textoData, com início às $horaInicio, no local situado em $local.',
      ),
    );

    final historico = ficha.dadosFichaBase?.historico?.trim();
    if (historico?.isNotEmpty == true) {
      final iniciaComSegundo = RegExp(
        r'^segundo\b',
        caseSensitive: false,
      ).hasMatch(historico!);
      buffer.writeln(
        _gerarParagrafoHistorico(
          iniciaComSegundo ? historico : 'Segundo o apurado, $historico',
        ),
      );
    }

    final condicoes = _formatarCondicoesMeteorologicas(ficha.dadosFichaBase);
    if (condicoes.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'As condições meteorológicas no momento do exame apresentavam-se $condicoes.',
        ),
      );
    }

    if (unidade.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'O exame foi realizado pela equipe da $unidade, restringindo-se aos elementos materiais observados no momento da vistoria.',
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoObjetivosVistoriaVeiculo(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecaoComFootnote('2. OBJETIVOS', 1));

    final temDano = _temDadosDanoPreenchidos(ficha);
    final objetivo = temDano
        ? 'Estabelecer a materialidade relacionada a crime contra o patrimônio, com ênfase na constatação e descrição técnica dos danos verificados no veículo, buscando elementos materiais compatíveis com o fato sob investigação.'
        : 'Estabelecer a materialidade relacionada a crime contra o patrimônio, por meio da vistoria e avaliação veicular, buscando elementos materiais que possam contribuir para a elucidação do fato sob investigação.';

    buffer.writeln(_gerarParagrafoHistorico(objetivo));
    return buffer.toString();
  }

  String _gerarSecaoIsolamentoPreservacaoVeiculo(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    final fb = ficha.dadosFichaBase;
    final observacoesIsolamento = fb?.isolamentoObservacoes?.trim();
    buffer.writeln(
      _gerarTituloSecaoComFootnote('3. ISOLAMENTO E PRESERVAÇÃO DO VEÍCULO', 2),
    );

    if (observacoesIsolamento?.isNotEmpty == true) {
      buffer.writeln(_gerarParagrafoHistorico(observacoesIsolamento!));
    } else {
      if (fb?.isolamentoNao == true) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'O veículo não se encontrava sob isolamento oficial quando da realização da vistoria.',
          ),
        );
      } else if (fb?.isolamentoSim == true) {
        final meios = _formatarMeiosIsolamento(fb!);
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Quando da realização da vistoria, o veículo encontrava-se isolado por $meios.',
          ),
        );
      } else {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Não houve informação específica sobre isolamento formal do veículo.',
          ),
        );
      }
    }

    if (fb?.preservacaoSim == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quanto à preservação, não foram relatadas ou constatadas alterações aparentes que inviabilizassem o exame dos elementos observados.',
        ),
      );
    } else if (fb?.preservacaoNao == true) {
      final alteracoes = fb?.preservacaoAlteracoesDetectadas?.trim();
      final complemento = alteracoes?.isNotEmpty == true
          ? ' Foram registradas as seguintes alterações: $alteracoes.'
          : '';
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foi possível atestar a preservação integral do veículo desde o fato investigado até a vistoria.$complemento O presente laudo limita-se aos achados efetivamente detectados no momento do exame.',
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoLocalVistoriaVeiculo(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('4. DESCRIÇÃO DO LOCAL DA VISTORIA'));
    buffer.writeln(_gerarParagrafoHistorico(_textoLocalSimples(ficha)));

    final descricaoSimples = ficha.vistoriaVeiculoLocalDescricao?.trim();
    if (descricaoSimples?.isNotEmpty == true) {
      buffer.writeln(_gerarParagrafoHistorico(descricaoSimples!));
      return buffer.toString();
    }

    final localFurto = ficha.localFurto;
    final descricoes = <String>[
      if (localFurto?.descricaoLocalMediato?.trim().isNotEmpty == true)
        localFurto!.descricaoLocalMediato!.trim(),
      if (localFurto?.descricaoLocalImediato?.trim().isNotEmpty == true)
        localFurto!.descricaoLocalImediato!.trim(),
      if (localFurto?.descricaoLocalRelacionado?.trim().isNotEmpty == true)
        localFurto!.descricaoLocalRelacionado!.trim(),
    ];
    for (final descricao in descricoes) {
      buffer.writeln(_gerarParagrafoHistorico(descricao));
    }
    if (descricoes.isEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foram registradas informações complementares sobre o local da vistoria.',
        ),
      );
    }

    final coordS = ficha.local?.coordenadasSFormatada;
    final coordW = ficha.local?.coordenadasWFormatada;
    if (coordS != null && coordW != null) {
      buffer.writeln(
        _gerarParagrafoHistorico('Coordenadas geográficas: $coordS $coordW.'),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoDoVeiculoVistoria(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('5. DO VEÍCULO'));

    final veiculos = ficha.veiculos ?? const <VeiculoModel>[];
    if (veiculos.isEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico('Não houve veículo cadastrado na ficha.'),
      );
      return buffer.toString();
    }

    for (final veiculo in veiculos) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Tratava-se de ${_textoIdentificacaoVeiculo(veiculo)}.',
        ),
      );
      final origem = veiculo.observacoes?.trim();
      if (origem?.isNotEmpty == true) {
        buffer.writeln(_gerarParagrafoHistorico(origem!));
      }
    }

    return buffer.toString();
  }

  Future<String> _gerarSecaoExamesVistoriaVeiculo(
    FichaCompletaModel ficha,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('6. EXAMES'));
    buffer.writeln(_gerarTituloSubSecao('6.1 No Veículo'));

    final veiculos = ficha.veiculos ?? const <VeiculoModel>[];
    if (veiculos.isEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foram cadastradas informações técnicas do veículo vistoriado.',
        ),
      );
    } else {
      for (final veiculo in veiculos) {
        final danos = _textoDanosVeiculoVistoria(veiculo);
        buffer.writeln(_gerarParagrafoHistorico(danos));

        final vestigios = veiculo.vestigios ?? const <VestigioVeiculoModel>[];
        for (final vestigio in vestigios) {
          buffer.writeln(
            _gerarParagrafoLista(_textoVestigioVeiculoVistoria(vestigio)),
          );
        }

        if (vestigios.isEmpty &&
            veiculo.presencaSangue != true &&
            veiculo.presencaProjeteisImpactos != true &&
            (veiculo.outrosVestigios?.trim().isEmpty ?? true)) {
          buffer.writeln(
            _gerarParagrafoHistorico(
              'Não foram registrados outros vestígios materiais vinculados ao veículo.',
            ),
          );
        }
      }
    }

    final materiais = ficha.evidenciasFurto?.materiaisApreendidos ?? const [];
    if (materiais.isNotEmpty) {
      buffer.writeln(_gerarTituloSubSecao('6.2 Exames Complementares'));
      buffer.writeln(
        _gerarParagrafoHistorico(
          await _textoMateriaisEncaminhadosVistoria(materiais),
        ),
      );
    }

    final exames =
        ficha.examesComplementares ?? const <ExameComplementarModel>[];
    if (exames.isNotEmpty) {
      buffer.writeln(_gerarTituloSubSecao('6.3 Exames na Unidade'));
      for (final exame in exames) {
        final texto = [exame.nomeExibicao, exame.destinoNome, exame.observacao]
            .where((v) => v?.trim().isNotEmpty == true)
            .map((v) => v!.trim())
            .join(' - ');
        if (texto.isNotEmpty) {
          buffer.writeln(_gerarParagrafoHistorico(texto));
        }
      }
    }

    return buffer.toString();
  }

  String _gerarSecaoAvaliacaoVistoriaVeiculo(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('7. AVALIAÇÃO'));

    final avaliacao = ficha.vistoriaVeiculoAvaliacao?.trim();
    if (avaliacao?.isNotEmpty == true) {
      buffer.writeln(_gerarParagrafoHistorico(avaliacao!));
      return buffer.toString();
    }

    final valor = ficha.dano?.valorEstimadoPrejuizos?.trim();
    final dano = ficha.dano?.danoCausado?.trim();
    if (valor?.isNotEmpty == true) {
      final complemento = dano?.isNotEmpty == true
          ? ' relativos a $dano'
          : ' relativos às avarias detectadas';
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Realizada avaliação estimativa, verificou-se que o custo dos reparos$complemento é de aproximadamente $valor.',
        ),
      );
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foi informado valor estimado para reparo ou avaliação de mercado do veículo na ficha.',
        ),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoConclusaoVistoriaVeiculo(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('8. CONCLUSÃO'));

    final conclusao = ficha.vistoriaVeiculoConclusao?.trim();
    if (conclusao?.isNotEmpty == true) {
      buffer.writeln(_gerarParagrafoHistorico(conclusao!));
      return buffer.toString();
    }

    final instrumento = ficha.dano?.qualInstrumentoSubstancia?.trim();
    final dano = ficha.dano?.danoCausado?.trim();
    final dinamica = ficha.dano?.dinamicaEvento?.trim();

    if (dano?.isNotEmpty == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'O veículo apresentava os danos descritos nos exames, consistentes em $dano.',
        ),
      );
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'O exame pericial limitou-se à descrição técnica dos achados observados no veículo no momento da vistoria.',
        ),
      );
    }

    if (instrumento?.isNotEmpty == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quando tecnicamente compatível com os vestígios observados, os danos são compatíveis com ação produzida por $instrumento.',
        ),
      );
    }
    if (dinamica?.isNotEmpty == true) {
      buffer.writeln(_gerarParagrafoHistorico(dinamica!));
    }

    return buffer.toString();
  }

  String _textoLocalSimples(FichaCompletaModel ficha) {
    final partes = <String>[
      if (ficha.local?.endereco?.trim().isNotEmpty == true)
        ficha.local!.endereco!.trim()
      else if (ficha.dadosSolicitacao.endereco?.trim().isNotEmpty == true)
        ficha.dadosSolicitacao.endereco!.trim(),
      if (ficha.local?.municipio?.trim().isNotEmpty == true)
        ficha.local!.municipio!.trim()
      else if (ficha.dadosSolicitacao.municipio?.trim().isNotEmpty == true)
        ficha.dadosSolicitacao.municipio!.trim(),
    ];
    if (partes.isEmpty) return 'local não informado';
    final texto = partes.join(', ');
    return texto.endsWith('.') ? texto : '$texto.';
  }

  String _textoIdentificacaoVeiculo(VeiculoModel veiculo) {
    final tipo = veiculo.tipoVeiculo == TipoVeiculo.outro
        ? (veiculo.tipoVeiculoOutro?.trim().isNotEmpty == true
            ? veiculo.tipoVeiculoOutro!.trim()
            : 'veículo')
        : (veiculo.tipoVeiculo?.label.toLowerCase() ?? 'veículo');
    final partes = <String>[
      tipo,
      if (veiculo.marcaModelo?.trim().isNotEmpty == true)
        'marca/modelo ${veiculo.marcaModelo!.trim()}',
      if (veiculo.cor?.trim().isNotEmpty == true) 'cor ${veiculo.cor!.trim()}',
      if (veiculo.placa?.trim().isNotEmpty == true)
        'placas ${veiculo.placa!.trim()}',
      if (veiculo.anoFabricacao?.trim().isNotEmpty == true ||
          veiculo.anoModelo?.trim().isNotEmpty == true)
        'ano fabricação/modelo ${veiculo.anoFabricacao?.trim().isNotEmpty == true ? veiculo.anoFabricacao!.trim() : 'não informado'}/${veiculo.anoModelo?.trim().isNotEmpty == true ? veiculo.anoModelo!.trim() : 'não informado'}',
      if (veiculo.chassiAparente?.trim().isNotEmpty == true)
        'chassi aparente ${veiculo.chassiAparente!.trim()}, sem exame de autenticidade veicular específico',
    ];
    return partes.join(', ');
  }

  String _textoDanosVeiculoVistoria(VeiculoModel veiculo) {
    final partes = <String>[];

    final setores = veiculo.setoresImpacto?.isNotEmpty == true
        ? _formatarListaTextoCrime(veiculo.setoresImpacto, _labelSetorImpacto)
        : null;
    final tipificacoes = veiculo.tipificacoesDeformacoes?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            veiculo.tipificacoesDeformacoes,
            _labelTipificacaoDeformacao,
          )
        : null;
    final orientacoes = veiculo.orientacoesDeformacoes?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            veiculo.orientacoesDeformacoes,
            _labelOrientacaoDeformacao,
          )
        : null;

    if (veiculo.condicaoGeral?.trim().isNotEmpty == true) {
      partes.add(
        'O veículo apresentava condição geral: ${veiculo.condicaoGeral!.trim()}.',
      );
    }
    if (veiculo.intensidadeDano != null ||
        setores != null ||
        tipificacoes != null ||
        orientacoes != null ||
        veiculo.danosObservacoes?.trim().isNotEmpty == true ||
        veiculo.descricaoDanos?.trim().isNotEmpty == true) {
      final texto = StringBuffer('Ao exame, verificaram-se avarias');
      if (veiculo.intensidadeDano != null) {
        texto.write(
          ' de intensidade ${_labelIntensidadeDano(veiculo.intensidadeDano!)}',
        );
      }
      if (setores != null) {
        texto.write(' no(s) setor(es) $setores');
      }
      if (tipificacoes != null) {
        texto.write(', caracterizadas por $tipificacoes');
      }
      if (orientacoes != null) {
        texto.write(', com orientação $orientacoes');
      }
      texto.write('.');
      if (veiculo.danosObservacoes?.trim().isNotEmpty == true) {
        texto.write(' ${veiculo.danosObservacoes!.trim()}');
      }
      if (veiculo.descricaoDanos?.trim().isNotEmpty == true) {
        texto.write(' ${veiculo.descricaoDanos!.trim()}');
      }
      partes.add(texto.toString());
    }
    if (veiculo.presencaSangue == true &&
        veiculo.localizacaoSangue?.trim().isNotEmpty == true) {
      partes.add(
        'Foram observadas manchas com aspecto hemático em ${veiculo.localizacaoSangue!.trim()}.',
      );
    }
    if (veiculo.presencaProjeteisImpactos == true &&
        veiculo.localizacaoProjeteisImpactos?.trim().isNotEmpty == true) {
      partes.add(
        'Foram observados sinais compatíveis com impacto/perfuração em ${veiculo.localizacaoProjeteisImpactos!.trim()}.',
      );
    }
    if (veiculo.outrosVestigios?.trim().isNotEmpty == true) {
      partes.add(veiculo.outrosVestigios!.trim());
    }

    if (partes.isEmpty) {
      return 'Ao exame do veículo ${veiculo.numero}, não foram registradas avarias ou vestígios específicos no cadastro.';
    }
    return partes.join(' ');
  }

  String _textoVestigioVeiculoVistoria(VestigioVeiculoModel vestigio) {
    final partes = <String>[
      if (vestigio.nome?.trim().isNotEmpty == true) vestigio.nome!.trim(),
      if (vestigio.descricao?.trim().isNotEmpty == true)
        vestigio.descricao!.trim(),
      if (vestigio.localizacao?.trim().isNotEmpty == true)
        'Localização: ${vestigio.localizacao!.trim()}',
    ];
    if (vestigio.isSangueHumano) {
      partes.add('Material assinalado como sangue humano.');
    }
    if (vestigio.numeroLacre?.trim().isNotEmpty == true) {
      partes.add('Lacre n. ${vestigio.numeroLacre!.trim()}.');
    }
    if (vestigio.numerosFotografias?.isNotEmpty == true) {
      partes.add(
        'Registro fotográfico: ${_formatarNumerosFotografias(vestigio.numerosFotografias!)}.',
      );
    }
    return partes.isEmpty ? 'Vestígio veicular registrado.' : partes.join('. ');
  }

  Future<String> _textoMateriaisEncaminhadosVistoria(
    List<MaterialApreendidoModel> materiais,
  ) async {
    final partes = materiais.map((m) {
      final qtd = m.quantidade?.trim();
      final desc = m.descricaoDetalhada?.trim().isNotEmpty == true
          ? m.descricaoDetalhada!.trim()
          : m.descricao;
      return qtd?.isNotEmpty == true ? '$qtd $desc' : desc;
    }).toList();
    return 'Foram registrados para coleta, apreensão ou encaminhamento: ${_juntarItens(partes)}.';
  }

  String _formatarNumerosFotografias(List<int> numeros) {
    final ordenados = [...numeros]..sort();
    if (ordenados.isEmpty) return 'não informado';
    if (ordenados.length == 1) return 'fotografia ${ordenados.first}';
    return 'fotografias ${_juntarItens(ordenados.map((n) => n.toString()).toList())}';
  }

  String _labelIntensidadeDano(IntensidadeDano dano) {
    return switch (dano) {
      IntensidadeDano.leve => 'leve',
      IntensidadeDano.media => 'média',
      IntensidadeDano.grave => 'grave',
      IntensidadeDano.gravissima => 'gravíssima',
    };
  }

  String _labelSetorImpacto(SetorImpacto setor) {
    return switch (setor) {
      SetorImpacto.anterior => 'anterior',
      SetorImpacto.posterior => 'posterior',
      SetorImpacto.lateralEsquerdo => 'lateral esquerdo',
      SetorImpacto.lateralDireito => 'lateral direito',
      SetorImpacto.angularAnteriorEsquerdo => 'angular anterior esquerdo',
      SetorImpacto.angularAnteriorDireito => 'angular anterior direito',
      SetorImpacto.angularPosteriorEsquerdo => 'angular posterior esquerdo',
      SetorImpacto.angularPosteriorDireito => 'angular posterior direito',
    };
  }

  String _labelTipificacaoDeformacao(TipificacaoDeformacao deformacao) {
    return switch (deformacao) {
      TipificacaoDeformacao.amassamento => 'amassamento',
      TipificacaoDeformacao.cisalhamento => 'cisalhamento',
      TipificacaoDeformacao.arrastamento => 'arrastamento',
      TipificacaoDeformacao.empenamento => 'empenamento',
      TipificacaoDeformacao.arrancamento => 'arrancamento',
      TipificacaoDeformacao.estampamento => 'estampamento',
      TipificacaoDeformacao.quebramento => 'quebramento',
      TipificacaoDeformacao.esmagamento => 'esmagamento',
      TipificacaoDeformacao.sanfonamento => 'sanfonamento',
      TipificacaoDeformacao.mossa => 'mossa',
      TipificacaoDeformacao.atritamento => 'atritamento',
      TipificacaoDeformacao.afundamento => 'afundamento',
    };
  }

  String _labelOrientacaoDeformacao(OrientacaoDeformacao orientacao) {
    return switch (orientacao) {
      OrientacaoDeformacao.direitaParaEsquerda => 'da direita para a esquerda',
      OrientacaoDeformacao.esquerdaParaDireita => 'da esquerda para a direita',
      OrientacaoDeformacao.dianteiraParaTraseira =>
        'da dianteira para a traseira',
      OrientacaoDeformacao.traseiraParaDianteira =>
        'da traseira para a dianteira',
    };
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
        return 'EXAME EM LOCAL DE MORTE VIOLENTA';
      case TipoOcorrencia.morteEsclarecer:
        return 'EXAME EM LOCAL DE MORTE VIOLENTA';
      case TipoOcorrencia.crimeTransito:
        return 'CRIME DE TRÂNSITO';
      case TipoOcorrencia.vistoriaVeiculo:
        return 'VISTORIA E AVALIAÇÃO VEICULAR';
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
              <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
              <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

    buffer.writeln(_gerarTituloSecao('1. HISTÓRICO'));

    // ── Parágrafo 1: comunicação via ODIN ────────────────────────────────────
    final dataComunicacaoAbrev = _formatarDataAbreviada(
      ficha.dadosSolicitacao.dataHoraComunicacao,
    );
    final horaComunicacao = _extrairHoraInicio(
      ficha.dadosSolicitacao.dataHoraComunicacao,
    );
    final unidade = perito.unidadePericial.isNotEmpty
        ? perito.unidadePericial
        : 'Unidade Pericial';
    final equipeTexto = await _formatarEquipeParaPrimeiroParagrafo(
      ficha,
      perito,
      equipeService,
    );
    final parteData = dataComunicacaoAbrev != null
        ? 'no dia $dataComunicacaoAbrev às $horaComunicacao'
        : 'às $horaComunicacao';

    buffer.writeln(
      _gerarParagrafoHistorico(
        'Comunicada a requisição ao plantão da $unidade, $parteData, '
        'por meio do Sistema Odin, $equipeTexto compareceu ao local do evento, '
        'onde foi realizada a Perícia Criminal requisitada.',
      ),
    );

    // ── Parágrafo 2: presença policial na chegada ─────────────────────────────
    final textoPolicial = _textoPresencaPolicial(ficha);
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Quando da chegada da referida equipe, estavam presentes no local $textoPolicial.',
      ),
    );

    // Equipes de resgate (se houver, parágrafo separado)
    if (ficha.equipesResgate != null && ficha.equipesResgate!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          _formatarEquipesResgate(ficha.equipesResgate!),
        ),
      );
    }

    // ── Parágrafo 3: início, duração e liberação ───────────────────────────────
    final horaInicio = _extrairHoraInicio(ficha.dataHoraInicio);
    final horaTermino = _extrairHoraInicio(ficha.dataHoraTermino);
    final duracaoMin = _calcularDuracaoMinutos(
      ficha.dataHoraInicio,
      ficha.dataHoraTermino,
    );
    final duracaoTexto = duracaoMin != null ? '$duracaoMin' : 'XX';
    final qtdVeiculos = ficha.veiculos?.length ?? 0;
    final textoVeiculos = qtdVeiculos == 1 ? 'o veículo' : 'os veículos';

    final temCorpo = (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
            ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
            ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) &&
        (ficha.cadaveres?.isNotEmpty == true);

    final cidade = perito.cidade.isNotEmpty ? perito.cidade : 'Cidade';
    final qtdCorpos = ficha.cadaveres?.length ?? 0;

    buffer.writeln(
      _gerarParagrafoHistorico(
        'O levantamento de local teve início às $horaInicio, com duração aproximada de '
        '$duracaoTexto minutos, sendo o local e $textoVeiculos posteriormente liberados '
        'aos policiais militares presentes.',
      ),
    );

    // ── Condições meteorológicas ──────────────────────────────────────────────
    final condicoesMeteo = _formatarCondicoesMeteorologicas(
      ficha.dadosFichaBase,
    );
    if (condicoesMeteo.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'As condições meteorológicas no momento do exame apresentavam-se $condicoesMeteo.',
        ),
      );
    }

    // ── Parágrafo 4: relatos (histórico) ─────────────────────────────────────
    final historico = ficha.dadosFichaBase?.historico ?? '';
    if (historico.isNotEmpty) {
      final historicoTrim = historico.trim();
      final iniciaComSegundo = RegExp(
        r'^segundo\b',
        caseSensitive: false,
      ).hasMatch(historicoTrim);
      final textoHistorico = iniciaComSegundo
          ? historicoTrim
          : 'Segundo o apurado, $historicoTrim';
      buffer.writeln(_gerarParagrafoHistorico(textoHistorico));
    }

    // ── Último parágrafo: recolhimento/encaminhamento de corpo(s) ─────────────
    if (temCorpo) {
      final textoCorpos = qtdCorpos > 1
          ? 'os corpos foram recolhidos e encaminhados'
          : 'o corpo foi recolhido e encaminhado';
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Ao fim dos trabalhos, por volta de $horaTermino, $textoCorpos, em viatura própria, '
          'ao necrotério do Instituto de Medicina Legal (IML) de $cidade, onde foi realizado '
          'o Exame Médico-Legal Cadavérico. Os pertences, se existissem, foram deixados sob a '
          'guarda da auxiliar de autópsia e o local liberado.',
        ),
      );
    }

    return buffer.toString();
  }

  /// Formata data como "dd-MMM" (ex.: "19-ABR") a partir de "dd/MM/yyyy HH:mm".
  String? _formatarDataAbreviada(String? dataHora) {
    if (dataHora == null || dataHora.isEmpty) return null;
    final partes = dataHora.trim().split(' ');
    final campos = partes[0].split('/');
    if (campos.length < 3) return null;
    const meses = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    final mes = int.tryParse(campos[1]);
    if (mes == null || mes < 1 || mes > 12) return null;
    return '${campos[0]}-${meses[mes - 1]}';
  }

  /// Calcula duração em minutos entre duas strings "dd/MM/yyyy HH:mm".
  int? _calcularDuracaoMinutos(String? inicio, String? termino) {
    if (inicio == null || termino == null) return null;
    DateTime? parse(String s) {
      try {
        final partes = s.trim().split(' ');
        if (partes.length < 2) return null;
        final d = partes[0].split('/');
        final t = partes[1].split(':');
        if (d.length < 3 || t.length < 2) return null;
        return DateTime(
          int.parse(d[2]),
          int.parse(d[1]),
          int.parse(d[0]),
          int.parse(t[0]),
          int.parse(t[1]),
        );
      } catch (_) {
        return null;
      }
    }

    final dt1 = parse(inicio);
    final dt2 = parse(termino);
    if (dt1 == null || dt2 == null) return null;
    final diff = dt2.difference(dt1).inMinutes;
    return diff >= 0 ? diff : null;
  }

  /// Formata a lista de forças policiais presentes para o parágrafo 2 do histórico.
  String _textoPresencaPolicial(FichaCompletaModel ficha) {
    final equipes = ficha.equipesPoliciais;
    if (equipes == null || equipes.isEmpty) return 'XX';

    final partes = <String>[];
    for (final equipe in equipes) {
      final isPM = equipe.tipo == TipoEquipePolicial.policiaMilitar;
      final membrosValidos =
          equipe.membros.where((m) => m.nome.trim().isNotEmpty).toList();
      if (membrosValidos.isEmpty) continue;

      membrosValidos.sort(
        (a, b) => EquipeHierarchy.ordemQualificacaoPolicial(
          equipe.tipo,
          a.postoGraduacao,
        ).compareTo(
          EquipeHierarchy.ordemQualificacaoPolicial(
            equipe.tipo,
            b.postoGraduacao,
          ),
        ),
      );

      final membrosTexto = membrosValidos.map((m) {
        final qualificacao = m.postoGraduacao?.trim().isNotEmpty == true
            ? m.postoGraduacao!.trim()
            : null;
        final nomeComCargo =
            qualificacao != null ? '$qualificacao ${m.nome}' : m.nome;
        return _textoMembroComMatricula(
          nomeComCargo.trim(),
          m.matricula,
          usarRg: isPM,
        );
      }).toList();

      final sujeito = _sujeitoEquipePolicial(equipe, membrosValidos.length);
      final viatura = equipe.viaturaNumero?.trim();
      var textoEquipe = '$sujeito ${_juntarItens(membrosTexto)}';
      if (viatura != null && viatura.isNotEmpty) {
        final verboTripular =
            membrosValidos.length > 1 ? 'tripulavam' : 'tripulava';
        textoEquipe = '$textoEquipe, que $verboTripular a viatura $viatura';
      }

      partes.add(textoEquipe);
    }

    if (partes.isEmpty) return 'XX';
    if (partes.length == 1) return partes.first;
    if (partes.length == 2) return '${partes[0]}, bem como ${partes[1]}';
    return '${partes.sublist(0, partes.length - 1).join(', ')}, bem como ${partes.last}';
  }

  String _sujeitoEquipePolicial(
    EquipePolicialFichaModel equipe,
    int qtdMembros,
  ) {
    final plural = qtdMembros > 1;
    switch (equipe.tipo) {
      case TipoEquipePolicial.policiaMilitar:
        return plural ? 'os policiais militares' : 'o policial militar';
      case TipoEquipePolicial.policiaCivil:
        return plural ? 'os policiais civis' : 'o policial civil';
      case TipoEquipePolicial.prf:
        return plural
            ? 'os policiais rodoviários federais'
            : 'o policial rodoviário federal';
      case TipoEquipePolicial.gcm:
        return plural
            ? 'os guardas civis municipais'
            : 'o guarda civil municipal';
      case TipoEquipePolicial.outros:
        final tipoOutros = equipe.outrosTipo?.trim();
        if (tipoOutros != null && tipoOutros.isNotEmpty) {
          return plural
              ? 'os agentes de $tipoOutros'
              : 'o agente de $tipoOutros';
        }
        return plural ? 'os policiais' : 'o policial';
    }
  }

  String? _fraseIsolamentoComPoliciaisMilitares(FichaCompletaModel ficha) {
    final equipesPm = ficha.equipesPoliciais
        ?.where((e) => e.tipo == TipoEquipePolicial.policiaMilitar)
        .toList();
    if (equipesPm == null || equipesPm.isEmpty) return null;

    final policiais = <String>[];
    for (final equipe in equipesPm) {
      final membrosOrdenados = [...equipe.membros]..sort(
          (a, b) => EquipeHierarchy.ordemQualificacaoPolicial(
            equipe.tipo,
            a.postoGraduacao,
          ).compareTo(
            EquipeHierarchy.ordemQualificacaoPolicial(
              equipe.tipo,
              b.postoGraduacao,
            ),
          ),
        );
      for (final m in membrosOrdenados) {
        final nome = m.nome.trim();
        if (nome.isEmpty) continue;
        final posto = m.postoGraduacao?.trim();
        final nomeComCargo =
            (posto != null && posto.isNotEmpty) ? '$posto $nome' : nome;
        policiais.add(
          _textoMembroComMatricula(nomeComCargo, m.matricula, usarRg: true),
        );
      }
    }

    if (policiais.isEmpty) {
      return 'O local encontrava-se isolado pelos policiais militares presentes, que mantiveram o isolamento e a segurança da equipe durante os levantamentos e o processamento do local.';
    }

    if (policiais.length == 1) {
      return 'O local encontrava-se isolado pelo policial militar ${policiais.first}, que manteve o isolamento e a segurança da equipe durante os levantamentos e o processamento do local.';
    }

    return 'O local encontrava-se isolado pelos policiais militares ${_juntarItens(policiais)}, que mantiveram o isolamento e a segurança da equipe durante os levantamentos e o processamento do local.';
  }

  /// Retorna o complemento de "foi recebida ___" com base nas equipes presentes.
  /// Prioridade: PM > outros policiais > resgate > XX.
  String _juntarItens(List<String> itens) {
    if (itens.isEmpty) return '';
    if (itens.length == 1) return itens[0];
    if (itens.length == 2) return '${itens[0]} e ${itens[1]}';
    return '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';
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
    // 1º nível: caixa alta, negrito, Gadugi 12pt, alinhado à esquerda (Portaria 128/2019, Art. 2º IV.1)
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="left"/>
        <w:spacing w:before="240" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

  String _gerarTituloSecaoComFootnote(String titulo, int footnoteId) {
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="left"/>
        <w:spacing w:before="240" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="20"/>
          <w:szCs w:val="20"/>
          <w:vertAlign w:val="superscript"/>
        </w:rPr>
        <w:footnoteReference w:id="$footnoteId"/>
      </w:r>
    </w:p>''';
  }

  String _gerarParagrafoHistorico(String texto) {
    // Parágrafo com recuo de primeira linha 1,25 cm, entrelinhas 1,25, justificado.
    // Sem espaço antes/depois para não adicionar espaço entre parágrafos do mesmo estilo.
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

  /// Extrai "dd de [mês] de yyyy" de uma string "dd/MM/yyyy HH:mm".
  /// Retorna null se o campo estiver vazio ou mal formatado.
  String _formatarHora(String hora) {
    // Converte de HH:mm para HHhMMmin
    // Exemplo: "15:43" -> "15h43min"
    final partes = hora.split(':');
    if (partes.length >= 2) {
      return '${partes[0]}h${partes[1]}min';
    }
    return hora; // Retorna como está se não conseguir formatar
  }

  /// Formata a equipe para o 1º parágrafo do histórico:
  /// "a equipe composta pelo(a) Perito(a) Criminal [nome] e pelo(a) [cargo] [nome], matrícula [x]"
  /// Se só o perito: "o(a) Perito(a) Criminal [nome]"
  Future<String> _formatarEquipeParaPrimeiroParagrafo(
    FichaCompletaModel ficha,
    PeritoModel perito,
    EquipeService equipeService,
  ) async {
    final todosMembros = await equipeService.listarEquipe();
    final outros = <String>[];

    void adicionarMembro(String? id) {
      if (id == null) return;
      final m = todosMembros.firstWhere(
        (m) => m.id == id,
        orElse: () =>
            MembroEquipeModel(id: '', cargo: '', nome: '', matricula: ''),
      );
      if (m.nome.isEmpty) return;
      final texto = _textoMembroComMatricula(
        '${m.cargo} ${m.nome}'.trim(),
        m.matricula,
      );
      outros.add('pelo(a) $texto');
    }

    if (ficha.equipe != null) {
      for (final id in ficha.equipe!.demaisServidoresIds) {
        adicionarMembro(id);
      }
    }

    final peritoTexto = 'pelo(a) Perito(a) Criminal ${perito.nome}';

    if (outros.isEmpty) {
      return 'o(a) Perito(a) Criminal ${perito.nome}';
    }

    final todos = [peritoTexto, ...outros];
    if (todos.length == 2) {
      return 'a equipe composta ${todos[0]} e ${todos[1]}';
    }
    final ultimo = todos.removeLast();
    return 'a equipe composta ${todos.join(', ')} e $ultimo';
  }

  /// Inclui matrícula ou RG no texto do membro (PM e Bombeiros: RG; demais: matrícula).
  String _textoMembroComMatricula(
    String nomeOuDescricao,
    String? matricula, {
    bool usarRg = false,
  }) {
    if (matricula == null || matricula.trim().isEmpty) {
      return nomeOuDescricao;
    }
    final id = matricula.trim();
    if (usarRg) {
      return '$nomeOuDescricao, RG $id';
    }
    return '$nomeOuDescricao, matrícula $id';
  }

  String _formatarNomeCorreto(String nome) {
    // Converte de CAIXA ALTA para formato correto (primeira letra maiúscula, resto minúsculo)
    // Trata nomes compostos corretamente (ex: "MARIA DA SILVA" -> "Maria da Silva")
    const preposicoes = {'da', 'de', 'do', 'dos', 'das', 'e'};
    final palavras = nome.toLowerCase().split(' ');
    final palavrasFormatadas = palavras.asMap().entries.map((entry) {
      final index = entry.key;
      final palavra = entry.value;
      if (palavra.isEmpty) return palavra;
      if (index > 0 && preposicoes.contains(palavra)) return palavra;
      return palavra[0].toUpperCase() + palavra.substring(1);
    }).toList();

    return palavrasFormatadas.join(' ');
  }

  String _formatarEquipesResgate(List<EquipeResgateModel> equipes) {
    final partes = <String>[];

    for (final equipe in equipes) {
      final tipoNome = equipe.outrosTipo ?? equipe.tipo.label;
      final membrosOrdenados = [...equipe.membros]..sort(
          (a, b) => EquipeHierarchy.ordemQualificacaoResgate(
            equipe.tipo,
            a.cargo,
          ).compareTo(
            EquipeHierarchy.ordemQualificacaoResgate(equipe.tipo, b.cargo),
          ),
        );
      final membros = membrosOrdenados.map((m) {
        final partesMembro = <String>[];
        if (m.cargo != null) {
          partesMembro.add(m.cargo!);
        }
        partesMembro.add(m.nome);
        if (m.matricula != null && m.matricula!.trim().isNotEmpty) {
          final id = m.matricula!.trim();
          final labelRg = equipe.tipo == TipoEquipeResgate.cbm;
          partesMembro.add(labelRg ? 'RG $id' : 'matrícula $id');
        }
        if (m.crm != null && m.crm!.trim().isNotEmpty) {
          partesMembro.add('CRM ${m.crm}');
        }
        return partesMembro.join(', ');
      }).join(', ');

      String textoEquipe;
      if (equipe.naoEstavaNoLocal) {
        textoEquipe =
            '$tipoNome: $membros. Nota: A equipe esteve presente durante o atendimento à ocorrência, porém não se encontrava no local ao momento da perícia.';
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

  String _gerarSecaoObjetivos(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln(_gerarTituloSecao('2. OBJETIVOS DA PERÍCIA'));

    final texto = ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito
        ? 'Determinar a materialidade de possível crime de trânsito, bem como, quando possível, definir a dinâmica e as circunstâncias do fato sob investigação, identificar sua causa geradora e responder aos quesitos apresentados.'
        : 'Estabelecer a materialidade dos fatos, buscando os elementos comprobatórios e os meios e/ou instrumentos utilizados na perpetração do ato delituoso e, se possível, os vestígios materiais que contribuam com a elucidação da autoria.';

    buffer.writeln(_gerarParagrafoHistorico(texto));

    return buffer.toString();
  }

  String _gerarSecaoIsolamentoPreservacao(FichaCompletaModel ficha) {
    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      return _gerarSecaoIsolamentoTransito(ficha);
    }

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
      final frasePm = _fraseIsolamentoComPoliciaisMilitares(ficha);
      buffer.writeln(
        _gerarParagrafoHistorico(
          frasePm ?? 'O local encontrava-se isolado por $meios.',
        ),
      );
    }

    // PRESERVAÇÃO
    if (fb?.preservacaoSim == true) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quanto à Preservação, não foram relatadas e/ou constatadas alterações aparentes no estado geral das coisas que inviabilizassem o correto processamento do local.',
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

  String _gerarSecaoIsolamentoTransito(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    final fb = ficha.dadosFichaBase;

    buffer.writeln(
      _gerarTituloSecao('3. ISOLAMENTO DO LOCAL E PRESERVAÇÃO DOS VESTÍGIOS'),
    );

    // Parágrafo 1: condição de isolamento + fluxo de veículos + recursos
    String condicaoIsolamento;
    String fluxoVeiculos;
    bool temIsolamento = fb?.isolamentoSim == true;

    if (temIsolamento && fb?.isolamentoTotal == true) {
      condicaoIsolamento = 'devidamente isolado';
      fluxoVeiculos = 'interrompido';
    } else if (temIsolamento && fb?.isolamentoParcial == true) {
      condicaoIsolamento = 'parcialmente isolado';
      fluxoVeiculos = 'parcialmente controlado';
    } else if (fb?.isolamentoNao == true) {
      condicaoIsolamento = 'sem isolamento oficial';
      fluxoVeiculos = 'não interrompido';
      temIsolamento = false;
    } else {
      condicaoIsolamento = 'isolado';
      fluxoVeiculos = 'controlado';
    }

    if (temIsolamento && fb != null) {
      final meios = _formatarMeiosIsolamento(fb);
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quando do comparecimento da equipe de Polícia Científica, constatou-se que o local se encontrava $condicaoIsolamento, tendo sido o fluxo de veículos $fluxoVeiculos no trecho de interesse técnico-pericial, por meio do uso de $meios.',
        ),
      );
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quando do comparecimento da equipe de Polícia Científica, constatou-se que o local se encontrava $condicaoIsolamento, não tendo sido o fluxo de veículos controlado no trecho de interesse técnico-pericial.',
        ),
      );
    }

    // Parágrafo 2: preservação dos vestígios
    final temAlteracao = fb?.preservacaoInidoneo == true ||
        fb?.preservacaoParcialmenteIdoneo == true;

    if (!temAlteracao) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Quanto à Preservação, não foram relatadas e/ou constatadas alterações aparentes no estado geral das coisas que inviabilizasse o correto processamento do local.',
        ),
      );
    } else {
      if (fb?.preservacaoParcialmenteIdoneo == true) {
        final alteracoes =
            fb?.preservacaoAlteracoesDetectadas?.isNotEmpty == true
                ? ' ${fb!.preservacaoAlteracoesDetectadas}'
                : '';
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Quanto à Preservação dos vestígios, foram detectadas alterações relevantes$alteracoes.',
          ),
        );
      }
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Constatou-se que o local não se encontrava devidamente preservado quando da chegada desta equipe, com indícios de intervenções/alterações anteriores à perícia. Tais circunstâncias podem ter suprimido, deslocado ou modificado vestígios e sua distribuição espacial, afetando a possibilidade de correlação segura entre vestígios materiais e a dinâmica informada no histórico. Assim, os exames concentraram-se no registro técnico do cenário remanescente, com indicação expressa do grau de prejuízo decorrente das condições de preservação.',
        ),
      );
    }

    return buffer.toString();
  }

  Future<String> _gerarSecaoDescricaoLocal(
    FichaCompletaModel ficha, {
    int? mapaRId,
  }) async {
    final buffer = StringBuffer();

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      return _gerarSecaoDescricaoLocalTransito(ficha, mapaRId: mapaRId);
    }

    // 4. DO LOCAL (demais tipos de ocorrência)
    buffer.writeln(_gerarTituloSecao('4. DO LOCAL'));

    // 4.1 Endereço
    buffer.writeln(_gerarTituloSubSecao('4.1 Endereço'));
    final endereco =
        ficha.local?.endereco ?? ficha.dadosSolicitacao.endereco ?? '';
    final municipio =
        ficha.local?.municipio ?? ficha.dadosSolicitacao.municipio ?? '';

    String enderecoCompleto = endereco;
    if (municipio.isNotEmpty) {
      enderecoCompleto = enderecoCompleto.isNotEmpty
          ? '$enderecoCompleto, $municipio'
          : municipio;
    }
    if (enderecoCompleto.isEmpty) enderecoCompleto = 'Não informado';
    enderecoCompleto += enderecoCompleto.endsWith('.') ? '' : '.';
    buffer.writeln(_gerarParagrafoHistorico(enderecoCompleto));

    final coordS = ficha.local?.coordenadasSFormatada;
    final coordW = ficha.local?.coordenadasWFormatada;
    final textoCoordenadas = (coordS != null && coordW != null)
        ? 'Coordenadas geográficas: $coordS $coordW.'
        : 'Coordenadas geográficas: Não obtidas.';
    buffer.writeln(_gerarParagrafoHistorico(textoCoordenadas));

    if (mapaRId != null) {
      buffer.writeln(_gerarLegendaEImagemMapa(mapaRId));
    }

    // 4.2 Descrição — para furto/dano
    final isCvliOuMorte = ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
        ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer;
    if (!isCvliOuMorte &&
        ficha.localFurto != null &&
        _temVestigiosLocal(ficha.localFurto!)) {
      buffer.writeln(_gerarTituloSubSecao('4.2 Descrição'));
      buffer.writeln(await _gerarSecaoExamesLocal(ficha));
    }

    return buffer.toString();
  }

  /// Seção 4 no padrão da Superintendência para Crime de Trânsito.
  String _gerarSecaoDescricaoLocalTransito(
    FichaCompletaModel ficha, {
    int? mapaRId,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('4. DESCRIÇÃO'));
    buffer.writeln(_gerarTituloSubSecao('4.1 Local'));

    // 4.1.1 Endereço
    buffer.writeln(_gerarTituloSubSubSecao('4.1.1 Endereço'));
    final endereco =
        ficha.local?.endereco ?? ficha.dadosSolicitacao.endereco ?? '';
    final municipio =
        ficha.local?.municipio ?? ficha.dadosSolicitacao.municipio ?? '';
    String enderecoCompleto = endereco;
    if (municipio.isNotEmpty) {
      enderecoCompleto = enderecoCompleto.isNotEmpty
          ? '$enderecoCompleto, $municipio'
          : municipio;
    }
    if (enderecoCompleto.isEmpty) enderecoCompleto = 'Não informado';
    enderecoCompleto += enderecoCompleto.endsWith('.') ? '' : '.';
    buffer.writeln(_gerarParagrafoHistorico(enderecoCompleto));

    // 4.1.2 Coordenadas Geográficas
    buffer.writeln(_gerarTituloSubSubSecao('4.1.2 Coordenadas Geográficas'));
    final coordS = ficha.local?.coordenadasSFormatada;
    final coordW = ficha.local?.coordenadasWFormatada;
    final textoCoordenadas = (coordS != null && coordW != null)
        ? 'Coordenadas geográficas: $coordS $coordW.'
        : 'Coordenadas geográficas: Não obtidas.';
    buffer.writeln(_gerarParagrafoHistorico(textoCoordenadas));
    if (mapaRId != null) {
      buffer.writeln(_gerarLegendaEImagemMapa(mapaRId));
    }

    // 4.1.3 Características e Condições (conteúdo movido de 5.1)
    buffer.writeln(
      _gerarTituloSubSubSecao('4.1.3 Características e Condições'),
    );
    final cond = ficha.crimeTransitoCondicoes;
    final textoCondicoes =
        cond != null ? _textoCondicoesCrimeTransito(cond) : '';
    buffer.writeln(
      _gerarParagrafoHistorico(
        textoCondicoes.isNotEmpty ? textoCondicoes : 'Não informado.',
      ),
    );

    // 4.1.4 Velocidade Máxima Regulamentar
    buffer.writeln(
      _gerarTituloSubSubSecao('4.1.4 Velocidade Máxima Regulamentar'),
    );
    buffer.writeln(
      _gerarParagrafoHistorico(_textoVelocidadeCrimeTransito(cond)),
    );

    // 4.2 Unidades Veiculares
    final veiculos = ficha.veiculos;
    if (veiculos != null && veiculos.isNotEmpty) {
      buffer.writeln(
        _gerarTituloSubSecaoComFootnote('4.2 Unidades Veiculares', 1),
      );
      for (int i = 0; i < veiculos.length; i++) {
        final v = veiculos[i];
        final num = i + 1;
        buffer.writeln(
          _gerarTituloSubSubSecao('4.2.$num Unidade Veicular $num (V$num)'),
        );
        final tipo = v.tipoVeiculo == TipoVeiculo.outro
            ? (v.tipoVeiculoOutro?.isNotEmpty == true
                ? v.tipoVeiculoOutro!
                : 'Outro')
            : (v.tipoVeiculo?.label ?? 'Não informado');
        final mm = v.marcaModelo?.isNotEmpty == true
            ? v.marcaModelo!
            : 'Não informado';
        final cor = v.cor?.isNotEmpty == true ? v.cor! : 'Não informado';
        final placa = v.placa?.isNotEmpty == true ? v.placa! : 'Não informado';
        final anoFab = v.anoFabricacao?.isNotEmpty == true
            ? v.anoFabricacao!
            : 'Não informado';
        final anoMod =
            v.anoModelo?.isNotEmpty == true ? v.anoModelo! : 'Não informado';
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Tipo de Veículo: $tipo.   Marca/Modelo: $mm.   Cor: $cor.',
          ),
        );
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Placa de Licenciamento instalada: $placa.   '
            'Ano Fabricação/Ano Modelo: $anoFab/$anoMod.',
          ),
        );
      }
    }

    // 4.3 Vítima em óbito no local
    final cadaveres = ficha.cadaveres;
    if (cadaveres != null && cadaveres.isNotEmpty) {
      buffer.writeln(_gerarTituloSubSecao('4.3 Vítima em óbito no local'));
      final plural = cadaveres.length > 1;
      for (int i = 0; i < cadaveres.length; i++) {
        final c = cadaveres[i];
        final prefixo = plural ? '4.3.${i + 1} Vítima ${i + 1} – ' : '4.3.';

        // Identificação
        buffer.writeln(_gerarTituloSubSubSecao('${prefixo}1 Identificação'));
        final nome = c.nomeDaVitima?.isNotEmpty == true
            ? c.nomeDaVitima!
            : 'Não identificado';
        final doc = c.documentoIdentificacao?.isNotEmpty == true
            ? c.documentoIdentificacao!
            : 'Não informado';
        final dataNasc = c.dataNascimento?.isNotEmpty == true
            ? c.dataNascimento!
            : 'Não informado';
        final sexoTexto = c.sexo?.label ?? 'Não informado';
        final laudoNum = c.numeroLaudoCadaverico?.isNotEmpty == true
            ? c.numeroLaudoCadaverico!
            : 'a ser complementado';
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Nome: $nome.   Documento de Identificação: $doc.',
          ),
        );
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Data de nascimento: $dataNasc.   Sexo: $sexoTexto.   '
            'Laudo Cadavérico: $laudoNum.',
          ),
        );

        // Descrição/Indumentária/Pertences
        buffer.writeln(
          _gerarTituloSubSubSecao(
            '${prefixo}2 Descrição/Indumentária/Pertences',
          ),
        );
        final vestesTexto = _resumoVestesCadaverTransito(c);
        final pertencesTexto =
            c.pertences?.isNotEmpty == true ? 'Pertences: ${c.pertences}.' : '';
        final descricao = [
          vestesTexto,
          pertencesTexto,
        ].where((s) => s.isNotEmpty).join(' ');
        buffer.writeln(
          _gerarParagrafoHistorico(
            descricao.isNotEmpty ? descricao : 'Não informado.',
          ),
        );
      }
    }

    return buffer.toString();
  }

  String _gerarTituloSubSecao(String titulo) {
    // 2º nível: inicial maiúscula, negrito, Gadugi 12pt, esquerda (Portaria 128/2019, Art. 2º IV.2)
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="left"/>
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

  String _gerarTituloSubSecaoComFootnote(String titulo, int footnoteId) {
    final textoEscapado = _escapeXml(titulo);
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="left"/>
        <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
        <w:ind w:firstLine="0"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:t>$textoEscapado</w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
          <w:b/>
          <w:vertAlign w:val="superscript"/>
          <w:sz w:val="$_fontSizeNormal"/>
          <w:szCs w:val="$_fontSizeNormal"/>
        </w:rPr>
        <w:footnoteReference w:id="$footnoteId"/>
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

    // Para CVLI e Morte a Esclarecer: seção "5. DAS IMAGENS"
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
        ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
      buffer.writeln(_gerarTituloSecao('5. DAS IMAGENS'));

      // Converter quantidade para número por extenso
      final temImagemSatelite =
          (ficha.local?.capturaTelaLocalPath ?? '').trim().isNotEmpty;
      final qtdTotalImagens = qtdFotos + (temImagemSatelite ? 1 : 0);
      String qtdPorExtenso = _numeroPorExtenso(qtdTotalImagens);
      String qtdNumerica = qtdTotalImagens.toString().padLeft(2, '0');
      final trechoSatelite = temImagemSatelite
          ? ' incluindo 01 (uma) imagem de satélite proveniente de captura de tela do local,'
          : '';

      // Gerar parágrafo com "XX" em vermelho
      buffer.writeln(
        _gerarParagrafoHistoricoComTextoColorido(
          'Integra o presente laudo o levantamento fotográfico composto por $qtdNumerica ($qtdPorExtenso) imagens, todas produzidas pelo próprio Perito Criminal responsável pela elaboração deste documento. As fotografias encontram-se organizadas e inseridas a partir da página ',
          'XX',
          '$trechoSatelite destinando-se à documentação objetiva do local, dos vestígios e das condições observadas durante a realização dos exames periciais.',
        ),
      );

      return buffer.toString();
    }

    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      buffer.writeln(_gerarTituloSecao('5. LEVANTAMENTO DE IMAGENS'));
      final temImagemSatelite =
          (ficha.local?.capturaTelaLocalPath ?? '').trim().isNotEmpty;
      final qtdTotalImagens = qtdFotos + (temImagemSatelite ? 1 : 0);
      final qtdPorExtenso = _numeroPorExtenso(qtdTotalImagens);
      final qtdNumerica = qtdTotalImagens.toString().padLeft(2, '0');
      final trechoSatelite = temImagemSatelite
          ? ' incluindo 01 (uma) imagem de satélite proveniente de captura de tela do local,'
          : '';
      buffer.writeln(
        _gerarParagrafoHistoricoComTextoColorido(
          'Integra o presente laudo o levantamento fotográfico composto por $qtdNumerica ($qtdPorExtenso) imagens, todas produzidas pelo próprio Perito Criminal responsável pela elaboração deste documento. As fotografias encontram-se organizadas e inseridas a partir da página ',
          'XX',
          '$trechoSatelite destinando-se à documentação objetiva do local, dos vestígios e das condições observadas durante a realização dos exames periciais.',
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
    final temPapiloComplementar = materialImpressoes != null ||
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
          'Os vestígios coletados foram devidamente acondicionados, identificados e encaminhados para processamento na $nomeUnidade, para a realização de exames complementares.',
        ),
      );

      // 5.2.2 Levantamento Papiloscópico
      if (temPapiloComplementar) {
        buffer.writeln(
          _gerarTituloSubSecao('5.2.2 Levantamento Papiloscópico'),
        );

        final superfPapiloRaw = materialImpressoes?.descricaoDetalhada?.trim();
        final superfPapilo = (superfPapiloRaw == null ||
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

  Future<String> _gerarSecaoExamesCrimeTransito(
    FichaCompletaModel ficha,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('6. EXAMES'));

    // 6.1 No Local
    buffer.writeln(_gerarTituloSubSecao('6.1 No Local'));
    final lev = ficha.crimeTransitoLevantamento;
    final croquiObs = lev?.croquiObservacoes;
    final escalaTexto = (croquiObs != null && croquiObs.isNotEmpty)
        ? croquiObs
        : 'fora de escala';
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Para maior detalhamento da disposição dos vestígios, foi confeccionado '
        'um desenho esquemático $escalaTexto, alusivo ao sinistro em questão, '
        'indicando em ilustração os vestígios mais relevantes encontrados.',
      ),
    );

    // Vestígios da via
    final vestigios = lev?.vestigios ?? const [];
    if (vestigios.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'No local dos fatos, foram detectados os seguintes vestígios:',
        ),
      );
      for (final v in vestigios) {
        final tipoText = switch (v.tipo) {
          TipoVestigioVia.marcaFrenagem => 'Marca de frenagem',
          TipoVestigioVia.marcaDerrapagem => 'Marca de derrapagem',
          TipoVestigioVia.sulcagem => 'Sulcagem',
          TipoVestigioVia.friccao => 'Marca de fricção',
          TipoVestigioVia.arraste => 'Marca de arraste',
          TipoVestigioVia.arrastamentoCorpoFlacido =>
            'Marca de arrastamento de corpo flácido',
          TipoVestigioVia.marcaGuinada => 'Marca de guinada',
          TipoVestigioVia.materialBiologico => 'Material biológico',
          TipoVestigioVia.substanciaHematica => 'Substância hemática',
          TipoVestigioVia.liquidos => 'Líquidos',
          TipoVestigioVia.fragmentos => 'Fragmentos',
          TipoVestigioVia.outro => v.tipoOutroDescricao ?? 'Outro vestígio',
        };
        final posText = v.posicao != null
            ? switch (v.posicao!) {
                PosicaoRelativaVestigio.antes => 'antes do sítio de colisão',
                PosicaoRelativaVestigio.apos => 'após o sítio de colisão',
                PosicaoRelativaVestigio.noSitio => 'no sítio de colisão',
                PosicaoRelativaVestigio.naoSeAplica => '',
              }
            : '';
        final medText = v.medidaMetros?.isNotEmpty == true
            ? ', medindo ${v.medidaMetros} m'
            : '';
        final condText = v.condutorAssociado?.isNotEmpty == true
            ? ', associado a ${v.condutorAssociado}'
            : '';
        final obsText =
            v.observacao?.isNotEmpty == true ? '. ${v.observacao}' : '';
        final descricao = [
          tipoText,
          posText.isNotEmpty ? posText : null,
        ].whereType<String>().join(', ');
        buffer.writeln(
          _gerarParagrafoHistorico(
            '\u2022 $descricao$medText$condText$obsText.',
          ),
        );
      }
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'No local dos fatos, não foram detectados vestígios sobre a pista.',
        ),
      );
    }

    // 6.2 Nas Unidades Veiculares
    final veiculos = ficha.veiculos;
    if (veiculos != null && veiculos.isNotEmpty) {
      buffer.writeln(_gerarTituloSubSecao('6.2 Nas Unidades Veiculares'));
      for (int i = 0; i < veiculos.length; i++) {
        final v = veiculos[i];
        final num = i + 1;
        final intensText = v.intensidadeDano != null
            ? switch (v.intensidadeDano!) {
                IntensidadeDano.leve => 'de intensidade leve',
                IntensidadeDano.media => 'de intensidade média',
                IntensidadeDano.grave => 'de intensidade grave',
                IntensidadeDano.gravissima => 'de intensidade gravíssima',
              }
            : '';
        final setoresText = v.setoresImpacto?.isNotEmpty == true
            ? _formatarListaTextoCrime(
                v.setoresImpacto,
                (s) => switch (s) {
                  SetorImpacto.anterior => 'anterior',
                  SetorImpacto.posterior => 'posterior',
                  SetorImpacto.lateralEsquerdo => 'lateral esquerdo',
                  SetorImpacto.lateralDireito => 'lateral direito',
                  SetorImpacto.angularAnteriorEsquerdo =>
                    'angular anterior esquerdo',
                  SetorImpacto.angularAnteriorDireito =>
                    'angular anterior direito',
                  SetorImpacto.angularPosteriorEsquerdo =>
                    'angular posterior esquerdo',
                  SetorImpacto.angularPosteriorDireito =>
                    'angular posterior direito',
                },
              )
            : null;
        final defText = v.tipificacoesDeformacoes?.isNotEmpty == true
            ? _formatarListaTextoCrime(
                v.tipificacoesDeformacoes,
                (d) => switch (d) {
                  TipificacaoDeformacao.amassamento => 'amassamento',
                  TipificacaoDeformacao.cisalhamento => 'cisalhamento',
                  TipificacaoDeformacao.arrastamento => 'arrastamento',
                  TipificacaoDeformacao.empenamento => 'empenamento',
                  TipificacaoDeformacao.arrancamento => 'arrancamento',
                  TipificacaoDeformacao.estampamento => 'estampamento',
                  TipificacaoDeformacao.quebramento => 'quebramento',
                  TipificacaoDeformacao.esmagamento => 'esmagamento',
                  TipificacaoDeformacao.sanfonamento => 'sanfonamento',
                  TipificacaoDeformacao.mossa => 'mossa',
                  TipificacaoDeformacao.atritamento => 'atritamento',
                  TipificacaoDeformacao.afundamento => 'afundamento',
                },
              )
            : null;
        final oriText = v.orientacoesDeformacoes?.isNotEmpty == true
            ? _formatarListaTextoCrime(
                v.orientacoesDeformacoes,
                (o) => switch (o) {
                  OrientacaoDeformacao.direitaParaEsquerda =>
                    'da direita para a esquerda',
                  OrientacaoDeformacao.esquerdaParaDireita =>
                    'da esquerda para a direita',
                  OrientacaoDeformacao.dianteiraParaTraseira =>
                    'da dianteira para a traseira',
                  OrientacaoDeformacao.traseiraParaDianteira =>
                    'da traseira para a dianteira',
                },
              )
            : null;

        final sb = StringBuffer('A unidade V-$num exibia avarias permanentes');
        if (intensText.isNotEmpty) sb.write(', $intensText');
        if (oriText != null) sb.write(', orientadas $oriText');
        if (setoresText != null) {
          sb.write(', sendo a sede de colisão o setor $setoresText');
        }
        sb.write('.');
        if (defText != null) {
          sb.write(' Os danos eram representados por $defText.');
        }
        if (v.danosObservacoes?.isNotEmpty == true) {
          sb.write(' ${v.danosObservacoes}.');
        }

        // Sistemas de segurança
        final seguros = <String>[];
        if (v.cintosSeguranca != null) {
          seguros.add(
            'cinto de segurança: ${switch (v.cintosSeguranca!) {
              StatusComponenteVeiculo.funcionando => 'em funcionamento',
              StatusComponenteVeiculo.naoFuncionando => 'sem funcionamento',
              StatusComponenteVeiculo.prejudicado =>
                'com funcionamento prejudicado',
            }}',
          );
        }
        if (v.airbag != null) {
          seguros.add(
            'airbag: ${switch (v.airbag!) {
              AirbagStatus.acionado => 'acionado',
              AirbagStatus.naoAcionado => 'não acionado',
              AirbagStatus.ausente => 'ausente',
            }}',
          );
        }
        if (v.estadoPneumaticos != null) {
          seguros.add(
            'pneus: ${switch (v.estadoPneumaticos!) {
              EstadoPneumaticos.novos => 'novos (acima do TWI)',
              EstadoPneumaticos.meiaVida => 'meia-vida (acima do TWI)',
              EstadoPneumaticos.desgastados =>
                'desgastados (abaixo do limite TWI)',
            }}',
          );
        }
        if (v.tacografoStatus != null &&
            v.tacografoStatus != TacografoStatus.naoSeAplica) {
          seguros.add(
            'tacógrafo: ${switch (v.tacografoStatus!) {
              TacografoStatus.ausente => 'ausente',
              TacografoStatus.recolhido => 'recolhido para análise',
              TacografoStatus.naoSeAplica => '',
            }}',
          );
        }
        if (seguros.isNotEmpty) {
          sb.write(' Reporta-se ainda: ${seguros.join('; ')}.');
        }

        buffer.writeln(_gerarParagrafoHistorico(sb.toString()));
      }
    }

    // 6.3 Na Vítima (opcional - apenas se houver cadáveres com observações)
    final cadaveres = ficha.cadaveres;
    if (cadaveres != null && cadaveres.isNotEmpty) {
      buffer.writeln(_gerarTituloSubSecao('6.3 Na Vítima'));
      buffer.writeln(await _gerarSecaoExamesCadaveres(ficha));
    }

    // 6.4 Exames Complementares
    buffer.writeln(_gerarTituloSubSecao('6.4 Exames Complementares'));
    final exDinamica = lev?.examesDinamica;
    final solicitouExames = lev?.solicitacaoExamesComplementares ?? false;
    final labDestino = lev?.laboratorioDestino;
    if (solicitouExames == true &&
        (exDinamica?.isNotEmpty == true || labDestino?.isNotEmpty == true)) {
      if (exDinamica?.isNotEmpty == true) {
        buffer.writeln(_gerarParagrafoHistorico(exDinamica!));
      }
      if (labDestino?.isNotEmpty == true) {
        buffer.writeln(
          _gerarParagrafoHistorico('Material encaminhado ao: $labDestino.'),
        );
      }
    } else {
      buffer.writeln(
        _gerarParagrafoHistorico('não realizados/não solicitados.'),
      );
    }

    return buffer.toString();
  }

  String _gerarSecaoConsideracoesTecnicasTransito(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('7. CONSIDERAÇÕES TÉCNICAS'));

    buffer.writeln(_gerarTituloSubSecao('7.1 Dinâmica do Evento'));
    final lev = ficha.crimeTransitoLevantamento;
    final natureza = ficha.crimeTransitoNatureza;
    final formas = lev?.formasInteracao ?? natureza?.formasInteracao;
    final dinamica =
        lev?.dinamica ?? CausasDeterminantesCatalogo.derivarDinamica(formas);

    final partesDinamica = <String>[];
    if (dinamica != null) {
      partesDinamica.add(
        'A dinâmica principal indicada para o evento corresponde a ${CausasDeterminantesCatalogo.labelDinamica(dinamica).toLowerCase()}.',
      );
    }
    final formasTexto = _formatarListaTextoCrime(
      formas,
      _labelFormaInteracaoTransito,
    );
    if (formasTexto.isNotEmpty) {
      partesDinamica.add(
        'Foram registradas as seguintes formas de interação: $formasTexto.',
      );
    }
    final complemento = natureza?.complementoDinamicaFato?.trim();
    if (complemento != null && complemento.isNotEmpty) {
      partesDinamica.add(
        complemento.endsWith('.') ? complemento : '$complemento.',
      );
    }
    final obsNatureza = natureza?.observacoes?.trim();
    if (obsNatureza != null && obsNatureza.isNotEmpty) {
      partesDinamica.add(
        obsNatureza.endsWith('.') ? obsNatureza : '$obsNatureza.',
      );
    }

    buffer.writeln(
      _gerarParagrafoHistorico(
        partesDinamica.isNotEmpty
            ? partesDinamica.join(' ')
            : 'A dinâmica do evento não foi descrita nos dados da ficha.',
      ),
    );

    buffer.writeln(_gerarTituloSubSecao('7.2 Estimativa de Velocidade'));
    buffer.writeln(
      _gerarParagrafoHistorico(_textoEstimativaVelocidadeTransito(ficha)),
    );

    buffer.writeln(_gerarTituloSubSecao('7.3 Análise da Causa Determinante'));
    final causasTexto = _textoCausasDeterminantesTransito(ficha, dinamica);
    buffer.writeln(_gerarParagrafoHistorico(causasTexto));

    return buffer.toString();
  }

  String _gerarSecaoRespostaQuesitosTransito(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('8. RESPOSTA A QUESITOS'));
    buffer.writeln(
      _gerarParagrafoHistorico(
        'Não foram apresentados quesitos pela Autoridade Requisitante até o momento da elaboração deste laudo.',
      ),
    );
    return buffer.toString();
  }

  String _gerarSecaoConclusaoTransito(FichaCompletaModel ficha) {
    final buffer = StringBuffer();
    buffer.writeln(_gerarTituloSecao('9. CONCLUSÃO'));
    buffer.writeln(
      _gerarParagrafoHistorico(
        'A conclusão técnico-pericial acerca da causa do evento deverá ser consignada após a consolidação da dinâmica do evento, da estimativa de velocidade, quando aplicável, e da análise da causa determinante.',
      ),
    );
    return buffer.toString();
  }

  String _textoEstimativaVelocidadeTransito(FichaCompletaModel ficha) {
    final calculo = ficha.atropelamentoCalculo;
    if (calculo == null) {
      return 'No presente caso, não foi realizada estimativa de velocidade de deslocamento dos veículos envolvidos, por ausência de elementos técnicos suficientes ou por inexistência de cálculo aplicável registrado na ficha.';
    }

    final dt = calculo.dt;
    final mu = calculo.mu;
    if (dt == null || dt <= 0 || mu == null || mu <= 0 || mu > 1) {
      return 'Os parâmetros registrados para estimativa de velocidade não são suficientes para a apresentação de resultado técnico.';
    }

    if (calculo.useNorthwestern == true) {
      final resultado = calcularSoNorthwestern(
        s: dt,
        mu: mu,
        muMin: calculo.muMin,
        muMax: calculo.muMax,
      );
      if (resultado == null) {
        return 'Não foi possível calcular a estimativa de velocidade pelo método Northwestern com os parâmetros registrados.';
      }
      return 'Foi registrada estimativa de velocidade pelo método Northwestern, considerando distância de projeção de ${_formatarNumeroDecimal(dt)} m e coeficiente de atrito ${_formatarNumeroDecimal(mu)}. O resultado estimado foi de ${_formatarResultadoVelocidade(resultado)}.';
    }

    final ep = _eficienciaProjecaoSearleTransito(calculo);
    if (ep == null || ep <= 0 || ep >= 1) {
      return 'Não foi possível calcular a estimativa de velocidade pelo método Searle porque a eficiência de projeção não foi informada de forma válida.';
    }

    final resultado = calcularAtropelamento(
      s: dt,
      mu: mu,
      muMin: calculo.muMin,
      muMax: calculo.muMax,
      ep: ep,
    );
    if (resultado == null) {
      return 'Não foi possível calcular a estimativa de velocidade pelo método Searle com os parâmetros registrados.';
    }
    return 'Foi registrada estimativa de velocidade pelo método Searle, considerando distância de projeção de ${_formatarNumeroDecimal(dt)} m, coeficiente de atrito ${_formatarNumeroDecimal(mu)} e eficiência de projeção ${_formatarNumeroDecimal(ep)}. A velocidade de impacto estimada foi de ${_formatarResultadoVelocidade(resultado.searleVc)}.';
  }

  String _textoCausasDeterminantesTransito(
    FichaCompletaModel ficha,
    DinamicaAcidente? dinamica,
  ) {
    final ids = ficha.crimeTransitoNatureza?.causasDeterminantesIds;
    if (dinamica == null || ids == null || ids.isEmpty) {
      return 'Não foi selecionado modelo de causa determinante para o evento, permanecendo a análise condicionada à interpretação técnica dos vestígios descritos.';
    }

    final opcoes = CausasDeterminantesCatalogo.opcoesPara(
      dinamica,
    ).where((c) => ids.contains(c.id)).toList();
    if (opcoes.isEmpty) {
      return 'Os modelos de causa determinante selecionados não correspondem à dinâmica principal registrada para o evento.';
    }

    final texto = opcoes.map((c) => '${c.referencia} - ${c.titulo}').join('; ');
    return 'Foram selecionados, como referência técnica para análise da causa determinante, os seguintes modelos: $texto.';
  }

  double? _eficienciaProjecaoSearleTransito(AtropelamentoCalculoModel calculo) {
    if (calculo.epCustom != null) return calculo.epCustom;
    final tipoVitima = calculo.tipoVitima;
    final frontal = calculo.frontalVeiculo;
    if (tipoVitima == null || frontal == null) return null;
    if (tipoVitima == AtropelamentoTipoVitima.adulto) {
      return frontal == AtropelamentoFrontalVeiculo.baixo ? 0.64 : 0.744;
    }
    return frontal == AtropelamentoFrontalVeiculo.baixo ? 0.727 : 0.831;
  }

  String _formatarResultadoVelocidade(ResultadoVelocidade resultado) {
    if (resultado.isIntervalo &&
        resultado.vMinKmh != null &&
        resultado.vMaxKmh != null) {
      return 'entre ${_formatarNumeroDecimal(resultado.vMinKmh!)} km/h e ${_formatarNumeroDecimal(resultado.vMaxKmh!)} km/h';
    }
    if (resultado.vKmh != null) {
      return '${_formatarNumeroDecimal(resultado.vKmh!)} km/h';
    }
    return 'não determinado';
  }

  String _formatarNumeroDecimal(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _labelFormaInteracaoTransito(CrimeTransitoFormaInteracao forma) {
    return switch (forma) {
      CrimeTransitoFormaInteracao.saidaPista => 'saída de pista',
      CrimeTransitoFormaInteracao.capotamento => 'capotamento',
      CrimeTransitoFormaInteracao.tombamento => 'tombamento',
      CrimeTransitoFormaInteracao.queda => 'queda',
      CrimeTransitoFormaInteracao.atropelamento => 'atropelamento',
      CrimeTransitoFormaInteracao.outro => 'outro',
      CrimeTransitoFormaInteracao.colisao => 'colisão',
      CrimeTransitoFormaInteracao.abalroamento => 'abalroamento',
      CrimeTransitoFormaInteracao.choque => 'choque',
      CrimeTransitoFormaInteracao.colisaoFrontal => 'colisão frontal',
      CrimeTransitoFormaInteracao.colisaoTraseira => 'colisão traseira',
      CrimeTransitoFormaInteracao.colisaoLateral => 'colisão lateral',
      CrimeTransitoFormaInteracao.colisaoLongitudinal => 'colisão longitudinal',
      CrimeTransitoFormaInteracao.colisaoOposta => 'colisão em sentido oposto',
      CrimeTransitoFormaInteracao.colisaoTransversal => 'colisão transversal',
      CrimeTransitoFormaInteracao.colisaoObliqua => 'colisão oblíqua',
      CrimeTransitoFormaInteracao.colisaoOrtogonal => 'colisão ortogonal',
      CrimeTransitoFormaInteracao.objetoFixo => 'objeto fixo',
      CrimeTransitoFormaInteracao.veiculoEstacionado => 'veículo estacionado',
      CrimeTransitoFormaInteracao.veiculoParado => 'veículo parado',
      CrimeTransitoFormaInteracao.pedestre => 'pedestre',
      CrimeTransitoFormaInteracao.animal => 'animal',
    };
  }

  Future<String> _gerarSecaoAnaliseInterpretacao(
    FichaCompletaModel ficha,
  ) async {
    final buffer = StringBuffer();

    // Para Crime de Trânsito: seção "6. EXAMES"
    if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
      buffer.writeln(await _gerarSecaoExamesCrimeTransito(ficha));
      return buffer.toString();
    }

    // Para CVLI e Morte a Esclarecer: seção "6. DOS EXAMES"
    if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
        ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
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
        buffer.writeln(
          _gerarParagrafoHistorico(_textoSistemaCoordenadasVestigios),
        );
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var i = 0; i < lf.vestigiosMediato!.length; i++) {
          final vestigio = lf.vestigiosMediato![i];
          final textoVestigio = _gerarTextoVestigioLocal(vestigio, i);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
        final resumoEnc = await _gerarResumoEncaminhamentoLocais(
          lf.vestigiosMediato!,
        );
        if (resumoEnc.isNotEmpty) {
          buffer.writeln(_gerarParagrafoHistorico(resumoEnc));
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
        buffer.writeln(
          _gerarParagrafoHistorico(_textoSistemaCoordenadasVestigios),
        );
        buffer.writeln(
          _gerarParagrafoHistorico('Vestígios encontrados por ambiente:'),
        );
        final grupos = _agruparVestigiosPorAmbiente(lf.vestigiosImediato!);
        for (final entry in grupos.entries) {
          final ambiente = entry.key;
          buffer.writeln(
            _gerarParagrafoHistorico('Ambiente: ${_capitalizar(ambiente)}.'),
          );
          final marco = lf.marcosZeroAmbientesImediato?[ambiente];
          final textoMarco = _formatarMarcoZeroLocal(marco);
          if (textoMarco.isNotEmpty) {
            buffer.writeln(_gerarParagrafoHistorico(textoMarco));
          }
          for (var i = 0; i < entry.value.length; i++) {
            final vestigio = entry.value[i];
            final textoVestigio = _gerarTextoVestigioLocal(vestigio, i);
            buffer.writeln(_gerarParagrafoLista(textoVestigio));
          }
        }
        final resumoEnc = await _gerarResumoEncaminhamentoLocais(
          lf.vestigiosImediato!,
        );
        if (resumoEnc.isNotEmpty) {
          buffer.writeln(_gerarParagrafoHistorico(resumoEnc));
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
        buffer.writeln(
          _gerarParagrafoHistorico(_textoSistemaCoordenadasVestigios),
        );
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var i = 0; i < lf.vestigiosRelacionado!.length; i++) {
          final vestigio = lf.vestigiosRelacionado![i];
          final textoVestigio = _gerarTextoVestigioLocal(vestigio, i);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
        final resumoEnc = await _gerarResumoEncaminhamentoLocais(
          lf.vestigiosRelacionado!,
        );
        if (resumoEnc.isNotEmpty) {
          buffer.writeln(_gerarParagrafoHistorico(resumoEnc));
        }
        final temNaoColetados = lf.vestigiosRelacionado!.any(
          (v) => v.tipoAcao != TipoAcaoVestigio.coletado,
        );
        if (temNaoColetados) {
          buffer.writeln(
            _gerarParagrafoHistorico(
              'Os demais vestígios, que não demandaram recolhimento para exame complementar, foram suficientemente registrados e documentados pericialmente no local.',
            ),
          );
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

  Map<String, List<VestigioLocalModel>> _agruparVestigiosPorAmbiente(
    List<VestigioLocalModel> vestigios,
  ) {
    final grupos = <String, List<VestigioLocalModel>>{};
    for (final vestigio in vestigios) {
      final ambiente = vestigio.ambiente?.trim();
      final chave = ambiente == null || ambiente.isEmpty
          ? 'ambiente não especificado'
          : ambiente;
      grupos.putIfAbsent(chave, () => <VestigioLocalModel>[]).add(vestigio);
    }
    return grupos;
  }

  String _formatarMarcoZeroLocal(MarcoZeroLocalModel? marco) {
    if (marco == null) return '';
    final partes = <String>[];
    final descricao = marco.descricao?.trim();
    final x = marco.coordenadaX?.trim();
    final y = marco.coordenadaY?.trim();
    if (descricao != null && descricao.isNotEmpty) {
      partes.add('descrição: $descricao');
    }
    if (x != null && x.isNotEmpty) partes.add('X=$x');
    if (y != null && y.isNotEmpty) partes.add('Y=$y');
    if (partes.isEmpty) return '';
    return 'Marco zero do ambiente: ${partes.join(', ')}.';
  }

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  String _enumerarLetrasOrdinal(List<String> letras) {
    if (letras.isEmpty) return '';
    if (letras.length == 1) return letras.first;
    if (letras.length == 2) return '${letras[0]} e ${letras[1]}';
    return '${letras.sublist(0, letras.length - 1).join(', ')} e ${letras.last}';
  }

  String _fraseEncaminhamentoColetaLetras(
    List<String> letras,
    String nomeDestino,
  ) {
    if (letras.isEmpty) return '';
    final listaFmt = _enumerarLetrasOrdinal(letras);
    if (letras.length == 1) {
      return 'O vestígio descrito na alínea ${letras.first} foi encaminhado '
          'para $nomeDestino.';
    }
    return 'Os vestígios descritos nas alíneas $listaFmt foram encaminhados '
        'para $nomeDestino.';
  }

  Future<String> _resolverNomeDestinoParaLaudoLocal(
    VestigioLocalModel v,
  ) async {
    if (v.tipoDestino != null && v.destinoId != null) {
      try {
        if (v.tipoDestino == TipoDestinoVestigio.unidade) {
          final unidades = await _unidadeService.listarUnidades();
          final unidade = unidades.firstWhere((u) => u.id == v.destinoId);
          return unidade.nome;
        }
        if (v.tipoDestino == TipoDestinoVestigio.laboratorio) {
          final laboratorios = await _laboratorioService.listarLaboratorios();
          final laboratorio = laboratorios.firstWhere(
            (l) => l.id == v.destinoId,
          );
          return _formatarLaboratorioParaLaudoLocal(laboratorio);
        }
      } catch (_) {}
    }
    if (v.tipoDestino == TipoDestinoVestigio.unidade) {
      return 'Unidade (não localizada)';
    }
    if (v.tipoDestino == TipoDestinoVestigio.laboratorio) {
      return 'Laboratório (não localizado)';
    }
    return 'a unidade ou laboratório cadastrados para o vestígio';
  }

  String _formatarLaboratorioParaLaudoLocal(LaboratorioModel lab) {
    final nome = lab.nome.trim();
    final sigla = lab.sigla?.trim();
    if (sigla == null || sigla.isEmpty) return nome;
    return '$nome (${sigla.toUpperCase()})';
  }

  Future<String> _resolverNomeDestinoParaLaudoVeiculo(
    VestigioVeiculoModel v,
  ) async {
    if (v.tipoDestino != null && v.destinoId != null) {
      try {
        if (v.tipoDestino == TipoDestinoVestigioVeiculo.unidade) {
          final unidades = await _unidadeService.listarUnidades();
          final unidade = unidades.firstWhere((u) => u.id == v.destinoId);
          return unidade.nome;
        }
        if (v.tipoDestino == TipoDestinoVestigioVeiculo.laboratorio) {
          final laboratorios = await _laboratorioService.listarLaboratorios();
          final laboratorio = laboratorios.firstWhere(
            (l) => l.id == v.destinoId,
          );
          return _formatarLaboratorioParaLaudoLocal(laboratorio);
        }
      } catch (_) {}
    }
    if (v.tipoDestino == TipoDestinoVestigioVeiculo.unidade) {
      return 'Unidade (não localizada)';
    }
    if (v.tipoDestino == TipoDestinoVestigioVeiculo.laboratorio) {
      return 'Laboratório (não localizado)';
    }
    return 'a unidade ou laboratório cadastrados para o vestígio';
  }

  Future<String> _gerarResumoEncaminhamentoLocais(
    List<VestigioLocalModel> vestigios,
  ) async {
    final grupos = <String, List<String>>{};
    for (var i = 0; i < vestigios.length; i++) {
      final v = vestigios[i];
      if (v.tipoAcao != TipoAcaoVestigio.coletado) continue;
      final key = '${v.tipoDestino?.name ?? '_'}|${v.destinoId ?? '_'}';
      grupos.putIfAbsent(key, () => []).add(_indicePraLetra(i));
    }
    if (grupos.isEmpty) return '';

    final frases = <String>[];
    for (final entry in grupos.entries) {
      VestigioLocalModel? amostra;
      for (final v in vestigios) {
        if (v.tipoAcao != TipoAcaoVestigio.coletado) continue;
        final k = '${v.tipoDestino?.name ?? '_'}|${v.destinoId ?? '_'}';
        if (k == entry.key) {
          amostra = v;
          break;
        }
      }
      if (amostra == null) continue;
      final nome = await _resolverNomeDestinoParaLaudoLocal(amostra);
      frases.add(_fraseEncaminhamentoColetaLetras(entry.value, nome));
    }
    return frases.join(' ');
  }

  Future<String> _gerarResumoEncaminhamentoVeiculo(
    List<VestigioVeiculoModel> vestigios,
  ) async {
    final grupos = <String, List<String>>{};
    for (var i = 0; i < vestigios.length; i++) {
      final v = vestigios[i];
      if (v.tipoAcao != TipoAcaoVestigioVeiculo.coletado) continue;
      final key = '${v.tipoDestino?.name ?? '_'}|${v.destinoId ?? '_'}';
      grupos.putIfAbsent(key, () => []).add(_indicePraLetra(i));
    }
    if (grupos.isEmpty) return '';

    final frases = <String>[];
    for (final entry in grupos.entries) {
      VestigioVeiculoModel? amostra;
      for (final v in vestigios) {
        if (v.tipoAcao != TipoAcaoVestigioVeiculo.coletado) continue;
        final k = '${v.tipoDestino?.name ?? '_'}|${v.destinoId ?? '_'}';
        if (k == entry.key) {
          amostra = v;
          break;
        }
      }
      if (amostra == null) continue;
      final nome = await _resolverNomeDestinoParaLaudoVeiculo(amostra);
      frases.add(_fraseEncaminhamentoColetaLetras(entry.value, nome));
    }
    return frases.join(' ');
  }

  /// Gera o texto de um vestígio de local sem incluir seu posicionamento técnico.
  String _gerarTextoVestigioLocal(VestigioLocalModel vestigio, int indice) {
    final letra = _indicePraLetra(indice);
    final partes = <String>[];

    // Descrição do vestígio (nome opcional + descrição)
    String descricao = vestigio.rotuloNomeDescricao;
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
      partes.add('Presença de $descricao');
    }

    if (partes.isEmpty) return '$letra) Vestígio registrado.';
    return '$letra) ${partes.join('. ')}.';
  }

  String _formatarCitacaoFotosVestigio(List<int> numeros) {
    if (numeros.isEmpty) return '';
    final unicosOrdenados = {...numeros}.where((n) => n > 0).toList()..sort();
    if (unicosOrdenados.isEmpty) return '';
    final numerosFmt =
        unicosOrdenados.map((n) => n.toString().padLeft(2, '0')).toList();
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

      // Tipo + marca/modelo juntos sem vírgula entre eles
      String cabecalhoVeiculo = '';
      if (veiculo.tipoVeiculo != null) {
        String tipo = veiculo.tipoVeiculo!.label;
        if (veiculo.tipoVeiculo == TipoVeiculo.outro &&
            veiculo.tipoVeiculoOutro != null &&
            veiculo.tipoVeiculoOutro!.isNotEmpty) {
          tipo = veiculo.tipoVeiculoOutro!;
        }
        cabecalhoVeiculo = tipo;
      }
      if (veiculo.marcaModelo != null && veiculo.marcaModelo!.isNotEmpty) {
        cabecalhoVeiculo = cabecalhoVeiculo.isEmpty
            ? veiculo.marcaModelo!
            : '$cabecalhoVeiculo ${veiculo.marcaModelo!}';
      }
      if (cabecalhoVeiculo.isNotEmpty) partesDescricao.add(cabecalhoVeiculo);

      if (veiculo.anoFabricacao != null && veiculo.anoFabricacao!.isNotEmpty) {
        partesDescricao.add('ano de fabricação ${veiculo.anoFabricacao}');
      }

      if (veiculo.anoModelo != null && veiculo.anoModelo!.isNotEmpty) {
        partesDescricao.add('modelo ${veiculo.anoModelo}');
      }

      if (veiculo.cor != null && veiculo.cor!.isNotEmpty) {
        partesDescricao.add('cor ${veiculo.cor!.toLowerCase()}');
      }

      if (veiculo.placa != null && veiculo.placa!.isNotEmpty) {
        final placaRaw = veiculo.placa!.toUpperCase().replaceAll('-', '');
        final placaFormatada = placaRaw.length == 7
            ? '${placaRaw.substring(0, 3)}-${placaRaw.substring(3)}'
            : placaRaw;
        partesDescricao.add('placa $placaFormatada');
      }

      if (veiculo.localizacaoAmbiente != null &&
          veiculo.localizacaoAmbiente!.isNotEmpty) {
        partesDescricao.add('localização: ${veiculo.localizacaoAmbiente}');
      }

      if (partesDescricao.isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(partesDescricao.join(', ')));
      }

      // Listar vestígios do veículo
      if (veiculo.vestigios != null && veiculo.vestigios!.isNotEmpty) {
        buffer.writeln(
          _gerarParagrafoHistorico(_textoSistemaCoordenadasVestigios),
        );
        buffer.writeln(_gerarParagrafoHistorico('Vestígios encontrados:'));
        for (var j = 0; j < veiculo.vestigios!.length; j++) {
          final vestigio = veiculo.vestigios![j];
          final textoVestigio = _gerarTextoVestigioVeiculo(vestigio, j);
          buffer.writeln(_gerarParagrafoLista(textoVestigio));
        }
        final resumoEnc = await _gerarResumoEncaminhamentoVeiculo(
          veiculo.vestigios!,
        );
        if (resumoEnc.isNotEmpty) {
          buffer.writeln(_gerarParagrafoHistorico(resumoEnc));
        }
        final temNaoColetados = veiculo.vestigios!.any(
          (v) => v.tipoAcao != TipoAcaoVestigioVeiculo.coletado,
        );
        if (temNaoColetados) {
          buffer.writeln(
            _gerarParagrafoHistorico(
              'Os demais vestígios, que não demandaram recolhimento para exame complementar, foram suficientemente registrados e documentados pericialmente no local.',
            ),
          );
        }
      }

      // Espaço entre veículos (exceto no último)
      if (i < ficha.veiculos!.length - 1) {
        buffer.writeln(_gerarParagrafoVazio());
      }
    }

    return buffer.toString();
  }

  /// Gera o texto de um vestígio de veículo (descrição; encaminhamento em parágrafo à parte).
  String _gerarTextoVestigioVeiculo(VestigioVeiculoModel vestigio, int indice) {
    final letra = _indicePraLetra(indice);
    final partes = <String>[];

    // Núcleo descritivo (nome opcional + descrição + local em texto corrido)
    String nucleo = vestigio.rotuloNomeDescricao;
    final loc = (vestigio.localizacao ?? '').trim();
    if (loc.isNotEmpty) {
      if (nucleo.isEmpty) {
        nucleo = loc;
      } else {
        nucleo = '$nucleo, situado em $loc';
      }
    }
    String descricao = nucleo;
    if (vestigio.isSangueHumano) {
      descricao = '${descricao.isNotEmpty ? '$descricao, ' : ''}com indícios '
          'compatíveis com sangue humano';
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
      partes.add('Presença de $descricao');
    }

    if (partes.isEmpty) return '$letra) Vestígio registrado.';
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
      buffer.writeln(_gerarTatuagensMarcasCadaver(cadaver));

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
    <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

  String _gerarTituloSubSubSecao(String titulo) {
    final textoEscapado = _escapeXml(titulo);
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:before="0" w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
    <w:jc w:val="left"/>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
      <w:b/>
      <w:sz w:val="$_fontSizeNormal"/>
      <w:szCs w:val="$_fontSizeNormal"/>
    </w:rPr>
    <w:t>$textoEscapado</w:t>
  </w:r>
</w:p>''';
  }

  /// Célula da tabela de identificação do cadáver.
  /// Cada célula tem um label pequeno e o valor em fonte normal abaixo.
  String _celulaIdentificacao(String label, String valor, int largura) {
    final labelEsc = _escapeXml(label);
    final valorEsc = _escapeXml(valor);
    return '''<w:tc>
  <w:tcPr>
    <w:tcW w:w="$largura" w:type="dxa"/>
    <w:tcBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    </w:tcBorders>
    <w:tcMar>
      <w:top w:w="80" w:type="dxa"/>
      <w:left w:w="115" w:type="dxa"/>
      <w:bottom w:w="80" w:type="dxa"/>
      <w:right w:w="115" w:type="dxa"/>
    </w:tcMar>
  </w:tcPr>
  <w:p>
    <w:pPr>
      <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
      <w:ind w:firstLine="0"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
        <w:sz w:val="16"/>
        <w:szCs w:val="16"/>
        <w:color w:val="555555"/>
      </w:rPr>
      <w:t>$labelEsc</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
      <w:ind w:firstLine="0"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="$_fontName" w:hAnsi="$_fontName" w:cs="$_fontName"/>
        <w:sz w:val="$_fontSizeNormal"/>
        <w:szCs w:val="$_fontSizeNormal"/>
      </w:rPr>
      <w:t>${valorEsc.isEmpty ? ' ' : valorEsc}</w:t>
    </w:r>
  </w:p>
</w:tc>''';
  }

  /// Gera a tabela de identificação preliminar do cadáver.
  /// Layout:
  ///   Linha 1: Nome (4050) | Documento/CPF (2700) | Compleição Física (2250)
  ///   Linha 2: Filiação (4050) | Data de Nascimento (2250) | Cor (1350) | Sexo (1350)
  String _gerarIdentificacaoCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    final nome =
        cadaver.nomeDaVitima != null && cadaver.nomeDaVitima!.isNotEmpty
            ? _formatarNomeCorreto(cadaver.nomeDaVitima!)
            : 'Não identificada';
    final doc = cadaver.documentoIdentificacao ?? '';
    final compleicao = cadaver.compleicao?.label ?? '';
    final filiacao = cadaver.filiacao != null && cadaver.filiacao!.isNotEmpty
        ? _formatarNomeCorreto(cadaver.filiacao!)
        : '';
    final dataNasc = cadaver.dataNascimento ?? '';
    final cor = cadaver.corPele?.label ?? '';
    final sexo = cadaver.sexo?.label ?? '';

    buffer.writeln('''<w:tbl>
  <w:tblPr>
    <w:tblW w:w="9000" w:type="dxa"/>
    <w:tblBorders>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    </w:tblBorders>
    <w:tblLook w:val="04A0"/>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="4050"/>
    <w:gridCol w:w="2700"/>
    <w:gridCol w:w="2250"/>
  </w:tblGrid>
  <w:tr>
    ${_celulaIdentificacao('Nome:', nome, 4050)}
    ${_celulaIdentificacao('Documento (CPF):', doc, 2700)}
    ${_celulaIdentificacao('Compleição Física:', compleicao, 2250)}
  </w:tr>
  <w:tr>
    ${_celulaIdentificacao('Filiação:', filiacao, 4050)}
    ${_celulaIdentificacao('Data de Nascimento:', dataNasc, 2250)}
    ${_celulaIdentificacao('Cor:', cor, 1350)}
    ${_celulaIdentificacao('Sexo:', sexo, 1350)}
  </w:tr>
</w:tbl>''');

    // Laudo cadavérico associado (se houver)
    if (cadaver.numeroLaudoCadaverico != null &&
        cadaver.numeroLaudoCadaverico!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'O laudo cadavérico de n. ${cadaver.numeroLaudoCadaverico} foi associado ao presente exame.',
        ),
      );
    }

    // Características físicas complementares em prosa (cabelo, barba, tatuagens)
    final caracteristicas = <String>[];

    if (cadaver.faixaEtaria != null) {
      caracteristicas.add(
        'faixa etária ${cadaver.faixaEtaria!.label.toLowerCase()}',
      );
    }

    final descricaoCabelo = _descreverCabelo(cadaver);
    if (descricaoCabelo != null && descricaoCabelo.isNotEmpty) {
      caracteristicas.add(descricaoCabelo);
    }

    final descricaoBarba = _descreverBarba(cadaver);
    if (descricaoBarba != null && descricaoBarba.isNotEmpty) {
      caracteristicas.add(descricaoBarba);
    }

    if (caracteristicas.isNotEmpty) {
      final ultimo = caracteristicas.removeLast();
      final textoCaracteristicas = caracteristicas.isEmpty
          ? ultimo
          : '${caracteristicas.join(', ')} e $ultimo';
      buffer.writeln(
        _gerarParagrafoHistorico('Apresentava $textoCaracteristicas.'),
      );
    }

    return buffer.toString();
  }

  String? _descreverCabelo(CadaverModel cadaver) {
    final tamanhoTexto = cadaver.tamanhoCabelo == null
        ? ''
        : (cadaver.tamanhoCabelo == TamanhoCabelo.outro
            ? (cadaver.tamanhoCabeloOutro ?? '').trim().toLowerCase()
            : cadaver.tamanhoCabelo!.label.toLowerCase());
    final tipoTexto = cadaver.tipoCabelo == null
        ? ''
        : (cadaver.tipoCabelo == TipoCabelo.outro
            ? (cadaver.tipoCabeloOutro ?? '').trim().toLowerCase()
            : cadaver.tipoCabelo!.label.toLowerCase());
    final corTexto = cadaver.corCabelo == null
        ? ''
        : (cadaver.corCabelo == CorCabelo.outro
            ? (cadaver.corCabeloOutro ?? '').trim().toLowerCase()
            : cadaver.corCabelo!.label.toLowerCase());

    if (tamanhoTexto.isEmpty && tipoTexto.isEmpty && corTexto.isEmpty) {
      return null;
    }

    if (tamanhoTexto == 'calvo') {
      return corTexto.isEmpty ? 'calvície' : 'calvície, com cabelos $corTexto';
    }

    final partes = <String>['cabelos'];
    if (tamanhoTexto.isNotEmpty) partes.add(tamanhoTexto);
    if (tipoTexto.isNotEmpty) partes.add(tipoTexto);
    if (corTexto.isNotEmpty) partes.add('de coloração $corTexto');
    return partes.join(' ');
  }

  String? _descreverBarba(CadaverModel cadaver) {
    final tipo = cadaver.tipoBarba;
    if (tipo == null || tipo == TipoBarba.naoSeAplica) return null;

    final tipoTexto = tipo == TipoBarba.outro
        ? (cadaver.tipoBarbaOutro ?? '').trim().toLowerCase()
        : tipo.label.toLowerCase();
    final tamanhoTexto = cadaver.tamanhoBarba == null
        ? ''
        : (cadaver.tamanhoBarba == TamanhoBarba.outro
            ? (cadaver.tamanhoBarbaOutro ?? '').trim().toLowerCase()
            : cadaver.tamanhoBarba!.label.toLowerCase());
    final corTexto = cadaver.corBarba == null
        ? ''
        : (cadaver.corBarba == CorBarba.outra
            ? (cadaver.corBarbaOutra ?? '').trim().toLowerCase()
            : cadaver.corBarba!.label.toLowerCase());

    if (tipoTexto.isEmpty && tamanhoTexto.isEmpty && corTexto.isEmpty) {
      return null;
    }

    if (tipo == TipoBarba.bigode) {
      final partes = <String>['bigode'];
      if (tamanhoTexto.isNotEmpty) partes.add(tamanhoTexto);
      if (corTexto.isNotEmpty) partes.add('de coloração $corTexto');
      return partes.join(' ');
    }

    if (tipo == TipoBarba.cavanhaque) {
      final partes = <String>['cavanhaque'];
      if (tamanhoTexto.isNotEmpty) partes.add(tamanhoTexto);
      if (corTexto.isNotEmpty) partes.add('de coloração $corTexto');
      return partes.join(' ');
    }

    final partes = <String>['barba'];
    if (tipoTexto.isNotEmpty) partes.add('do tipo $tipoTexto');
    if (tamanhoTexto.isNotEmpty) partes.add(tamanhoTexto);
    if (corTexto.isNotEmpty) partes.add('de coloração $corTexto');
    return partes.join(' ');
  }

  String _gerarTatuagensMarcasCadaver(CadaverModel cadaver) {
    final buffer = StringBuffer();

    if (cadaver.tatuagensMarcasLista != null &&
        cadaver.tatuagensMarcasLista!.isNotEmpty) {
      for (var i = 0; i < cadaver.tatuagensMarcasLista!.length; i++) {
        final item = cadaver.tatuagensMarcasLista![i];
        final desc = item.descricao?.trim();
        if (desc == null || desc.isEmpty) continue;

        var texto = 'Tatuagem/Marca ${i + 1}: $desc';
        if (item.numerosFotografias.isNotEmpty) {
          final nums = item.numerosFotografias.toSet().toList()..sort();
          final numsFmt =
              nums.map((n) => n.toString().padLeft(2, '0')).toList();
          if (numsFmt.length == 1) {
            texto += ' (Fotografia ${numsFmt.first}).';
          } else if (numsFmt.length == 2) {
            texto += ' (Fotografias ${numsFmt[0]} e ${numsFmt[1]}).';
          } else {
            texto +=
                ' (Fotografias ${numsFmt.sublist(0, numsFmt.length - 1).join(', ')} e ${numsFmt.last}).';
          }
        } else {
          texto += '.';
        }
        buffer.writeln(_gerarParagrafoHistorico(texto));
      }
      return buffer.toString();
    }

    if (cadaver.tatuagensMarcas != null &&
        cadaver.tatuagensMarcas!.isNotEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Tatuagens/Marcas Corporais: ${cadaver.tatuagensMarcas}.',
        ),
      );
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

    if (cadaver.modoVestes == ModoVestesCadaver.geral) {
      if (cadaver.descricaoVestesGerais != null &&
          cadaver.descricaoVestesGerais!.trim().isNotEmpty) {
        buffer.writeln(_gerarParagrafoHistorico(
          'Vestes: ${cadaver.descricaoVestesGerais!.trim()}',
        ));
      }
    } else if (cadaver.vestes == null || cadaver.vestes!.isEmpty) {
      buffer.writeln(_gerarParagrafoHistorico('Não informado'));
      return buffer.toString();
    } else {
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

        final descricaoVeste =
            partes.isNotEmpty ? partes.join(', ') : 'Sem descrição';
        buffer.writeln(_gerarParagrafoLista('$letra) $descricaoVeste.'));
      }
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

    buffer.writeln(
      _gerarParagrafoHistorico('Ao exame perinecroscópico, observou-se:'),
    );

    // Itens fixos — sinais clínicos de morte
    buffer.writeln(
      _gerarParagrafoLista(
        'a) Sinais clínicos de morte ocorrida (insensibilidade geral do organismo, ausência de movimentos cardíacos e respiratórios);',
      ),
    );
    buffer.writeln(
      _gerarParagrafoLista(
        'b) Presença de midríase (dilatação) e fotoplegia (não reação à luz) pupilar;',
      ),
    );

    if (cadaver.lesoes == null || cadaver.lesoes!.isEmpty) {
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Não foram observadas lesões aparentes no exame externo.',
        ),
      );
      return buffer.toString();
    }

    // Lesões registradas — iniciam na letra c) (índice 2)
    for (var i = 0; i < cadaver.lesoes!.length; i++) {
      final lesao = cadaver.lesoes![i];
      final letra = _indicePraLetra(i + 2);

      String descricaoLesao;
      if (lesao.isPaf && lesao.paf != null) {
        final textoPaf = gerarDescricaoPAF(
          regiao: lesao.regiao,
          tipo: lesao.paf!.tipo,
          distancia: lesao.paf!.distancia,
          diametro: lesao.paf!.diametro,
          sinais: lesao.paf!.sinais,
        );
        final textoLower = textoPaf[0].toLowerCase() + textoPaf.substring(1);
        descricaoLesao = 'Presença de $textoLower';
      } else {
        final tipo = lesao.tipo;
        final desc = lesao.descricao;
        if (tipo != null && tipo.isNotEmpty) {
          final tipoLower = tipo[0].toLowerCase() + tipo.substring(1);
          if (desc != null && desc.isNotEmpty) {
            descricaoLesao = 'Presença de $tipoLower — $desc';
          } else {
            descricaoLesao = 'Presença de $tipoLower em ${lesao.regiao}';
          }
        } else {
          final base = desc != null && desc.isNotEmpty
              ? desc
              : 'lesão em ${lesao.regiao}';
          final baseLower = base[0].toLowerCase() + base.substring(1);
          descricaoLesao = 'Presença de $baseLower';
        }
      }

      final nomeLesao = lesao.nome?.trim();
      if (nomeLesao != null && nomeLesao.isNotEmpty) {
        descricaoLesao =
            'Evidência identificada como «$nomeLesao»: $descricaoLesao';
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

    // Ausência de lesões de defesa
    if (cadaver.ausenciaLesoesDefesa) {
      final membros = cadaver.membrosExaminadosDefesa;
      String textoMembros;
      if (membros.isEmpty) {
        textoMembros = 'nos membros examinados';
      } else if (membros.length == 1) {
        textoMembros = 'no ${membros.first.toLowerCase()}';
      } else {
        final ultimo = membros.last.toLowerCase();
        final demais = membros
            .sublist(0, membros.length - 1)
            .map((m) => m.toLowerCase())
            .join(', ');
        textoMembros = 'no $demais e $ultimo';
      }

      String textoDefesa =
          'Não foram observadas lesões de defesa $textoMembros';

      final nums = cadaver.numerosFotosLesoesDefesa;
      if (nums != null && nums.isNotEmpty) {
        final numsFmt = nums.map((n) => n.toString().padLeft(2, '0')).toList();
        if (numsFmt.length == 1) {
          textoDefesa += ' (Fotografia ${numsFmt.first})';
        } else if (numsFmt.length == 2) {
          textoDefesa += ' (Fotografias ${numsFmt[0]} e ${numsFmt[1]})';
        } else {
          textoDefesa +=
              ' (Fotografias ${numsFmt.sublist(0, numsFmt.length - 1).join(', ')} e ${numsFmt.last})';
        }
      }
      textoDefesa += '.';

      if (cadaver.observacoesLesoesDefesa != null &&
          cadaver.observacoesLesoesDefesa!.isNotEmpty) {
        textoDefesa += ' ${cadaver.observacoesLesoesDefesa}';
      }

      buffer.writeln(_gerarParagrafoHistorico(textoDefesa));
    }

    // Exames do cadáver integrados aos demais vestígios observados no local

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
    if (cadaver.hipostasePosicao != null ||
        cadaver.hipostaseCompativeis != null) {
      final hipostase = <String>[];
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
    final frases = <String>[];

    // --- Frase 1: tipo de pista, sentido, orientação, separação ---
    final tipoPista = cond.tiposPista?.isNotEmpty == true
        ? (cond.tiposPista!.first == TipoPistaRodovia.simples
            ? 'simples'
            : 'dupla')
        : null;
    final sentido = cond.sentidos?.isNotEmpty == true
        ? (cond.sentidos!.first == SentidoPista.unico ? 'simples' : 'duplo')
        : null;
    final orientacao = cond.orientacaoVia != null
        ? switch (cond.orientacaoVia!) {
            OrientacaoVia.norteSul => 'Norte\u2013Sul',
            OrientacaoVia.lesteOeste => 'Leste\u2013Oeste',
            OrientacaoVia.nordesteSudoeste => 'Nordeste\u2013Sudoeste',
            OrientacaoVia.noroesteSudeste => 'Noroeste\u2013Sudeste',
          }
        : null;

    final sepPistas = cond.separacoesPistas?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            cond.separacoesPistas,
            (v) => switch (v) {
              SeparacaoPistasOpcao.canteiro => 'canteiro central',
              SeparacaoPistasOpcao.muretaConcreto => 'mureta de concreto',
              SeparacaoPistasOpcao.tachoes => 'tachões',
              SeparacaoPistasOpcao.defensa => 'defensa lateral (guard rail)',
              SeparacaoPistasOpcao.nenhum => 'sem separação',
              SeparacaoPistasOpcao.outro => 'outro elemento separador',
            },
          )
        : null;

    final sb1 = StringBuffer('Tratava-se de via de pista ');
    sb1.write(tipoPista ?? '[não especificado]');
    if (sentido != null) {
      sb1.write(', com sentido de tráfego $sentido');
    }
    if (orientacao != null) {
      sb1.write(' com orientação $orientacao');
    }
    if (sepPistas != null &&
        sepPistas.isNotEmpty &&
        cond.tiposPista?.contains(TipoPistaRodovia.dupla) == true) {
      sb1.write(', sendo as pistas separadas por $sepPistas');
    }
    frases.add(sb1.toString());

    // --- Frase 2: calibre e faixas ---
    final largura =
        cond.larguraPista?.isNotEmpty == true ? cond.larguraPista : null;
    final numFaixas = cond.numeroFaixas;
    final numAcostamento = cond.faixasAcostamento;
    if (largura != null || numFaixas != null) {
      final sb2 = StringBuffer('Cada pista apresentava');
      if (largura != null) sb2.write(' calibre total de $largura m');
      if (largura != null && numFaixas != null) sb2.write(' e');
      if (numFaixas != null) {
        sb2.write(
          ' era composta por $numFaixas faixa${numFaixas == 1 ? '' : 's'} de rolamento',
        );
      }
      if (numAcostamento != null) {
        sb2.write(
          ' e $numAcostamento faixa${numAcostamento == 1 ? '' : 's'} destinada${numAcostamento == 1 ? '' : 's'} ao acostamento',
        );
      }
      frases.add(sb2.toString());
    }

    // --- Frase 3: pavimentação, condições, traçado ---
    final pavText = cond.tipoPavimento != null
        ? switch (cond.tipoPavimento!) {
            TipoPavimento.asfalto => 'havia pavimento em asfalto',
            TipoPavimento.concreto => 'havia pavimento em concreto',
            TipoPavimento.paralelepipedo =>
              'havia pavimento em paralelepípedo/pedra',
            TipoPavimento.cascalho =>
              'não havia pavimentação, sendo o piso em cascalho',
            TipoPavimento.terraBatida =>
              'não havia pavimentação, sendo o piso em terra batida',
            TipoPavimento.terraSolta =>
              'não havia pavimentação, sendo o piso em terra solta',
          }
        : null;

    // condições da via (excluindo seca/molhada que vão na frase 6)
    final condViaFiltradas = cond.condicoesVia
        ?.where(
          (v) => v != CondicaoViaOpcao.seca && v != CondicaoViaOpcao.molhada,
        )
        .toList();
    final condVia = _formatarListaTextoCrime(
      condViaFiltradas,
      (v) => switch (v) {
        CondicaoViaOpcao.seca => 'seca',
        CondicaoViaOpcao.umida => 'úmida',
        CondicaoViaOpcao.molhada => 'molhada',
        CondicaoViaOpcao.semDefeito => 'sem defeitos aparentes',
        CondicaoViaOpcao.comBuracos => 'com buracos',
        CondicaoViaOpcao.comOndulacoes => 'com ondulações',
        CondicaoViaOpcao.emObras => 'em obras',
        CondicaoViaOpcao.escorregadia => 'escorregadia',
        CondicaoViaOpcao.comContaminantes => 'com contaminantes',
        CondicaoViaOpcao.outro =>
          cond.condicaoViaOutroDescricao ?? 'em outra condição',
      },
    );

    // traçado + perfil
    final tracadoTexto = _formatarListaTextoCrime(
      cond.tracados,
      (v) => switch (v) {
        TracadoPista.curvaEsquerda => 'curvilíneo (curva à esquerda)',
        TracadoPista.curvaDireita => 'curvilíneo (curva à direita)',
        TracadoPista.reto => 'retilíneo',
        TracadoPista.raioAmplo => 'curvilíneo de raio amplo',
        TracadoPista.raioPequeno => 'curvilíneo de raio pequeno',
        TracadoPista.cruzamento => 'cruzamento',
      },
    );
    final perfisTexto = _formatarListaTextoCrime(
      cond.perfis,
      (v) => switch (v) {
        PerfilPista.plano => 'perfil plano',
        PerfilPista.suave => 'suave',
        PerfilPista.declive => 'declive',
        PerfilPista.moderado => 'moderado',
        PerfilPista.aclive => 'aclive',
        PerfilPista.acentuado => 'acentuado',
      },
    );
    final tracadoFull = [
      tracadoTexto,
      perfisTexto,
    ].where((s) => s.isNotEmpty).join(', ');

    if (pavText != null || condVia.isNotEmpty || tracadoFull.isNotEmpty) {
      final sb3 = StringBuffer('No trecho em que se deu o fato, ');
      sb3.write(pavText ?? '[pavimentação não informada]');
      if (condVia.isNotEmpty) sb3.write(' em condições $condVia');
      if (tracadoFull.isNotEmpty) sb3.write(', traçado $tracadoFull');
      frases.add(sb3.toString());
    }

    // condições de via não pavimentada (complemento)
    if (cond.condicoesNaoPavimentada?.isNotEmpty == true) {
      final naoPayText = _formatarListaTextoCrime(
        cond.condicoesNaoPavimentada,
        (v) => switch (v) {
          CondicaoViaNaoPavimentada.comErosao => 'com erosão (ravinas/sulcos)',
          CondicaoViaNaoPavimentada.comValetas => 'com valetas ou drenos',
          CondicaoViaNaoPavimentada.poeiraSuspensao =>
            'com poeira em suspensão',
          CondicaoViaNaoPavimentada.alagada => 'alagada/com lama',
          CondicaoViaNaoPavimentada.vegetacaoNaPista =>
            'com vegetação invadindo a pista',
          CondicaoViaNaoPavimentada.acostamentoIndefinido =>
            'acostamento indefinido',
        },
      );
      if (naoPayText.isNotEmpty) frases.add(naoPayText);
    }

    // --- Frase 4: sinalização ---
    final placas = cond.sinalizacao?.placasVerticais?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            cond.sinalizacao!.placasVerticais,
            (v) => switch (v) {
              PlacaVertical.paradaObrigatoria =>
                'placa de parada obrigatória (R-1)',
              PlacaVertical.deAPreferencia =>
                'placa de "Dê a Preferência" (R-2)',
              PlacaVertical.advertencia =>
                'placa de advertência${cond.sinalizacao?.placaAdvertenciaDescricao?.isNotEmpty == true ? ' (${cond.sinalizacao!.placaAdvertenciaDescricao})' : ''}',
            },
          )
        : null;
    final conservacaoSin = cond.sinalizacao?.conservacaoVertical != null
        ? switch (cond.sinalizacao!.conservacaoVertical!) {
            ConservacaoSinalizacao.boa => 'em bom estado de conservação',
            ConservacaoSinalizacao.regular =>
              'em estado regular de conservação',
            ConservacaoSinalizacao.ruim => 'em mau estado de conservação',
          }
        : null;
    final faixasHoriz = cond.sinalizacao?.separacoesFaixas?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            cond.sinalizacao!.separacoesFaixas,
            (v) => switch (v) {
              SeparacaoFaixasOpcao.simplesContinua => 'linha simples contínua',
              SeparacaoFaixasOpcao.duplaContinua => 'linha dupla contínua',
              SeparacaoFaixasOpcao.simplesSeccionada =>
                'linha simples seccionada',
              SeparacaoFaixasOpcao.duplaContinuaSeccionada =>
                'linha dupla contínua/seccionada',
            },
          )
        : null;

    if (placas != null || faixasHoriz != null) {
      final partesSin = <String>[];
      if (placas != null) partesSin.add(placas);
      if (faixasHoriz != null) {
        final corFaixas = cond.sinalizacao?.corFaixas?.isNotEmpty == true
            ? ' ${_formatarListaTextoCrime(cond.sinalizacao!.corFaixas, (v) => v == CorFaixa.amarela ? 'amarela' : 'branca')}'
            : '';
        partesSin.add('demarcação horizontal: $faixasHoriz$corFaixas');
      }
      final sinText = partesSin.join('; ');
      final conservStr = conservacaoSin != null ? ', $conservacaoSin' : '';
      frases.add('Nesse trecho, havia $sinText$conservStr');
    }

    // --- Frase 5: visibilidade ---
    if (cond.visibilidade != null) {
      if (cond.visibilidade == VisibilidadeTipo.boa) {
        frases.add('Não havia restrições físicas à visibilidade');
      } else {
        final motivo = cond.visibilidadeReducaoDescricao?.isNotEmpty == true
            ? ' — ${cond.visibilidadeReducaoDescricao}'
            : '';
        frases.add('Havia restrições físicas à visibilidade$motivo');
      }
    }

    // --- Frase 6: meteorologia, solo e regime de tráfego ---
    final iluminacaoTexto = _formatarListaTextoCrime(
      cond.iluminacao,
      (v) => switch (v) {
        IluminacaoLocal.artificial => 'noturno com iluminação artificial',
        IluminacaoLocal.naturalDia => 'diurno (iluminação natural)',
        IluminacaoLocal.ausente => 'noturno sem iluminação artificial',
      },
    );
    final soloTexto = _formatarListaTextoCrime(
      cond.condicoesSolo,
      (v) => switch (v) {
        CondicaoSoloLocal.seco => 'seco',
        CondicaoSoloLocal.umido => 'úmido',
        CondicaoSoloLocal.molhado => 'molhado/chuvoso',
      },
    );
    final pistaCondicao = cond.condicoesVia
            ?.where(
              (v) =>
                  v == CondicaoViaOpcao.seca || v == CondicaoViaOpcao.molhada,
            )
            .map((v) => v == CondicaoViaOpcao.seca ? 'seca' : 'molhada')
            .join(' e ') ??
        '';
    final regimeTexto = cond.regimeTrafego != null
        ? switch (cond.regimeTrafego!) {
            RegimeTrafego.intenso => 'intenso',
            RegimeTrafego.moderado => 'moderado',
            RegimeTrafego.leve => 'leve',
            RegimeTrafego.outro => cond.regimeTrafegoOutro ?? 'atípico',
          }
        : null;

    if (iluminacaoTexto.isNotEmpty ||
        soloTexto.isNotEmpty ||
        pistaCondicao.isNotEmpty ||
        regimeTexto != null) {
      final sb6 = StringBuffer('No momento da Perícia Criminal');
      if (iluminacaoTexto.isNotEmpty) {
        sb6.write(', o período era $iluminacaoTexto');
      }
      if (soloTexto.isNotEmpty) {
        sb6.write(', o tempo era $soloTexto');
      }
      if (pistaCondicao.isNotEmpty) {
        sb6.write(', e a pista estava $pistaCondicao');
      }
      if (regimeTexto != null) {
        sb6.write(', e o regime de tráfego era $regimeTexto');
      }
      frases.add(sb6.toString());
    }

    // --- Frase 7: contaminantes ---
    final contaminantesTexto = cond.contaminantes?.isNotEmpty == true
        ? _formatarListaTextoCrime(
            cond.contaminantes,
            (v) => switch (v) {
              ContaminanteTipo.oleo => 'óleo',
              ContaminanteTipo.areia => 'areia',
              ContaminanteTipo.combustivel => 'combustível',
              ContaminanteTipo.outro => 'outros contaminantes',
            },
          )
        : null;
    if (contaminantesTexto != null && contaminantesTexto.isNotEmpty) {
      frases.add(
        'Observou-se a presença de contaminantes na pista: $contaminantesTexto',
      );
    } else {
      frases.add(
        'Não se observou falhas de construção ou contaminantes de pista',
      );
    }

    // larguras das faixas (complemento técnico)
    if (cond.largurasFaixas?.isNotEmpty == true) {
      frases.add(
        'larguras aproximadas das faixas: ${cond.largurasFaixas!.join(', ')} m',
      );
    }

    if (cond.observacoes?.isNotEmpty == true) {
      frases.add(cond.observacoes!);
    }

    return frases.join('. ').trim();
  }

  /// Gera o parágrafo de 4.1.4 Velocidade Máxima Regulamentar.
  String _textoVelocidadeCrimeTransito(CrimeTransitoCondicoesViaModel? cond) {
    if (cond == null) {
      return 'Não foi possível determinar a velocidade máxima regulamentar para o trecho.';
    }
    final vel = cond.velocidadeMaxima;
    if (vel != null && vel.isNotEmpty) {
      if (cond.velocidadePorSinalizacao == true) {
        return 'A via apresentava sinalização regulamentar de velocidade máxima de $vel km/h.';
      }
      if (cond.velocidadePorCTB == true) {
        return 'Não havia sinalização regulamentar de velocidade máxima no trecho. '
            'Conforme estabelece o art. 61, §1º do CTB/1997, o limite de velocidade '
            'é de $vel km/h.';
      }
      return 'Velocidade máxima regulamentar: $vel km/h.';
    }
    return 'Não foi possível determinar a velocidade máxima regulamentar para o trecho.';
  }

  /// Resumo textual das vestes do cadáver para uso em 4.3.2.
  String _resumoVestesCadaverTransito(CadaverModel cadaver) {
    if (cadaver.vestes == null || cadaver.vestes!.isEmpty) return '';
    final itens = cadaver.vestes!
        .map((v) {
          final partes = <String>[];
          if (v.tipoMarca?.isNotEmpty == true) partes.add(v.tipoMarca!);
          if (v.cor?.isNotEmpty == true) partes.add(v.cor!);
          if (v.notas?.isNotEmpty == true) partes.add(v.notas!);
          return partes.join(', ');
        })
        .where((s) => s.isNotEmpty)
        .toList();
    if (itens.isEmpty) return '';
    return 'Indumentária: ${itens.join('; ')}.';
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
            : 'Não foram observados vestígios que indiquem destruição ou rompimento de obstáculo à subtração da coisa.',
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
            : 'Não foram observados vestígios que indiquem uso de escalada ou destreza especial.',
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
            : 'Não foram observados vestígios que indiquem emprego de chave falsa ou instrumento análogo.',
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
            : 'Não foram observados vestígios que indiquem o concurso de duas ou mais pessoas na prática do fato.',
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
            : 'Não foram observados vestígios que permitam inferir a recenticidade do fato.',
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
    String resposta1 =
        'Não foram observados vestígios que indiquem o emprego de substância inflamável ou explosiva.';
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
    String resposta2 =
        'Não foram observados vestígios que indiquem dano contra o patrimônio da União, Estado, Município, empresa concessionária de serviços públicos ou sociedade de economia mista.';
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
    String resposta3 =
        'Não foram observados vestígios que permitam aferir a existência de prejuízo considerável para a vítima.';
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
    String resposta4 =
        'Não foram observados vestígios que permitam identificar o instrumento e/ou substância empregados no evento.';
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
    String resposta5 =
        'O exame do local não possibilitou a identificação de vestígios conclusivos.';
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
    String resposta6 =
        'Não foram observados elementos que permitam estimar o dano causado ou o valor dos prejuízos.';
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
    String resposta7 =
        'Não foram observados vestígios que permitam identificar o número de pessoas que participaram do evento.';
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
    String resposta8 =
        'Não foram observados vestígios que indiquem a autoria do delito.';
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
    String resposta9 =
        'Não foram observados vestígios que permitam identificar a dinâmica do evento.';
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
    final examesSolicitados =
        (ficha.examesComplementares ?? const <ExameComplementarModel>[])
            .where(
              (e) =>
                  e.solicitado && e.tipo != TipoExameComplementar.necroscopico,
            )
            .toList();

    buffer.writeln(_gerarTituloSecao('7. EXAMES COMPLEMENTARES'));

    int proximaSubsecao = 1;
    buffer.writeln(_gerarTituloSubSecao('7.$proximaSubsecao Exame Cadavérico'));
    proximaSubsecao++;

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

    for (final exame in examesSolicitados) {
      buffer.writeln(_gerarParagrafoVazio());
      buffer.writeln(
        _gerarTituloSubSecao(
          '7.$proximaSubsecao ${_tituloExameComplementar(exame)}',
        ),
      );
      proximaSubsecao++;
      buffer.writeln(
        _gerarParagrafoHistorico(_textoExameComplementarSolicitado(exame)),
      );
    }

    return buffer.toString();
  }

  String _tituloExameComplementar(ExameComplementarModel exame) {
    final nome = exame.nomeExibicao.trim();
    if (nome.isEmpty) return 'Exame Complementar';
    return nome[0].toUpperCase() + nome.substring(1);
  }

  String _textoExameComplementarSolicitado(ExameComplementarModel exame) {
    final nomeExame = exame.nomeExibicao.trim();
    final observacao = exame.observacao?.trim();

    var texto = 'Foi solicitado $nomeExame.';

    if (observacao != null && observacao.isNotEmpty) {
      texto += ' Observação: $observacao.';
    }

    return texto;
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

    buffer.writeln(
      _gerarParagrafoHistorico(
        'A interpretação técnica dos vestígios observados foi realizada de forma integrada, considerando a coerência espacial, temporal e material entre os elementos documentados no exame pericial.',
      ),
    );

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
        <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
        <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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

  String _gerarFootnotesXml({
    bool isTransito = false,
    bool isVistoriaVeiculo = false,
  }) {
    const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

    String footnoteItem(int id, String texto, {String estiloExtra = ''}) {
      return '''  <w:footnote w:id="$id">
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
          $estiloExtra
        </w:rPr>
        <w:t>${_escapeXml(texto)}</w:t>
      </w:r>
    </w:p>
  </w:footnote>''';
    }

    final items = <String>[];
    if (isVistoriaVeiculo) {
      const textoNiv =
          'O presente Exame não tem como objetivo vistoriar o Número de Identificação Veicular (NIV), tampouco constatar possíveis adulterações efetuadas ou não nos locais de gravação dos NIVs do(s) veículo(s) em questão. Tal exame (químico-metalográfico), caso a Autoridade Policial entenda necessário, deverá ser realizado por equipe especializada de Peritos Criminais da Divisão de Perícias de Identificação Veicular - DPIV/DPCE/ICLR ou da Seção de Identificação Veicular - SIV/DPCL/DC da Coordenadoria Regional de Polícia, conforme o caso.';
      items.add(footnoteItem(1, textoNiv));
      items.add(footnoteItem(2, textoNiv));
    } else if (isTransito) {
      items.add(
        footnoteItem(
          1,
          'Informações obtidas a partir das placas de identificação instaladas nos veículos. O presente exame não teve como objetivo vistoriar ou constatar adulterações nos locais de gravação do número de identificação veicular (NIV).',
        ),
      );
    } else {
      items.add(
        footnoteItem(
          1,
          'Feca Cult One Step Teste é um teste imunocromatográfico rápido que detecta qualitativamente e especificamente a hemoglobina humana (hHb). O teste é sensível a concentrações de hHb iguais ou superiores a 40ng/mL, mas, em alguns casos, pode detectar resultados positivos em concentrações menores.',
          estiloExtra: '<w:i/>',
        ),
      );
    }

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
${items.join('\n')}
</w:footnotes>''';
  }

  String _gerarParagrafoLista(String texto) {
    // Parágrafo para lista com recuo pendente (hanging indent)
    // A primeira linha fica mais à esquerda, linhas seguintes alinhadas com o texto após "a) "
    return '''    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
        <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
        <w:spacing w:after="0" w:line="$_lineHeight125" w:lineRule="auto"/>
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
      final legendaDescricao =
          (legendas != null && i < legendas.length) ? legendas[i] : null;
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

  String _gerarAnexoAnalisesManchasSangue(FichaCompletaModel ficha) {
    final buffer = StringBuffer();

    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:br w:type="page"/>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    buffer.writeln(
      _gerarTituloPrincipal('ANEXO - ANÁLISES ASSISTIVAS DE MANCHAS DE SANGUE'),
    );
    buffer.writeln(_gerarLinhaEmBranco());

    for (var i = 0; i < ficha.analisesManchasSangue.length; i++) {
      final analise = ficha.analisesManchasSangue[i];
      final numero = (i + 1).toString().padLeft(2, '0');
      final data = DateFormat('dd/MM/yyyy HH:mm').format(analise.createdAt);

      buffer.writeln(
        _gerarParagrafoHistoricoNegrito('Análise assistiva $numero'),
      );
      buffer.writeln(_gerarParagrafoHistorico('Data de geração: $data.'));
      if ((analise.ambiente ?? '').trim().isNotEmpty) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Ambiente vinculado: ${analise.ambiente!.trim()}.',
          ),
        );
      }
      if (analise.contextText.trim().isNotEmpty) {
        buffer.writeln(
          _gerarParagrafoHistorico('Contexto: ${analise.contextText.trim()}'),
        );
      }
      if (analise.surfaceType.trim().isNotEmpty) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Superfície informada: ${analise.surfaceType.trim()}.',
          ),
        );
      }
      if (analise.planeOrientation.trim().isNotEmpty) {
        buffer.writeln(
          _gerarParagrafoHistorico(
            'Orientação do plano: ${analise.planeOrientation.trim()}.',
          ),
        );
      }
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Escala métrica visível: ${analise.scalePresent ? 'sim' : 'não'}.',
        ),
      );
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Imagens consideradas: ${analise.overviewImagePaths.length} ampla(s)/contextual(is) e ${analise.closeUpImagePaths.length} aproximada(s).',
        ),
      );
      buffer.writeln(_gerarParagrafoHistoricoNegrito('Resultado assistivo'));
      for (final line in analise.resultText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          buffer.writeln(_gerarLinhaEmBranco());
        } else {
          buffer.writeln(_gerarParagrafoHistorico(trimmed));
        }
      }
      buffer.writeln(
        _gerarParagrafoHistorico(
          'Observação: o conteúdo acima possui caráter assistivo e deve ser validado pelo perito responsável antes de qualquer aproveitamento técnico.',
        ),
      );

      if (i < ficha.analisesManchasSangue.length - 1) {
        buffer.writeln(_gerarLinhaEmBranco());
      }
    }

    return buffer.toString();
  }

  /// Legenda (Imagem 01 + texto) e imagem do mapa do local para a seção 4.1.
  /// Fonte 10 (20 half-points), centralizado, espaçamento simples.
  String _gerarLegendaEImagemMapa(
    int rId, {
    String legenda =
        'Imagem 01: Imagem de Satélite do Local do Fato – Fonte: Google Maps.',
  }) {
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
