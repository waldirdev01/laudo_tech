import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/evidencias_cadaver_regioes.dart';
import '../constants/tipos_barba_referencia.dart';
import '../models/cadaver_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/openai_service.dart';
import '../services/photo_backup_service.dart';
import '../widgets/ai_suggestion_button.dart';
import 'lesao_cadaver_form_screen.dart';

class CadastroCadaverScreen extends StatefulWidget {
  final CadaverModel cadaver;
  final FichaCompletaModel ficha;

  const CadastroCadaverScreen({
    super.key,
    required this.cadaver,
    required this.ficha,
  });

  @override
  State<CadastroCadaverScreen> createState() => _CadastroCadaverScreenState();
}

class _CadastroCadaverScreenState extends State<CadastroCadaverScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _modoRapido = false;

  // Controllers - Identificação
  final _laudoCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _nascimentoCtrl = TextEditingController();
  final _filiacaoCtrl = TextEditingController();

  // Controllers - Cabelo/Barba outro
  final _corCabeloOutroCtrl = TextEditingController();
  final _tipoCabeloOutroCtrl = TextEditingController();
  final _tamanhoCabeloOutroCtrl = TextEditingController();
  final _tipoBarbaOutroCtrl = TextEditingController();
  final _corBarbaOutraCtrl = TextEditingController();
  final _tamanhoBarbaOutroCtrl = TextEditingController();

  // Controllers - Exames
  final _localizacaoAmbienteCtrl = TextEditingController();
  final _coordenadaCabecaXCtrl = TextEditingController();
  final _coordenadaCabecaYCtrl = TextEditingController();
  final _alturaCabecaCtrl = TextEditingController();
  final _coordenadaPesXCtrl = TextEditingController();
  final _coordenadaPesYCtrl = TextEditingController();
  final _alturaPesCtrl = TextEditingController();
  final _coordenadaCentroTroncoXCtrl = TextEditingController();
  final _coordenadaCentroTroncoYCtrl = TextEditingController();
  final _alturaCentroTroncoCtrl = TextEditingController();
  final _posicaoCorpoLivreCtrl = TextEditingController();

  // FocusNode para o campo de texto livre da posição
  final _posicaoCorpoLivreFocusNode = FocusNode();
  final _hipostasePosicaoCtrl = TextEditingController();
  final _secrecaoNasalTipoCtrl = TextEditingController();
  final _secrecaoOralTipoCtrl = TextEditingController();
  final _secrecaoAnalTipoCtrl = TextEditingController();
  final _secrecaoPenianaVaginalTipoCtrl = TextEditingController();
  final _outrasObservacoesCtrl = TextEditingController();
  final _tatuagensMarcasCtrl = TextEditingController();
  final _pertencesCtrl = TextEditingController();

  // Estados
  FaixaEtaria? _faixaEtaria;
  SexoCadaver? _sexo;
  Compleicao? _compleicao;
  CorPele? _corPele;
  CorCabelo? _corCabelo;
  TipoCabelo? _tipoCabelo;
  TamanhoCabelo? _tamanhoCabelo;
  TipoBarba? _tipoBarba;
  CorBarba? _corBarba;
  TamanhoBarba? _tamanhoBarba;

  EstadoRigidez? _rigidezMandibula;
  EstadoRigidez? _rigidezMemSuperior;
  EstadoRigidez? _rigidezMemInferior;
  EstadoHipostase? _hipostaseEstado;
  bool? _hipostaseCompativeis;
  bool? _hipostasePresente;

  // Posição do corpo
  String? _posicaoCorpoPreset;

  bool? _secrecaoNasal;
  bool? _secrecaoOral;
  bool? _secrecaoAnal;
  bool? _secrecaoPenianaVaginal;
  bool? _secrecoesPresentes;

  List<LesaoCadaverModel> _lesoes = [];

  // Ausência de lesões de defesa
  bool _ausenciaLesoesDefesa = false;
  final List<String> _membrosExaminadosDefesa = [];
  final _obsLesoesDefesaCtrl = TextEditingController();
  List<String> _fotosLesoesDefesa = [];

  List<VesteCadaverModel> _vestes = [];
  List<TatuagemMarcaCorporalModel> _tatuagensMarcasLista = [];

  // Fotos dos exames (paths locais)
  List<String> _fotosVistaCadaversAmbiente = [];
  List<String> _fotosPosicaoEncontrada = [];
  List<String> _fotosHipostaseSecrecoes = [];
  List<String> _fotosTatuagens = [];

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregarDados();
  }

  void _reconfigurarTabs(bool modoRapido) {
    final antigo = _tabController;
    final maxIndex = modoRapido ? 2 : 3;
    final novoIndice = antigo.index > maxIndex ? maxIndex : antigo.index;
    final novoController = TabController(
      length: modoRapido ? 3 : 4,
      vsync: this,
      initialIndex: novoIndice,
    );
    _tabController = novoController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      antigo.dispose();
    });
  }

  void _carregarDados() {
    final c = widget.cadaver;
    _laudoCtrl.text = c.numeroLaudoCadaverico ?? '';
    _nomeCtrl.text = c.nomeDaVitima ?? '';
    _documentoCtrl.text = c.documentoIdentificacao ?? '';
    _nascimentoCtrl.text = c.dataNascimento ?? '';
    _filiacaoCtrl.text = c.filiacao ?? '';

    _faixaEtaria = c.faixaEtaria;
    _sexo = c.sexo;
    _compleicao = c.compleicao;
    _corPele = c.corPele;
    _corCabelo = c.corCabelo;
    _corCabeloOutroCtrl.text = c.corCabeloOutro ?? '';
    _tipoCabelo = c.tipoCabelo;
    _tipoCabeloOutroCtrl.text = c.tipoCabeloOutro ?? '';
    _tamanhoCabelo = c.tamanhoCabelo;
    _tamanhoCabeloOutroCtrl.text = c.tamanhoCabeloOutro ?? '';
    _tipoBarba = c.tipoBarba;
    _tipoBarbaOutroCtrl.text = c.tipoBarbaOutro ?? '';
    _corBarba = c.corBarba;
    _corBarbaOutraCtrl.text = c.corBarbaOutra ?? '';
    _tamanhoBarba = c.tamanhoBarba;
    _tamanhoBarbaOutroCtrl.text = c.tamanhoBarbaOutro ?? '';

    _localizacaoAmbienteCtrl.text = c.localizacaoAmbiente ?? '';
    _coordenadaCabecaXCtrl.text = c.coordenadaCabecaX ?? '';
    _coordenadaCabecaYCtrl.text = c.coordenadaCabecaY ?? '';
    _alturaCabecaCtrl.text = c.alturaCabeca ?? '';
    _coordenadaPesXCtrl.text = c.coordenadaPesX ?? '';
    _coordenadaPesYCtrl.text = c.coordenadaPesY ?? '';
    _alturaPesCtrl.text = c.alturaPes ?? '';
    _coordenadaCentroTroncoXCtrl.text = c.coordenadaCentroTroncoX ?? '';
    _coordenadaCentroTroncoYCtrl.text = c.coordenadaCentroTroncoY ?? '';
    _alturaCentroTroncoCtrl.text = c.alturaCentroTronco ?? '';
    _posicaoCorpoPreset = c.posicaoCorpoPreset;
    _posicaoCorpoLivreCtrl.text = c.posicaoCorpoLivre ?? '';
    _rigidezMandibula = c.rigidezMandibula;
    _rigidezMemSuperior = c.rigidezMemSuperior;
    _rigidezMemInferior = c.rigidezMemInferior;
    _hipostasePosicaoCtrl.text = c.hipostasePosicao ?? '';
    _hipostaseEstado = c.hipostaseEstado;
    _hipostaseCompativeis = c.hipostaseCompativeis;
    _hipostasePresente =
        (c.hipostasePosicao?.trim().isNotEmpty == true) ||
        c.hipostaseEstado != null ||
        c.hipostaseCompativeis != null;

    _secrecaoNasal = c.secrecaoNasal;
    _secrecaoNasalTipoCtrl.text = c.secrecaoNasalTipo ?? '';
    _secrecaoOral = c.secrecaoOral;
    _secrecaoOralTipoCtrl.text = c.secrecaoOralTipo ?? '';
    _secrecaoAnal = c.secrecaoAnal;
    _secrecaoAnalTipoCtrl.text = c.secrecaoAnalTipo ?? '';
    _secrecaoPenianaVaginal = c.secrecaoPenianaVaginal;
    _secrecaoPenianaVaginalTipoCtrl.text = c.secrecaoPenianaVaginalTipo ?? '';
    _secrecoesPresentes =
        c.secrecaoNasal == true ||
        c.secrecaoOral == true ||
        c.secrecaoAnal == true ||
        c.secrecaoPenianaVaginal == true;
    _outrasObservacoesCtrl.text = c.outrasObservacoes ?? '';
    _tatuagensMarcasCtrl.text = c.tatuagensMarcas ?? '';
    _tatuagensMarcasLista = List<TatuagemMarcaCorporalModel>.from(
      c.tatuagensMarcasLista ?? const [],
    );
    _pertencesCtrl.text = c.pertences ?? '';

    _lesoes = List<LesaoCadaverModel>.from(c.lesoes ?? []);
    _ausenciaLesoesDefesa = c.ausenciaLesoesDefesa;
    _membrosExaminadosDefesa
      ..clear()
      ..addAll(c.membrosExaminadosDefesa);
    _obsLesoesDefesaCtrl.text = c.observacoesLesoesDefesa ?? '';
    _fotosLesoesDefesa = List<String>.from(c.fotosLesoesDefesa);
    _vestes = List<VesteCadaverModel>.from(c.vestes ?? []);

    _fotosVistaCadaversAmbiente = List<String>.from(
      c.fotosVistaCadaversAmbiente,
    );
    _fotosPosicaoEncontrada = List<String>.from(c.fotosPosicaoEncontrada);
    _fotosHipostaseSecrecoes = List<String>.from(c.fotosHipostaseSecrecoes);
    _fotosTatuagens = List<String>.from(c.fotosTatuagens);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _laudoCtrl.dispose();
    _nomeCtrl.dispose();
    _documentoCtrl.dispose();
    _nascimentoCtrl.dispose();
    _filiacaoCtrl.dispose();
    _corCabeloOutroCtrl.dispose();
    _tipoCabeloOutroCtrl.dispose();
    _tamanhoCabeloOutroCtrl.dispose();
    _tipoBarbaOutroCtrl.dispose();
    _corBarbaOutraCtrl.dispose();
    _tamanhoBarbaOutroCtrl.dispose();
    _localizacaoAmbienteCtrl.dispose();
    _coordenadaCabecaXCtrl.dispose();
    _coordenadaCabecaYCtrl.dispose();
    _alturaCabecaCtrl.dispose();
    _coordenadaPesXCtrl.dispose();
    _coordenadaPesYCtrl.dispose();
    _alturaPesCtrl.dispose();
    _coordenadaCentroTroncoXCtrl.dispose();
    _coordenadaCentroTroncoYCtrl.dispose();
    _alturaCentroTroncoCtrl.dispose();
    _posicaoCorpoLivreCtrl.dispose();
    _posicaoCorpoLivreFocusNode.dispose();
    _hipostasePosicaoCtrl.dispose();
    _secrecaoNasalTipoCtrl.dispose();
    _secrecaoOralTipoCtrl.dispose();
    _secrecaoAnalTipoCtrl.dispose();
    _secrecaoPenianaVaginalTipoCtrl.dispose();
    _outrasObservacoesCtrl.dispose();
    _obsLesoesDefesaCtrl.dispose();
    _tatuagensMarcasCtrl.dispose();
    _pertencesCtrl.dispose();
    super.dispose();
  }

  CadaverModel _construirCadaver() {
    return widget.cadaver.copyWith(
      numeroLaudoCadaverico: _laudoCtrl.text.trim().isEmpty
          ? null
          : _laudoCtrl.text.trim(),
      nomeDaVitima: _nomeCtrl.text.trim().isEmpty
          ? null
          : _nomeCtrl.text.trim(),
      documentoIdentificacao: _documentoCtrl.text.trim().isEmpty
          ? null
          : _documentoCtrl.text.trim(),
      dataNascimento: _nascimentoCtrl.text.trim().isEmpty
          ? null
          : _nascimentoCtrl.text.trim(),
      filiacao: _filiacaoCtrl.text.trim().isEmpty
          ? null
          : _filiacaoCtrl.text.trim(),
      faixaEtaria: _faixaEtaria,
      sexo: _sexo,
      compleicao: _compleicao,
      corPele: _corPele,
      corCabelo: _corCabelo,
      corCabeloOutro: _corCabeloOutroCtrl.text.trim().isEmpty
          ? null
          : _corCabeloOutroCtrl.text.trim(),
      tipoCabelo: _tipoCabelo,
      tipoCabeloOutro: _tipoCabeloOutroCtrl.text.trim().isEmpty
          ? null
          : _tipoCabeloOutroCtrl.text.trim(),
      tamanhoCabelo: _tamanhoCabelo,
      tamanhoCabeloOutro: _tamanhoCabeloOutroCtrl.text.trim().isEmpty
          ? null
          : _tamanhoCabeloOutroCtrl.text.trim(),
      tipoBarba: _tipoBarba,
      tipoBarbaOutro: _tipoBarbaOutroCtrl.text.trim().isEmpty
          ? null
          : _tipoBarbaOutroCtrl.text.trim(),
      corBarba: _corBarba,
      corBarbaOutra: _corBarbaOutraCtrl.text.trim().isEmpty
          ? null
          : _corBarbaOutraCtrl.text.trim(),
      tamanhoBarba: _tamanhoBarba,
      tamanhoBarbaOutro: _tamanhoBarbaOutroCtrl.text.trim().isEmpty
          ? null
          : _tamanhoBarbaOutroCtrl.text.trim(),
      localizacaoAmbiente: _localizacaoAmbienteCtrl.text.trim().isEmpty
          ? null
          : _localizacaoAmbienteCtrl.text.trim(),
      coordenadaCabecaX: _coordenadaCabecaXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCabecaXCtrl.text.trim(),
      coordenadaCabecaY: _coordenadaCabecaYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCabecaYCtrl.text.trim(),
      alturaCabeca: _alturaCabecaCtrl.text.trim().isEmpty
          ? null
          : _alturaCabecaCtrl.text.trim(),
      coordenadaPesX: _coordenadaPesXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaPesXCtrl.text.trim(),
      coordenadaPesY: _coordenadaPesYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaPesYCtrl.text.trim(),
      alturaPes: _alturaPesCtrl.text.trim().isEmpty
          ? null
          : _alturaPesCtrl.text.trim(),
      coordenadaCentroTroncoX: _coordenadaCentroTroncoXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroTroncoXCtrl.text.trim(),
      coordenadaCentroTroncoY: _coordenadaCentroTroncoYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroTroncoYCtrl.text.trim(),
      alturaCentroTronco: _alturaCentroTroncoCtrl.text.trim().isEmpty
          ? null
          : _alturaCentroTroncoCtrl.text.trim(),
      posicaoCorpoPreset: _posicaoCorpoPreset,
      posicaoCorpoLivre: _posicaoCorpoLivreCtrl.text.trim().isEmpty
          ? null
          : _posicaoCorpoLivreCtrl.text.trim(),
      rigidezMandibula: _rigidezMandibula,
      rigidezMemSuperior: _rigidezMemSuperior,
      rigidezMemInferior: _rigidezMemInferior,
      hipostasePosicao:
          _hipostasePresente == true &&
              _hipostasePosicaoCtrl.text.trim().isNotEmpty
          ? _hipostasePosicaoCtrl.text.trim()
          : null,
      hipostaseEstado: _hipostasePresente == true ? _hipostaseEstado : null,
      hipostaseCompativeis: _hipostasePresente == true
          ? _hipostaseCompativeis
          : null,
      secrecaoNasal: _secrecoesPresentes == true ? _secrecaoNasal : null,
      secrecaoNasalTipo:
          (_secrecoesPresentes == true &&
              _secrecaoNasal == true &&
              _secrecaoNasalTipoCtrl.text.trim().isNotEmpty)
          ? _secrecaoNasalTipoCtrl.text.trim()
          : null,
      secrecaoOral: _secrecoesPresentes == true ? _secrecaoOral : null,
      secrecaoOralTipo:
          (_secrecoesPresentes == true &&
              _secrecaoOral == true &&
              _secrecaoOralTipoCtrl.text.trim().isNotEmpty)
          ? _secrecaoOralTipoCtrl.text.trim()
          : null,
      secrecaoAnal: _secrecoesPresentes == true ? _secrecaoAnal : null,
      secrecaoAnalTipo:
          (_secrecoesPresentes == true &&
              _secrecaoAnal == true &&
              _secrecaoAnalTipoCtrl.text.trim().isNotEmpty)
          ? _secrecaoAnalTipoCtrl.text.trim()
          : null,
      secrecaoPenianaVaginal: _secrecoesPresentes == true
          ? _secrecaoPenianaVaginal
          : null,
      secrecaoPenianaVaginalTipo:
          (_secrecoesPresentes == true &&
              _secrecaoPenianaVaginal == true &&
              _secrecaoPenianaVaginalTipoCtrl.text.trim().isNotEmpty)
          ? _secrecaoPenianaVaginalTipoCtrl.text.trim()
          : null,
      outrasObservacoes: _outrasObservacoesCtrl.text.trim().isEmpty
          ? null
          : _outrasObservacoesCtrl.text.trim(),
      lesoes: _lesoes,
      ausenciaLesoesDefesa: _ausenciaLesoesDefesa,
      membrosExaminadosDefesa: List.from(_membrosExaminadosDefesa),
      observacoesLesoesDefesa: _obsLesoesDefesaCtrl.text.trim().isEmpty
          ? null
          : _obsLesoesDefesaCtrl.text.trim(),
      fotosLesoesDefesa: _fotosLesoesDefesa,
      vestes: _vestes,
      fotosVistaCadaversAmbiente: _fotosVistaCadaversAmbiente,
      fotosPosicaoEncontrada: _fotosPosicaoEncontrada,
      fotosHipostaseSecrecoes:
          (_hipostasePresente == true || _secrecoesPresentes == true)
          ? _fotosHipostaseSecrecoes
          : const [],
      fotosTatuagens: _tatuagensMarcasLista.isNotEmpty
          ? _tatuagensMarcasLista
                .expand((t) => t.fotosPaths)
                .where((p) => p.trim().isNotEmpty)
                .toSet()
                .toList()
          : _fotosTatuagens,
      tatuagensMarcas: _tatuagensMarcasLista.isNotEmpty
          ? _tatuagensMarcasLista
                .map((t) => t.descricao?.trim())
                .whereType<String>()
                .where((d) => d.isNotEmpty)
                .join('; ')
          : (_tatuagensMarcasCtrl.text.trim().isEmpty
                ? null
                : _tatuagensMarcasCtrl.text.trim()),
      tatuagensMarcasLista: _tatuagensMarcasLista.isEmpty
          ? null
          : _tatuagensMarcasLista,
      pertences: _pertencesCtrl.text.trim().isEmpty
          ? null
          : _pertencesCtrl.text.trim(),
    );
  }

  Future<String?> _persistirFotoCadaver(XFile arquivo, String subpasta) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.ficha.id}/cadaver_${widget.cadaver.numero}/$subpasta',
      );
      if (!await pasta.exists()) await pasta.create(recursive: true);
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

  void _salvar() {
    if (_fotosVistaCadaversAmbiente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione ao menos uma foto: Vista do cadáver no ambiente.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _tabController.animateTo(0);
      return;
    }
    if (_fotosPosicaoEncontrada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione ao menos uma foto: Cadáver na posição em que foi encontrado.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _tabController.animateTo(0);
      return;
    }
    final cadaver = _construirCadaver();
    Navigator.of(context).pop(cadaver);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadáver ${widget.cadaver.numero}'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          tabs: _modoRapido
              ? const [
                  Tab(text: 'Cena', icon: Icon(Icons.photo_camera)),
                  Tab(text: 'Vestes', icon: Icon(Icons.checkroom)),
                  Tab(text: 'Exames', icon: Icon(Icons.medical_services)),
                ]
              : const [
                  Tab(text: 'Cena', icon: Icon(Icons.photo_camera)),
                  Tab(text: 'Vestes', icon: Icon(Icons.checkroom)),
                  Tab(text: 'Exames', icon: Icon(Icons.medical_services)),
                  Tab(text: 'Descrição', icon: Icon(Icons.person)),
                ],
        ),
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
            tooltip: _modoRapido
                ? 'Desativar modo rápido'
                : 'Ativar modo rápido',
            onPressed: () {
              setState(() {
                final novoModoRapido = !_modoRapido;
                _reconfigurarTabs(novoModoRapido);
                _modoRapido = novoModoRapido;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _modoRapido
            ? [_buildCenaTab(), _buildVestesTab(), _buildExamesTab()]
            : [
                _buildCenaTab(),
                _buildVestesTab(),
                _buildExamesTab(),
                _buildDescricaoTab(),
              ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _salvar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Salvar Cadáver'),
          ),
        ),
      ),
    );
  }

  /// Aba 4: Descrição — identificação e características físicas.
  Widget _buildDescricaoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Identificação e características físicas do cadáver.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Identificação
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTIFICAÇÃO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _laudoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número do Laudo Cadavérico',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: 123/2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Vítima',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _documentoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documento de Identificação',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nascimentoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Data de Nascimento',
                      border: OutlineInputBorder(),
                      hintText: 'DD/MM/AAAA',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _filiacaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filiação',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Características Físicas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARACTERÍSTICAS FÍSICAS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Faixa Etária
                  _buildDropdown<FaixaEtaria>(
                    label: 'Faixa Etária',
                    value: _faixaEtaria,
                    items: FaixaEtaria.values,
                    onChanged: (v) => setState(() => _faixaEtaria = v),
                  ),
                  const SizedBox(height: 12),

                  // Sexo
                  _buildDropdown<SexoCadaver>(
                    label: 'Sexo',
                    value: _sexo,
                    items: SexoCadaver.values,
                    onChanged: (v) => setState(() => _sexo = v),
                  ),
                  const SizedBox(height: 12),

                  // Compleição
                  _buildDropdown<Compleicao>(
                    label: 'Compleição',
                    value: _compleicao,
                    items: Compleicao.values,
                    onChanged: (v) => setState(() => _compleicao = v),
                  ),
                  const SizedBox(height: 12),

                  // Cor
                  _buildDropdown<CorPele>(
                    label: 'Cor',
                    value: _corPele,
                    items: CorPele.values,
                    onChanged: (v) => setState(() => _corPele = v),
                  ),
                  const SizedBox(height: 12),

                  const Divider(),
                  const Text(
                    'Cabelos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // Cor do Cabelo
                  _buildDropdown<CorCabelo>(
                    label: 'Cor',
                    value: _corCabelo,
                    items: CorCabelo.values,
                    onChanged: (v) => setState(() => _corCabelo = v),
                  ),
                  if (_corCabelo == CorCabelo.outro) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _corCabeloOutroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Especifique a cor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Tipo do Cabelo
                  _buildDropdown<TipoCabelo>(
                    label: 'Tipo',
                    value: _tipoCabelo,
                    items: TipoCabelo.values,
                    onChanged: (v) => setState(() => _tipoCabelo = v),
                  ),
                  if (_tipoCabelo == TipoCabelo.outro) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tipoCabeloOutroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Especifique o tipo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Tamanho do Cabelo
                  _buildDropdown<TamanhoCabelo>(
                    label: 'Tamanho',
                    value: _tamanhoCabelo,
                    items: TamanhoCabelo.values,
                    onChanged: (v) => setState(() => _tamanhoCabelo = v),
                  ),
                  if (_tamanhoCabelo == TamanhoCabelo.outro) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tamanhoCabeloOutroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Especifique o tamanho',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],

                  // Barba (só mostra se não for feminino)
                  if (_sexo != SexoCadaver.feminino) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    Row(
                      children: [
                        const Text(
                          'Barba',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _mostrarSelecaoBarbaReferencia(context),
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('Selecionar da referência'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tipo selecionado (apenas pela referência)
                    Text(
                      _textoTipoBarbaSelecionado(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_tipoBarba != null &&
                        _tipoBarba != TipoBarba.naoSeAplica) ...[
                      const SizedBox(height: 12),

                      // Cor da Barba
                      _buildDropdown<CorBarba>(
                        label: 'Cor',
                        value: _corBarba,
                        items: CorBarba.values,
                        onChanged: (v) => setState(() => _corBarba = v),
                      ),
                      if (_corBarba == CorBarba.outra) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _corBarbaOutraCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especifique a cor',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Tamanho da Barba
                      _buildDropdown<TamanhoBarba>(
                        label: 'Tamanho',
                        value: _tamanhoBarba,
                        items: TamanhoBarba.values,
                        onChanged: (v) => setState(() => _tamanhoBarba = v),
                      ),
                      if (_tamanhoBarba == TamanhoBarba.outro) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _tamanhoBarbaOutroCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especifique o tamanho',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _nomeArquivoFoto(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  Widget _buildSecaoFotos({
    required String titulo,
    required List<String> paths,
    required ValueChanged<List<String>> onChanged,
    bool obrigatorio = false,
    String? hint,
    String? subpasta,
  }) {
    final pasta =
        subpasta ?? titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (obrigatorio) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
                final path = await _persistirFotoCadaver(foto, pasta);
                if (path != null) onChanged([...paths, path]);
              },
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final fotos = await _imagePicker.pickMultiImage(
                  imageQuality: 75,
                  maxWidth: 2048,
                  maxHeight: 2048,
                );
                if (fotos.isEmpty || !mounted) return;
                final novas = <String>[];
                for (final foto in fotos) {
                  final path = await _persistirFotoCadaver(foto, pasta);
                  if (path != null) novas.add(path);
                }
                if (novas.isNotEmpty) onChanged([...paths, ...novas]);
              },
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Galeria'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (paths.isEmpty)
          Text(
            obrigatorio
                ? 'Nenhuma foto. Adicione ao menos uma.'
                : 'Nenhuma foto.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          )
        else
          ...paths.asMap().entries.map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined, size: 18),
              title: Text(
                _nomeArquivoFoto(e.value),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remover foto',
                onPressed: () {
                  final nova = List<String>.from(paths)..removeAt(e.key);
                  onChanged(nova);
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Aba 1: Cena — ambiente e posição em que o cadáver foi encontrado (sequência da perícia).
  Widget _buildCenaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registre o ambiente e a posição em que o cadáver foi encontrado.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Fotos obrigatórias
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOTOS DA CENA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSecaoFotos(
                    titulo: 'Vista do cadáver no ambiente',
                    paths: _fotosVistaCadaversAmbiente,
                    onChanged: (v) =>
                        setState(() => _fotosVistaCadaversAmbiente = v),
                    obrigatorio: true,
                  ),
                  const SizedBox(height: 20),
                  _buildSecaoFotos(
                    titulo:
                        'Cadáver na posição em que foi encontrado pela equipe pericial',
                    paths: _fotosPosicaoEncontrada,
                    onChanged: (v) =>
                        setState(() => _fotosPosicaoEncontrada = v),
                    obrigatorio: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Posição do Corpo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POSIÇÃO DO CORPO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: _posicaoCorpoPreset,
                    onChanged: (selectedValue) {
                      setState(() {
                        _posicaoCorpoPreset = selectedValue;
                        if (selectedValue == 'outra') {
                          _posicaoCorpoLivreCtrl.clear();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _posicaoCorpoLivreFocusNode.requestFocus();
                          });
                        } else {
                          _posicaoCorpoLivreCtrl.text = gerarTextoPosicaoCorpo(
                            preset: selectedValue,
                            textoLivre: null,
                          );
                        }
                      });
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Decúbito dorsal'),
                          value: 'decubito_dorsal',
                        ),
                        RadioListTile<String>(
                          title: const Text('Decúbito ventral'),
                          value: 'decubito_ventral',
                        ),
                        RadioListTile<String>(
                          title: const Text('Decúbito lateral direito'),
                          value: 'lateral_direito',
                        ),
                        RadioListTile<String>(
                          title: const Text('Decúbito lateral esquerdo'),
                          value: 'lateral_esquerdo',
                        ),
                        RadioListTile<String>(
                          title: const Text('Sentado / Semi-sentado'),
                          value: 'sentado',
                        ),
                        RadioListTile<String>(
                          title: const Text('Fetal'),
                          value: 'fetal',
                        ),
                        RadioListTile<String>(
                          title: const Text('Genupeitoral'),
                          value: 'genupeitoral',
                        ),
                        RadioListTile<String>(
                          title: const Text('Pendente (enforcamento)'),
                          value: 'pendente',
                        ),
                        RadioListTile<String>(
                          title: const Text('Outra'),
                          value: 'outra',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _posicaoCorpoLivreCtrl,
                    focusNode: _posicaoCorpoLivreFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Posição do corpo',
                      border: OutlineInputBorder(),
                      hintText: 'Descrição da posição do corpo',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Localização no ambiente
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOCALIZAÇÃO NO AMBIENTE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _localizacaoAmbienteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Localização *',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: sobre a cama, no centro do quarto',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Coordenadas (opcionais)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cabeça',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaCabecaXCtrl,
                          decoration: const InputDecoration(
                            labelText: 'X',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaCabecaYCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Y',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _alturaCabecaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Altura',
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Ex: 0.5 m',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pés',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaPesXCtrl,
                          decoration: const InputDecoration(
                            labelText: 'X',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaPesYCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Y',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _alturaPesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Altura',
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Ex: 0.5 m',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Centro do Tronco',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaCentroTroncoXCtrl,
                          decoration: const InputDecoration(
                            labelText: 'X',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coordenadaCentroTroncoYCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Y',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _alturaCentroTroncoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Altura',
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Ex: 0.5 m',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Aba 3: Exames no corpo (após retirada das vestes): rigidez, hipóstase, secreções, tatuagens, lesões.
  Widget _buildExamesTab() {
    if (_modoRapido) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registre apenas os vestígios observados no cadáver, com legenda e fotografia.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VESTÍGIOS NO CADÁVER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _adicionarLesao,
                          tooltip: 'Adicionar vestígio',
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_lesoes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('Nenhum vestígio registrado'),
                        ),
                      )
                    else
                      ...List.generate(_lesoes.length, (index) {
                        final lesao = _lesoes[index];
                        return ListTile(
                          title: Text(
                            (lesao.descricao ?? '').trim().isNotEmpty
                                ? lesao.descricao!.trim()
                                : lesao.rotuloTituloLista,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lesao.fotosPaths.isNotEmpty)
                                Text(
                                  '${lesao.fotosPaths.length} foto(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              if (lesao.numerosFotografias?.isNotEmpty == true)
                                Text(
                                  'Fotografia(s): ${lesao.numerosFotografias!.map((n) => n.toString().padLeft(2, '0')).join(', ')}',
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editarLesao(index),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() => _lesoes.removeAt(index));
                                },
                                tooltip: 'Excluir',
                              ),
                            ],
                          ),
                          onTap: () => _editarLesao(index),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Exames no corpo (rigidez, hipóstase, secreções, tatuagens e lesões).',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Rigidez
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RIGIDEZ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDropdown<EstadoRigidez>(
                    label: 'Mandíbula',
                    value: _rigidezMandibula,
                    items: EstadoRigidez.values,
                    onChanged: (v) => setState(() => _rigidezMandibula = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<EstadoRigidez>(
                    label: 'Membros Superiores',
                    value: _rigidezMemSuperior,
                    items: EstadoRigidez.values,
                    onChanged: (v) => setState(() => _rigidezMemSuperior = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<EstadoRigidez>(
                    label: 'Membros Inferiores',
                    value: _rigidezMemInferior,
                    items: EstadoRigidez.values,
                    onChanged: (v) => setState(() => _rigidezMemInferior = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Manchas de Hipóstase
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANCHAS DE HIPÓSTASE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Há manchas de hipóstase?'),
                  RadioGroup<bool>(
                    groupValue: _hipostasePresente,
                    onChanged: (v) => setState(() {
                      _hipostasePresente = v;
                      if (v == false) {
                        _hipostasePosicaoCtrl.clear();
                        _hipostaseEstado = null;
                        _hipostaseCompativeis = null;
                      }
                    }),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Sim'),
                            value: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Não'),
                            value: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hipostasePresente == true) ...[
                    TextFormField(
                      controller: _hipostasePosicaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Posição',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<EstadoHipostase>(
                      label: 'Estado',
                      value: _hipostaseEstado,
                      items: EstadoHipostase.values,
                      onChanged: (v) => setState(() => _hipostaseEstado = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('Compatíveis:'),
                    RadioGroup<bool>(
                      groupValue: _hipostaseCompativeis,
                      onChanged: (v) =>
                          setState(() => _hipostaseCompativeis = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Sim'),
                              value: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Não'),
                              value: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secreções
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECREÇÕES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Há secreções?'),
                  RadioGroup<bool>(
                    groupValue: _secrecoesPresentes,
                    onChanged: (v) => setState(() {
                      _secrecoesPresentes = v;
                      if (v == false) {
                        _secrecaoNasal = null;
                        _secrecaoOral = null;
                        _secrecaoAnal = null;
                        _secrecaoPenianaVaginal = null;
                        _secrecaoNasalTipoCtrl.clear();
                        _secrecaoOralTipoCtrl.clear();
                        _secrecaoAnalTipoCtrl.clear();
                        _secrecaoPenianaVaginalTipoCtrl.clear();
                      }
                    }),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Sim'),
                            value: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Não'),
                            value: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_secrecoesPresentes == true) ...[
                    _buildSecrecaoRow('Nasal', _secrecaoNasal, (v) {
                      setState(() => _secrecaoNasal = v);
                    }, _secrecaoNasalTipoCtrl),
                    const SizedBox(height: 12),
                    _buildSecrecaoRow('Oral', _secrecaoOral, (v) {
                      setState(() => _secrecaoOral = v);
                    }, _secrecaoOralTipoCtrl),
                    const SizedBox(height: 12),
                    _buildSecrecaoRow('Anal', _secrecaoAnal, (v) {
                      setState(() => _secrecaoAnal = v);
                    }, _secrecaoAnalTipoCtrl),
                    const SizedBox(height: 12),
                    _buildSecrecaoRow(
                      _sexo == SexoCadaver.feminino ? 'Vaginal' : 'Peniana',
                      _secrecaoPenianaVaginal,
                      (v) {
                        setState(() => _secrecaoPenianaVaginal = v);
                      },
                      _secrecaoPenianaVaginalTipoCtrl,
                    ),
                  ],
                  if (_hipostasePresente == true ||
                      _secrecoesPresentes == true) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildSecaoFotos(
                      titulo: 'Fotos (manchas de hipóstase e secreções)',
                      paths: _fotosHipostaseSecrecoes,
                      onChanged: (v) =>
                          setState(() => _fotosHipostaseSecrecoes = v),
                      obrigatorio: false,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tatuagens e Marcas Corporais
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TATUAGENS E MARCAS CORPORAIS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Itens registrados',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Adicionar tatuagem/marca',
                        onPressed: _adicionarTatuagemMarca,
                      ),
                    ],
                  ),
                  Text(
                    'Cadastre uma por vez. Sugestão: foto de vista ampla (posição no corpo) e foto aproximada.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_tatuagensMarcasLista.isEmpty &&
                      _tatuagensMarcasCtrl.text.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhuma tatuagem/marca registrada.'),
                    )
                  else ...[
                    if (_tatuagensMarcasLista.isNotEmpty)
                      ...List.generate(_tatuagensMarcasLista.length, (index) {
                        final item = _tatuagensMarcasLista[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              item.descricao?.trim().isNotEmpty == true
                                  ? item.descricao!
                                  : 'Tatuagem/Marca ${index + 1}',
                            ),
                            subtitle: item.fotosPaths.isNotEmpty
                                ? Text('${item.fotosPaths.length} foto(s)')
                                : null,
                            onTap: () => _editarTatuagemMarca(index),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editarTatuagemMarca(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _tatuagensMarcasLista.removeAt(index),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (_tatuagensMarcasLista.isEmpty &&
                        _tatuagensMarcasCtrl.text.trim().isNotEmpty)
                      TextFormField(
                        controller: _tatuagensMarcasCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Descrição legada de tatuagens/marcas corporais',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 5,
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Outras Observações
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OUTRAS OBSERVAÇÕES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _outrasObservacoesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lesões/Evidências (simplificado por enquanto)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LESÕES/EVIDÊNCIAS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _adicionarLesao,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_lesoes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhuma lesão registrada'),
                      ),
                    )
                  else
                    ...List.generate(_lesoes.length, (index) {
                      final lesao = _lesoes[index];
                      return ListTile(
                        title: Text(lesao.rotuloTituloLista),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _descricaoLesaoParaExibicao(lesao),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (lesao.fotosPaths.isNotEmpty)
                              Text(
                                '${lesao.fotosPaths.length} foto(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            if (lesao.numerosFotografias?.isNotEmpty == true)
                              Text(
                                'Fotografia(s): ${lesao.numerosFotografias!.map((n) => n.toString().padLeft(2, '0')).join(', ')}',
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editarLesao(index),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() => _lesoes.removeAt(index));
                              },
                              tooltip: 'Excluir',
                            ),
                          ],
                        ),
                        onTap: () => _editarLesao(index),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Ausência de lesões de defesa
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LESÕES DE DEFESA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ausência de lesões de defesa'),
                    subtitle: const Text(
                      'Nenhuma lesão de defesa observada nos membros examinados',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _ausenciaLesoesDefesa,
                    onChanged: (v) => setState(() {
                      _ausenciaLesoesDefesa = v ?? false;
                      if (!_ausenciaLesoesDefesa) {
                        _membrosExaminadosDefesa.clear();
                      }
                    }),
                  ),
                  if (_ausenciaLesoesDefesa) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Membros examinados:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final membro in [
                      'Membro superior direito',
                      'Membro superior esquerdo',
                      'Membro inferior direito',
                      'Membro inferior esquerdo',
                    ])
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(membro),
                        value: _membrosExaminadosDefesa.contains(membro),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _membrosExaminadosDefesa.add(membro);
                          } else {
                            _membrosExaminadosDefesa.remove(membro);
                          }
                        }),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _obsLesoesDefesaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observações (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    AiSuggestionButton(
                      fieldLabel: 'Observações sobre lesões de defesa',
                      currentText: _obsLesoesDefesaCtrl.text,
                      currentTextBuilder: () => _obsLesoesDefesaCtrl.text,
                      profile: AiSuggestionProfile.cvli,
                      contextTextBuilder: _buildAiContextLesoesDefesa,
                      imagePathsBuilder: () => _fotosLesoesDefesa,
                      onReplace: (text) =>
                          _replaceControllerText(_obsLesoesDefesaCtrl, text),
                      onAppend: (text) =>
                          _appendControllerText(_obsLesoesDefesaCtrl, text),
                    ),
                    const SizedBox(height: 12),
                    _buildSecaoFotos(
                      titulo: 'Fotos dos membros',
                      paths: _fotosLesoesDefesa,
                      onChanged: (v) => setState(() => _fotosLesoesDefesa = v),
                      subpasta: 'lesoes_defesa',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Aba 2: Vestes — exame das roupas antes da retirada.
  Widget _buildVestesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Examine e registre as vestes antes da retirada (fotos opcionais por peça).',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Lista de Vestes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VESTES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _adicionarVeste,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_vestes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhuma veste registrada'),
                      ),
                    )
                  else
                    ...List.generate(_vestes.length, (index) {
                      final veste = _vestes[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${veste.numero}')),
                          title: Text(
                            _modoRapido
                                ? ((veste.notas ?? '').trim().isNotEmpty
                                      ? veste.notas!.trim()
                                      : 'Veste ${veste.numero}')
                                : (veste.tipoMarca ?? 'Veste ${veste.numero}'),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_modoRapido &&
                                  (veste.notas ?? '').trim().isNotEmpty)
                                Text('Legenda: ${veste.notas!.trim()}'),
                              if (veste.cor != null) Text('Cor: ${veste.cor}'),
                              if (veste.fotosPaths.isNotEmpty)
                                Text(
                                  '${veste.fotosPaths.length} foto(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (veste.sujidades == true)
                                    const Chip(
                                      label: Text('Sujidades'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (veste.sangue == true)
                                    const Chip(
                                      label: Text('Sangue'),
                                      backgroundColor: Colors.red,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _vestes.removeAt(index);
                              });
                            },
                          ),
                          onTap: () => _editarVeste(index),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pertences encontrados com o cadáver
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERTENCES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pertencesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descreva os pertences encontrados',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDropdown<T extends Enum>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        final labelText = (item as dynamic).label as String;
        return DropdownMenuItem<T>(value: item, child: Text(labelText));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSecrecaoRow(
    String label,
    bool? value,
    ValueChanged<bool?> onChanged,
    TextEditingController tipoController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        RadioGroup<bool>(
          groupValue: value,
          onChanged: onChanged,
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Sim'),
                  value: true,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Não'),
                  value: false,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
        if (value == true)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextFormField(
              controller: tipoController,
              decoration: const InputDecoration(
                labelText: 'De que tipo?',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
      ],
    );
  }

  /// Retorna o texto da descrição da lesão para exibir na lista (tela e ficha).
  /// Usa descrição salva, ou gera no caso PAF, ou fallback região/tipo.
  String _descricaoLesaoParaExibicao(LesaoCadaverModel lesao) {
    if (lesao.descricao != null && lesao.descricao!.trim().isNotEmpty) {
      return lesao.descricao!;
    }
    if (lesao.isPaf && lesao.paf != null) {
      return gerarDescricaoPAF(
        regiao: lesao.regiao,
        tipo: lesao.paf!.tipo,
        distancia: lesao.paf!.distancia,
        diametro: lesao.paf!.diametro,
        sinais: lesao.paf!.sinais,
      );
    }
    if (lesao.tipo != null && lesao.tipo!.trim().isNotEmpty) {
      return '${lesao.tipo}: Lesão em ${lesao.regiao}';
    }
    return 'Lesão em ${lesao.regiao}';
  }

  String _buildAiContextLesoesDefesa() {
    final partes = <String>[
      'Contexto: lesões de defesa no cadáver ${widget.cadaver.numero}.',
    ];

    if (_membrosExaminadosDefesa.isNotEmpty) {
      partes.add('Membros examinados: ${_membrosExaminadosDefesa.join(', ')}.');
    }

    if (_ausenciaLesoesDefesa) {
      partes.add('Foi marcada ausência de lesões de defesa.');
    }

    return partes.join('\n');
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

  static const String _assetCorpoMasculino = 'assets/images/corpo_homem.png';
  static const String _assetCorpoFeminino = 'assets/images/corpo_mulher.png';
  static const String _assetBarba = 'assets/images/barba.png';

  /// Abre bottom sheet com a numeração das regiões da ficha EVIDÊNCIAS NO CADÁVER (CVLI).
  /// Ao tocar em uma região, preenche o [regiaoCtrl] e fecha o sheet.
  void _mostrarNumeracaoCorpoCvli(
    BuildContext dialogContext,
    TextEditingController regiaoCtrl,
  ) {
    showModalBottomSheet(
      context: dialogContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EVIDÊNCIAS NO CADÁVER — Numeração',
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _mostrarFiguraCorpo(
                            sheetContext,
                            _assetCorpoMasculino,
                            'Corpo masculino',
                          ),
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: const Text('Masculino'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _mostrarFiguraCorpo(
                            sheetContext,
                            _assetCorpoFeminino,
                            'Corpo feminino',
                          ),
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: const Text('Feminino'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Toque em uma região para preencher o campo.',
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Vista anterior (frente)',
                          style: Theme.of(sheetContext).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                        ),
                      ),
                      ...EvidenciasCadaverRegioes.vistaAnterior.map((r) {
                        final texto = EvidenciasCadaverRegioes.textoRegiao(
                          r.numero,
                          r.nome,
                          anterior: true,
                        );
                        return ListTile(
                          title: Text('${r.numero} - ${r.nome}'),
                          dense: true,
                          onTap: () {
                            regiaoCtrl.text = texto;
                            Navigator.pop(sheetContext);
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Vista posterior (costas)',
                          style: Theme.of(sheetContext).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                        ),
                      ),
                      ...EvidenciasCadaverRegioes.vistaPosterior.map((r) {
                        final texto = EvidenciasCadaverRegioes.textoRegiao(
                          r.numero,
                          r.nome,
                          anterior: false,
                        );
                        return ListTile(
                          title: Text('${r.numero} - ${r.nome}'),
                          dense: true,
                          onTap: () {
                            regiaoCtrl.text = texto;
                            Navigator.pop(sheetContext);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _textoTipoBarbaSelecionado() {
    if (_tipoBarba == null) return 'Tipo: Nenhum selecionado';
    switch (_tipoBarba!) {
      case TipoBarba.cavanhaque:
        return 'Tipo: Cavanhaque';
      case TipoBarba.bigode:
        return 'Tipo: Bigode';
      case TipoBarba.naoSeAplica:
        return 'Tipo: Rosto limpo (não se aplica)';
      case TipoBarba.outro:
        final outro = _tipoBarbaOutroCtrl.text.trim();
        return outro.isEmpty ? 'Tipo: Nenhum selecionado' : 'Tipo: $outro';
    }
  }

  /// Abre bottom sheet com a imagem de referência da barba e lista numerada;
  /// ao tocar em um item, preenche o tipo de barba e fecha.
  void _mostrarSelecaoBarbaReferencia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tipos de barba (referência)',
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.asset(
                        _assetBarba,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, s) =>
                            const Center(child: Text('Imagem não encontrada.')),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Use o gesto de pinça para zoom. Toque no tipo desejado abaixo para preencher.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: TiposBarbaReferencia.tipos.length,
                    itemBuilder: (_, i) {
                      final item = TiposBarbaReferencia.tipos[i];
                      return ListTile(
                        title: Text('${item.numero} - ${item.nome}'),
                        dense: true,
                        onTap: () {
                          TipoBarba? tipo;
                          if (item.nome == 'Cavanhaque') {
                            tipo = TipoBarba.cavanhaque;
                          } else if (item.nome == 'Rosto Limpo') {
                            tipo = TipoBarba.naoSeAplica;
                          } else {
                            tipo = TipoBarba.outro;
                            _tipoBarbaOutroCtrl.text = item.nome;
                          }
                          setState(() => _tipoBarba = tipo);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Exibe a figura do corpo (masculino/feminino) em um diálogo para consulta.
  void _mostrarFiguraCorpo(
    BuildContext context,
    String assetPath,
    String titulo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Imagem não encontrada.',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adicionarLesao() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => LesaoCadaverFormScreen(
          fichaId: widget.ficha.id,
          cadaverNumero: widget.cadaver.numero,
          lesaoExistente: null,
          modoRapido: _modoRapido,
          manterNaTelaAposSalvarNovo: true,
          onSalvo: (LesaoCadaverModel l) {
            if (!mounted) return;
            setState(() => _lesoes.add(l));
          },
          onAjudaRegiao: _mostrarNumeracaoCorpoCvli,
        ),
      ),
    );
  }

  Future<void> _editarLesao(int index) async {
    final existente = _lesoes[index];
    final resultado = await Navigator.of(context).push<LesaoCadaverModel>(
      MaterialPageRoute(
        builder: (ctx) => LesaoCadaverFormScreen(
          fichaId: widget.ficha.id,
          cadaverNumero: widget.cadaver.numero,
          lesaoExistente: existente,
          modoRapido: _modoRapido,
          onAjudaRegiao: _mostrarNumeracaoCorpoCvli,
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    setState(() => _lesoes[index] = resultado);
  }

  Future<void> _adicionarVeste() async {
    final proximoNumero = _vestes.isEmpty
        ? 1
        : _vestes.map((v) => v.numero).reduce((a, b) => a > b ? a : b) + 1;
    final novaVeste = await Navigator.of(context).push<VesteCadaverModel>(
      MaterialPageRoute(
        builder: (ctx) => CadastroVesteScreen(
          fichaId: widget.ficha.id,
          cadaverNumero: widget.cadaver.numero,
          numeroVeste: proximoNumero,
          modoRapido: _modoRapido,
        ),
      ),
    );
    if (!mounted || novaVeste == null) return;
    setState(() => _vestes.add(novaVeste));
  }

  Future<void> _editarVeste(int index) async {
    final resultado = await Navigator.of(context).push<VesteCadaverModel>(
      MaterialPageRoute(
        builder: (ctx) => CadastroVesteScreen(
          fichaId: widget.ficha.id,
          cadaverNumero: widget.cadaver.numero,
          numeroVeste: _vestes[index].numero,
          vesteExistente: _vestes[index],
          modoRapido: _modoRapido,
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    setState(() => _vestes[index] = resultado);
  }

  Future<void> _adicionarTatuagemMarca() async {
    final nova = await Navigator.of(context).push<TatuagemMarcaCorporalModel>(
      MaterialPageRoute(
        builder: (ctx) => CadastroTatuagemMarcaScreen(
          fichaId: widget.ficha.id,
          cadaverNumero: widget.cadaver.numero,
        ),
      ),
    );
    if (!mounted || nova == null) return;
    setState(() => _tatuagensMarcasLista.add(nova));
  }

  Future<void> _editarTatuagemMarca(int index) async {
    final resultado = await Navigator.of(context)
        .push<TatuagemMarcaCorporalModel>(
          MaterialPageRoute(
            builder: (ctx) => CadastroTatuagemMarcaScreen(
              fichaId: widget.ficha.id,
              cadaverNumero: widget.cadaver.numero,
              existente: _tatuagensMarcasLista[index],
            ),
          ),
        );
    if (!mounted || resultado == null) return;
    setState(() => _tatuagensMarcasLista[index] = resultado);
  }
}

class CadastroVesteScreen extends StatefulWidget {
  final String fichaId;
  final int cadaverNumero;
  final int numeroVeste;
  final VesteCadaverModel? vesteExistente;
  final bool modoRapido;

  const CadastroVesteScreen({
    super.key,
    required this.fichaId,
    required this.cadaverNumero,
    required this.numeroVeste,
    this.vesteExistente,
    this.modoRapido = false,
  });

  @override
  State<CadastroVesteScreen> createState() => _CadastroVesteScreenState();
}

class CadastroTatuagemMarcaScreen extends StatefulWidget {
  final String fichaId;
  final int cadaverNumero;
  final TatuagemMarcaCorporalModel? existente;

  const CadastroTatuagemMarcaScreen({
    super.key,
    required this.fichaId,
    required this.cadaverNumero,
    this.existente,
  });

  @override
  State<CadastroTatuagemMarcaScreen> createState() =>
      _CadastroTatuagemMarcaScreenState();
}

class _CadastroTatuagemMarcaScreenState
    extends State<CadastroTatuagemMarcaScreen> {
  final _descricaoCtrl = TextEditingController();
  final _numerosFotosCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  List<String> _fotos = [];

  @override
  void initState() {
    super.initState();
    _descricaoCtrl.text = widget.existente?.descricao ?? '';
    if (widget.existente?.numerosFotografias.isNotEmpty == true) {
      _numerosFotosCtrl.text = widget.existente!.numerosFotografias
          .map((n) => n.toString().padLeft(2, '0'))
          .join(', ');
    }
    _fotos = List<String>.from(widget.existente?.fotosPaths ?? const []);
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _numerosFotosCtrl.dispose();
    super.dispose();
  }

  List<int> _parseNumerosFotografia(String raw) {
    final partes = raw
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final nums = <int>{};
    for (final parte in partes) {
      final n = int.tryParse(parte);
      if (n != null && n > 0) nums.add(n);
    }
    final lista = nums.toList()..sort();
    return lista;
  }

  Future<String?> _persistirFoto(XFile arquivo) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.fichaId}/cadaver_${widget.cadaverNumero}/tatuagens_marcas',
      );
      if (!await pasta.exists()) await pasta.create(recursive: true);
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

  String _nomeArquivoFoto(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  void _salvar() {
    final item = TatuagemMarcaCorporalModel(
      id:
          widget.existente?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      descricao: _descricaoCtrl.text.trim().isEmpty
          ? null
          : _descricaoCtrl.text.trim(),
      numerosFotografias: _parseNumerosFotografia(_numerosFotosCtrl.text),
      fotosPaths: List<String>.from(_fotos),
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existente == null
              ? 'Nova Tatuagem/Marca'
              : 'Editar Tatuagem/Marca',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex.: tatuagem em antebraço direito...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numerosFotosCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nº da(s) fotografia(s)',
                hintText: 'Ex.: 12, 13',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sugestão: inclua uma foto de vista ampla e outra aproximada.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
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
                    final path = await _persistirFoto(foto);
                    if (path != null) setState(() => _fotos.add(path));
                  },
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Câmera'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final fotos = await _imagePicker.pickMultiImage(
                      imageQuality: 75,
                      maxWidth: 2048,
                      maxHeight: 2048,
                    );
                    if (fotos.isEmpty || !mounted) return;
                    final novas = <String>[];
                    for (final foto in fotos) {
                      final path = await _persistirFoto(foto);
                      if (path != null) novas.add(path);
                    }
                    if (novas.isNotEmpty) {
                      setState(() => _fotos = [..._fotos, ...novas]);
                    }
                  },
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Galeria'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fotos.isEmpty)
              Text(
                'Nenhuma foto adicionada',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ..._fotos.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(p),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                    title: Text(
                      _nomeArquivoFoto(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _fotos.removeAt(i)),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _salvar, child: const Text('Salvar')),
        ),
      ),
    );
  }
}

class _CadastroVesteScreenState extends State<CadastroVesteScreen> {
  final _tipoMarcaCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  bool? _sujidades;
  bool? _sangue;
  bool? _bolsos;
  bool? _bolsosVazios;
  List<String> _fotosVeste = [];

  @override
  void initState() {
    super.initState();
    final v = widget.vesteExistente;
    _tipoMarcaCtrl.text = v?.tipoMarca ?? '';
    _corCtrl.text = v?.cor ?? '';
    _notasCtrl.text = v?.notas ?? '';
    _sujidades = v?.sujidades;
    _sangue = v?.sangue;
    _bolsos = v?.bolsos;
    _bolsosVazios = v?.bolsosVazios;
    _fotosVeste = List<String>.from(v?.fotosPaths ?? []);
  }

  @override
  void dispose() {
    _tipoMarcaCtrl.dispose();
    _corCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<String?> _persistirFotoVeste(XFile arquivo) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.fichaId}/cadaver_${widget.cadaverNumero}/veste_${widget.numeroVeste}',
      );
      if (!await pasta.exists()) await pasta.create(recursive: true);
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

  String _nomeArquivoFoto(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  String _buildAiContextVeste() {
    final partes = <String>[
      'Contexto: descrição de veste do cadáver ${widget.cadaverNumero}.',
      'Número da veste: ${widget.numeroVeste}.',
    ];

    if (_tipoMarcaCtrl.text.trim().isNotEmpty) {
      partes.add('Tipo/marca: ${_tipoMarcaCtrl.text.trim()}.');
    }
    if (_corCtrl.text.trim().isNotEmpty) {
      partes.add('Cor: ${_corCtrl.text.trim()}.');
    }
    if (_sujidades != null) {
      partes.add('Sujidades: ${_sujidades! ? 'sim' : 'não'}.');
    }
    if (_sangue != null) {
      partes.add('Sangue: ${_sangue! ? 'sim' : 'não'}.');
    }
    if (_bolsos != null) {
      partes.add('Possui bolsos: ${_bolsos! ? 'sim' : 'não'}.');
    }
    if (_bolsos == true && _bolsosVazios != null) {
      partes.add('Bolsos vazios: ${_bolsosVazios! ? 'sim' : 'não'}.');
    }

    return partes.join('\n');
  }

  void _replaceNotas(String text) {
    setState(() => _notasCtrl.text = text.trim());
  }

  void _appendNotas(String text) {
    final atual = _notasCtrl.text.trim();
    setState(() {
      _notasCtrl.text = atual.isEmpty
          ? text.trim()
          : '$atual\n\n${text.trim()}';
    });
  }

  Widget _buildSecaoFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fotos da veste',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                final path = await _persistirFotoVeste(foto);
                if (path != null) setState(() => _fotosVeste.add(path));
              },
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final fotos = await _imagePicker.pickMultiImage(
                  imageQuality: 75,
                  maxWidth: 2048,
                  maxHeight: 2048,
                );
                if (fotos.isEmpty || !mounted) return;
                final novas = <String>[];
                for (final foto in fotos) {
                  final path = await _persistirFotoVeste(foto);
                  if (path != null) novas.add(path);
                }
                if (novas.isNotEmpty) {
                  setState(() => _fotosVeste = [..._fotosVeste, ...novas]);
                }
              },
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Galeria'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_fotosVeste.isEmpty)
          Text(
            'Nenhuma foto adicionada',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          ..._fotosVeste.asMap().entries.map((entry) {
            final i = entry.key;
            final path = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(path),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  ),
                ),
                title: Text(
                  _nomeArquivoFoto(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _fotosVeste.removeAt(i));
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  void _salvar() {
    final veste = VesteCadaverModel(
      id:
          widget.vesteExistente?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      numero: widget.numeroVeste,
      tipoMarca: widget.modoRapido
          ? null
          : _tipoMarcaCtrl.text.trim().isEmpty
          ? null
          : _tipoMarcaCtrl.text.trim(),
      cor: widget.modoRapido
          ? null
          : _corCtrl.text.trim().isEmpty
          ? null
          : _corCtrl.text.trim(),
      sujidades: widget.modoRapido ? null : _sujidades,
      sangue: widget.modoRapido ? null : _sangue,
      bolsos: widget.modoRapido ? null : _bolsos,
      bolsosVazios: widget.modoRapido ? null : _bolsosVazios,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      fotosPaths: List<String>.from(_fotosVeste),
    );
    Navigator.of(context).pop(veste);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vesteExistente == null
              ? 'Nova Veste Nº ${widget.numeroVeste}'
              : 'Editar Veste Nº ${widget.numeroVeste}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.modoRapido) ...[
              TextField(
                controller: _tipoMarcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipo e marca',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _corCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Sujidades:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        ChoiceChip(
                          label: const Text('Sim'),
                          selected: _sujidades == true,
                          onSelected: (v) =>
                              setState(() => _sujidades = v ? true : null),
                        ),
                        ChoiceChip(
                          label: const Text('Não'),
                          selected: _sujidades == false,
                          onSelected: (v) =>
                              setState(() => _sujidades = v ? false : null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Sangue:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        ChoiceChip(
                          label: const Text('Sim'),
                          selected: _sangue == true,
                          onSelected: (v) =>
                              setState(() => _sangue = v ? true : null),
                        ),
                        ChoiceChip(
                          label: const Text('Não'),
                          selected: _sangue == false,
                          onSelected: (v) =>
                              setState(() => _sangue = v ? false : null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Bolsos:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        ChoiceChip(
                          label: const Text('Sim'),
                          selected: _bolsos == true,
                          onSelected: (v) =>
                              setState(() => _bolsos = v ? true : null),
                        ),
                        ChoiceChip(
                          label: const Text('Não'),
                          selected: _bolsos == false,
                          onSelected: (v) =>
                              setState(() => _bolsos = v ? false : null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_bolsos == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Vazios:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          ChoiceChip(
                            label: const Text('Sim'),
                            selected: _bolsosVazios == true,
                            onSelected: (v) =>
                                setState(() => _bolsosVazios = v ? true : null),
                          ),
                          ChoiceChip(
                            label: const Text('Não'),
                            selected: _bolsosVazios == false,
                            onSelected: (v) => setState(
                              () => _bolsosVazios = v ? false : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _notasCtrl,
              decoration: InputDecoration(
                labelText: widget.modoRapido ? 'Legenda' : 'Notas',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (!widget.modoRapido) ...[
              const SizedBox(height: 8),
              AiSuggestionButton(
                fieldLabel: 'Notas da veste',
                currentText: _notasCtrl.text,
                currentTextBuilder: () => _notasCtrl.text,
                profile: AiSuggestionProfile.cvli,
                contextTextBuilder: _buildAiContextVeste,
                imagePathsBuilder: () => _fotosVeste,
                onReplace: _replaceNotas,
                onAppend: _appendNotas,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildSecaoFotos(),
            if (widget.modoRapido) ...[
              const SizedBox(height: 8),
              Text(
                'A legenda será usada na lista de vestes. A numeração da fotografia será preenchida automaticamente no laudo.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _salvar, child: const Text('Salvar')),
        ),
      ),
    );
  }
}
