import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cadaver_model.dart';
import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/ficha_service.dart';
import '../services/file_open_service.dart';
import '../services/laudo_generator_service.dart';
import '../services/perito_service.dart';
import '../services/photo_backup_service.dart';
import '../services/word_generator_service.dart';
import 'atropelamento_calculo_screen.dart';
import 'condicoes_observacoes_screen.dart';
import 'crime_transito_condicoes_screen.dart';
import 'crime_transito_levantamento_screen.dart';
import 'dano_screen.dart';
import 'detalhes_local_screen.dart';
import 'dinamica_fato_transito_screen.dart';
import 'equipes_policiais_screen.dart';
import 'evidencias_furto_screen.dart';
import 'historico_screen.dart';
import 'isolamento_screen.dart';
import 'lista_cadaveres_screen.dart';
import 'lista_envolvidos_transito_screen.dart';
import 'lista_veiculos_screen.dart';
import 'local_screen.dart';
import 'modus_operandi_screen.dart';
import 'preenchimento_ficha_screen.dart';
import 'preservacao_screen.dart';
import 'selecao_equipe_screen.dart';

class ListaFichasScreen extends StatefulWidget {
  const ListaFichasScreen({super.key});

  @override
  State<ListaFichasScreen> createState() => _ListaFichasScreenState();
}

class _ListaFichasScreenState extends State<ListaFichasScreen> {
  final _fichaService = FichaService();
  final _wordGeneratorService = WordGeneratorService();
  List<FichaCompletaModel> _fichas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarFichas();
  }

  Future<void> _carregarFichas() async {
    setState(() {
      _carregando = true;
    });

    try {
      final fichas = await _fichaService.listarFichas();
      if (mounted) {
        setState(() {
          _fichas = fichas;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar fichas: $e')));
      }
    }
  }

  String _textoLegendaVestigioLocal(VestigioLocalModel vestigio) {
    final ambiente = vestigio.ambiente?.trim() ?? '';
    final nome = vestigio.nome?.trim() ?? '';
    if (nome.isNotEmpty) {
      return ambiente.isEmpty ? nome : '$nome - ambiente: $ambiente';
    }

    final descricao = vestigio.descricao?.trim() ?? '';
    if (descricao.isNotEmpty) {
      return ambiente.isEmpty ? descricao : '$descricao - ambiente: $ambiente';
    }

    return ambiente.isEmpty
        ? 'vestígio registrado'
        : 'vestígio registrado - ambiente: $ambiente';
  }

  String _textoLegendaVestigioVeiculo(VestigioVeiculoModel vestigio) {
    final nome = vestigio.nome?.trim() ?? '';
    if (nome.isNotEmpty) return nome;

    final descricao = vestigio.descricao?.trim() ?? '';
    if (descricao.isNotEmpty) return descricao;

    final localizacao = vestigio.localizacao?.trim() ?? '';
    if (localizacao.isNotEmpty) return localizacao;

    return 'vestígio registrado';
  }

  String _normalizarLegendaFoto(String texto, {int maxLength = 80}) {
    final trimmed = texto.trim();
    final legenda = trimmed.length > maxLength
        ? '${trimmed.substring(0, maxLength)}...'
        : trimmed;
    return legenda.endsWith('.') ? legenda : '$legenda.';
  }

  Future<void> _abrirFicha(FichaCompletaModel ficha) async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreenchimentoFichaScreen(
          tipoOcorrencia: ficha.tipoOcorrencia,
          dadosSolicitacao: ficha.dadosSolicitacao,
          fichaExistente: ficha,
        ),
      ),
    );

    if (resultado == true) {
      _carregarFichas();
    }
  }

  Future<void> _mostrarMenuNavegacao(FichaCompletaModel ficha) async {
    final telaEscolhida = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navegar para Tela'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('1. Solicitação'),
                onTap: () => Navigator.of(context).pop('solicitacao'),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('2. Equipe de Perícia'),
                onTap: () => Navigator.of(context).pop('equipe'),
              ),
              ListTile(
                leading: const Icon(Icons.local_police),
                title: const Text('3. Equipes Policiais'),
                onTap: () => Navigator.of(context).pop('equipes_policiais'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('4. Local - Coordenadas GPS'),
                onTap: () => Navigator.of(context).pop('local'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('5. Histórico'),
                onTap: () => Navigator.of(context).pop('historico'),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('6. Isolamento'),
                onTap: () => Navigator.of(context).pop('isolamento'),
              ),
              ListTile(
                leading: const Icon(Icons.shield),
                title: const Text('7. Preservação'),
                onTap: () => Navigator.of(context).pop('preservacao'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('8. Condições Ambientais'),
                onTap: () => Navigator.of(context).pop('condicoes'),
              ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
                  ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
                  ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('9. Local - Detalhes do Local'),
                  onTap: () => Navigator.of(context).pop('local_furto'),
                ),
              ],
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal)
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('10. Evidências'),
                  onTap: () => Navigator.of(context).pop('evidencias'),
                ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
                  ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) ...[
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('10. Veículos'),
                  onTap: () => Navigator.of(context).pop('veiculos'),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('11. Cadáveres'),
                  onTap: () => Navigator.of(context).pop('cadaveres'),
                ),
              ],
              if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) ...[
                ListTile(
                  leading: const Icon(Icons.traffic),
                  title: const Text('9. Condições da Via'),
                  onTap: () => Navigator.of(context).pop('condicoes_transito'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('10. Levantamento - Via'),
                  onTap: () =>
                      Navigator.of(context).pop('levantamento_transito'),
                ),
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('11. Veículos'),
                  onTap: () => Navigator.of(context).pop('veiculos'),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('11b. Vítima em Óbito'),
                  onTap: () => Navigator.of(context).pop('cadaveres'),
                ),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: const Text('12. Envolvidos'),
                  onTap: () => Navigator.of(context).pop('envolvidos_transito'),
                ),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('13. Cálculo de velocidade'),
                  onTap: () => Navigator.of(context).pop('natureza_ocorrencia'),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text('14. Dinâmica do Fato'),
                  onTap: () => Navigator.of(context).pop('dinamica_fato'),
                ),
              ],
              if (ficha.tipoOcorrencia != TipoOcorrencia.crimeTransito)
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text('Modus Operandi'),
                  onTap: () => Navigator.of(context).pop('modus_operandi'),
                ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal)
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('13. Dano'),
                  onTap: () => Navigator.of(context).pop('dano'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (telaEscolhida != null && mounted) {
      await _navegarParaTela(ficha, telaEscolhida);
    }
  }

  Future<void> _gerarDocumentoWord(FichaCompletaModel ficha) async {
    if (!mounted) return;

    // Verificar se o template existe antes de tentar gerar
    final perito = await PeritoService().obterPerito();
    if (perito == null || perito.caminhoTemplate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template não configurado. Vá em Configurações > Editar Perito e selecione o template.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final templateFile = File(perito.caminhoTemplate!);
    if (!await templateFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arquivo template não encontrado. Vá em Configurações > Editar Perito e selecione o template novamente.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Mostrar diálogo de carregamento
    if (!mounted) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gerando documento Word...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final arquivo = await _wordGeneratorService.gerarDocumentoWord(ficha);

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      // Tentar abrir o arquivo gerado
      await _abrirOuCompartilharArquivo(arquivo, 'Ficha');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar documento: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _gerarQuadroPosicionamento(FichaCompletaModel ficha) async {
    if (!mounted) return;

    final perito = await PeritoService().obterPerito();
    if (perito == null || perito.caminhoTemplate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template não configurado. Vá em Configurações > Editar Perito e selecione o template.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final templateFile = File(perito.caminhoTemplate!);
    if (!await templateFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arquivo template não encontrado. Vá em Configurações > Editar Perito e selecione o template novamente.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gerando quadro de posicionamento...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final arquivo = await _wordGeneratorService
          .gerarQuadroPosicionamentoVestigios(ficha);

      if (!mounted) return;
      Navigator.of(context).pop();
      await _abrirOuCompartilharArquivo(arquivo, 'Quadro de posicionamento');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar quadro de posicionamento: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _gerarDocumentoLaudo(FichaCompletaModel ficha) async {
    // Verificar se o perito está cadastrado
    final peritoService = PeritoService();
    final perito = await peritoService.obterPerito();

    if (perito == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre o perito nas configurações antes de gerar o laudo',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar se o template existe
    final templatePath = perito.caminhoTemplate;
    if (templatePath == null || templatePath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um template nas configurações do perito'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final templateFile = File(templatePath);
    if (!await templateFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template não encontrado. Selecione novamente nas configurações.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fichaService = FichaService();
    var fichaAtual = await fichaService.obterFicha(ficha.id) ?? ficha;

    List<File>? fotosSelecionadas;
    List<String>? legendasFotos;
    final isTransito =
        fichaAtual.tipoOcorrencia == TipoOcorrencia.crimeTransito;
    final useLevantamentoVestigios =
        fichaAtual.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
        fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
        fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
        isTransito;

    if (useLevantamentoVestigios) {
      final lf = fichaAtual.localFurto;
      final orderedPaths = <String>[];

      final dir = await getApplicationDocumentsDirectory();
      final basePath = dir.path;

      int vistaAmplaOk = 0;
      int vestigioFotosOk = 0;
      int totalVestigios = 0;
      int vestigiosSemFoto = 0;
      final pathMap = <String, String>{}; // original → resolved
      final pathToLegenda =
          <String, String>{}; // path (resolved) → legenda para anexo

      final fotosVistaAmpla = <String>[
        ...?lf?.fotosVistaAmplaMediatoPaths,
        ...?lf?.fotosVistaAmplaImediatoPaths,
      ];
      if (fotosVistaAmpla.isEmpty) {
        fotosVistaAmpla.addAll(lf?.fotosVistaAmplaPaths ?? const []);
      }

      for (final p in fotosVistaAmpla) {
        final resolved = await _resolverPath(p, basePath);
        if (resolved != null) {
          orderedPaths.add(resolved);
          pathMap[p] = resolved;
          final isImediato = (lf?.fotosVistaAmplaImediatoPaths ?? []).contains(
            p,
          );
          pathToLegenda[resolved] = isImediato
              ? 'Vista ampla do local imediato.'
              : 'Vista ampla do local mediato.';
          vistaAmplaOk++;
        }
      }

      for (final entry
          in (lf?.fotosVistaAmplaAmbientesImediato ?? const {}).entries) {
        final ambiente = entry.key;
        for (final p in entry.value) {
          final resolved = await _resolverPath(p, basePath);
          if (resolved != null) {
            orderedPaths.add(resolved);
            pathMap[p] = resolved;
            pathToLegenda[resolved] =
                'Vista ampla do ambiente ${ambiente.toLowerCase()} (local imediato).';
            vistaAmplaOk++;
          }
        }
      }

      for (final p in lf?.fotosSinaisArrombamentoPaths ?? const <String>[]) {
        final resolved = await _resolverPath(p, basePath);
        if (resolved != null) {
          orderedPaths.add(resolved);
          pathMap[p] = resolved;
          pathToLegenda[resolved] =
              'Sinais de arrombamento observados no local.';
        }
      }

      Future<void> adicionarFotosVestigios(
        List<VestigioLocalModel>? lista,
      ) async {
        if (lista == null) return;
        for (final v in lista) {
          totalVestigios++;
          if (v.fotosVinculadasPaths.isEmpty) {
            vestigiosSemFoto++;
            continue;
          }
          final legenda = _normalizarLegendaFoto(_textoLegendaVestigioLocal(v));
          for (final p in v.fotosVinculadasPaths) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] = legenda;
              vestigioFotosOk++;
            }
          }
        }
      }

      await adicionarFotosVestigios(lf?.vestigiosMediato);
      await adicionarFotosVestigios(lf?.vestigiosImediato);
      await adicionarFotosVestigios(lf?.vestigiosRelacionado);

      // Fotos do levantamento da via (Crime de Trânsito)
      if (isTransito && fichaAtual.crimeTransitoLevantamento != null) {
        final lev = fichaAtual.crimeTransitoLevantamento!;

        for (final f in lev.marcoZero?.fotos ?? []) {
          final resolved = await _resolverPath(f, basePath);
          if (resolved != null) {
            orderedPaths.add(resolved);
            pathMap[f] = resolved;
            pathToLegenda[resolved] = 'Marco zero do levantamento.';
            vistaAmplaOk++;
          }
        }

        for (final f in lev.fotosLocalEncontrado?.fotos ?? []) {
          final resolved = await _resolverPath(f.path, basePath);
          if (resolved != null) {
            orderedPaths.add(resolved);
            pathMap[f.path] = resolved;
            pathToLegenda[resolved] =
                f.legendaIndividual ??
                lev.fotosLocalEncontrado?.legendaGrupo ??
                'Vista do local do evento.';
            vistaAmplaOk++;
          }
        }

        for (final grupo in lev.fotosContextuais) {
          for (final f in grupo.fotos) {
            final resolved = await _resolverPath(f.path, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[f.path] = resolved;
              pathToLegenda[resolved] =
                  f.legendaIndividual ?? grupo.legendaGrupo;
            }
          }
        }

        for (final f in lev.fotosSinalizacao?.fotos ?? []) {
          final resolved = await _resolverPath(f.path, basePath);
          if (resolved != null) {
            orderedPaths.add(resolved);
            pathMap[f.path] = resolved;
            pathToLegenda[resolved] =
                f.legendaIndividual ??
                lev.fotosSinalizacao?.legendaGrupo ??
                'Sinalização viária.';
          }
        }

        for (final v in lev.vestigios) {
          for (final f in v.fotos) {
            final resolved = await _resolverPath(f.path, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[f.path] = resolved;
              pathToLegenda[resolved] =
                  f.legendaIndividual ?? 'Vestígio na via.';
              vestigioFotosOk++;
            }
          }
        }

        for (final f in lev.fotosComplementares?.fotos ?? []) {
          final resolved = await _resolverPath(f.path, basePath);
          if (resolved != null) {
            orderedPaths.add(resolved);
            pathMap[f.path] = resolved;
            pathToLegenda[resolved] =
                f.legendaIndividual ??
                lev.fotosComplementares?.legendaGrupo ??
                'Foto complementar.';
          }
        }
      }

      // Fotos dos cadáveres (CVLI / Morte a Esclarecer): vista ambiente, posição, hipóstase, tatuagens, lesões
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) &&
          fichaAtual.cadaveres != null) {
        for (final c in fichaAtual.cadaveres!) {
          for (final p in c.fotosVistaCadaversAmbiente) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Vista do cadáver no ambiente (cadáver ${c.numero}).';
            }
          }
          for (final p in c.fotosPosicaoEncontrada) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Cadáver na posição em que foi encontrado (cadáver ${c.numero}).';
            }
          }
          for (final p in c.fotosHipostaseSecrecoes) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Manchas de hipóstase e secreções (cadáver ${c.numero}).';
            }
          }
          for (final p in c.fotosTatuagens) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Tatuagens e marcas corporais (cadáver ${c.numero}).';
            }
          }
          for (final lesao in c.lesoes ?? []) {
            final descResumo = lesao.textoLegendaFoto;
            final comContexto = 'Lesão no cadáver ${c.numero}: $descResumo';
            final legendaTexto = comContexto.length > 60
                ? '${comContexto.substring(0, 60)}...'
                : comContexto;
            final legenda =
                '$legendaTexto${legendaTexto.endsWith('.') ? '' : '.'}';
            for (final p in lesao.fotosPaths) {
              final resolved = await _resolverPath(p, basePath);
              if (resolved != null) {
                orderedPaths.add(resolved);
                pathMap[p] = resolved;
                pathToLegenda[resolved] = legenda;
              }
            }
          }
          // Fotos de ausência de lesões de defesa (sempre por último nas lesões)
          for (final p in c.fotosLesoesDefesa) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] = c.ausenciaLesoesDefesa
                  ? 'Ausência de lesões de defesa (cadáver ${c.numero}).'
                  : 'Lesões de defesa (cadáver ${c.numero}).';
            }
          }

          for (final veste in c.vestes ?? []) {
            for (final p in veste.fotosPaths) {
              final resolved = await _resolverPath(p, basePath);
              if (resolved != null) {
                orderedPaths.add(resolved);
                pathMap[p] = resolved;
                pathToLegenda[resolved] =
                    'Veste ${veste.numero} do cadáver ${c.numero}.';
              }
            }
          }
        }
      }

      // Fotos dos veículos (CVLI / Morte a Esclarecer / Crime de Trânsito)
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.crimeTransito) &&
          fichaAtual.veiculos != null) {
        for (final v in fichaAtual.veiculos!) {
          for (final p in v.fotosVistaVeiculoAmbiente) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Vista do veículo no ambiente (veículo ${v.numero}).';
            }
          }
          for (final vest in v.vestigios ?? []) {
            final descResumo = _textoLegendaVestigioVeiculo(vest);
            final legendaTexto = descResumo.length > 60
                ? '${descResumo.substring(0, 60)}...'
                : descResumo;
            final legenda =
                'Vestígio no veículo ${v.numero}: $legendaTexto${legendaTexto.endsWith('.') ? '' : '.'}';
            for (final p in vest.fotosPaths) {
              final resolved = await _resolverPath(p, basePath);
              if (resolved != null) {
                orderedPaths.add(resolved);
                pathMap[p] = resolved;
                pathToLegenda[resolved] = legenda;
              }
            }
          }
        }
      }

      // Fotos dos envolvidos (Crime de Trânsito): cenário, posição, lesões/pertences
      if (fichaAtual.tipoOcorrencia == TipoOcorrencia.crimeTransito &&
          fichaAtual.envolvidosTransito != null) {
        for (final env in fichaAtual.envolvidosTransito!) {
          final id = env.nome?.isNotEmpty == true
              ? env.nome!
              : 'envolvido ${fichaAtual.envolvidosTransito!.indexOf(env) + 1}';
          for (final p in env.fotosVistaAmplaCenario ?? []) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] = 'Vista ampla do cenário ($id).';
            }
          }
          for (final p in env.fotosVistaAmplaPosicaoEncontrado ?? []) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] =
                  'Vista ampla na posição em que foi encontrado ($id).';
            }
          }
          for (final p in env.fotosLesoesPertences ?? []) {
            final resolved = await _resolverPath(p, basePath);
            if (resolved != null) {
              orderedPaths.add(resolved);
              pathMap[p] = resolved;
              pathToLegenda[resolved] = 'Lesões e pertences ($id).';
            }
          }
        }
      }

      if (vestigioFotosOk == 0 && fichaAtual.fotosLevantamento.isNotEmpty) {
        final setOrdered = orderedPaths.toSet();
        for (final p in fichaAtual.fotosLevantamento) {
          if (setOrdered.contains(p)) continue;
          final resolved = await _resolverPath(p, basePath);
          if (resolved != null && !setOrdered.contains(resolved)) {
            orderedPaths.add(resolved);
            setOrdered.add(resolved);
            pathToLegenda[resolved] = 'Foto do levantamento.';
          }
        }
      }

      if (orderedPaths.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Adicione a foto da vista ampla do local (tela Local - Detalhes) e as fotos de cada vestígio ao registrá-los.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      if (!mounted) return;
      final detalhes = StringBuffer();
      detalhes.writeln('Vista ampla: $vistaAmplaOk foto(s)');
      detalhes.writeln('Vestígios: $totalVestigios (fotos: $vestigioFotosOk)');
      if (vestigiosSemFoto > 0) {
        detalhes.writeln('(!) $vestigiosSemFoto vestígio(s) sem foto');
      }
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) &&
          fichaAtual.cadaveres != null &&
          fichaAtual.cadaveres!.isNotEmpty) {
        detalhes.writeln(
          'Inclui fotos dos cadáveres (exames e lesões) no anexo.',
        );
      }
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.crimeTransito) &&
          fichaAtual.veiculos != null &&
          fichaAtual.veiculos!.isNotEmpty) {
        detalhes.writeln(
          'Inclui fotos dos veículos (cena e vestígios) no anexo.',
        );
      }
      detalhes.write('Total no levantamento: ${orderedPaths.length} foto(s)');

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Levantamento Fotográfico'),
          content: Text(detalhes.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Gerar laudo'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;

      // Opcional: reordenar fotos (vista ampla deve ficar primeiro)
      final pathsAtuais = List<String>.from(orderedPaths);
      final novosPaths = await _gerenciarFotosLevantamento(
        pathsAtuais,
        basePath,
      );
      if (!mounted) return;
      final pathsFinais = novosPaths ?? pathsAtuais;

      VestigioLocalModel comNumeros(VestigioLocalModel v) {
        final nums = <int>[];
        for (final p in v.fotosVinculadasPaths) {
          final resolved = pathMap[p] ?? p;
          final idx = pathsFinais.indexOf(resolved);
          if (idx >= 0) nums.add(idx + 1);
        }
        nums.sort();
        return v.copyWith(numerosFotografias: nums);
      }

      final vestigiosMediato = (lf?.vestigiosMediato ?? [])
          .map(comNumeros)
          .toList();
      final vestigiosImediato = (lf?.vestigiosImediato ?? [])
          .map(comNumeros)
          .toList();
      final vestigiosRelacionado = (lf?.vestigiosRelacionado ?? [])
          .map(comNumeros)
          .toList();

      final localFurtoParaLaudo = lf?.copyWith(
        vestigiosMediato: vestigiosMediato,
        vestigiosImediato: vestigiosImediato,
        vestigiosRelacionado: vestigiosRelacionado,
      );

      // Para CVLI / Morte a Esclarecer: preencher numerosFotografias em cada lesão para citação no laudo
      List<CadaverModel>? cadaveresParaLaudo;
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) &&
          fichaAtual.cadaveres != null) {
        cadaveresParaLaudo = fichaAtual.cadaveres!.map((c) {
          final lesoesComNumeros = (c.lesoes ?? []).map((lesao) {
            final nums = <int>[];
            for (final p in lesao.fotosPaths) {
              final resolved = pathMap[p] ?? p;
              final idx = pathsFinais.indexOf(resolved);
              if (idx >= 0) nums.add(idx + 1);
            }
            nums.sort();
            return lesao.copyWith(
              numerosFotografias: nums.isEmpty ? null : nums,
            );
          }).toList();
          // Números das fotos de ausência de lesões de defesa
          final numsDefesa = <int>[];
          for (final p in c.fotosLesoesDefesa) {
            final resolved = pathMap[p] ?? p;
            final idx = pathsFinais.indexOf(resolved);
            if (idx >= 0) numsDefesa.add(idx + 1);
          }
          numsDefesa.sort();
          return c.copyWith(
            lesoes: lesoesComNumeros,
            numerosFotosLesoesDefesa: numsDefesa.isEmpty ? null : numsDefesa,
          );
        }).toList();
      }

      // Para CVLI / Morte a Esclarecer / Crime de Trânsito: preencher numerosFotografias em cada vestígio de veículo
      List<VeiculoModel>? veiculosParaLaudo;
      if ((fichaAtual.tipoOcorrencia == TipoOcorrencia.cvli ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
              fichaAtual.tipoOcorrencia == TipoOcorrencia.crimeTransito) &&
          fichaAtual.veiculos != null) {
        veiculosParaLaudo = fichaAtual.veiculos!.map((v) {
          final vestigiosComNumeros = (v.vestigios ?? []).map((vest) {
            final nums = <int>[];
            for (final p in vest.fotosPaths) {
              final resolved = pathMap[p] ?? p;
              final idx = pathsFinais.indexOf(resolved);
              if (idx >= 0) nums.add(idx + 1);
            }
            nums.sort();
            return vest.copyWith(
              numerosFotografias: nums.isEmpty ? null : nums,
            );
          }).toList();
          return v.copyWith(vestigios: vestigiosComNumeros);
        }).toList();
      }

      fichaAtual = fichaAtual.copyWith(
        localFurto: localFurtoParaLaudo ?? fichaAtual.localFurto,
        cadaveres: cadaveresParaLaudo ?? fichaAtual.cadaveres,
        veiculos: veiculosParaLaudo ?? fichaAtual.veiculos,
      );
      fotosSelecionadas = pathsFinais.isEmpty
          ? null
          : pathsFinais.map((p) => File(p)).toList();
      legendasFotos = pathsFinais.isEmpty
          ? null
          : pathsFinais.map((p) => pathToLegenda[p] ?? '').toList();
    } else {
      // Outros tipos de ocorrência: usar fotos já salvas na ficha (se houver)
      final fotosExistentes = <String>[];
      for (final p in fichaAtual.fotosLevantamento) {
        final f = File(p);
        if (await f.exists()) fotosExistentes.add(p);
      }
      if (fotosExistentes.length != fichaAtual.fotosLevantamento.length) {
        await fichaService.salvarFicha(
          fichaAtual.copyWith(fotosLevantamento: fotosExistentes),
        );
      }
      if (fotosExistentes.isNotEmpty) {
        if (!mounted) return;
        final usar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Levantamento Fotográfico'),
            content: Text(
              'Esta ficha possui ${fotosExistentes.length} foto(s). Incluir no laudo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Não'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sim'),
              ),
            ],
          ),
        );
        if (usar == true) {
          fotosSelecionadas = fotosExistentes.map((p) => File(p)).toList();
        }
      }
    }

    if (!mounted) return;

    // Mostrar diálogo de carregamento
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gerando laudo...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final laudoService = LaudoGeneratorService();
      final arquivo = await laudoService.gerarLaudo(
        ficha: fichaAtual,
        perito: perito,
        templatePath: templatePath,
        fotos: fotosSelecionadas,
        legendasFotos: legendasFotos,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      // Tentar abrir o arquivo gerado
      await _abrirOuCompartilharArquivo(arquivo, 'Laudo');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar laudo: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Tenta abrir o arquivo; se falhar, oferece compartilhar
  Future<void> _abrirOuCompartilharArquivo(File arquivo, String tipo) async {
    final opened = await FileOpenService.open(arquivo.path);

    if (opened) {
      // Abriu com sucesso
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tipo gerado com sucesso!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Não conseguiu abrir - mostrar opções
      if (!mounted) return;
      final acao = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$tipo Gerado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('O documento foi gerado com sucesso!'),
              const SizedBox(height: 12),
              Text(
                'Não foi possível abrir automaticamente.\n\nArquivo: ${arquivo.path.split('/').last}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'fechar'),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'compartilhar'),
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar'),
            ),
          ],
        ),
      );

      if (acao == 'compartilhar' && mounted) {
        final origemCompartilhamento = _obterSharePositionOrigin();
        await Share.shareXFiles(
          [XFile(arquivo.path)],
          text: '$tipo - Laudo Tech',
          sharePositionOrigin: origemCompartilhamento,
        );
      }
    }
  }

  Rect _obterSharePositionOrigin() {
    final overlayBox =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlayBox != null &&
        overlayBox.hasSize &&
        overlayBox.size.width > 0 &&
        overlayBox.size.height > 0) {
      return Offset.zero & overlayBox.size;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null &&
        mediaQuery.size.width > 0 &&
        mediaQuery.size.height > 0) {
      return Rect.fromCenter(
        center: mediaQuery.size.center(Offset.zero),
        width: 1,
        height: 1,
      );
    }

    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  // Mantido para eventual uso em outros fluxos (ex.: adicionar fotos em outros tipos de ocorrência).
  // ignore: unused_element
  Future<List<File>?> _selecionarFotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final fotos = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (!mounted) return fotos;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fotos.length} foto(s) selecionada(s)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      return fotos;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar fotos: $e'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }
  }

  // ignore: unused_element
  Future<List<String>> _persistirFotosDaFicha(
    String fichaId,
    List<File> fotos,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory('${dir.path}/levantamento_fotografico/$fichaId');
    if (!await pasta.exists()) {
      await pasta.create(recursive: true);
    }

    final paths = <String>[];
    for (final foto in fotos) {
      if (!await foto.exists()) continue;
      final ext = foto.path.split('.').last.toLowerCase();
      final nome = 'foto_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final destino = File('${pasta.path}/$nome');
      await foto.copy(destino.path);
      await PhotoBackupService.saveToGallery(destino.path);
      paths.add(destino.path);
    }
    return paths;
  }

  /// Tenta resolver um caminho de foto salvo. Se o caminho original existe, retorna-o.
  /// Caso contrário (ex.: UUID do container iOS mudou), tenta reconstruir usando
  /// o diretório de documentos atual + parte relativa do levantamento.
  Future<String?> _resolverPath(String path, String currentBasePath) async {
    if (await File(path).exists()) return path;
    const markers = ['levantamento_fotografico/', 'levantamento_transito/'];
    for (final marker in markers) {
      final idx = path.indexOf(marker);
      if (idx >= 0) {
        final relative = path.substring(idx);
        final resolved = '$currentBasePath/$relative';
        if (await File(resolved).exists()) return resolved;
      }
    }
    return null;
  }

  Future<List<String>?> _gerenciarFotosLevantamento(
    List<String> paths,
    String basePath,
  ) async {
    if (paths.isEmpty) return paths;

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _GerenciarFotosLevantamentoSheet(
        pathsIniciais: paths,
        basePath: basePath,
        resolver: (p) => _resolverPath(p, basePath),
      ),
    );
  }

  Future<void> _navegarParaTela(FichaCompletaModel ficha, String tela) async {
    Widget? telaDestino;

    switch (tela) {
      case 'solicitacao':
        telaDestino = PreenchimentoFichaScreen(
          tipoOcorrencia: ficha.tipoOcorrencia,
          dadosSolicitacao: ficha.dadosSolicitacao,
          fichaExistente: ficha,
        );
        break;
      case 'equipe':
        telaDestino = SelecaoEquipeScreen(ficha: ficha);
        break;
      case 'equipes_policiais':
        telaDestino = EquipesPoliciaisScreen(ficha: ficha);
        break;
      case 'local':
        telaDestino = LocalScreen(ficha: ficha);
        break;
      case 'historico':
        telaDestino = HistoricoScreen(ficha: ficha);
        break;
      case 'isolamento':
        telaDestino = IsolamentoScreen(ficha: ficha);
        break;
      case 'preservacao':
        telaDestino = PreservacaoScreen(ficha: ficha);
        break;
      case 'condicoes':
        telaDestino = CondicoesObservacoesScreen(ficha: ficha);
        break;
      case 'condicoes_transito':
        if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = CrimeTransitoCondicoesScreen(ficha: ficha);
        }
        break;
      case 'levantamento_transito':
        if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = CrimeTransitoLevantamentoScreen(ficha: ficha);
        }
        break;
      case 'local_furto':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
            ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
            ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
          telaDestino = LocalFurtoScreen(ficha: ficha);
        }
        break;
      case 'evidencias':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = EvidenciasFurtoScreen(ficha: ficha);
        }
        break;
      case 'veiculos':
        if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
            ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
            ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = ListaVeiculosScreen(ficha: ficha);
        }
        break;
      case 'cadaveres':
        if (ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
            ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer ||
            ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = ListaCadaveresScreen(ficha: ficha);
        }
        break;
      case 'modus_operandi':
        if (ficha.tipoOcorrencia != TipoOcorrencia.crimeTransito) {
          telaDestino = ModusOperandiScreen(ficha: ficha);
        }
        break;
      case 'dano':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = DanoScreen(ficha: ficha);
        }
        break;
      case 'envolvidos_transito':
        if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = ListaEnvolvidosTransitoScreen(ficha: ficha);
        }
        break;
      case 'natureza_ocorrencia':
        if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          final formas =
              ficha.crimeTransitoLevantamento?.formasInteracao ??
              ficha.crimeTransitoNatureza?.formasInteracao ??
              [];
          telaDestino =
              formas.contains(CrimeTransitoFormaInteracao.atropelamento)
              ? AtropelamentoCalculoScreen(ficha: ficha)
              : DinamicaFatoTransitoScreen(ficha: ficha);
        }
        break;
      case 'dinamica_fato':
        if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito) {
          telaDestino = DinamicaFatoTransitoScreen(ficha: ficha);
        }
        break;
    }

    if (telaDestino != null) {
      final resultado = await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => telaDestino!));

      if (resultado == true && mounted) {
        _carregarFichas();
      }
    }
  }

  Future<void> _removerFicha(FichaCompletaModel ficha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja realmente excluir esta ficha?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _fichaService.removerFicha(ficha.id);
        _carregarFichas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ficha excluída com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas Salvas'), centerTitle: true),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _fichas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma ficha salva',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie uma nova ocorrência para começar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregarFichas,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _fichas.length,
                itemBuilder: (context, index) {
                  final ficha = _fichas[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        ficha.dadosSolicitacao.raiNumero ?? 'Sem RAI',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            ficha.tipoOcorrencia.label,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (ficha.dadosSolicitacao.numeroOcorrencia != null)
                            Text(
                              'Ocorrência: ${ficha.dadosSolicitacao.numeroOcorrencia}',
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Criada em: ${DateFormat('dd/MM/yyyy HH:mm').format(ficha.dataCriacao)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (ficha.dataHoraTermino == null ||
                              ficha.dataHoraTermino!.isEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.orange.shade900,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Em atendimento',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'navegar',
                            child: Row(
                              children: [
                                Icon(Icons.navigation, size: 20),
                                SizedBox(width: 8),
                                Text('Navegar para Tela'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'gerar_ficha',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gerar Ficha',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'gerar_laudo',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.article,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gerar Laudo',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'gerar_quadro_posicionamento',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.scatter_plot,
                                  size: 20,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Gerar Quadro de Posicionamento',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'excluir',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Excluir',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'editar') {
                            _abrirFicha(ficha);
                          } else if (value == 'navegar') {
                            _mostrarMenuNavegacao(ficha);
                          } else if (value == 'gerar_ficha') {
                            _gerarDocumentoWord(ficha);
                          } else if (value == 'gerar_laudo') {
                            _gerarDocumentoLaudo(ficha);
                          } else if (value == 'gerar_quadro_posicionamento') {
                            _gerarQuadroPosicionamento(ficha);
                          } else if (value == 'excluir') {
                            _removerFicha(ficha);
                          }
                        },
                      ),
                      onTap: () => _abrirFicha(ficha),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _GerenciarFotosLevantamentoSheet extends StatefulWidget {
  const _GerenciarFotosLevantamentoSheet({
    required this.pathsIniciais,
    required this.basePath,
    required this.resolver,
  });

  final List<String> pathsIniciais;
  final String basePath;
  final Future<String?> Function(String) resolver;

  @override
  State<_GerenciarFotosLevantamentoSheet> createState() =>
      _GerenciarFotosLevantamentoSheetState();
}

class _GerenciarFotosLevantamentoSheetState
    extends State<_GerenciarFotosLevantamentoSheet> {
  late final List<String> _paths = [...widget.pathsIniciais];
  final Map<String, String?> _resolvedPaths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePaths());
  }

  Future<void> _resolvePaths() async {
    for (final p in _paths) {
      if (_resolvedPaths.containsKey(p)) continue;
      final r = await widget.resolver(p);
      if (mounted) setState(() => _resolvedPaths[p] = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: SizedBox(
        height: altura,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Organizar fotos do Anexo (${_paths.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_paths),
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _paths.isEmpty
                  ? const Center(child: Text('Nenhuma foto selecionada.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(12),
                      itemCount: _paths.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _paths.removeAt(oldIndex);
                          _paths.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final path = _paths[index];
                        final numero = (index + 1).toString().padLeft(2, '0');
                        final displayPath = _resolvedPaths[path] ?? path;
                        final fileExists = File(displayPath).existsSync();

                        return Card(
                          key: ValueKey(path),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: ListTile(
                              leading: SizedBox(
                                width: 140,
                                height: 140,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: fileExists
                                      ? Image.file(
                                          File(displayPath),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                ),
                              ),
                              title: Text(
                                numero,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Excluir',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(() {
                                        _paths.removeAt(index);
                                      });
                                    },
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
