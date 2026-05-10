import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/detatlhes_local.dart';
import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/marco_zero_local_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/unidade_model.dart';
import '../models/vestigio_local_model.dart';
import '../services/ficha_service.dart';
import '../services/laboratorio_service.dart';
import '../services/openai_service.dart';
import '../services/photo_backup_service.dart';
import '../services/unidade_service.dart';
import '../widgets/ai_suggestion_button.dart';
import 'bloodstain_analysis_screen.dart';
import 'evidencias_furto_screen.dart';
import 'lista_veiculos_screen.dart';
import 'vestigio_local_form_screen.dart';

class LocalFurtoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const LocalFurtoScreen({super.key, required this.ficha});

  @override
  State<LocalFurtoScreen> createState() => _LocalFurtoScreenState();
}

class _LocalFurtoScreenState extends State<LocalFurtoScreen> {
  final _fichaService = FichaService();
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();
  final _imagePicker = ImagePicker();
  final _sinaisArrombamentoController = TextEditingController();
  final _descricaoLocalController = TextEditingController();
  final _descricaoMediatoController = TextEditingController();
  final _descricaoImediatoController = TextEditingController();
  final _descricaoRelacionadoController = TextEditingController();
  final _demaisObservacoesController = TextEditingController();
  bool _salvando = false;
  int _etapaLocalAtual = 0; // 0=mediato, 1=imediato, 2=relacionado
  bool? _temVestigiosMediato;

  // Marco Zero por local
  final _marcoZeroDescricaoMediatoController = TextEditingController();
  final _marcoZeroXMediatoController = TextEditingController(text: '0');
  final _marcoZeroYMediatoController = TextEditingController(text: '0');
  final _marcoZeroDescricaoImediatoController = TextEditingController();
  final _marcoZeroXImediatoController = TextEditingController(text: '0');
  final _marcoZeroYImediatoController = TextEditingController(text: '0');
  final _marcoZeroDescricaoRelacionadoController = TextEditingController();
  final _marcoZeroXRelacionadoController = TextEditingController(text: '0');
  final _marcoZeroYRelacionadoController = TextEditingController(text: '0');

  // Estados dos checkboxes
  bool? _classificacaoMediato;
  bool? _classificacaoImediato;
  bool? _classificacaoRelacionado;

  // Piso e Iluminação - Mediato
  bool? _pisoSecoMediato;
  bool? _pisoUmidoMediato;
  bool? _pisoMolhadoMediato;
  bool? _iluminacaoArtificialMediato;
  bool? _iluminacaoNaturalMediato;
  bool? _iluminacaoAusenteMediato;

  // Piso e Iluminação - Imediato
  bool? _pisoSecoImediato;
  bool? _pisoUmidoImediato;
  bool? _pisoMolhadoImediato;
  bool? _iluminacaoArtificialImediato;
  bool? _iluminacaoNaturalImediato;
  bool? _iluminacaoAusenteImediato;

  // Piso e Iluminação - Relacionado
  bool? _pisoSecoRelacionado;
  bool? _pisoUmidoRelacionado;
  bool? _pisoMolhadoRelacionado;
  bool? _iluminacaoArtificialRelacionado;
  bool? _iluminacaoNaturalRelacionado;
  bool? _iluminacaoAusenteRelacionado;

  bool? _sinaisArrombamentoSim;
  bool? _sinaisArrombamentoNao;
  bool? _sinaisArrombamentoNaoSeAplica;

  // Descrição assistida – Mediato
  String? _tipoRegiaoMediato;
  String? _tipoImovelMediato;
  int? _qtdPavimentosMediato;
  int? _quantidadeAcessosMediato;
  final Set<String> _infraestruturaMediato = {};
  final Set<String> _delimitacaoMediato = {};
  final Set<String> _tiposAcessoMediato = {};
  final Set<String> _posicoesAcessoMediato = {};

  // Descrição assistida – Imediato
  String? _abrangenciaImediato;
  final Set<String> _ambientesImediato = {};
  final Map<String, Set<String>> _acessosPorAmbienteImediato = {};
  String? _ambienteAcessoSelecionado;
  String? _estadoConservacaoImediato;
  final _observacaoImediatoController = TextEditingController();

  static const _opcoesAbrangenciaImediato = [
    'único ambiente',
    'múltiplos ambientes',
  ];
  static const _opcoesAmbiente = [
    'sala',
    'quarto',
    'cozinha',
    'banheiro',
    'garagem',
    'quintal',
    'varanda',
    'corredor',
    'escritório',
    'depósito',
    'área de serviço',
    'loja (interior)',
    'recepção',
    'estacionamento',
    'área comum',
    'outro',
  ];
  static const _opcoesEstadoConservacao = [
    'bom estado de conservação',
    'estado regular de conservação',
    'mau estado de conservação',
    'em reforma',
    'abandonado',
  ];

  static const _opcoesRegiao = [
    'comercial',
    'residencial',
    'mista (residencial e comercial)',
    'industrial',
    'rural',
  ];
  static const _opcoesInfraestrutura = [
    'asfalto',
    'calçadas',
    'iluminação pública',
    'rede de esgoto',
  ];
  static const _opcoesTipoImovel = [
    'casa',
    'apartamento',
    'conjunto de kitnets',
    'loja',
    'galpão',
    'prédio comercial',
    'prédio residencial',
    'terreno baldio',
    'igreja',
    'escola',
    'outro',
  ];
  static const _opcoesDelimitacao = [
    'muro de alvenaria',
    'grade metálica',
    'cerca de arame',
    'cerca viva',
    'sem delimitação',
  ];
  static const _opcoesTiposAcessoMediato = [
    'portão metálico',
    'portão metálico com social embutido',
    'portão metálico do tipo basculante',
    'portão metálico do tipo deslizante sobre trilho',
    'portão de madeira',
    'cancela',
    'sem portão (cerca de arame)',
  ];
  static const _opcoesPosicoesAcessoMediato = [
    'frontal',
    'posterior',
    'lateral direita',
    'lateral esquerda',
  ];
  static const _opcoesAcessosInternos = [
    'porta interna de madeira',
    'porta interna de vidro',
    'porta metálica',
    'janela',
    'corredor interno',
    'escada interna',
    'acesso livre (sem porta interna)',
  ];

  // Vestígios por local
  List<VestigioLocalModel> _vestigiosMediato = [];
  List<VestigioLocalModel> _vestigiosImediato = [];
  List<VestigioLocalModel> _vestigiosRelacionado = [];
  bool _semVestigiosMediato = false;
  bool _semVestigiosImediato = false;
  bool _semVestigiosRelacionado = false;
  final List<String> _fotosVistaAmplaPaths = [];
  final List<String> _fotosVistaAmplaImediatoPaths = [];

  /// true = via pública / área aberta; false = imóvel; null = não definido
  bool? _localEmViaPublica;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.localFurto;
    if (dados != null) {
      _classificacaoMediato = dados.classificacaoMediato;
      _classificacaoImediato = dados.classificacaoImediato;
      _classificacaoRelacionado = dados.classificacaoRelacionado;
      _pisoSecoMediato = dados.pisoSecoMediato;
      _pisoUmidoMediato = dados.pisoUmidoMediato;
      _pisoMolhadoMediato = dados.pisoMolhadoMediato;
      _iluminacaoArtificialMediato = dados.iluminacaoArtificialMediato;
      _iluminacaoNaturalMediato = dados.iluminacaoNaturalMediato;
      _iluminacaoAusenteMediato = dados.iluminacaoAusenteMediato;
      _pisoSecoImediato = dados.pisoSecoImediato;
      _pisoUmidoImediato = dados.pisoUmidoImediato;
      _pisoMolhadoImediato = dados.pisoMolhadoImediato;
      _iluminacaoArtificialImediato = dados.iluminacaoArtificialImediato;
      _iluminacaoNaturalImediato = dados.iluminacaoNaturalImediato;
      _iluminacaoAusenteImediato = dados.iluminacaoAusenteImediato;
      _pisoSecoRelacionado = dados.pisoSecoRelacionado;
      _pisoUmidoRelacionado = dados.pisoUmidoRelacionado;
      _pisoMolhadoRelacionado = dados.pisoMolhadoRelacionado;
      _iluminacaoArtificialRelacionado = dados.iluminacaoArtificialRelacionado;
      _iluminacaoNaturalRelacionado = dados.iluminacaoNaturalRelacionado;
      _iluminacaoAusenteRelacionado = dados.iluminacaoAusenteRelacionado;
      _sinaisArrombamentoSim = dados.sinaisArrombamentoSim;
      _sinaisArrombamentoNao = dados.sinaisArrombamentoNao;
      _sinaisArrombamentoNaoSeAplica = dados.sinaisArrombamentoNaoSeAplica;
      _quantidadeAcessosMediato = dados.quantidadeAcessosMediato;
      _tiposAcessoMediato
        ..clear()
        ..addAll(dados.tiposAcessoMediato ?? const []);
      _posicoesAcessoMediato
        ..clear()
        ..addAll(dados.posicoesAcessoMediato ?? const []);
      _sinaisArrombamentoController.text =
          dados.sinaisArrombamentoDescricao ?? '';
      _descricaoLocalController.text = dados.descricaoLocal ?? '';
      _descricaoMediatoController.text = dados.descricaoLocalMediato ?? '';
      _descricaoImediatoController.text = dados.descricaoLocalImediato ?? '';
      _descricaoRelacionadoController.text =
          dados.descricaoLocalRelacionado ?? '';
      _observacaoImediatoController.text = '';
      _marcoZeroDescricaoMediatoController.text =
          dados.marcoZeroMediato?.descricao ?? '';
      _marcoZeroXMediatoController.text =
          dados.marcoZeroMediato?.coordenadaX ?? '0';
      _marcoZeroYMediatoController.text =
          dados.marcoZeroMediato?.coordenadaY ?? '0';
      _marcoZeroDescricaoImediatoController.text =
          dados.marcoZeroImediato?.descricao ?? '';
      _marcoZeroXImediatoController.text =
          dados.marcoZeroImediato?.coordenadaX ?? '0';
      _marcoZeroYImediatoController.text =
          dados.marcoZeroImediato?.coordenadaY ?? '0';
      _marcoZeroDescricaoRelacionadoController.text =
          dados.marcoZeroRelacionado?.descricao ?? '';
      _marcoZeroXRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaX ?? '0';
      _marcoZeroYRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaY ?? '0';
      _vestigiosMediato = List<VestigioLocalModel>.from(
        dados.vestigiosMediato ?? [],
      );
      _vestigiosImediato = List<VestigioLocalModel>.from(
        dados.vestigiosImediato ?? [],
      );
      _vestigiosRelacionado = List<VestigioLocalModel>.from(
        dados.vestigiosRelacionado ?? [],
      );
      _semVestigiosMediato = dados.semVestigiosMediato ?? false;
      _semVestigiosImediato = dados.semVestigiosImediato ?? false;
      _semVestigiosRelacionado = dados.semVestigiosRelacionado ?? false;
      _temVestigiosMediato = !(dados.semVestigiosMediato ?? false);
      _fotosVistaAmplaPaths.clear();
      _fotosVistaAmplaPaths.addAll(
        dados.fotosVistaAmplaMediatoPaths ??
            dados.fotosVistaAmplaPaths ??
            const [],
      );
      _fotosVistaAmplaImediatoPaths.clear();
      _fotosVistaAmplaImediatoPaths.addAll(
        dados.fotosVistaAmplaImediatoPaths ?? const [],
      );
    } else if (widget.ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
      // Pré-popular vestígios padrão para Morte a Esclarecer (apenas na primeira abertura)
      _classificacaoImediato = true;
      _vestigiosImediato = _vestigiosPadraoMorteEsclarecer();
    }
  }

  String get _tituloEtapaLocal {
    switch (_etapaLocalAtual) {
      case 0:
        return 'Local Mediato';
      case 1:
        return 'Local Imediato';
      default:
        return 'Local Relacionado';
    }
  }

  Future<void> _avancarEtapaLocal() async {
    if (_etapaLocalAtual == 0) {
      setState(() {
        _classificacaoMediato = true;
        _classificacaoImediato = true;
        _etapaLocalAtual = 1;
      });
      return;
    }

    if (_etapaLocalAtual == 1) {
      final incluirRelacionado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Local Relacionado'),
          content: const Text('Há local relacionado para preencher?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Não'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sim'),
            ),
          ],
        ),
      );

      if (incluirRelacionado == true) {
        setState(() {
          _classificacaoRelacionado = true;
          _etapaLocalAtual = 2;
        });
        return;
      }

      setState(() {
        _classificacaoRelacionado = false;
      });
      await _salvarLocalFurto();
      return;
    }

    await _salvarLocalFurto();
  }

  List<VestigioLocalModel> _vestigiosPadraoMorteEsclarecer() {
    return [
      VestigioLocalModel(
        id: 'me_01',
        descricao: 'Presença do corpo da vítima',
        tipoAcao: TipoAcaoVestigio.registrado,
      ),
      VestigioLocalModel(
        id: 'me_02',
        descricao:
            'Ausência de sinais de luta tanto no ambiente externo quanto no interno (objetos e móveis alinhados)',
        tipoAcao: TipoAcaoVestigio.registrado,
      ),
      VestigioLocalModel(
        id: 'me_03',
        descricao:
            'Ausência de objetos do tipo arma eventual ou vestígios do uso de armas',
        tipoAcao: TipoAcaoVestigio.registrado,
      ),
      VestigioLocalModel(
        id: 'me_04',
        descricao: 'Ausência de produtos tóxicos nas imediações do local',
        tipoAcao: TipoAcaoVestigio.registrado,
      ),
      VestigioLocalModel(
        id: 'me_05',
        descricao:
            'Ausência de outros elementos relevantes para a perícia criminal',
        tipoAcao: TipoAcaoVestigio.registrado,
      ),
    ];
  }

  @override
  void dispose() {
    _sinaisArrombamentoController.dispose();
    _descricaoLocalController.dispose();
    _descricaoMediatoController.dispose();
    _descricaoImediatoController.dispose();
    _descricaoRelacionadoController.dispose();
    _observacaoImediatoController.dispose();
    _demaisObservacoesController.dispose();
    _marcoZeroDescricaoMediatoController.dispose();
    _marcoZeroXMediatoController.dispose();
    _marcoZeroYMediatoController.dispose();
    _marcoZeroDescricaoImediatoController.dispose();
    _marcoZeroXImediatoController.dispose();
    _marcoZeroYImediatoController.dispose();
    _marcoZeroDescricaoRelacionadoController.dispose();
    _marcoZeroXRelacionadoController.dispose();
    _marcoZeroYRelacionadoController.dispose();
    super.dispose();
  }

  void _onPisoChanged(bool? value, String tipo, String local) {
    setState(() {
      switch (local) {
        case 'mediato':
          switch (tipo) {
            case 'seco':
              _pisoSecoMediato = value ?? false;
              if (value == true) {
                _pisoUmidoMediato = false;
                _pisoMolhadoMediato = false;
              }
              break;
            case 'umido':
              _pisoUmidoMediato = value ?? false;
              if (value == true) {
                _pisoSecoMediato = false;
                _pisoMolhadoMediato = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoMediato = value ?? false;
              if (value == true) {
                _pisoSecoMediato = false;
                _pisoUmidoMediato = false;
              }
              break;
          }
          break;
        case 'imediato':
          switch (tipo) {
            case 'seco':
              _pisoSecoImediato = value ?? false;
              if (value == true) {
                _pisoUmidoImediato = false;
                _pisoMolhadoImediato = false;
              }
              break;
            case 'umido':
              _pisoUmidoImediato = value ?? false;
              if (value == true) {
                _pisoSecoImediato = false;
                _pisoMolhadoImediato = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoImediato = value ?? false;
              if (value == true) {
                _pisoSecoImediato = false;
                _pisoUmidoImediato = false;
              }
              break;
          }
          break;
        case 'relacionado':
          switch (tipo) {
            case 'seco':
              _pisoSecoRelacionado = value ?? false;
              if (value == true) {
                _pisoUmidoRelacionado = false;
                _pisoMolhadoRelacionado = false;
              }
              break;
            case 'umido':
              _pisoUmidoRelacionado = value ?? false;
              if (value == true) {
                _pisoSecoRelacionado = false;
                _pisoMolhadoRelacionado = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoRelacionado = value ?? false;
              if (value == true) {
                _pisoSecoRelacionado = false;
                _pisoUmidoRelacionado = false;
              }
              break;
          }
          break;
      }
    });
  }

  void _onIluminacaoChanged(bool? value, String tipo, String local) {
    setState(() {
      switch (local) {
        case 'mediato':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialMediato = value ?? false;
              if (value == true) {
                _iluminacaoNaturalMediato = false;
                _iluminacaoAusenteMediato = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalMediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialMediato = false;
                _iluminacaoAusenteMediato = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteMediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialMediato = false;
                _iluminacaoNaturalMediato = false;
              }
              break;
          }
          break;
        case 'imediato':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialImediato = value ?? false;
              if (value == true) {
                _iluminacaoNaturalImediato = false;
                _iluminacaoAusenteImediato = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalImediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialImediato = false;
                _iluminacaoAusenteImediato = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteImediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialImediato = false;
                _iluminacaoNaturalImediato = false;
              }
              break;
          }
          break;
        case 'relacionado':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoNaturalRelacionado = false;
                _iluminacaoAusenteRelacionado = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoArtificialRelacionado = false;
                _iluminacaoAusenteRelacionado = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoArtificialRelacionado = false;
                _iluminacaoNaturalRelacionado = false;
              }
              break;
          }
          break;
      }
    });
  }

  void _onSinaisArrombamentoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'sim':
          _sinaisArrombamentoSim = value ?? false;
          if (value == true) {
            _sinaisArrombamentoNao = false;
            _sinaisArrombamentoNaoSeAplica = false;
          }
          break;
        case 'nao':
          _sinaisArrombamentoNao = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNaoSeAplica = false;
            _sinaisArrombamentoController.clear();
          }
          break;
        case 'naoSeAplica':
          _sinaisArrombamentoNaoSeAplica = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNao = false;
            _sinaisArrombamentoController.clear();
          }
          break;
      }
    });
  }

  Future<String?> _persistirFotoVestigio(XFile arquivo) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.ficha.id}',
      );
      if (!await pasta.exists()) {
        await pasta.create(recursive: true);
      }
      final ext = arquivo.path.contains('.')
          ? arquivo.path.split('.').last.toLowerCase()
          : 'jpg';
      final destino = File(
        '${pasta.path}/foto_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      final bytes = await arquivo.readAsBytes();
      await destino.writeAsBytes(bytes);
      await PhotoBackupService.saveToGallery(destino.path);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _adicionarOuEditarVestigio(
    String secao, {
    VestigioLocalModel? existente,
  }) async {
    final inclusaoContinua = existente == null;

    final resultado = await Navigator.of(context).push<VestigioLocalModel>(
      MaterialPageRoute(
        builder: (ctx) => VestigioLocalFormScreen(
          fichaId: widget.ficha.id,
          vestigioExistente: existente,
          manterNaTelaAposSalvarNovo: inclusaoContinua,
          onSalvo: inclusaoContinua
              ? (VestigioLocalModel v) {
                  if (!mounted) return;
                  setState(() {
                    switch (secao) {
                      case 'mediato':
                        _vestigiosMediato.add(v);
                        _semVestigiosMediato = false;
                        break;
                      case 'imediato':
                        _vestigiosImediato.add(v);
                        _semVestigiosImediato = false;
                        break;
                      default:
                        _vestigiosRelacionado.add(v);
                        _semVestigiosRelacionado = false;
                        break;
                    }
                  });
                }
              : null,
        ),
      ),
    );

    if (!mounted) return;

    // Novos vestígios já foram incluídos em [onSalvo] a cada salvamento.
    if (inclusaoContinua) return;

    if (resultado == null) return;

    setState(() {
      List<VestigioLocalModel> alvo;
      switch (secao) {
        case 'mediato':
          alvo = _vestigiosMediato;
          _semVestigiosMediato = false;
          break;
        case 'imediato':
          alvo = _vestigiosImediato;
          _semVestigiosImediato = false;
          break;
        default:
          alvo = _vestigiosRelacionado;
          _semVestigiosRelacionado = false;
          break;
      }
      final idx = alvo.indexWhere((e) => e.id == resultado.id);
      if (idx >= 0) {
        alvo[idx] = resultado;
      } else {
        alvo.add(resultado);
      }
    });
  }

  void _removerVestigio(String secao, String id) {
    setState(() {
      switch (secao) {
        case 'mediato':
          _vestigiosMediato.removeWhere((v) => v.id == id);
          break;
        case 'imediato':
          _vestigiosImediato.removeWhere((v) => v.id == id);
          break;
        default:
          _vestigiosRelacionado.removeWhere((v) => v.id == id);
          break;
      }
    });
  }

  Future<void> _salvarLocalFurto() async {
    setState(() {
      _salvando = true;
    });

    try {
      final partesDescricao = <String>[];
      final mediatoTexto = _descricaoMediatoController.text.trim();
      final imediatoTexto = _descricaoImediatoController.text.trim();
      final relacionadoTexto = _descricaoRelacionadoController.text.trim();
      if (mediatoTexto.isNotEmpty) {
        partesDescricao.add('Mediato: $mediatoTexto');
      }
      if (imediatoTexto.isNotEmpty) {
        partesDescricao.add('Imediato: $imediatoTexto');
      }
      if (relacionadoTexto.isNotEmpty) {
        partesDescricao.add('Relacionado: $relacionadoTexto');
      }
      final descricaoLocalAgrupada = partesDescricao.isEmpty
          ? null
          : partesDescricao.join('\n\n');

      final localFurto = LocalFurtoModel(
        classificacaoMediato: _classificacaoMediato,
        classificacaoImediato: _classificacaoImediato,
        classificacaoRelacionado: _classificacaoRelacionado,
        pisoSecoMediato: _pisoSecoMediato,
        pisoUmidoMediato: _pisoUmidoMediato,
        pisoMolhadoMediato: _pisoMolhadoMediato,
        iluminacaoArtificialMediato: _iluminacaoArtificialMediato,
        iluminacaoNaturalMediato: _iluminacaoNaturalMediato,
        iluminacaoAusenteMediato: _iluminacaoAusenteMediato,
        pisoSecoImediato: _pisoSecoImediato,
        pisoUmidoImediato: _pisoUmidoImediato,
        pisoMolhadoImediato: _pisoMolhadoImediato,
        iluminacaoArtificialImediato: _iluminacaoArtificialImediato,
        iluminacaoNaturalImediato: _iluminacaoNaturalImediato,
        iluminacaoAusenteImediato: _iluminacaoAusenteImediato,
        pisoSecoRelacionado: _pisoSecoRelacionado,
        pisoUmidoRelacionado: _pisoUmidoRelacionado,
        pisoMolhadoRelacionado: _pisoMolhadoRelacionado,
        iluminacaoArtificialRelacionado: _iluminacaoArtificialRelacionado,
        iluminacaoNaturalRelacionado: _iluminacaoNaturalRelacionado,
        iluminacaoAusenteRelacionado: _iluminacaoAusenteRelacionado,
        descricaoViasAcesso: _gerarDescricaoViasAcessoMediato().isEmpty
            ? null
            : _gerarDescricaoViasAcessoMediato(),
        quantidadeAcessosMediato: _quantidadeAcessosMediato,
        tiposAcessoMediato: _tiposAcessoMediato.isEmpty
            ? null
            : _tiposAcessoMediato.toList(),
        posicoesAcessoMediato: _posicoesAcessoMediato.isEmpty
            ? null
            : _posicoesAcessoMediato.toList(),
        sinaisArrombamentoDescricao:
            (_sinaisArrombamentoSim == true &&
                _sinaisArrombamentoController.text.trim().isNotEmpty)
            ? _sinaisArrombamentoController.text.trim()
            : null,
        descricaoLocal: descricaoLocalAgrupada,
        demaisObservacoes: _demaisObservacoesController.text.trim().isEmpty
            ? null
            : _demaisObservacoesController.text.trim(),
        descricaoLocalMediato: _descricaoMediatoController.text.trim().isEmpty
            ? null
            : _descricaoMediatoController.text.trim(),
        descricaoLocalImediato: _descricaoImediatoController.text.trim().isEmpty
            ? null
            : _descricaoImediatoController.text.trim(),
        descricaoLocalRelacionado:
            _descricaoRelacionadoController.text.trim().isEmpty
            ? null
            : _descricaoRelacionadoController.text.trim(),
        marcoZeroMediato:
            (_classificacaoMediato == true && _temVestigiosMediato == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoMediatoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoMediatoController.text.trim(),
                coordenadaX: _marcoZeroXMediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXMediatoController.text.trim(),
                coordenadaY: _marcoZeroYMediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYMediatoController.text.trim(),
              )
            : null,
        marcoZeroImediato: (_classificacaoImediato == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoImediatoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoImediatoController.text.trim(),
                coordenadaX: _marcoZeroXImediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXImediatoController.text.trim(),
                coordenadaY: _marcoZeroYImediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYImediatoController.text.trim(),
              )
            : null,
        marcoZeroRelacionado: (_classificacaoRelacionado == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoRelacionadoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoRelacionadoController.text.trim(),
                coordenadaX:
                    _marcoZeroXRelacionadoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXRelacionadoController.text.trim(),
                coordenadaY:
                    _marcoZeroYRelacionadoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYRelacionadoController.text.trim(),
              )
            : null,
        vestigiosMediato: (_temVestigiosMediato == true)
            ? _vestigiosMediato
            : [],
        vestigiosImediato: _semVestigiosImediato ? [] : _vestigiosImediato,
        vestigiosRelacionado: _semVestigiosRelacionado
            ? []
            : _vestigiosRelacionado,
        semVestigiosMediato: !(_temVestigiosMediato ?? false),
        semVestigiosImediato: _semVestigiosImediato,
        semVestigiosRelacionado: _semVestigiosRelacionado,
        sinaisArrombamentoSim: _sinaisArrombamentoSim,
        sinaisArrombamentoNao: _sinaisArrombamentoNao,
        sinaisArrombamentoNaoSeAplica: _sinaisArrombamentoNaoSeAplica,
        fotosVistaAmplaPaths: _fotosVistaAmplaPaths.isEmpty
            ? null
            : _fotosVistaAmplaPaths,
        fotosVistaAmplaMediatoPaths: _fotosVistaAmplaPaths.isEmpty
            ? null
            : _fotosVistaAmplaPaths,
        fotosVistaAmplaImediatoPaths: _fotosVistaAmplaImediatoPaths.isEmpty
            ? null
            : _fotosVistaAmplaImediatoPaths,
        localEmViaPublica: _localEmViaPublica,
      );

      final fichaBaseAtual =
          await _fichaService.obterFicha(widget.ficha.id) ?? widget.ficha;

      // Preservar todos os dados existentes, inclusive análises salvas em telas auxiliares.
      final fichaAtualizada = fichaBaseAtual.copyWith(
        localFurto: localFurto,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: fichaBaseAtual.equipe,
        equipesPoliciais: fichaBaseAtual.equipesPoliciais,
        local: fichaBaseAtual.local,
        dadosFichaBase: fichaBaseAtual.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Mostrar alerta sobre o croqui
        await _mostrarAlertaCroqui();

        if (!mounted) return;

        // Verificar tipo de ocorrência
        if (fichaAtualizada.tipoOcorrencia == TipoOcorrencia.cvli ||
            fichaAtualizada.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
          // Para CVLI, navegar para tela de veículos e aguardar retorno
          final resultadoVeiculos = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ListaVeiculosScreen(ficha: fichaAtualizada),
            ),
          );

          // Se voltou de veículos com sucesso, apenas propagar o sucesso
          if (mounted && resultadoVeiculos != null) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Para crimes patrimoniais, navegar para tela de evidências
          final resultado = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  EvidenciasFurtoScreen(ficha: fichaAtualizada),
            ),
          );

          // Se voltou das evidências, retornar true para atualizar lista
          if (mounted && resultado == true) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Future<void> _mostrarAlertaCroqui() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.draw, size: 48, color: Colors.orange),
        title: const Text('Lembrete: Croqui'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Não esqueça de fazer o croqui do local!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'O croqui deve relacionar os principais vestígios encontrados, '
              'indicando suas posições em relação ao marco zero definido.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(String label, List<Map<String, dynamic>> opcoes) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: opcoes.map((opcao) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: opcao['value'] as bool? ?? false,
                      onChanged: opcao['onChanged'] as void Function(bool?)?,
                    ),
                    Flexible(child: Text(opcao['label'] as String)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _gerarTextoDescricaoMediato() {
    final partes = <String>[];

    if (_tipoImovelMediato != null) {
      String frase;
      if (_tipoImovelMediato == 'conjunto de kitnets') {
        frase =
            'Tratava-se de um conjunto de kitnets implantado em um mesmo lote, com unidades dispostas umas em frente às outras e área de quintal/pátio central entre elas';
        if (_qtdPavimentosMediato != null && _qtdPavimentosMediato! > 0) {
          final n = _qtdPavimentosMediato.toString().padLeft(2, '0');
          frase += ', com $n pavimento${_qtdPavimentosMediato == 1 ? '' : 's'}';
        }
        frase += '.';
      } else {
        frase = 'Tratava-se de $_tipoImovelMediato';
        if (_qtdPavimentosMediato != null && _qtdPavimentosMediato! > 0) {
          final n = _qtdPavimentosMediato.toString().padLeft(2, '0');
          frase += ' de $n pavimento${_qtdPavimentosMediato == 1 ? '' : 's'}';
        }
        frase += '.';
      }
      partes.add(frase);
    }

    if (_tipoRegiaoMediato != null) {
      String frase =
          'O imóvel estava situado em região predominantemente $_tipoRegiaoMediato';
      if (_infraestruturaMediato.isNotEmpty) {
        frase +=
            ', provida de ${_listarItens(_infraestruturaMediato.toList())}';
      }
      frase += '.';
      partes.add(frase);
    }

    if (_delimitacaoMediato.isNotEmpty) {
      if (_delimitacaoMediato.contains('sem delimitação')) {
        partes.add(
          'Não existia muro ou qualquer outro tipo de cerca delimitando o terreno.',
        );
      } else {
        partes.add(
          'O terreno era delimitado por ${_listarItens(_delimitacaoMediato.toList())}.',
        );
      }
    }

    final descricaoAcessos = _gerarDescricaoViasAcessoMediato();
    if (descricaoAcessos.isNotEmpty) {
      partes.add('O acesso ao imóvel se dava por $descricaoAcessos.');
    }

    return partes.join(' ');
  }

  String _gerarTextoDescricaoImediato() {
    final partes = <String>[];

    if (_ambientesImediato.isNotEmpty) {
      final ambientes = _listarItens(_ambientesImediato.toList());
      final plural = _ambientesImediato.length > 1;
      String frase;
      if (_tipoImovelMediato == 'conjunto de kitnets') {
        frase = plural
            ? 'No conjunto de kitnets, o local imediato abrangeu mais de um ponto de interesse, compreendendo $ambientes'
            : 'No conjunto de kitnets, o local imediato correspondeu especificamente a $ambientes';
      } else {
        frase = plural
            ? 'O local imediato abrangeu múltiplos ambientes no interior do imóvel, compreendendo $ambientes'
            : 'O local imediato correspondeu ao ambiente: $ambientes';
      }
      if (_estadoConservacaoImediato != null) {
        frase += ', em $_estadoConservacaoImediato';
      }
      frase += '.';
      partes.add(frase);
    }

    final descricaoAcessos = _gerarDescricaoAcessosInternosImediato();
    if (descricaoAcessos.isNotEmpty) {
      partes.add(descricaoAcessos);
    }

    final obsImediato = _observacaoImediatoController.text.trim();
    if (obsImediato.isNotEmpty) {
      partes.add('Observação do local imediato: $obsImediato.');
    }

    return partes.join(' ');
  }

  String _gerarDescricaoAcessosInternosImediato() {
    final descricoes = <String>[];
    for (final ambiente in _ambientesImediato) {
      final acessos = _acessosPorAmbienteImediato[ambiente];
      if (acessos == null || acessos.isEmpty) continue;
      descricoes.add(
        'no ambiente ${_capitalize(ambiente)} havia ${_listarItens(acessos.toList())}',
      );
    }
    if (descricoes.isEmpty) return '';
    return 'Quanto aos acessos internos, ${_listarItens(descricoes)}.';
  }

  void _sincronizarAcessosPorAmbienteImediato() {
    _acessosPorAmbienteImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    for (final ambiente in _ambientesImediato) {
      _acessosPorAmbienteImediato.putIfAbsent(ambiente, () => <String>{});
    }
    if (_ambienteAcessoSelecionado != null &&
        !_ambientesImediato.contains(_ambienteAcessoSelecionado)) {
      _ambienteAcessoSelecionado = null;
    }
    _ambienteAcessoSelecionado ??= _ambientesImediato.isEmpty
        ? null
        : _ambientesImediato.first;
  }

  String _gerarDescricaoViasAcessoMediato() {
    if (_localEmViaPublica == true) return '';
    final qtd = _quantidadeAcessosMediato;
    final tipos = _tiposAcessoMediato.toList();
    final posicoes = _posicoesAcessoMediato.toList();
    if (qtd == null && tipos.isEmpty && posicoes.isEmpty) return '';

    final partes = <String>[];
    if (qtd != null) {
      final qtdFormatada = qtd.toString().padLeft(2, '0');
      final qtdExtenso = _numeroPorExtenso(qtd);
      if (tipos.isEmpty) {
        partes.add(
          '$qtdFormatada ($qtdExtenso) portão${qtd == 1 ? '' : 'ões'}',
        );
      } else if (tipos.length == 1) {
        partes.add('$qtdFormatada ($qtdExtenso) ${tipos.first}');
      } else {
        partes.add(
          '$qtdFormatada ($qtdExtenso) portões, sendo ${_listarItens(tipos)}',
        );
      }
    } else {
      partes.add(tipos.isNotEmpty ? _listarItens(tipos) : 'portão(ões)');
    }
    if (posicoes.isNotEmpty) {
      partes.add('nas posições ${_listarItens(posicoes)}');
    }
    return partes.join(' ');
  }

  String _numeroPorExtenso(int numero) {
    const mapa = {
      1: 'um',
      2: 'dois',
      3: 'três',
      4: 'quatro',
      5: 'cinco',
      6: 'seis',
      7: 'sete',
      8: 'oito',
      9: 'nove',
      10: 'dez',
    };
    return mapa[numero] ?? numero.toString();
  }

  String _listarItens(List<String> itens) {
    if (itens.isEmpty) return '';
    if (itens.length == 1) return itens.first;
    final ultimos = itens.sublist(0, itens.length - 1).join(', ');
    return '$ultimos e ${itens.last}';
  }

  void _atualizarTextoMediato() {
    final texto = _gerarTextoDescricaoMediato();
    if (texto.isNotEmpty) {
      _descricaoMediatoController.text = texto;
    }
  }

  void _atualizarTextoImediato() {
    final texto = _gerarTextoDescricaoImediato();
    if (texto.isNotEmpty) {
      _descricaoImediatoController.text = texto;
    }
  }

  Widget _buildDescricaoAssistidaMediato() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assistente de descrição',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecione as opções para gerar o texto automaticamente.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: 'Local mediato',
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de local',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _tipoRegiaoMediato,
          decoration: const InputDecoration(
            labelText: 'Tipo de região',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _opcoesRegiao
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(_capitalize(r))),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _tipoRegiaoMediato = v;
            _atualizarTextoMediato();
          }),
        ),
        const SizedBox(height: 12),
        const Text('Infraestrutura da região'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: _opcoesInfraestrutura
              .map(
                (op) => FilterChip(
                  label: Text(_capitalize(op)),
                  selected: _infraestruturaMediato.contains(op),
                  onSelected: (_) => setState(() {
                    _infraestruturaMediato.contains(op)
                        ? _infraestruturaMediato.remove(op)
                        : _infraestruturaMediato.add(op);
                    _atualizarTextoMediato();
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _tipoImovelMediato,
          decoration: const InputDecoration(
            labelText: 'Tipo de imóvel',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _opcoesTipoImovel
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(_capitalize(r))),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _tipoImovelMediato = v;
            _atualizarTextoMediato();
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _qtdPavimentosMediato,
          decoration: const InputDecoration(
            labelText: 'Nº de pavimentos',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: List.generate(10, (i) => i + 1)
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(n.toString().padLeft(2, '0')),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _qtdPavimentosMediato = v;
            _atualizarTextoMediato();
          }),
        ),
        const SizedBox(height: 12),
        const Text('Delimitação'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: _opcoesDelimitacao
              .map(
                (op) => FilterChip(
                  label: Text(_capitalize(op)),
                  selected: _delimitacaoMediato.contains(op),
                  onSelected: (_) => setState(() {
                    _delimitacaoMediato.contains(op)
                        ? _delimitacaoMediato.remove(op)
                        : _delimitacaoMediato.add(op);
                    _atualizarTextoMediato();
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('Acessos'),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _quantidadeAcessosMediato,
          decoration: const InputDecoration(
            labelText: 'Quantidade de acessos',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [1, 2, 3, 4]
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(n.toString().padLeft(2, '0')),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _quantidadeAcessosMediato = v;
            if (v != null && _posicoesAcessoMediato.length > v) {
              final manter = _posicoesAcessoMediato.take(v).toSet();
              _posicoesAcessoMediato
                ..clear()
                ..addAll(manter);
            }
            _atualizarTextoMediato();
          }),
        ),
        const SizedBox(height: 12),
        const Text('Tipo de acesso'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: _opcoesTiposAcessoMediato
              .map(
                (op) => FilterChip(
                  label: Text(_capitalize(op)),
                  selected: _tiposAcessoMediato.contains(op),
                  onSelected: (_) => setState(() {
                    _tiposAcessoMediato.contains(op)
                        ? _tiposAcessoMediato.remove(op)
                        : _tiposAcessoMediato.add(op);
                    _atualizarTextoMediato();
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('Posição do(s) acesso(s)'),
        const SizedBox(height: 4),
        if (_quantidadeAcessosMediato != null)
          Text(
            'Selecionadas ${_posicoesAcessoMediato.length} de $_quantidadeAcessosMediato posição(ões).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        if (_quantidadeAcessosMediato != null) const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: _opcoesPosicoesAcessoMediato
              .map(
                (op) => FilterChip(
                  label: Text(_capitalize(op)),
                  selected: _posicoesAcessoMediato.contains(op),
                  onSelected:
                      (_quantidadeAcessosMediato != null &&
                          _posicoesAcessoMediato.length >=
                              _quantidadeAcessosMediato! &&
                          !_posicoesAcessoMediato.contains(op))
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            final limite = _quantidadeAcessosMediato ?? 4;
                            if (_posicoesAcessoMediato.length >= limite) return;
                            _posicoesAcessoMediato.add(op);
                          } else {
                            _posicoesAcessoMediato.remove(op);
                          }
                          _atualizarTextoMediato();
                        }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Exemplo comum: 02 (dois) portões, sendo portão metálico do tipo basculante e portão metálico do tipo deslizante sobre trilho.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDescricaoAssistidaImediato() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assistente de descrição',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Descreva o(s) ambiente(s) onde ocorreu o fato.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _abrangenciaImediato,
          decoration: const InputDecoration(
            labelText: 'Abrangência do local imediato',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _opcoesAbrangenciaImediato
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(_capitalize(r))),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _abrangenciaImediato = v;
            if (v == 'único ambiente' && _ambientesImediato.length > 1) {
              final primeiro = _ambientesImediato.first;
              _ambientesImediato
                ..clear()
                ..add(primeiro);
            }
            _sincronizarAcessosPorAmbienteImediato();
            _atualizarTextoImediato();
          }),
        ),
        const SizedBox(height: 12),
        const Text('Ambiente(s) do fato'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: _opcoesAmbiente
              .map(
                (op) => FilterChip(
                  label: Text(_capitalize(op)),
                  selected: _ambientesImediato.contains(op),
                  onSelected: (_) => setState(() {
                    _ambientesImediato.contains(op)
                        ? _ambientesImediato.remove(op)
                        : _ambientesImediato.add(op);
                    if (_abrangenciaImediato == 'único ambiente' &&
                        _ambientesImediato.length > 1) {
                      _ambientesImediato
                        ..clear()
                        ..add(op);
                    }
                    _sincronizarAcessosPorAmbienteImediato();
                    _atualizarTextoImediato();
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _estadoConservacaoImediato,
          decoration: const InputDecoration(
            labelText: 'Estado de conservação',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _opcoesEstadoConservacao
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(_capitalize(r))),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _estadoConservacaoImediato = v;
            _atualizarTextoImediato();
          }),
        ),
        const SizedBox(height: 12),
        const Text('Acessos internos por ambiente'),
        const SizedBox(height: 4),
        if (_ambientesImediato.isEmpty)
          Text(
            'Selecione pelo menos um ambiente para informar os acessos internos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          )
        else ...[
          Text(
            'Ambiente selecionado',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: _ambientesImediato
                .map(
                  (ambiente) => ChoiceChip(
                    label: Text(_capitalize(ambiente)),
                    selected: _ambienteAcessoSelecionado == ambiente,
                    onSelected: (_) => setState(() {
                      _ambienteAcessoSelecionado = ambiente;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: _opcoesAcessosInternos
                .map(
                  (op) => FilterChip(
                    label: Text(_capitalize(op)),
                    selected:
                        _ambienteAcessoSelecionado != null &&
                        (_acessosPorAmbienteImediato[_ambienteAcessoSelecionado!]
                                ?.contains(op) ??
                            false),
                    onSelected: _ambienteAcessoSelecionado == null
                        ? null
                        : (_) => setState(() {
                            final ambiente = _ambienteAcessoSelecionado!;
                            final acessos = _acessosPorAmbienteImediato
                                .putIfAbsent(ambiente, () => <String>{});
                            if (acessos.contains(op)) {
                              acessos.remove(op);
                            } else {
                              acessos.add(op);
                            }
                            _atualizarTextoImediato();
                          }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          ..._ambientesImediato
              .where(
                (ambiente) =>
                    (_acessosPorAmbienteImediato[ambiente] ?? const <String>{})
                        .isNotEmpty,
              )
              .map(
                (ambiente) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${_capitalize(ambiente)}: ${_listarItens((_acessosPorAmbienteImediato[ambiente] ?? const <String>{}).toList())}.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _observacaoImediatoController,
          decoration: const InputDecoration(
            labelText: 'Observação (opcional)',
            hintText: 'Descreva algum ponto relevante do local imediato...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
          onChanged: (_) => _atualizarTextoImediato(),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _buildAiContextLocal({
    required String titulo,
    required String local,
    required List<VestigioLocalModel> vestigios,
    required bool? pisoSeco,
    required bool? pisoUmido,
    required bool? pisoMolhado,
    required bool? iluminacaoArtificial,
    required bool? iluminacaoNatural,
    required bool? iluminacaoAusente,
  }) {
    final partes = <String>[];

    final piso = <String>[];
    if (pisoSeco == true) piso.add('seco');
    if (pisoUmido == true) piso.add('úmido');
    if (pisoMolhado == true) piso.add('molhado');
    if (piso.isNotEmpty) partes.add('Piso: ${_listarItens(piso)}.');

    final iluminacao = <String>[];
    if (iluminacaoArtificial == true) iluminacao.add('artificial');
    if (iluminacaoNatural == true) iluminacao.add('natural');
    if (iluminacaoAusente == true) iluminacao.add('ausente');
    if (iluminacao.isNotEmpty) {
      partes.add('Iluminação: ${_listarItens(iluminacao)}.');
    }

    if (local == 'mediato') {
      if (_tipoRegiaoMediato != null) {
        partes.add('Região: $_tipoRegiaoMediato.');
      }
      if (_tipoImovelMediato != null) {
        partes.add('Imóvel/local: $_tipoImovelMediato.');
      }
      if (_infraestruturaMediato.isNotEmpty) {
        partes.add(
          'Infraestrutura: ${_listarItens(_infraestruturaMediato.toList())}.',
        );
      }
      if (_delimitacaoMediato.isNotEmpty) {
        partes.add(
          'Delimitação: ${_listarItens(_delimitacaoMediato.toList())}.',
        );
      }
      final acessos = _gerarDescricaoViasAcessoMediato();
      if (acessos.isNotEmpty) partes.add('Acessos: $acessos.');
    }

    if (local == 'imediato') {
      if (_abrangenciaImediato != null) {
        partes.add('Abrangência: $_abrangenciaImediato.');
      }
      if (_ambientesImediato.isNotEmpty) {
        partes.add('Ambientes: ${_listarItens(_ambientesImediato.toList())}.');
      }
      if (_estadoConservacaoImediato != null) {
        partes.add('Conservação: $_estadoConservacaoImediato.');
      }
      if (_observacaoImediatoController.text.trim().isNotEmpty) {
        partes.add(
          'Observações: ${_observacaoImediatoController.text.trim()}.',
        );
      }
    }

    if (vestigios.isNotEmpty) {
      final descricoes = vestigios
          .map((v) => v.descricao?.trim())
          .whereType<String>()
          .where((d) => d.isNotEmpty)
          .toList();
      if (descricoes.isNotEmpty) {
        partes.add('Vestígios observados: ${_listarItens(descricoes)}.');
      }
    }

    return partes.join('\n');
  }

  List<String> _imagePathsForLocal(String local) {
    if (local == 'mediato') return _fotosVistaAmplaPaths;
    if (local == 'imediato') return _fotosVistaAmplaImediatoPaths;
    return const [];
  }

  void _replaceControllerText(TextEditingController controller, String text) {
    setState(() => controller.text = text.trim());
  }

  void _appendControllerText(TextEditingController controller, String text) {
    final atual = controller.text.trim();
    setState(() {
      controller.text = atual.isEmpty
          ? text.trim()
          : '$atual\n\n${text.trim()}';
    });
  }

  bool get _podeAnalisarManchasSangue =>
      widget.ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
      widget.ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer;

  Future<void> _abrirAnaliseManchasSangue() async {
    final initialContext = _buildAiContextLocal(
      titulo: 'Local Imediato',
      local: 'imediato',
      vestigios: _vestigiosImediato,
      pisoSeco: _pisoSecoImediato,
      pisoUmido: _pisoUmidoImediato,
      pisoMolhado: _pisoMolhadoImediato,
      iluminacaoArtificial: _iluminacaoArtificialImediato,
      iluminacaoNatural: _iluminacaoNaturalImediato,
      iluminacaoAusente: _iluminacaoAusenteImediato,
    );

    final overviewImages = <String>[
      ..._fotosVistaAmplaPaths,
      ..._fotosVistaAmplaImediatoPaths,
    ];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BloodstainAnalysisScreen(
          fichaId: widget.ficha.id,
          initialContextText: initialContext,
          initialOverviewImagePaths: overviewImages,
        ),
      ),
    );
  }

  Widget _buildSecaoLocalDetalhado({
    required String titulo,
    required String local,
    required TextEditingController descricaoController,
    required TextEditingController marcoZeroDescricaoController,
    required TextEditingController marcoZeroXController,
    required TextEditingController marcoZeroYController,
    required List<VestigioLocalModel> vestigios,
    required bool semVestigios,
    required ValueChanged<bool> onSemVestigiosChanged,
    required VoidCallback onAdicionarVestigio,
    required void Function(String id) onRemoverVestigio,
    required void Function(VestigioLocalModel existente) onEditarVestigio,
    required bool? pisoSeco,
    required bool? pisoUmido,
    required bool? pisoMolhado,
    required bool? iluminacaoArtificial,
    required bool? iluminacaoNatural,
    required bool? iluminacaoAusente,
    required void Function(bool?, String) onPisoChanged,
    required void Function(bool?, String) onIluminacaoChanged,
    bool showMarcoZero = true,
    bool usarFluxoVestigioMediato = false,
    bool exibirSinaisArrombamento = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_localEmViaPublica != true && local == 'mediato')
                  _buildDescricaoAssistidaMediato(),
                if (_localEmViaPublica != true && local == 'imediato')
                  _buildDescricaoAssistidaImediato(),
                const Text('Descrição (do geral para o particular)'),
                const SizedBox(height: 4),
                Text(
                  _localEmViaPublica != true &&
                          (local == 'mediato' || local == 'imediato')
                      ? 'Texto gerado automaticamente. Edite à vontade.'
                      : 'Descreva o local...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    hintText: 'Descreva o local...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: null,
                  minLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 8),
                AiSuggestionButton(
                  fieldLabel: 'Descrição do $titulo',
                  currentText: descricaoController.text,
                  currentTextBuilder: () => descricaoController.text,
                  profile: AiSuggestionProfile.furtoDanoExameLocal,
                  contextTextBuilder: () => _buildAiContextLocal(
                    titulo: titulo,
                    local: local,
                    vestigios: vestigios,
                    pisoSeco: pisoSeco,
                    pisoUmido: pisoUmido,
                    pisoMolhado: pisoMolhado,
                    iluminacaoArtificial: iluminacaoArtificial,
                    iluminacaoNatural: iluminacaoNatural,
                    iluminacaoAusente: iluminacaoAusente,
                  ),
                  imagePathsBuilder: () => _imagePathsForLocal(local),
                  onReplace: (text) =>
                      _replaceControllerText(descricaoController, text),
                  onAppend: (text) =>
                      _appendControllerText(descricaoController, text),
                ),
                if (exibirSinaisArrombamento) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (_localEmViaPublica == true) ...[
                    Text(
                      'Sinais de arrombamento não se aplicam para via pública/área aberta.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ] else ...[
                    _buildCheckboxRow('Sinais de Arrombamento', [
                      {
                        'label': 'Sim',
                        'value': _sinaisArrombamentoSim ?? false,
                        'onChanged': (value) =>
                            _onSinaisArrombamentoChanged(value, 'sim'),
                      },
                      {
                        'label': 'Não',
                        'value': _sinaisArrombamentoNao ?? false,
                        'onChanged': (value) =>
                            _onSinaisArrombamentoChanged(value, 'nao'),
                      },
                      {
                        'label': 'Não Se Aplica',
                        'value': _sinaisArrombamentoNaoSeAplica ?? false,
                        'onChanged': (value) =>
                            _onSinaisArrombamentoChanged(value, 'naoSeAplica'),
                      },
                    ]),
                    if (_sinaisArrombamentoSim == true) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sinaisArrombamentoController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição dos Sinais de Arrombamento',
                          hintText: 'Descreva os sinais de arrombamento...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ],
                ],
                if (!usarFluxoVestigioMediato && showMarcoZero) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Marco Zero',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: marcoZeroDescricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do Marco Zero',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: null,
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: marcoZeroXController,
                          decoration: const InputDecoration(
                            labelText: 'Coordenada X',
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Ex: -23,5',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: marcoZeroYController,
                          decoration: const InputDecoration(
                            labelText: 'Coordenada Y',
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Ex: -46,6',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Condições do Piso',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoSeco ?? false,
                          onChanged: (value) => onPisoChanged(value, 'seco'),
                        ),
                        const Text('Seco'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoUmido ?? false,
                          onChanged: (value) => onPisoChanged(value, 'umido'),
                        ),
                        const Text('Úmido'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoMolhado ?? false,
                          onChanged: (value) => onPisoChanged(value, 'molhado'),
                        ),
                        const Text('Molhado'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Iluminação',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoArtificial ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'artificial'),
                        ),
                        const Text('Artificial'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoNatural ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'natural'),
                        ),
                        const Text('Natural'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoAusente ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'ausente'),
                        ),
                        const Text('Ausente'),
                      ],
                    ),
                  ],
                ),
                if (usarFluxoVestigioMediato) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Há vestígios neste local?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<bool>(
                    groupValue: _temVestigiosMediato,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _temVestigiosMediato = value;
                        _semVestigiosMediato = !value;
                        if (!value) {
                          _vestigiosMediato.clear();
                          marcoZeroDescricaoController.clear();
                          marcoZeroXController.text = '0';
                          marcoZeroYController.text = '0';
                        }
                      });
                    },
                    child: Row(
                      children: const [
                        Row(children: [Radio<bool>(value: true), Text('Sim')]),
                        SizedBox(width: 16),
                        Row(children: [Radio<bool>(value: false), Text('Não')]),
                      ],
                    ),
                  ),
                  if (_temVestigiosMediato == true && showMarcoZero) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Marco Zero',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Defina o marco zero: ponto de referência utilizado para amarração e posicionamento dos vestígios.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: marcoZeroDescricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do Marco Zero',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: null,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: marcoZeroXController,
                            decoration: const InputDecoration(
                              labelText: 'Coordenada X',
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Ex: -23,5',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: marcoZeroYController,
                            decoration: const InputDecoration(
                              labelText: 'Coordenada Y',
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Ex: -46,6',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sem vestígios neste local'),
                    value: semVestigios,
                    onChanged: (value) {
                      onSemVestigiosChanged(value);
                    },
                  ),
                ],
                if ((usarFluxoVestigioMediato &&
                        _temVestigiosMediato == true) ||
                    (!usarFluxoVestigioMediato && !semVestigios)) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onAdicionarVestigio,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar vestígio'),
                    ),
                  ),
                  if (vestigios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhum vestígio adicionado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ...vestigios.map(
                    (v) => Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Vestígio',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar',
                                      onPressed: () => onEditarVestigio(v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Remover',
                                      onPressed: () => onRemoverVestigio(v.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (v.nome != null && v.nome!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Nome: ${v.nome}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (v.descricao != null && v.descricao!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Descrição: ${v.descricao}'),
                              ),
                            if (v.coordenadaX != null && v.coordenadaY != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Coordenadas: X=${v.coordenadaX}, Y=${v.coordenadaY}',
                                ),
                              ),
                            if (v.alturaRelacaoPiso != null &&
                                v.alturaRelacaoPiso!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Altura em relação ao piso: ${v.alturaRelacaoPiso}',
                                ),
                              ),
                            if (v.fotosVinculadasPaths.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Fotografias vinculadas: ${v.fotosVinculadasPaths.length}',
                                ),
                              ),
                            if (v.tipoAcao != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Tipo: ${v.tipoAcao!.label}'),
                              ),
                            if (v.tipoAcao == TipoAcaoVestigio.coletado) ...[
                              if (v.coletadoPor != null &&
                                  v.coletadoPor!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Coletado por: ${v.coletadoPor}'),
                                ),
                              if (v.dataHoraColeta != null &&
                                  v.dataHoraColeta!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Data/Hora coleta: ${v.dataHoraColeta}',
                                  ),
                                ),
                              if (v.tipoDestino != null && v.destinoId != null)
                                FutureBuilder<dynamic>(
                                  future:
                                      v.tipoDestino ==
                                          TipoDestinoVestigio.unidade
                                      ? _unidadeService.listarUnidades()
                                      : _laboratorioService
                                            .listarLaboratorios(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final lista = snapshot.data as List;
                                      final items = lista.where(
                                        (item) => item.id == v.destinoId,
                                      );
                                      if (items.isNotEmpty) {
                                        final item = items.first;
                                        final nome =
                                            v.tipoDestino ==
                                                TipoDestinoVestigio.unidade
                                            ? (item as UnidadeModel).nome
                                            : (item as LaboratorioModel).nome;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Destino: ${v.tipoDestino!.label} - $nome',
                                          ),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              if (v.numeroLacre != null &&
                                  v.numeroLacre!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Número do lacre: ${v.numeroLacre}',
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarInstrucoes() {
    final isViaPublica = _localEmViaPublica == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instruções - Descrição do Local'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: isViaPublica
                ? [
                    const Text(
                      'Para local em via pública ou área aberta:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Descreva o trecho da via (rua, avenida, praça, beco etc.);',
                    ),
                    const Text(
                      '• Tipo de piso (calçada, asfalto, terra) e condições (seco, úmido, molhado);',
                    ),
                    const Text(
                      '• Iluminação (artificial, natural ou ausente);',
                    ),
                    const Text(
                      '• Ponto exato do fato (local imediato) e vestígios com posição no cenário.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Use as descrições em texto livre por local (Mediato, Imediato, Relacionado) e registre os vestígios em cada um. Itens de imóvel (sinais de arrombamento, tipo de imóvel etc.) não se aplicam e foram ocultados.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ]
                : [
                    const Text(
                      'Descrever objetivamente os seguintes itens:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Classificar o tipo de imóvel (ex.: imóvel residencial, comercial, industrial, religioso, educacional, prisional etc.);',
                    ),
                    const Text(
                      '• Descrever o tipo de delimitação (Ex.: muros de alvenaria);',
                    ),
                    const Text(
                      '• Descrever os acessos de entrada e saída (Ex.: portão e portas); e',
                    ),
                    const Text(
                      '• Descrever as estruturas pertinentes ao exame (Ex.: cadeados, fechaduras, paredes, janelas e coberturas).',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exemplo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tratava-se de prédio comercial de 03 pavimentos. Não existia muro ou qualquer outro tipo de cerca delimitando o terreno. As portas eram metálicas de enrolar, sendo que em duas dessas portas existiam portas de vidro temperado, internamente às portas metálicas.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descrição do Local'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInstrucoes,
            tooltip: 'Instruções de uso',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título da seção
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Tipo de local (apenas no mediato)
            if (_etapaLocalAtual == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'O local é em imóvel (fechado) ou em via pública / área aberta?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<bool>(
                      groupValue: _localEmViaPublica,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _localEmViaPublica = value;
                            if (value == true) {
                              _sinaisArrombamentoNaoSeAplica = true;
                              _sinaisArrombamentoSim = false;
                              _sinaisArrombamentoNao = false;
                            }
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Radio<bool>(value: false),
                              const Expanded(
                                child: Text(
                                  'Imóvel (fechado)',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Radio<bool>(value: true),
                              const Expanded(
                                child: Text(
                                  'Via pública ou área aberta',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Foto(s) vista ampla por etapa (mediato/imediato)
            if (_etapaLocalAtual == 0 || _etapaLocalAtual == 1)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto(s) vista ampla do local',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _etapaLocalAtual == 0
                          ? (_localEmViaPublica == true
                                ? 'Vista geral do local mediato (ex.: trecho da via, ponto do fato).'
                                : 'Ex.: fachada ou porção anterior do imóvel (local mediato).')
                          : 'Registre a vista ampla específica do local imediato.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final foto = await _imagePicker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 90,
                            );
                            if (foto != null && mounted) {
                              final path = await _persistirFotoVestigio(foto);
                              if (path != null) {
                                setState(() {
                                  if (_etapaLocalAtual == 0) {
                                    _fotosVistaAmplaPaths.add(path);
                                  } else {
                                    _fotosVistaAmplaImediatoPaths.add(path);
                                  }
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Câmera'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              allowMultiple: true,
                            );
                            if (result != null &&
                                result.files.isNotEmpty &&
                                mounted) {
                              for (final f in result.files) {
                                if (f.path == null) continue;
                                final path = await _persistirFotoVestigio(
                                  XFile(f.path!),
                                );
                                if (path != null) {
                                  setState(() {
                                    if (_etapaLocalAtual == 0) {
                                      _fotosVistaAmplaPaths.add(path);
                                    } else {
                                      _fotosVistaAmplaImediatoPaths.add(path);
                                    }
                                  });
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeria'),
                        ),
                      ],
                    ),
                    if ((_etapaLocalAtual == 0
                            ? _fotosVistaAmplaPaths
                            : _fotosVistaAmplaImediatoPaths)
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            (_etapaLocalAtual == 0
                                    ? _fotosVistaAmplaPaths
                                    : _fotosVistaAmplaImediatoPaths)
                                .asMap()
                                .entries
                                .map((e) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(e.value),
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade800,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          onPressed: () {
                                            setState(
                                              () =>
                                                  (_etapaLocalAtual == 0
                                                          ? _fotosVistaAmplaPaths
                                                          : _fotosVistaAmplaImediatoPaths)
                                                      .removeAt(e.key),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                })
                                .toList(),
                      ),
                    ],
                    if (_etapaLocalAtual == 1 &&
                        _podeAnalisarManchasSangue) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Análise assistiva de manchas de sangue',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Abra a ferramenta para enviar fotos amplas e aproximadas da mancha, informar a superfície e obter uma leitura assistiva conservadora.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _abrirAnaliseManchasSangue,
                                icon: const Icon(Icons.bloodtype_outlined),
                                label: const Text(
                                  'Abrir análise de manchas de sangue',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Tabela de dados
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  // Descrição dos Locais (Mediato, Imediato, Relacionado) + Vestígios
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Descrição por Área:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Descreva os Locais Mediato, Imediato e Relacionado do geral para o particular. Registre aqui vestígios observados durante a descrição física de cada área.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _tituloEtapaLocal,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_etapaLocalAtual == 0)
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Mediato',
                            local: 'mediato',
                            showMarcoZero:
                                widget.ficha.tipoOcorrencia !=
                                TipoOcorrencia.morteEsclarecer,
                            usarFluxoVestigioMediato: true,
                            descricaoController: _descricaoMediatoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoMediatoController,
                            marcoZeroXController: _marcoZeroXMediatoController,
                            marcoZeroYController: _marcoZeroYMediatoController,
                            vestigios: _vestigiosMediato,
                            semVestigios: _semVestigiosMediato,
                            onSemVestigiosChanged: (value) {},
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('mediato'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('mediato', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'mediato',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoMediato,
                            pisoUmido: _pisoUmidoMediato,
                            pisoMolhado: _pisoMolhadoMediato,
                            iluminacaoArtificial: _iluminacaoArtificialMediato,
                            iluminacaoNatural: _iluminacaoNaturalMediato,
                            iluminacaoAusente: _iluminacaoAusenteMediato,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'mediato'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(value, tipo, 'mediato'),
                          ),
                        if (_etapaLocalAtual == 1)
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Imediato',
                            local: 'imediato',
                            exibirSinaisArrombamento: true,
                            showMarcoZero:
                                widget.ficha.tipoOcorrencia !=
                                TipoOcorrencia.morteEsclarecer,
                            descricaoController: _descricaoImediatoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoImediatoController,
                            marcoZeroXController: _marcoZeroXImediatoController,
                            marcoZeroYController: _marcoZeroYImediatoController,
                            vestigios: _vestigiosImediato,
                            semVestigios: _semVestigiosImediato,
                            onSemVestigiosChanged: (value) {
                              setState(() {
                                _semVestigiosImediato = value;
                                if (value) _vestigiosImediato.clear();
                              });
                            },
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('imediato'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('imediato', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'imediato',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoImediato,
                            pisoUmido: _pisoUmidoImediato,
                            pisoMolhado: _pisoMolhadoImediato,
                            iluminacaoArtificial: _iluminacaoArtificialImediato,
                            iluminacaoNatural: _iluminacaoNaturalImediato,
                            iluminacaoAusente: _iluminacaoAusenteImediato,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'imediato'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(value, tipo, 'imediato'),
                          ),
                        if (_etapaLocalAtual == 2)
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Relacionado',
                            local: 'relacionado',
                            showMarcoZero:
                                widget.ficha.tipoOcorrencia !=
                                TipoOcorrencia.morteEsclarecer,
                            descricaoController:
                                _descricaoRelacionadoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoRelacionadoController,
                            marcoZeroXController:
                                _marcoZeroXRelacionadoController,
                            marcoZeroYController:
                                _marcoZeroYRelacionadoController,
                            vestigios: _vestigiosRelacionado,
                            semVestigios: _semVestigiosRelacionado,
                            onSemVestigiosChanged: (value) {
                              setState(() {
                                _semVestigiosRelacionado = value;
                                if (value) _vestigiosRelacionado.clear();
                              });
                            },
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('relacionado'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('relacionado', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'relacionado',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoRelacionado,
                            pisoUmido: _pisoUmidoRelacionado,
                            pisoMolhado: _pisoMolhadoRelacionado,
                            iluminacaoArtificial:
                                _iluminacaoArtificialRelacionado,
                            iluminacaoNatural: _iluminacaoNaturalRelacionado,
                            iluminacaoAusente: _iluminacaoAusenteRelacionado,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'relacionado'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(
                                  value,
                                  tipo,
                                  'relacionado',
                                ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Demais Observações
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demais Observações:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _demaisObservacoesController,
                          decoration: const InputDecoration(
                            hintText: 'Digite observações adicionais...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 4,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _avancarEtapaLocal,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _etapaLocalAtual == 0
                          ? 'Salvar e Ir para Local Imediato'
                          : _etapaLocalAtual == 1
                          ? 'Salvar e Continuar'
                          : 'Salvar',
                    ),
            ),
            const SizedBox(
              height: 80,
            ), // Padding extra no final para garantir que o botão fique visível
          ],
        ),
      ),
    );
  }
}
