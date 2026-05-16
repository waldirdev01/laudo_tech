import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/detatlhes_local.dart';
import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/marco_zero_local_model.dart';
import '../models/metodo_posicionamento_model.dart';
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
  final _scrollController = ScrollController();
  bool _salvando = false;
  bool _modoRapido = false;
  int _etapaLocalAtual = 0; // 0=mediato, 1=imediato, 2=relacionado
  bool? _temVestigiosMediato;
  MetodoPosicionamentoVestigio _metodoPosicionamentoMediato =
      MetodoPosicionamentoVestigio.nenhum;
  MetodoPosicionamentoVestigio _metodoPosicionamentoRelacionado =
      MetodoPosicionamentoVestigio.nenhum;

  // Marco Zero por local
  final _marcoZeroDescricaoMediatoController = TextEditingController();
  final _marcoZeroXMediatoController = TextEditingController();
  final _marcoZeroYMediatoController = TextEditingController();
  final _marcoZeroDescricaoImediatoController = TextEditingController();
  final _marcoZeroXImediatoController = TextEditingController();
  final _marcoZeroYImediatoController = TextEditingController();
  final _marcoZeroDescricaoRelacionadoController = TextEditingController();
  final _marcoZeroXRelacionadoController = TextEditingController();
  final _marcoZeroYRelacionadoController = TextEditingController();

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
  String? _ambienteDestaqueImediato;
  final Map<String, Set<String>> _acessosPorAmbienteImediato = {};
  final Map<String, Set<String>> _comunicacaoAmbientesImediato = {};
  final Map<String, bool> _acessoExternoPorAmbienteImediato = {};
  final Map<String, TextEditingController> _marcoAmbienteDescricaoCtrls = {};
  final Map<String, TextEditingController> _marcoAmbienteXCtrls = {};
  final Map<String, TextEditingController> _marcoAmbienteYCtrls = {};
  final Map<String, TextEditingController> _consideracoesAmbienteCtrls = {};
  final Map<String, MetodoPosicionamentoVestigio>
  _metodosPosicionamentoAmbientesImediato = {};
  String? _ambienteAcessoSelecionado;
  String? _estadoConservacaoImediato;
  final _observacaoImediatoController = TextEditingController();

  static const _opcoesAbrangenciaImediato = [
    'único ambiente',
    'múltiplos ambientes',
  ];
  static const _tiposRapidosAmbienteImediato = [
    'sala',
    'quarto',
    'banheiro',
    'cozinha',
    'varanda',
    'corredor',
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
    'escada interna',
    'acesso livre (sem porta interna)',
  ];
  static const _opcoesComunicacaoEspecial = ['corredor'];

  // Vestígios por local
  List<VestigioLocalModel> _vestigiosMediato = [];
  List<VestigioLocalModel> _vestigiosImediato = [];
  List<VestigioLocalModel> _vestigiosRelacionado = [];
  bool _semVestigiosMediato = false;
  bool _semVestigiosImediato = false;
  bool _semVestigiosRelacionado = false;
  final List<String> _fotosVistaAmplaPaths = [];
  final List<String> _fotosVistaAmplaImediatoPaths = [];
  final Map<String, List<String>> _fotosVistaAmplaAmbientesImediato = {};
  final List<String> _fotosSinaisArrombamentoPaths = [];

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
      _abrangenciaImediato = dados.abrangenciaImediato;
      _ambientesImediato
        ..clear()
        ..addAll(dados.ambientesImediato ?? const []);
      _ambienteDestaqueImediato = dados.ambienteDestaqueImediato;
      _estadoConservacaoImediato = dados.estadoConservacaoImediato;
      _observacaoImediatoController.text = dados.observacaoImediato ?? '';
      _acessosPorAmbienteImediato
        ..clear()
        ..addAll(
          (dados.acessosPorAmbienteImediato ?? const {}).map(
            (key, value) => MapEntry(key, value.toSet()),
          ),
        );
      _comunicacaoAmbientesImediato
        ..clear()
        ..addAll(
          (dados.comunicacaoAmbientesImediato ?? const {}).map(
            (key, value) => MapEntry(key, value.toSet()),
          ),
        );
      _acessoExternoPorAmbienteImediato
        ..clear()
        ..addAll(dados.acessoExternoPorAmbienteImediato ?? const {});
      _metodoPosicionamentoMediato =
          dados.metodoPosicionamentoMediato ??
          _inferirMetodoPosicionamentoVestigios(
            dados.vestigiosMediato ?? const [],
            marcoZero: dados.marcoZeroMediato,
          );
      _metodoPosicionamentoRelacionado =
          dados.metodoPosicionamentoRelacionado ??
          _inferirMetodoPosicionamentoVestigios(
            dados.vestigiosRelacionado ?? const [],
            marcoZero: dados.marcoZeroRelacionado,
          );
      _metodosPosicionamentoAmbientesImediato
        ..clear()
        ..addAll(dados.metodosPosicionamentoAmbientesImediato ?? const {});
      _limparMarcoAmbienteControllers();
      for (final entry
          in (dados.marcosZeroAmbientesImediato ?? const {}).entries) {
        _marcoAmbienteDescricaoCtrls[entry.key] = TextEditingController(
          text: entry.value.descricao ?? '',
        );
        _marcoAmbienteXCtrls[entry.key] = TextEditingController(
          text: entry.value.coordenadaX ?? '0,0',
        );
        _marcoAmbienteYCtrls[entry.key] = TextEditingController(
          text: entry.value.coordenadaY ?? '0,0',
        );
      }
      _limparConsideracoesAmbienteControllers();
      for (final entry
          in (dados.consideracoesTecnicasAmbientesImediato ?? const {})
              .entries) {
        _consideracoesAmbienteCtrls[entry.key] = TextEditingController(
          text: entry.value,
        );
      }
      _marcoZeroDescricaoMediatoController.text =
          dados.marcoZeroMediato?.descricao ?? '';
      _marcoZeroXMediatoController.text =
          dados.marcoZeroMediato?.coordenadaX ?? '';
      _marcoZeroYMediatoController.text =
          dados.marcoZeroMediato?.coordenadaY ?? '';
      _marcoZeroDescricaoImediatoController.text =
          dados.marcoZeroImediato?.descricao ?? '';
      _marcoZeroXImediatoController.text =
          dados.marcoZeroImediato?.coordenadaX ?? '';
      _marcoZeroYImediatoController.text =
          dados.marcoZeroImediato?.coordenadaY ?? '';
      _marcoZeroDescricaoRelacionadoController.text =
          dados.marcoZeroRelacionado?.descricao ?? '';
      _marcoZeroXRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaX ?? '';
      _marcoZeroYRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaY ?? '';
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
      _fotosVistaAmplaAmbientesImediato
        ..clear()
        ..addAll(
          (dados.fotosVistaAmplaAmbientesImediato ?? const {}).map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        );
      _fotosSinaisArrombamentoPaths.clear();
      _fotosSinaisArrombamentoPaths.addAll(
        dados.fotosSinaisArrombamentoPaths ?? const [],
      );
      for (final ambiente in _ambientesImediato) {
        _metodosPosicionamentoAmbientesImediato.putIfAbsent(
          ambiente,
          () => _inferirMetodoPosicionamentoVestigios(
            _vestigiosImediato.where((v) => v.ambiente == ambiente).toList(),
            marcoZero:
                (dados.marcosZeroAmbientesImediato ?? const {})[ambiente],
          ),
        );
      }
      _sincronizarAcessosPorAmbienteImediato();
    } else if (widget.ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer) {
      // Pré-popular vestígios padrão para Morte a Esclarecer (apenas na primeira abertura)
      _classificacaoImediato = true;
      _vestigiosImediato = _vestigiosPadraoMorteEsclarecer();
    }
  }

  MetodoPosicionamentoVestigio _inferirMetodoPosicionamentoVestigios(
    List<VestigioLocalModel> vestigios, {
    MarcoZeroLocalModel? marcoZero,
  }) {
    if (vestigios.any((v) => v.latitude != null && v.longitude != null)) {
      return MetodoPosicionamentoVestigio.gps;
    }
    final marcoInformado =
        (marcoZero?.coordenadaX ?? '').trim().isNotEmpty ||
        (marcoZero?.coordenadaY ?? '').trim().isNotEmpty;
    if (marcoInformado ||
        vestigios.any(
          (v) =>
              (v.coordenadaX ?? '').trim().isNotEmpty ||
              (v.coordenadaY ?? '').trim().isNotEmpty,
        )) {
      return MetodoPosicionamentoVestigio.marcoZero;
    }
    return MetodoPosicionamentoVestigio.nenhum;
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
      _rolarParaInicio();
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
        _rolarParaInicio();
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

  void _rolarParaInicio() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
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
    _scrollController.dispose();
    _limparMarcoAmbienteControllers();
    _limparConsideracoesAmbienteControllers();
    super.dispose();
  }

  void _limparMarcoAmbienteControllers() {
    for (final controller in _marcoAmbienteDescricaoCtrls.values) {
      controller.dispose();
    }
    for (final controller in _marcoAmbienteXCtrls.values) {
      controller.dispose();
    }
    for (final controller in _marcoAmbienteYCtrls.values) {
      controller.dispose();
    }
    _marcoAmbienteDescricaoCtrls.clear();
    _marcoAmbienteXCtrls.clear();
    _marcoAmbienteYCtrls.clear();
  }

  void _limparConsideracoesAmbienteControllers() {
    for (final controller in _consideracoesAmbienteCtrls.values) {
      controller.dispose();
    }
    _consideracoesAmbienteCtrls.clear();
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
            _fotosSinaisArrombamentoPaths.clear();
          }
          break;
        case 'naoSeAplica':
          _sinaisArrombamentoNaoSeAplica = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNao = false;
            _sinaisArrombamentoController.clear();
            _fotosSinaisArrombamentoPaths.clear();
          }
          break;
      }
    });
  }

  Future<String?> _persistirFotoVestigio(XFile arquivo) async {
    final messenger = ScaffoldMessenger.of(context);
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
      await PhotoBackupService.saveToGalleryWithFeedback(messenger, destino.path);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _adicionarOuEditarVestigio(
    String secao, {
    VestigioLocalModel? existente,
    String? ambienteInicial,
  }) async {
    final inclusaoContinua = existente == null;

    final resultado = await Navigator.of(context).push<VestigioLocalModel>(
      MaterialPageRoute(
        builder: (ctx) => VestigioLocalFormScreen(
          fichaId: widget.ficha.id,
          vestigioExistente: existente,
          ambientesDisponiveis: secao == 'imediato'
              ? _ambientesImediato.toList()
              : const [],
          ambienteInicial: secao == 'imediato' ? ambienteInicial : null,
          modoRapido: _modoRapido,
          metodoPosicionamentoPadrao: _metodoPosicionamentoVestigio(
            secao,
            ambiente: ambienteInicial ?? existente?.ambiente,
          ),
          avisoContextoGps: _avisoGpsVestigio(
            secao,
            ambiente: ambienteInicial ?? existente?.ambiente,
          ),
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

  MetodoPosicionamentoVestigio _metodoPosicionamentoVestigio(
    String secao, {
    String? ambiente,
  }) {
    switch (secao) {
      case 'mediato':
        return _metodoPosicionamentoMediato;
      case 'relacionado':
        return _metodoPosicionamentoRelacionado;
      case 'imediato':
        if (ambiente == null) {
          return MetodoPosicionamentoVestigio.nenhum;
        }
        return _metodosPosicionamentoAmbientesImediato[ambiente] ??
            MetodoPosicionamentoVestigio.nenhum;
      default:
        return MetodoPosicionamentoVestigio.nenhum;
    }
  }

  String? _avisoGpsVestigio(String secao, {String? ambiente}) {
    final metodo = _metodoPosicionamentoVestigio(secao, ambiente: ambiente);
    if (metodo != MetodoPosicionamentoVestigio.gps) return null;
    if (_localEmViaPublica == false &&
        (secao == 'mediato' || secao == 'relacionado')) {
      return 'Ambiente interno ou imóvel fechado. O uso de GPS pode apresentar baixa confiabilidade neste contexto.';
    }
    if (_localEmViaPublica == false && secao == 'imediato') {
      final nome = (ambiente ?? '').trim().toLowerCase();
      if (nome.isNotEmpty && nome != 'varanda') {
        return 'Ambiente interno. O uso de GPS pode apresentar baixa confiabilidade neste contexto.';
      }
    }
    return null;
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
        abrangenciaImediato: _abrangenciaImediato,
        ambientesImediato: _ambientesImediato.isEmpty
            ? null
            : _ambientesImediato.toList(),
        ambienteDestaqueImediato:
            _ambienteDestaqueImediato == null ||
                !_ambientesImediato.contains(_ambienteDestaqueImediato)
            ? null
            : _ambienteDestaqueImediato,
        estadoConservacaoImediato: _estadoConservacaoImediato,
        observacaoImediato: _observacaoImediatoController.text.trim().isEmpty
            ? null
            : _observacaoImediatoController.text.trim(),
        acessosPorAmbienteImediato: _acessosPorAmbienteImediato.isEmpty
            ? null
            : _acessosPorAmbienteImediato.map(
                (key, value) => MapEntry(key, value.toList()),
              ),
        comunicacaoAmbientesImediato: _comunicacaoAmbientesImediato.isEmpty
            ? null
            : _comunicacaoAmbientesImediato.map(
                (key, value) => MapEntry(key, value.toList()),
              ),
        acessoExternoPorAmbienteImediato:
            _acessoExternoPorAmbienteImediato.isEmpty
            ? null
            : Map<String, bool>.from(_acessoExternoPorAmbienteImediato),
        marcosZeroAmbientesImediato: _buildMarcosZeroAmbientesImediato(),
        metodoPosicionamentoMediato: _metodoPosicionamentoMediato,
        metodoPosicionamentoRelacionado: _metodoPosicionamentoRelacionado,
        metodosPosicionamentoAmbientesImediato:
            _metodosPosicionamentoAmbientesImediato.isEmpty
            ? null
            : Map<String, MetodoPosicionamentoVestigio>.from(
                _metodosPosicionamentoAmbientesImediato,
              ),
        consideracoesTecnicasAmbientesImediato:
            _buildConsideracoesTecnicasAmbientesImediato(),
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
        marcoZeroMediato: (_classificacaoMediato == true)
            ? _buildMarcoZero(
                _marcoZeroDescricaoMediatoController,
                _marcoZeroXMediatoController,
                _marcoZeroYMediatoController,
              )
            : null,
        marcoZeroImediato: (_classificacaoImediato == true)
            ? _buildMarcoZero(
                _marcoZeroDescricaoImediatoController,
                _marcoZeroXImediatoController,
                _marcoZeroYImediatoController,
              )
            : null,
        marcoZeroRelacionado: (_classificacaoRelacionado == true)
            ? _buildMarcoZero(
                _marcoZeroDescricaoRelacionadoController,
                _marcoZeroXRelacionadoController,
                _marcoZeroYRelacionadoController,
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
        fotosVistaAmplaAmbientesImediato:
            _buildFotosVistaAmplaAmbientesImediato(),
        fotosSinaisArrombamentoPaths: _sinaisArrombamentoSim == true
            ? (_fotosSinaisArrombamentoPaths.isEmpty
                  ? null
                  : _fotosSinaisArrombamentoPaths)
            : null,
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
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

    if (_ambienteDestaqueImediato != null &&
        _ambientesImediato.contains(_ambienteDestaqueImediato)) {
      partes.add(
        'Foi indicado como ambiente de maior relevância na cena: $_ambienteDestaqueImediato.',
      );
    }

    final descricaoAcessos = _gerarDescricaoAcessosInternosImediato();
    if (descricaoAcessos.isNotEmpty) {
      partes.add(descricaoAcessos);
    }

    final consideracoes = _consideracoesAmbienteCtrls.entries
        .map((entry) => MapEntry(entry.key, entry.value.text.trim()))
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => '${_capitalize(entry.key)}: ${entry.value}')
        .toList();
    if (consideracoes.isNotEmpty) {
      partes.add(
        'Foram registradas as seguintes considerações técnicas por ambiente: ${_listarItens(consideracoes)}.',
      );
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
      final acessos = _acessosPorAmbienteImediato[ambiente] ?? const <String>{};
      final comunicacoes =
          _comunicacaoAmbientesImediato[ambiente] ?? const <String>{};
      final possuiAcessoExterno =
          _acessoExternoPorAmbienteImediato[ambiente] == true;
      final partes = <String>[];
      if (possuiAcessoExterno) {
        partes.add('possuía acesso externo');
      }
      if (comunicacoes.isNotEmpty) {
        partes.add('comunicava-se com ${_listarItens(comunicacoes.toList())}');
      }
      final acessosValidos = acessos
          .where((acesso) => acesso != 'corredor interno')
          .toList();
      if (acessosValidos.isNotEmpty) {
        partes.add('por meio de ${_listarItens(acessosValidos)}');
      }
      if (partes.isEmpty) continue;
      descricoes.add('${_capitalize(ambiente)}: ${partes.join(', ')}');
    }
    if (descricoes.isEmpty) return '';
    return 'Quanto aos acessos dos ambientes, ${_listarItens(descricoes)}.';
  }

  void _sincronizarAcessosPorAmbienteImediato() {
    final comunicacoesPermitidas = {
      ..._ambientesImediato,
      ..._opcoesComunicacaoEspecial,
    };
    _acessosPorAmbienteImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    _comunicacaoAmbientesImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    _acessoExternoPorAmbienteImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    _metodosPosicionamentoAmbientesImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    for (final ambiente in _consideracoesAmbienteCtrls.keys.toList()) {
      if (_ambientesImediato.contains(ambiente)) continue;
      _consideracoesAmbienteCtrls.remove(ambiente)?.dispose();
    }
    _fotosVistaAmplaAmbientesImediato.removeWhere(
      (ambiente, _) => !_ambientesImediato.contains(ambiente),
    );
    for (final ambiente in _marcoAmbienteDescricaoCtrls.keys.toList()) {
      if (_ambientesImediato.contains(ambiente)) continue;
      _marcoAmbienteDescricaoCtrls.remove(ambiente)?.dispose();
      _marcoAmbienteXCtrls.remove(ambiente)?.dispose();
      _marcoAmbienteYCtrls.remove(ambiente)?.dispose();
    }
    for (final ambiente in _ambientesImediato) {
      _acessosPorAmbienteImediato.putIfAbsent(ambiente, () => <String>{});
      _comunicacaoAmbientesImediato.putIfAbsent(ambiente, () => <String>{});
      _acessoExternoPorAmbienteImediato.putIfAbsent(ambiente, () => false);
      if (_acessosPorAmbienteImediato[ambiente]!.remove('corredor interno')) {
        _comunicacaoAmbientesImediato[ambiente]!.add('corredor');
      }
      _marcoAmbienteDescricaoCtrls.putIfAbsent(
        ambiente,
        () => TextEditingController(),
      );
      _marcoAmbienteXCtrls.putIfAbsent(
        ambiente,
        () => TextEditingController(text: '0,0'),
      );
      _marcoAmbienteYCtrls.putIfAbsent(
        ambiente,
        () => TextEditingController(text: '0,0'),
      );
      _consideracoesAmbienteCtrls.putIfAbsent(
        ambiente,
        () => TextEditingController(),
      );
      _metodosPosicionamentoAmbientesImediato.putIfAbsent(
        ambiente,
        () => MetodoPosicionamentoVestigio.nenhum,
      );
      _fotosVistaAmplaAmbientesImediato.putIfAbsent(ambiente, () => <String>[]);
      _comunicacaoAmbientesImediato[ambiente]!.removeWhere(
        (outro) => !comunicacoesPermitidas.contains(outro) || outro == ambiente,
      );
    }
    if (_ambienteDestaqueImediato != null &&
        !_ambientesImediato.contains(_ambienteDestaqueImediato)) {
      _ambienteDestaqueImediato = null;
    }
    if (_ambienteAcessoSelecionado != null &&
        !_ambientesImediato.contains(_ambienteAcessoSelecionado)) {
      _ambienteAcessoSelecionado = null;
    }
    _ambienteAcessoSelecionado ??= _ambientesImediato.isEmpty
        ? null
        : _ambientesImediato.first;
  }

  List<String> _opcoesComunicacaoParaAmbiente(String ambienteAtual) {
    final opcoes = <String>[
      ..._ambientesImediato.where((ambiente) => ambiente != ambienteAtual),
    ];
    for (final especial in _opcoesComunicacaoEspecial) {
      if (especial != ambienteAtual && !opcoes.contains(especial)) {
        opcoes.add(especial);
      }
    }
    return opcoes;
  }

  List<VestigioLocalModel> _vestigiosOrdenadosPorAmbiente(
    String local,
    List<VestigioLocalModel> vestigios,
  ) {
    if (local != 'imediato') return vestigios;
    final ordenados = [...vestigios];
    ordenados.sort((a, b) => (a.ambiente ?? '').compareTo(b.ambiente ?? ''));
    return ordenados;
  }

  Map<String, MarcoZeroLocalModel>? _buildMarcosZeroAmbientesImediato() {
    final marcos = <String, MarcoZeroLocalModel>{};
    for (final ambiente in _ambientesImediato) {
      final marco = _buildMarcoZeroAmbiente(ambiente);
      if (marco == null) continue;
      marcos[ambiente] = marco;
    }
    return marcos.isEmpty ? null : marcos;
  }

  MarcoZeroLocalModel? _buildMarcoZeroAmbiente(String ambiente) {
    final descricao = _marcoAmbienteDescricaoCtrls[ambiente]?.text.trim() ?? '';
    final x = _marcoAmbienteXCtrls[ambiente]?.text.trim() ?? '';
    final y = _marcoAmbienteYCtrls[ambiente]?.text.trim() ?? '';
    final xPadrao = x.isEmpty || x == '0,0';
    final yPadrao = y.isEmpty || y == '0,0';
    if (descricao.isEmpty && xPadrao && yPadrao) return null;
    return MarcoZeroLocalModel(
      descricao: descricao.isEmpty ? null : descricao,
      coordenadaX: xPadrao ? '0,0' : x,
      coordenadaY: yPadrao ? '0,0' : y,
    );
  }

  Map<String, List<String>>? _buildFotosVistaAmplaAmbientesImediato() {
    final fotos = <String, List<String>>{};
    for (final entry in _fotosVistaAmplaAmbientesImediato.entries) {
      if (entry.value.isEmpty) continue;
      fotos[entry.key] = List<String>.from(entry.value);
    }
    return fotos.isEmpty ? null : fotos;
  }

  Map<String, String>? _buildConsideracoesTecnicasAmbientesImediato() {
    final consideracoes = <String, String>{};
    for (final entry in _consideracoesAmbienteCtrls.entries) {
      final texto = entry.value.text.trim();
      if (texto.isEmpty) continue;
      consideracoes[entry.key] = texto;
    }
    return consideracoes.isEmpty ? null : consideracoes;
  }

  MarcoZeroLocalModel? _buildMarcoZero(
    TextEditingController descricaoController,
    TextEditingController xController,
    TextEditingController yController,
  ) {
    final descricao = descricaoController.text.trim();
    final x = xController.text.trim();
    final y = yController.text.trim();
    if (descricao.isEmpty && x.isEmpty && y.isEmpty) {
      return null;
    }
    return MarcoZeroLocalModel(
      descricao: descricao.isEmpty ? null : descricao,
      coordenadaX: x.isEmpty ? null : x,
      coordenadaY: y.isEmpty ? null : y,
    );
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

  Widget _buildMetodoPosicionamentoCard({
    required String titulo,
    required MetodoPosicionamentoVestigio valor,
    required ValueChanged<MetodoPosicionamentoVestigio?> onChanged,
    String? avisoGps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<MetodoPosicionamentoVestigio>(
          initialValue: valor,
          decoration: const InputDecoration(
            labelText: 'Método de posicionamento',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: MetodoPosicionamentoVestigio.values
              .map(
                (metodo) =>
                    DropdownMenuItem(value: metodo, child: Text(metodo.label)),
              )
              .toList(),
          onChanged: onChanged,
        ),
        if (avisoGps != null && valor == MetodoPosicionamentoVestigio.gps) ...[
          const SizedBox(height: 8),
          Text(
            avisoGps,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
          ),
        ],
      ],
    );
  }

  String _resumoPosicionamentoVestigio(VestigioLocalModel vestigio) {
    final ambiente = vestigio.ambiente;
    final metodo =
        vestigio.metodoPosicionamentoOverride ??
        (ambiente != null
            ? _metodosPosicionamentoAmbientesImediato[ambiente]
            : null) ??
        _inferirMetodoPosicionamentoVestigios([vestigio]);
    switch (metodo) {
      case MetodoPosicionamentoVestigio.marcoZero:
        final partes = <String>[];
        if ((vestigio.coordenadaX ?? '').trim().isNotEmpty) {
          partes.add('X=${vestigio.coordenadaX}');
        }
        if ((vestigio.coordenadaY ?? '').trim().isNotEmpty) {
          partes.add('Y=${vestigio.coordenadaY}');
        }
        if ((vestigio.alturaRelacaoPiso ?? '').trim().isNotEmpty) {
          partes.add('altura ${vestigio.alturaRelacaoPiso}');
        }
        return partes.isEmpty
            ? 'Posicionamento: marco zero'
            : 'Posicionamento: ${partes.join(', ')}';
      case MetodoPosicionamentoVestigio.gps:
        final partes = <String>[];
        if ((vestigio.coordenadasGpsFormatadas ?? '').trim().isNotEmpty) {
          partes.add(vestigio.coordenadasGpsFormatadas!);
        }
        if (vestigio.precisaoGpsMetros != null) {
          partes.add(
            'precisão ${vestigio.precisaoGpsMetros!.toStringAsFixed(1)} m',
          );
        }
        return partes.isEmpty
            ? 'Posicionamento: GPS'
            : 'Posicionamento: ${partes.join(' | ')}';
      case MetodoPosicionamentoVestigio.nenhum:
        return 'Posicionamento: não registrado';
    }
  }

  void _atualizarTextoImediato() {
    final texto = _gerarTextoDescricaoImediato();
    if (texto.isNotEmpty) {
      _descricaoImediatoController.text = texto;
    }
  }

  void _adicionarAmbienteImediato(String tipoBase) {
    final tipo = tipoBase.trim().toLowerCase();
    if (tipo.isEmpty) return;
    final nome = _proximoNomeAmbienteImediato(tipo);
    setState(() {
      if (_abrangenciaImediato == 'único ambiente') {
        _ambientesImediato
          ..clear()
          ..add(nome);
      } else {
        _ambientesImediato.add(nome);
      }
      _ambienteAcessoSelecionado = nome;
      _sincronizarAcessosPorAmbienteImediato();
      _atualizarTextoImediato();
    });
  }

  String _proximoNomeAmbienteImediato(String tipoBase) {
    final exigeNumero = tipoBase == 'quarto' || tipoBase == 'banheiro';
    if (!exigeNumero && !_ambientesImediato.contains(tipoBase)) {
      return tipoBase;
    }

    var numero = 1;
    while (_ambientesImediato.contains('$tipoBase $numero') ||
        (!exigeNumero &&
            numero == 1 &&
            _ambientesImediato.contains(tipoBase))) {
      numero++;
    }
    return '$tipoBase $numero';
  }

  Future<void> _mostrarDialogAdicionarAmbientePersonalizado() async {
    final controller = TextEditingController();
    final tipo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo tipo de ambiente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do ambiente',
            hintText: 'Ex.: despensa, suíte, área gourmet',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (tipo == null || tipo.trim().isEmpty) return;
    _adicionarAmbienteImediato(tipo);
  }

  void _removerAmbienteImediato(String ambiente) {
    final possuiVestigios = _vestigiosImediato.any(
      (v) => v.ambiente == ambiente,
    );
    if (possuiVestigios) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este ambiente possui vestígios. Edite ou remova os vestígios antes de excluir o ambiente.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _ambientesImediato.remove(ambiente);
      if (_ambienteDestaqueImediato == ambiente) {
        _ambienteDestaqueImediato = null;
      }
      if (_ambienteAcessoSelecionado == ambiente) {
        _ambienteAcessoSelecionado = null;
      }
      _acessosPorAmbienteImediato.remove(ambiente);
      _comunicacaoAmbientesImediato.remove(ambiente);
      _acessoExternoPorAmbienteImediato.remove(ambiente);
      _fotosVistaAmplaAmbientesImediato.remove(ambiente);
      _marcoAmbienteDescricaoCtrls.remove(ambiente)?.dispose();
      _marcoAmbienteXCtrls.remove(ambiente)?.dispose();
      _marcoAmbienteYCtrls.remove(ambiente)?.dispose();
      _consideracoesAmbienteCtrls.remove(ambiente)?.dispose();
      _sincronizarAcessosPorAmbienteImediato();
      _atualizarTextoImediato();
    });
  }

  Future<void> _adicionarFotoVistaAmbienteImediatoCamera(
    String ambiente,
  ) async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (foto == null || !mounted) return;
    final path = await _persistirFotoVestigio(foto);
    if (path == null || !mounted) return;
    setState(() {
      _fotosVistaAmplaAmbientesImediato
          .putIfAbsent(ambiente, () => <String>[])
          .add(path);
    });
  }

  Future<void> _adicionarFotosVistaAmbienteImediatoGaleria(
    String ambiente,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      final path = await _persistirFotoVestigio(XFile(f.path!));
      if (path == null || !mounted) continue;
      setState(() {
        _fotosVistaAmplaAmbientesImediato
            .putIfAbsent(ambiente, () => <String>[])
            .add(path);
      });
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

  Widget _buildFotosVistaAmbienteImediato(String ambiente) {
    final fotos =
        _fotosVistaAmplaAmbientesImediato[ambiente] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto(s) de vista ampla deste ambiente (opcional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Use para registrar a vista ampla do ambiente selecionado sem alterar a ordem de preenchimento.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _adicionarFotoVistaAmbienteImediatoCamera(ambiente),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _adicionarFotosVistaAmbienteImediatoGaleria(ambiente),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galeria'),
            ),
          ],
        ),
        if (fotos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fotos.asMap().entries.map((e) {
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
                          borderRadius: BorderRadius.circular(8),
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
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(4),
                      ),
                      onPressed: () => setState(() {
                        _fotosVistaAmplaAmbientesImediato[ambiente]?.removeAt(
                          e.key,
                        );
                      }),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBotaoAdicionarAmbiente(String tipo) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 18),
      label: Text(_capitalize(tipo)),
      onPressed: () => _adicionarAmbienteImediato(tipo),
    );
  }

  Widget _buildCardAmbienteImediato(String ambiente) {
    final selecionado = _ambienteAcessoSelecionado == ambiente;
    final vestigios = _vestigiosImediato
        .where((v) => v.ambiente == ambiente)
        .toList();
    final fotos = _fotosVistaAmplaAmbientesImediato[ambiente]?.length ?? 0;
    final consideracaoController = _consideracoesAmbienteCtrls.putIfAbsent(
      ambiente,
      () => TextEditingController(),
    );

    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                '${_ambientesImediato.toList().indexOf(ambiente) + 1}',
              ),
            ),
            title: Text(_capitalize(ambiente)),
            subtitle: Text(
              [
                if (_ambienteDestaqueImediato == ambiente)
                  'ambiente de maior relevância',
                '${vestigios.length} ${vestigios.length == 1 ? 'vestígio' : 'vestígios'}',
                '$fotos foto(s) ampla(s)',
                if (_marcoAmbienteInformado(ambiente)) 'marco zero',
              ].join(' • '),
            ),
            trailing: Icon(
              selecionado ? Icons.expand_less : Icons.chevron_right,
            ),
            onTap: () => setState(() {
              _ambienteAcessoSelecionado = selecionado ? null : ambiente;
            }),
          ),
          if (selecionado)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Ambiente de maior relevância'),
                        selected: _ambienteDestaqueImediato == ambiente,
                        onSelected: (value) => setState(() {
                          _ambienteDestaqueImediato = value ? ambiente : null;
                          _atualizarTextoImediato();
                        }),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remover ambiente'),
                        onPressed: () => _removerAmbienteImediato(ambiente),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFotosVistaAmbienteImediato(ambiente),
                  if (!_modoRapido) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Possui acesso externo'),
                      value:
                          _acessoExternoPorAmbienteImediato[ambiente] ?? false,
                      onChanged: (value) => setState(() {
                        _acessoExternoPorAmbienteImediato[ambiente] = value;
                        _atualizarTextoImediato();
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comunicação com outros ambientes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: _opcoesComunicacaoParaAmbiente(ambiente)
                          .map(
                            (opcao) => FilterChip(
                              label: Text(_capitalize(opcao)),
                              selected:
                                  (_comunicacaoAmbientesImediato[ambiente] ??
                                          const <String>{})
                                      .contains(opcao),
                              onSelected: (_) => setState(() {
                                final comunicacoes =
                                    _comunicacaoAmbientesImediato.putIfAbsent(
                                      ambiente,
                                      () => <String>{},
                                    );
                                comunicacoes.contains(opcao)
                                    ? comunicacoes.remove(opcao)
                                    : comunicacoes.add(opcao);
                                _atualizarTextoImediato();
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tipo de acesso/comunicação',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: _opcoesAcessosInternos
                          .map(
                            (opcao) => FilterChip(
                              label: Text(_capitalize(opcao)),
                              selected:
                                  (_acessosPorAmbienteImediato[ambiente] ??
                                          const <String>{})
                                      .contains(opcao),
                              onSelected: (_) => setState(() {
                                final acessos = _acessosPorAmbienteImediato
                                    .putIfAbsent(ambiente, () => <String>{});
                                acessos.contains(opcao)
                                    ? acessos.remove(opcao)
                                    : acessos.add(opcao);
                                _atualizarTextoImediato();
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildMetodoPosicionamentoCard(
                    titulo: 'Posicionamento dos vestígios deste ambiente',
                    valor:
                        _metodosPosicionamentoAmbientesImediato[ambiente] ??
                        MetodoPosicionamentoVestigio.nenhum,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _metodosPosicionamentoAmbientesImediato[ambiente] =
                            value;
                      });
                    },
                    avisoGps: _avisoGpsVestigio('imediato', ambiente: ambiente),
                  ),
                  const SizedBox(height: 8),
                  if ((_metodosPosicionamentoAmbientesImediato[ambiente] ??
                          MetodoPosicionamentoVestigio.nenhum) ==
                      MetodoPosicionamentoVestigio.marcoZero) ...[
                    const Text(
                      'Marco zero do ambiente (opcional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _marcoAmbienteDescricaoCtrls[ambiente],
                      decoration: const InputDecoration(
                        labelText: 'Descrição do marco zero',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _marcoAmbienteXCtrls[ambiente],
                            decoration: const InputDecoration(
                              labelText: 'Coordenada X (opcional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _marcoAmbienteYCtrls[ambiente],
                            decoration: const InputDecoration(
                              labelText: 'Coordenada Y (opcional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Vestígios deste ambiente',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _adicionarOuEditarVestigio(
                          'imediato',
                          ambienteInicial: ambiente,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  if (vestigios.isEmpty)
                    Text(
                      'Nenhum vestígio cadastrado neste ambiente.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ...vestigios.map(
                      (v) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          v.nome?.trim().isNotEmpty == true
                              ? v.nome!.trim()
                              : ((v.descricao ?? '').trim().isNotEmpty
                                    ? v.descricao!.trim()
                                    : 'Vestígio'),
                        ),
                        subtitle: Text(
                          [
                            if ((v.descricao ?? '').trim().isNotEmpty)
                              'Legenda: ${v.descricao!.trim()}',
                            if (v.numerosFotografias.isNotEmpty)
                              'Fotografia(s): ${v.numerosFotografias.map((n) => n.toString().padLeft(2, '0')).join(', ')}',
                            _resumoPosicionamentoVestigio(v),
                          ].join('\n'),
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _adicionarOuEditarVestigio(
                                'imediato',
                                existente: v,
                                ambienteInicial: ambiente,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _removerVestigio('imediato', v.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_podeAnalisarManchasSangue) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          _abrirAnaliseManchasSangue(ambiente: ambiente),
                      icon: const Icon(Icons.bloodtype_outlined),
                      label: const Text('Análise de manchas de sangue'),
                    ),
                  ],
                  if (!_modoRapido) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Considerações técnicas do ambiente (opcional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: consideracaoController,
                      decoration: const InputDecoration(
                        hintText:
                            'Registre observações técnicas específicas deste ambiente.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 3,
                      maxLines: null,
                      onChanged: (_) => _atualizarTextoImediato(),
                    ),
                    const SizedBox(height: 8),
                    AiSuggestionButton(
                      fieldLabel:
                          'Considerações técnicas do ambiente ${_capitalize(ambiente)}',
                      currentText: consideracaoController.text,
                      currentTextBuilder: () => consideracaoController.text,
                      contextTextBuilder: () =>
                          _buildContextoAmbienteImediato(ambiente),
                      imagePathsBuilder: () => [
                        ...?_fotosVistaAmplaAmbientesImediato[ambiente],
                        ...vestigios.expand((v) => v.fotosVinculadasPaths),
                      ],
                      profile: AiSuggestionProfile.furtoDanoExameLocal,
                      onReplace: (text) {
                        _replaceControllerText(consideracaoController, text);
                        _atualizarTextoImediato();
                      },
                      onAppend: (text) {
                        _appendControllerText(consideracaoController, text);
                        _atualizarTextoImediato();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _ambienteAcessoSelecionado = null;
                        _atualizarTextoImediato();
                      }),
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar ambiente e voltar à lista'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDescricaoAssistidaImediato() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _modoRapido ? 'Ambientes do local imediato' : 'Descrição por área',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _modoRapido
              ? 'Adicione um ambiente e toque nele para registrar foto ampla, marco zero opcional e vestígios.'
              : 'Selecione a abrangência e adicione os ambientes conforme for examinando. Toque em um ambiente da lista para registrar fotos, marco zero, vestígios, comunicação, manchas de sangue e considerações técnicas.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (!_modoRapido) ...[
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
                  (r) =>
                      DropdownMenuItem(value: r, child: Text(_capitalize(r))),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _abrangenciaImediato = v;
              if (v == 'único ambiente' && _ambientesImediato.length > 1) {
                final primeiro = _ambientesImediato.first;
                _ambientesImediato
                  ..clear()
                  ..add(primeiro);
                _ambienteAcessoSelecionado = primeiro;
              }
              _sincronizarAcessosPorAmbienteImediato();
              _atualizarTextoImediato();
            }),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Adicionar ambiente',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._tiposRapidosAmbienteImediato.map(_buildBotaoAdicionarAmbiente),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Outro tipo'),
              onPressed: _mostrarDialogAdicionarAmbientePersonalizado,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ambientesImediato.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'Nenhum ambiente adicionado. Use os botões acima para montar a lista do local imediato.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else ...[
          const Text(
            'Ambientes selecionados',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Toque em um ambiente para abrir o cadastro específico dele.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          ..._ambientesImediato.map(_buildCardAmbienteImediato),
        ],
        if (!_modoRapido) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _estadoConservacaoImediato,
            decoration: const InputDecoration(
              labelText: 'Estado de conservação geral do local imediato',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _opcoesEstadoConservacao
                .map(
                  (r) =>
                      DropdownMenuItem(value: r, child: Text(_capitalize(r))),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _estadoConservacaoImediato = v;
              _atualizarTextoImediato();
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _observacaoImediatoController,
            decoration: const InputDecoration(
              labelText: 'Observação geral do local imediato (opcional)',
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
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _marcoAmbienteInformado(String ambiente) {
    final descricao = _marcoAmbienteDescricaoCtrls[ambiente]?.text.trim() ?? '';
    final x = _marcoAmbienteXCtrls[ambiente]?.text.trim() ?? '';
    final y = _marcoAmbienteYCtrls[ambiente]?.text.trim() ?? '';
    return descricao.isNotEmpty ||
        (x.isNotEmpty && x != '0,0') ||
        (y.isNotEmpty && y != '0,0');
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
      if (_ambienteDestaqueImediato != null) {
        partes.add('Ambiente de maior relevância: $_ambienteDestaqueImediato.');
      }
      final consideracoes = _consideracoesAmbienteCtrls.entries
          .where((entry) => entry.value.text.trim().isNotEmpty)
          .map((entry) => '${entry.key}: ${entry.value.text.trim()}')
          .toList();
      if (consideracoes.isNotEmpty) {
        partes.add(
          'Considerações por ambiente: ${_listarItens(consideracoes)}.',
        );
      }
      final descricaoAcessos = _gerarDescricaoAcessosInternosImediato();
      if (descricaoAcessos.isNotEmpty) {
        partes.add(descricaoAcessos);
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

  String _buildContextoAmbienteImediato(String ambiente) {
    final partes = <String>['Ambiente: $ambiente.'];
    final comunicacoes = _comunicacaoAmbientesImediato[ambiente];
    if (comunicacoes != null && comunicacoes.isNotEmpty) {
      partes.add('Comunicação: ${_listarItens(comunicacoes.toList())}.');
    }
    final acessos = _acessosPorAmbienteImediato[ambiente];
    if (acessos != null && acessos.isNotEmpty) {
      partes.add(
        'Tipo de acesso/comunicação: ${_listarItens(acessos.toList())}.',
      );
    }
    final marco = _buildMarcoZeroAmbiente(ambiente);
    if (marco != null) {
      final textoMarco = [
        if ((marco.descricao ?? '').trim().isNotEmpty)
          'descrição: ${marco.descricao}',
        if ((marco.coordenadaX ?? '').trim().isNotEmpty)
          'X=${marco.coordenadaX}',
        if ((marco.coordenadaY ?? '').trim().isNotEmpty)
          'Y=${marco.coordenadaY}',
      ].join(', ');
      if (textoMarco.isNotEmpty) partes.add('Marco zero: $textoMarco.');
    }
    final vestigios = _vestigiosImediato
        .where((v) => v.ambiente == ambiente)
        .map((v) => v.descricao?.trim())
        .whereType<String>()
        .where((texto) => texto.isNotEmpty)
        .toList();
    if (vestigios.isNotEmpty) {
      partes.add('Vestígios no ambiente: ${_listarItens(vestigios)}.');
    }
    final consideracoes = _consideracoesAmbienteCtrls[ambiente]?.text.trim();
    if (consideracoes != null && consideracoes.isNotEmpty) {
      partes.add('Considerações técnicas já registradas: $consideracoes.');
    }
    return partes.join('\n');
  }

  bool get _podeAnalisarManchasSangue =>
      widget.ficha.tipoOcorrencia == TipoOcorrencia.cvli ||
      widget.ficha.tipoOcorrencia == TipoOcorrencia.morteEsclarecer;

  Future<void> _abrirAnaliseManchasSangue({String? ambiente}) async {
    final vestigios = ambiente == null
        ? _vestigiosImediato
        : _vestigiosImediato.where((v) => v.ambiente == ambiente).toList();
    final contextoAmbiente = ambiente == null
        ? ''
        : _buildContextoAmbienteImediato(ambiente);
    final contextoGeral = _buildAiContextLocal(
      titulo: 'Local Imediato',
      local: 'imediato',
      vestigios: vestigios,
      pisoSeco: _pisoSecoImediato,
      pisoUmido: _pisoUmidoImediato,
      pisoMolhado: _pisoMolhadoImediato,
      iluminacaoArtificial: _iluminacaoArtificialImediato,
      iluminacaoNatural: _iluminacaoNaturalImediato,
      iluminacaoAusente: _iluminacaoAusenteImediato,
    );
    final initialContext = [
      if (ambiente != null) 'Ambiente analisado: $ambiente.',
      if (contextoAmbiente.isNotEmpty) contextoAmbiente,
      contextoGeral,
    ].where((texto) => texto.trim().isNotEmpty).join('\n');

    final overviewImages = <String>[
      if (ambiente == null) ..._fotosVistaAmplaPaths,
      if (ambiente == null) ..._fotosVistaAmplaImediatoPaths,
      if (ambiente != null) ...?_fotosVistaAmplaAmbientesImediato[ambiente],
    ];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BloodstainAnalysisScreen(
          fichaId: widget.ficha.id,
          initialContextText: initialContext,
          initialOverviewImagePaths: overviewImages,
          ambiente: ambiente,
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
    final exibirVestigiosDaSecao =
        local != 'imediato' ||
        (local == 'imediato' && _ambientesImediato.isEmpty);
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
                if (!_modoRapido &&
                    _localEmViaPublica != true &&
                    local == 'mediato')
                  _buildDescricaoAssistidaMediato(),
                if (local == 'imediato') _buildDescricaoAssistidaImediato(),
                if (!_modoRapido) ...[
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
                ],
                if (local != 'imediato')
                  _buildMetodoPosicionamentoCard(
                    titulo: 'Posicionamento dos vestígios deste local',
                    valor: local == 'mediato'
                        ? _metodoPosicionamentoMediato
                        : _metodoPosicionamentoRelacionado,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        if (local == 'mediato') {
                          _metodoPosicionamentoMediato = value;
                        } else {
                          _metodoPosicionamentoRelacionado = value;
                        }
                      });
                    },
                    avisoGps: _avisoGpsVestigio(local),
                  ),
                if (exibirSinaisArrombamento && !_modoRapido) ...[
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
                      const SizedBox(height: 12),
                      const Text(
                        'Fotografia(s) dos sinais de arrombamento',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final foto = await _imagePicker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 75,
                                maxWidth: 2048,
                                maxHeight: 2048,
                              );
                              if (foto == null || !mounted) return;
                              final path = await _persistirFotoVestigio(foto);
                              if (path == null) return;
                              setState(() {
                                _fotosSinaisArrombamentoPaths.add(path);
                              });
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Câmera'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    allowMultiple: true,
                                  );
                              if (result == null ||
                                  result.files.isEmpty ||
                                  !mounted) {
                                return;
                              }
                              for (final f in result.files) {
                                if (f.path == null) continue;
                                final path = await _persistirFotoVestigio(
                                  XFile(f.path!),
                                );
                                if (path == null) continue;
                                setState(() {
                                  _fotosSinaisArrombamentoPaths.add(path);
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                          ),
                        ],
                      ),
                      if (_fotosSinaisArrombamentoPaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _fotosSinaisArrombamentoPaths
                              .asMap()
                              .entries
                              .map(
                                (e) => Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(e.value),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _fotosSinaisArrombamentoPaths
                                                .removeAt(e.key);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ],
                ],
                if (!usarFluxoVestigioMediato &&
                    showMarcoZero &&
                    _metodoPosicionamentoVestigio(local) ==
                        MetodoPosicionamentoVestigio.marcoZero) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Marco Zero (opcional)',
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
                if (!_modoRapido) ...[
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
                            onChanged: (value) =>
                                onPisoChanged(value, 'molhado'),
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
                ],
                if (exibirVestigiosDaSecao && usarFluxoVestigioMediato) ...[
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
                          marcoZeroXController.clear();
                          marcoZeroYController.clear();
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
                  if (_temVestigiosMediato == true &&
                      showMarcoZero &&
                      _metodoPosicionamentoMediato ==
                          MetodoPosicionamentoVestigio.marcoZero) ...[
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
                ] else if (exibirVestigiosDaSecao) ...[
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
                if (exibirVestigiosDaSecao &&
                    ((usarFluxoVestigioMediato &&
                            _temVestigiosMediato == true) ||
                        (!usarFluxoVestigioMediato && !semVestigios))) ...[
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
                  ..._vestigiosOrdenadosPorAmbiente(local, vestigios).map(
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
                                child: Text('Legenda: ${v.descricao}'),
                              ),
                            if (v.numerosFotografias.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Fotografia(s): ${v.numerosFotografias.map((n) => n.toString().padLeft(2, '0')).join(', ')}',
                                ),
                              ),
                            if (v.ambiente != null &&
                                v.ambiente!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Ambiente: ${_capitalize(v.ambiente!)}',
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_resumoPosicionamentoVestigio(v)),
                            ),
                            if (v.fotosVinculadasPaths.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Fotos vinculadas: ${v.fotosVinculadasPaths.length}',
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
            icon: Icon(_modoRapido ? Icons.speed : Icons.speed_outlined),
            style: IconButton.styleFrom(
              backgroundColor: _modoRapido
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              foregroundColor: _modoRapido
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
            onPressed: () => setState(() {
              _modoRapido = !_modoRapido;
            }),
            tooltip: _modoRapido
                ? 'Desativar modo rápido'
                : 'Ativar modo rápido',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInstrucoes,
            tooltip: 'Instruções de uso',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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
            if (_etapaLocalAtual == 0 && !_modoRapido)
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
            // Foto(s) vista ampla do mediato. No imediato, as fotos ficam em cada ambiente.
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
                      'Foto(s) vista ampla do local',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _etapaLocalAtual == 0
                          ? (_modoRapido
                                ? 'Foto geral do local mediato.'
                                : _localEmViaPublica == true
                                ? 'Vista geral do local mediato (ex.: trecho da via, ponto do fato).'
                                : 'Ex.: fachada ou porção anterior do imóvel (local mediato).')
                          : 'Registre uma vista geral do local imediato. As vistas por ambiente podem ser vinculadas acima, no ambiente selecionado.',
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
                              imageQuality: 75,
                              maxWidth: 2048,
                              maxHeight: 2048,
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
                        if (!_modoRapido) ...[
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
                        ],
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
                            showMarcoZero: false,
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
