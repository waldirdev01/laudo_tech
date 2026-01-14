import 'package:flutter/material.dart';

import '../models/cadaver_model.dart';
import '../models/ficha_completa_model.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  // Posição do corpo
  String? _posicaoCorpoPreset;

  bool? _secrecaoNasal;
  bool? _secrecaoOral;
  bool? _secrecaoAnal;
  bool? _secrecaoPenianaVaginal;

  List<LesaoCadaverModel> _lesoes = [];
  List<VesteCadaverModel> _vestes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarDados();
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

    _secrecaoNasal = c.secrecaoNasal;
    _secrecaoNasalTipoCtrl.text = c.secrecaoNasalTipo ?? '';
    _secrecaoOral = c.secrecaoOral;
    _secrecaoOralTipoCtrl.text = c.secrecaoOralTipo ?? '';
    _secrecaoAnal = c.secrecaoAnal;
    _secrecaoAnalTipoCtrl.text = c.secrecaoAnalTipo ?? '';
    _secrecaoPenianaVaginal = c.secrecaoPenianaVaginal;
    _secrecaoPenianaVaginalTipoCtrl.text = c.secrecaoPenianaVaginalTipo ?? '';
    _outrasObservacoesCtrl.text = c.outrasObservacoes ?? '';
    _tatuagensMarcasCtrl.text = c.tatuagensMarcas ?? '';
    _pertencesCtrl.text = c.pertences ?? '';

    _lesoes = List<LesaoCadaverModel>.from(c.lesoes ?? []);
    _vestes = List<VesteCadaverModel>.from(c.vestes ?? []);
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
      hipostasePosicao: _hipostasePosicaoCtrl.text.trim().isEmpty
          ? null
          : _hipostasePosicaoCtrl.text.trim(),
      hipostaseEstado: _hipostaseEstado,
      hipostaseCompativeis: _hipostaseCompativeis,
      secrecaoNasal: _secrecaoNasal,
      secrecaoNasalTipo: _secrecaoNasalTipoCtrl.text.trim().isEmpty
          ? null
          : _secrecaoNasalTipoCtrl.text.trim(),
      secrecaoOral: _secrecaoOral,
      secrecaoOralTipo: _secrecaoOralTipoCtrl.text.trim().isEmpty
          ? null
          : _secrecaoOralTipoCtrl.text.trim(),
      secrecaoAnal: _secrecaoAnal,
      secrecaoAnalTipo: _secrecaoAnalTipoCtrl.text.trim().isEmpty
          ? null
          : _secrecaoAnalTipoCtrl.text.trim(),
      secrecaoPenianaVaginal: _secrecaoPenianaVaginal,
      secrecaoPenianaVaginalTipo:
          _secrecaoPenianaVaginalTipoCtrl.text.trim().isEmpty
          ? null
          : _secrecaoPenianaVaginalTipoCtrl.text.trim(),
      outrasObservacoes: _outrasObservacoesCtrl.text.trim().isEmpty
          ? null
          : _outrasObservacoesCtrl.text.trim(),
      lesoes: _lesoes,
      vestes: _vestes,
      tatuagensMarcas: _tatuagensMarcasCtrl.text.trim().isEmpty
          ? null
          : _tatuagensMarcasCtrl.text.trim(),
      pertences: _pertencesCtrl.text.trim().isEmpty
          ? null
          : _pertencesCtrl.text.trim(),
    );
  }

  void _salvar() {
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
          tabs: const [
            Tab(text: 'Descrição', icon: Icon(Icons.person)),
            Tab(text: 'Exames', icon: Icon(Icons.medical_services)),
            Tab(text: 'Vestes', icon: Icon(Icons.checkroom)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDescricaoTab(), _buildExamesTab(), _buildVestesTab()],
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

  Widget _buildDescricaoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      prefixText: '/20',
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
                    const Text(
                      'Barba',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    // Tipo da Barba
                    _buildDropdown<TipoBarba>(
                      label: 'Tipo',
                      value: _tipoBarba,
                      items: TipoBarba.values,
                      onChanged: (v) => setState(() => _tipoBarba = v),
                    ),
                    if (_tipoBarba == TipoBarba.outro) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tipoBarbaOutroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Especifique o tipo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],

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

  Widget _buildExamesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                          // Focar automaticamente no campo quando "Outra" é selecionado
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
                  // Coordenadas da Cabeça
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
                  // Coordenadas dos Pés
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
                  // Coordenadas do Centro do Tronco
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
                    onChanged: (v) => setState(() => _hipostaseCompativeis = v),
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
                  TextFormField(
                    controller: _tatuagensMarcasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descreva tatuagens, cicatrizes, marcas, etc.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
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
                        title: Text(lesao.regiao),
                        subtitle: lesao.descricao != null
                            ? Text(lesao.descricao!)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _lesoes.removeAt(index);
                            });
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVestesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            veste.tipoMarca ?? 'Veste ${veste.numero}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (veste.cor != null) Text('Cor: ${veste.cor}'),
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

  void _adicionarLesao() {
    final regiaoCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final diametroCtrl = TextEditingController();

    // Estados para PAF
    bool isPaf = false;
    TipoLesaoPaf tipoLesaoPaf = TipoLesaoPaf.entrada;
    DistanciaTiro? distanciaTiro;
    Set<String> sinaisSelecionados = {};

    void atualizarPresets(StateSetter setDialogState) {
      final novosSinais = aplicarPresetPAF(tipoLesaoPaf, distanciaTiro);
      setDialogState(() {
        sinaisSelecionados = novosSinais;
      });
    }

    void atualizarDescricaoAutomatica(StateSetter setDialogState) {
      if (isPaf && regiaoCtrl.text.trim().isNotEmpty) {
        final descricao = gerarDescricaoPAF(
          regiao: regiaoCtrl.text.trim(),
          tipo: tipoLesaoPaf,
          distancia: tipoLesaoPaf != TipoLesaoPaf.saida ? distanciaTiro : null,
          diametro: double.tryParse(diametroCtrl.text),
          sinais: sinaisSelecionados,
        );
        setDialogState(() {
          descricaoCtrl.text = descricao;
        });
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nova Lesão'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo Região
                  TextField(
                    controller: regiaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Região *',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Torácica anterior esquerda',
                    ),
                    onChanged: (_) =>
                        atualizarDescricaoAutomatica(setDialogState),
                  ),
                  const SizedBox(height: 12),

                  // Campo Tipo (desabilitado se PAF)
                  TextField(
                    controller: tipoCtrl,
                    enabled: !isPaf,
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      border: const OutlineInputBorder(),
                      hintText: isPaf ? 'PAF' : 'Ex: PAB, contusão, etc.',
                      filled: isPaf,
                      fillColor: isPaf ? Colors.grey.shade800 : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checkbox PAF
                  CheckboxListTile(
                    title: const Text('Lesão por PAF'),
                    value: isPaf,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setDialogState(() {
                        isPaf = value ?? false;
                        if (isPaf) {
                          tipoCtrl.text = 'PAF';
                          atualizarPresets(setDialogState);
                          atualizarDescricaoAutomatica(setDialogState);
                        } else {
                          tipoCtrl.clear();
                          descricaoCtrl.clear();
                          sinaisSelecionados.clear();
                          distanciaTiro = null;
                        }
                      });
                    },
                  ),

                  // Painel PAF (visível apenas se isPaf)
                  if (isPaf) ...[
                    const Divider(),
                    const SizedBox(height: 8),

                    // A) Tipo de lesão PAF
                    Text(
                      'Tipo de lesão',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TipoLesaoPaf.values.map((tipo) {
                        final isSelected = tipoLesaoPaf == tipo;
                        return ChoiceChip(
                          label: Text(tipo.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tipoLesaoPaf = tipo;
                                // Se for SAÍDA, limpar distância
                                if (tipo == TipoLesaoPaf.saida) {
                                  distanciaTiro = null;
                                }
                              });
                              atualizarPresets(setDialogState);
                              atualizarDescricaoAutomatica(setDialogState);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // B) Distância do disparo (desabilitado se SAÍDA)
                    Text(
                      'Distância do disparo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tipoLesaoPaf == TipoLesaoPaf.saida
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DistanciaTiro.values.map((dist) {
                        final isSelected = distanciaTiro == dist;
                        final isDisabled = tipoLesaoPaf == TipoLesaoPaf.saida;
                        return ChoiceChip(
                          label: Text(
                            dist.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDisabled ? Colors.grey : null,
                            ),
                          ),
                          selected: isSelected && !isDisabled,
                          onSelected: isDisabled
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    distanciaTiro = selected ? dist : null;
                                  });
                                  atualizarPresets(setDialogState);
                                  atualizarDescricaoAutomatica(setDialogState);
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // C) Diâmetro do orifício
                    TextField(
                      controller: diametroCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Diâmetro do orifício (mm)',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: 9',
                      ),
                      onChanged: (_) =>
                          atualizarDescricaoAutomatica(setDialogState),
                    ),
                    const SizedBox(height: 16),

                    // D) Características (checkboxes)
                    Text(
                      'Características',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...SinaisPaf.todos.map((sinal) {
                      return CheckboxListTile(
                        title: Text(
                          sinal,
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: sinaisSelecionados.contains(sinal),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              sinaisSelecionados.add(sinal);
                            } else {
                              sinaisSelecionados.remove(sinal);
                            }
                          });
                          atualizarDescricaoAutomatica(setDialogState);
                        },
                      );
                    }),
                    const Divider(),
                  ],

                  const SizedBox(height: 12),

                  // Campo Descrição
                  TextField(
                    controller: descricaoCtrl,
                    decoration: InputDecoration(
                      labelText: isPaf
                          ? 'Descrição (gerada automaticamente)'
                          : 'Descrição',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (regiaoCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe a região da lesão'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Montar dados PAF se aplicável
                  PafData? pafData;
                  if (isPaf) {
                    pafData = PafData(
                      tipo: tipoLesaoPaf,
                      distancia: tipoLesaoPaf != TipoLesaoPaf.saida
                          ? distanciaTiro
                          : null,
                      diametro: double.tryParse(diametroCtrl.text),
                      sinais: Set<String>.from(sinaisSelecionados),
                    );
                  }

                  setState(() {
                    _lesoes.add(
                      LesaoCadaverModel(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        regiao: regiaoCtrl.text.trim(),
                        tipo: isPaf
                            ? 'PAF'
                            : (tipoCtrl.text.trim().isEmpty
                                  ? null
                                  : tipoCtrl.text.trim()),
                        descricao: descricaoCtrl.text.trim().isEmpty
                            ? null
                            : descricaoCtrl.text.trim(),
                        isPaf: isPaf,
                        paf: pafData,
                      ),
                    );
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _adicionarVeste() {
    _mostrarDialogoVeste(null);
  }

  void _editarVeste(int index) {
    _mostrarDialogoVeste(index);
  }

  void _mostrarDialogoVeste(int? index) {
    final vesteExistente = index != null ? _vestes[index] : null;
    final proximoNumero =
        vesteExistente?.numero ??
        (_vestes.isEmpty
            ? 1
            : _vestes.map((v) => v.numero).reduce((a, b) => a > b ? a : b) + 1);

    final tipoMarcaCtrl = TextEditingController(
      text: vesteExistente?.tipoMarca ?? '',
    );
    final corCtrl = TextEditingController(text: vesteExistente?.cor ?? '');
    final notasCtrl = TextEditingController(text: vesteExistente?.notas ?? '');

    bool? sujidades = vesteExistente?.sujidades;
    bool? sangue = vesteExistente?.sangue;
    bool? bolsos = vesteExistente?.bolsos;
    bool? bolsosVazios = vesteExistente?.bolsosVazios;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Nova Veste' : 'Editar Veste'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Veste Nº $proximoNumero'),
                const SizedBox(height: 12),
                TextField(
                  controller: tipoMarcaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tipo e marca',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: corCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Sujidades:'),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Sim'),
                      selected: sujidades == true,
                      onSelected: (v) =>
                          setDialogState(() => sujidades = v ? true : null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Não'),
                      selected: sujidades == false,
                      onSelected: (v) =>
                          setDialogState(() => sujidades = v ? false : null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Sangue:'),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Sim'),
                      selected: sangue == true,
                      onSelected: (v) =>
                          setDialogState(() => sangue = v ? true : null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Não'),
                      selected: sangue == false,
                      onSelected: (v) =>
                          setDialogState(() => sangue = v ? false : null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Bolsos:'),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Sim'),
                      selected: bolsos == true,
                      onSelected: (v) =>
                          setDialogState(() => bolsos = v ? true : null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Não'),
                      selected: bolsos == false,
                      onSelected: (v) =>
                          setDialogState(() => bolsos = v ? false : null),
                    ),
                  ],
                ),
                if (bolsos == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Vazios:'),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Sim'),
                        selected: bolsosVazios == true,
                        onSelected: (v) => setDialogState(
                          () => bolsosVazios = v ? true : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Não'),
                        selected: bolsosVazios == false,
                        onSelected: (v) => setDialogState(
                          () => bolsosVazios = v ? false : null,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final novaVeste = VesteCadaverModel(
                  id:
                      vesteExistente?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  numero: proximoNumero,
                  tipoMarca: tipoMarcaCtrl.text.trim().isEmpty
                      ? null
                      : tipoMarcaCtrl.text.trim(),
                  cor: corCtrl.text.trim().isEmpty ? null : corCtrl.text.trim(),
                  sujidades: sujidades,
                  sangue: sangue,
                  bolsos: bolsos,
                  bolsosVazios: bolsosVazios,
                  notas: notasCtrl.text.trim().isEmpty
                      ? null
                      : notasCtrl.text.trim(),
                );

                setState(() {
                  if (index != null) {
                    _vestes[index] = novaVeste;
                  } else {
                    _vestes.add(novaVeste);
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
