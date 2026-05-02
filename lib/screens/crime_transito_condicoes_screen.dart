import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'crime_transito_levantamento_screen.dart';

enum _CategoriaVeiculoCTB { automoveisMotos, onibusMicroonibus, caminhoes }

class CrimeTransitoCondicoesScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const CrimeTransitoCondicoesScreen({super.key, required this.ficha});

  @override
  State<CrimeTransitoCondicoesScreen> createState() =>
      _CrimeTransitoCondicoesScreenState();
}

class _CrimeTransitoCondicoesScreenState
    extends State<CrimeTransitoCondicoesScreen> {
  final _fichaService = FichaService();
  final _larguraPistaCtrl = TextEditingController();
  final _condicaoOutroCtrl = TextEditingController();
  final _velocidadeMaxCtrl = TextEditingController();
  final _numeroFaixasCtrl = TextEditingController();
  final _largurasFaixasCtrl = TextEditingController();
  final _visibilidadeDescricaoCtrl = TextEditingController();
  final _sinalizacaoObsCtrl = TextEditingController();
  final _regimeOutroCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  final _lateralDirLarguraCtrl = TextEditingController();
  final _lateralDirObsCtrl = TextEditingController();
  final _lateralEsqLarguraCtrl = TextEditingController();
  final _lateralEsqObsCtrl = TextEditingController();

  ClassificacaoVia? _classificacaoVia;
  final Set<String> _ladosAcostamento = {};
  final Set<CondicaoSoloLocal> _soloSelecionado = {};
  final Set<IluminacaoLocal> _iluminacaoSelecionada = {};
  final Set<TracadoPista> _tracadoSelecionado = {};
  final Set<TipoPistaRodovia> _tipoPistaSelecionado = {};
  final Set<SentidoPista> _sentidoSelecionado = {};
  TipoPavimento? _tipoPavimento;
  OrientacaoVia? _orientacaoVia;
  final Set<ContaminanteTipo> _contaminantes = {};
  final Set<CondicaoViaNaoPavimentada> _condicoesNaoPavimentada = {};
  PerfilPista? _perfilDirecao;
  PerfilPista? _perfilIntensidade;
  final Set<CondicaoViaOpcao> _condicoesViaSelecionadas = {};
  final Set<PlacaVertical> _placasVerticais = {};
  ConservacaoSinalizacao? _conservacaoVertical;
  final Set<SeparacaoFaixasOpcao> _separacaoFaixas = {};
  final Set<CorFaixa> _corFaixas = {};
  final Set<SeparacaoPistasOpcao> _separacaoPistas = {};
  final Set<ElementoLateral> _lateralDirElementos = {};
  final Set<ElementoLateral> _lateralEsqElementos = {};
  RegimeTrafego? _regime;
  VisibilidadeTipo? _visibilidade;
  ConservacaoEstado? _lateralDirConservacao;
  ConservacaoEstado? _lateralEsqConservacao;
  bool _velocidadePorSinalizacao = false;
  bool _velocidadePorCTB = false;
  TipoPistaRodovia? _tipoPistaRodoviaCTB;
  _CategoriaVeiculoCTB? _categoriaVeiculoCTB;
  bool _salvando = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isUrbana =>
      _classificacaoVia != null &&
      const {
        ClassificacaoVia.urbanaTransitoRapido,
        ClassificacaoVia.urbanaArterial,
        ClassificacaoVia.urbanaColetora,
        ClassificacaoVia.urbanaLocal,
      }.contains(_classificacaoVia);

  bool get _isRural =>
      _classificacaoVia != null &&
      const {
        ClassificacaoVia.ruralRodovia,
        ClassificacaoVia.ruralEstrada,
      }.contains(_classificacaoVia);

  bool get _isRodovia => _classificacaoVia == ClassificacaoVia.ruralRodovia;
  bool get _isEstrada => _classificacaoVia == ClassificacaoVia.ruralEstrada;

  List<String> _opcoesAcostamento() {
    final lados = switch (_orientacaoVia) {
      OrientacaoVia.norteSul => ['Leste', 'Oeste'],
      OrientacaoVia.lesteOeste => ['Norte', 'Sul'],
      OrientacaoVia.nordesteSudoeste => ['Noroeste', 'Sudeste'],
      OrientacaoVia.noroesteSudeste => ['Nordeste', 'Sudoeste'],
      null => ['Direita', 'Esquerda'],
    };
    return [...lados, 'Nenhum'];
  }

  String _labelClassificacao(ClassificacaoVia v) => switch (v) {
    ClassificacaoVia.urbanaTransitoRapido => 'Trânsito Rápido',
    ClassificacaoVia.urbanaArterial => 'Arterial',
    ClassificacaoVia.urbanaColetora => 'Coletora',
    ClassificacaoVia.urbanaLocal => 'Local',
    ClassificacaoVia.ruralRodovia => 'Rodovia',
    ClassificacaoVia.ruralEstrada => 'Estrada',
  };

  String? _velocidadeCTBParaClassificacao() {
    if (!_velocidadePorCTB || _classificacaoVia == null) return null;
    return switch (_classificacaoVia!) {
      ClassificacaoVia.urbanaTransitoRapido => '80',
      ClassificacaoVia.urbanaArterial => '60',
      ClassificacaoVia.urbanaColetora => '40',
      ClassificacaoVia.urbanaLocal => '30',
      ClassificacaoVia.ruralEstrada => '60',
      ClassificacaoVia.ruralRodovia => _calcVelocidadeRodovia(),
    };
  }

  String? _calcVelocidadeRodovia() {
    if (_tipoPistaRodoviaCTB == null || _categoriaVeiculoCTB == null)
      return null;
    return switch (_categoriaVeiculoCTB!) {
      _CategoriaVeiculoCTB.automoveisMotos =>
        _tipoPistaRodoviaCTB == TipoPistaRodovia.dupla ? '110' : '100',
      _CategoriaVeiculoCTB.onibusMicroonibus => '90',
      _CategoriaVeiculoCTB.caminhoes => '80',
    };
  }

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.crimeTransitoCondicoes;
    if (dados == null) return;

    _classificacaoVia = dados.classificacaoVia;
    _soloSelecionado.addAll(dados.condicoesSolo ?? const []);
    _iluminacaoSelecionada.addAll(dados.iluminacao ?? const []);
    _tracadoSelecionado.addAll(dados.tracados ?? const []);
    _tipoPistaSelecionado.addAll(dados.tiposPista ?? const []);
    _sentidoSelecionado.addAll(dados.sentidos ?? const []);
    final perfis = dados.perfis ?? const [];
    for (final p in [
      PerfilPista.plano,
      PerfilPista.aclive,
      PerfilPista.declive,
    ]) {
      if (perfis.contains(p)) {
        _perfilDirecao = p;
        break;
      }
    }
    for (final p in [
      PerfilPista.suave,
      PerfilPista.moderado,
      PerfilPista.acentuado,
    ]) {
      if (perfis.contains(p)) {
        _perfilIntensidade = p;
        break;
      }
    }
    _tipoPavimento = dados.tipoPavimento;
    _orientacaoVia = dados.orientacaoVia;
    _ladosAcostamento.addAll(dados.ladosAcostamento ?? const []);
    _condicoesViaSelecionadas.addAll(dados.condicoesVia ?? const []);
    _contaminantes.addAll(dados.contaminantes ?? const []);
    _condicoesNaoPavimentada.addAll(dados.condicoesNaoPavimentada ?? const []);
    _placasVerticais.addAll(dados.sinalizacao?.placasVerticais ?? const []);
    _conservacaoVertical = dados.sinalizacao?.conservacaoVertical;
    _separacaoFaixas.addAll(dados.sinalizacao?.separacoesFaixas ?? const []);
    _corFaixas.addAll(dados.sinalizacao?.corFaixas ?? const []);
    _separacaoPistas.addAll(dados.separacoesPistas ?? const []);
    _lateralDirElementos.addAll(dados.lateralDireita?.elementos ?? const []);
    _lateralEsqElementos.addAll(dados.lateralEsquerda?.elementos ?? const []);
    _regime = dados.regimeTrafego;
    _visibilidade = dados.visibilidade;
    _lateralDirConservacao = dados.lateralDireita?.conservacao;
    _lateralEsqConservacao = dados.lateralEsquerda?.conservacao;
    _velocidadePorSinalizacao = dados.velocidadePorSinalizacao ?? false;
    _velocidadePorCTB = dados.velocidadePorCTB ?? false;
    _velocidadeMaxCtrl.text = _velocidadePorSinalizacao
        ? (dados.velocidadeMaxima ?? '')
        : '';
    // Para rodovia: recuperar tipo de pista e categoria do veículo a partir da velocidade salva
    if (_isRodovia && _velocidadePorCTB) {
      _inferirRodoviaDadosVelocidade(dados.velocidadeMaxima ?? '');
    }
    _larguraPistaCtrl.text = dados.larguraPista ?? '';
    _condicaoOutroCtrl.text = dados.condicaoViaOutroDescricao ?? '';
    _numeroFaixasCtrl.text = dados.numeroFaixas?.toString() ?? '';
    _largurasFaixasCtrl.text = (dados.largurasFaixas ?? const [])
        .where((e) => e.isNotEmpty)
        .join('\n');
    _visibilidadeDescricaoCtrl.text = dados.visibilidadeReducaoDescricao ?? '';
    _sinalizacaoObsCtrl.text =
        dados.sinalizacao?.placaAdvertenciaDescricao ?? '';
    _regimeOutroCtrl.text = dados.regimeTrafegoOutro ?? '';
    _observacoesCtrl.text = dados.observacoes ?? '';
    _lateralDirLarguraCtrl.text = dados.lateralDireita?.largura ?? '';
    _lateralDirObsCtrl.text = dados.lateralDireita?.observacoes ?? '';
    _lateralEsqLarguraCtrl.text = dados.lateralEsquerda?.largura ?? '';
    _lateralEsqObsCtrl.text = dados.lateralEsquerda?.observacoes ?? '';
  }

  void _inferirRodoviaDadosVelocidade(String velocidade) {
    switch (velocidade) {
      case '110':
        _tipoPistaRodoviaCTB = TipoPistaRodovia.dupla;
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.automoveisMotos;
      case '100':
        _tipoPistaRodoviaCTB = TipoPistaRodovia.simples;
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.automoveisMotos;
      case '90':
        _tipoPistaRodoviaCTB = TipoPistaRodovia.dupla;
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.onibusMicroonibus;
      case '80':
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.caminhoes;
    }
  }

  @override
  void dispose() {
    _larguraPistaCtrl.dispose();
    _condicaoOutroCtrl.dispose();
    _velocidadeMaxCtrl.dispose();
    _numeroFaixasCtrl.dispose();
    _largurasFaixasCtrl.dispose();
    _visibilidadeDescricaoCtrl.dispose();
    _sinalizacaoObsCtrl.dispose();
    _regimeOutroCtrl.dispose();
    _observacoesCtrl.dispose();
    _lateralDirLarguraCtrl.dispose();
    _lateralDirObsCtrl.dispose();
    _lateralEsqLarguraCtrl.dispose();
    _lateralEsqObsCtrl.dispose();
    super.dispose();
  }

  // ── actions ──────────────────────────────────────────────────────────────

  void _alternarSelecao<T>(Set<T> conjunto, T valor) {
    setState(() {
      if (conjunto.contains(valor)) {
        conjunto.remove(valor);
      } else {
        conjunto.add(valor);
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);

    final condicoes = CrimeTransitoCondicoesViaModel(
      classificacaoVia: _classificacaoVia,
      condicoesSolo: _soloSelecionado.toList(),
      iluminacao: _iluminacaoSelecionada.toList(),
      tracados: _tracadoSelecionado.toList(),
      tiposPista: _tipoPistaSelecionado.toList(),
      sentidos: _sentidoSelecionado.toList(),
      perfis: () {
        if (_perfilDirecao == null) return null;
        if (_perfilDirecao == PerfilPista.plano) return [PerfilPista.plano];
        final list = [_perfilDirecao!];
        if (_perfilIntensidade != null) list.add(_perfilIntensidade!);
        return list;
      }(),
      larguraPista: _larguraPistaCtrl.text.trim().isEmpty
          ? null
          : _larguraPistaCtrl.text.trim(),
      intensidadePerfil: null,
      orientacaoVia: _orientacaoVia,
      ladosAcostamento: _ladosAcostamento.isEmpty
          ? null
          : _ladosAcostamento.toList(),
      faixasAcostamento: () {
        final n = _ladosAcostamento.where((l) => l != 'Nenhum').length;
        return n == 0 ? null : n;
      }(),
      tipoPavimento: _tipoPavimento,
      condicoesVia: _condicoesViaSelecionadas.toList(),
      contaminantes: _contaminantes.isEmpty ? null : _contaminantes.toList(),
      condicoesNaoPavimentada: _condicoesNaoPavimentada.isEmpty
          ? null
          : _condicoesNaoPavimentada.toList(),
      condicaoViaOutroDescricao: _condicaoOutroCtrl.text.trim().isEmpty
          ? null
          : _condicaoOutroCtrl.text.trim(),
      sinalizacao:
          (_placasVerticais.isEmpty &&
              _separacaoFaixas.isEmpty &&
              _corFaixas.isEmpty &&
              _conservacaoVertical == null)
          ? null
          : CrimeTransitoSinalizacaoInfo(
              placasVerticais: _placasVerticais.isEmpty
                  ? null
                  : _placasVerticais.toList(),
              placaAdvertenciaDescricao:
                  _placasVerticais.contains(PlacaVertical.advertencia)
                  ? (_sinalizacaoObsCtrl.text.trim().isEmpty
                        ? null
                        : _sinalizacaoObsCtrl.text.trim())
                  : null,
              conservacaoVertical: _conservacaoVertical,
              separacoesFaixas: _separacaoFaixas.isEmpty
                  ? null
                  : _separacaoFaixas.toList(),
              corFaixas: _corFaixas.isEmpty ? null : _corFaixas.toList(),
            ),
      regimeTrafego: _regime,
      regimeTrafegoOutro: _regimeOutroCtrl.text.trim().isEmpty
          ? null
          : _regimeOutroCtrl.text.trim(),
      velocidadePorSinalizacao: _velocidadePorSinalizacao,
      velocidadePorCTB: _velocidadePorCTB,
      velocidadeMaxima: _velocidadePorSinalizacao
          ? (_velocidadeMaxCtrl.text.trim().isEmpty
                ? null
                : _velocidadeMaxCtrl.text.trim())
          : (_velocidadePorCTB ? _velocidadeCTBParaClassificacao() : null),
      numeroFaixas: int.tryParse(_numeroFaixasCtrl.text.trim()),
      largurasFaixas: _largurasFaixasCtrl.text
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      visibilidade: _visibilidade,
      visibilidadeReducaoDescricao:
          _visibilidadeDescricaoCtrl.text.trim().isEmpty
          ? null
          : _visibilidadeDescricaoCtrl.text.trim(),
      separacoesPistas: _separacaoPistas.toList(),
      lateralDireita:
          (_lateralDirElementos.isEmpty &&
              _lateralDirLarguraCtrl.text.trim().isEmpty &&
              _lateralDirObsCtrl.text.trim().isEmpty &&
              _lateralDirConservacao == null)
          ? null
          : CrimeTransitoLateralInfo(
              elementos: _lateralDirElementos.toList(),
              largura: _lateralDirLarguraCtrl.text.trim().isEmpty
                  ? null
                  : _lateralDirLarguraCtrl.text.trim(),
              conservacao: _lateralDirConservacao,
              observacoes: _lateralDirObsCtrl.text.trim().isEmpty
                  ? null
                  : _lateralDirObsCtrl.text.trim(),
            ),
      lateralEsquerda:
          (_lateralEsqElementos.isEmpty &&
              _lateralEsqLarguraCtrl.text.trim().isEmpty &&
              _lateralEsqObsCtrl.text.trim().isEmpty &&
              _lateralEsqConservacao == null)
          ? null
          : CrimeTransitoLateralInfo(
              elementos: _lateralEsqElementos.toList(),
              largura: _lateralEsqLarguraCtrl.text.trim().isEmpty
                  ? null
                  : _lateralEsqLarguraCtrl.text.trim(),
              conservacao: _lateralEsqConservacao,
              observacoes: _lateralEsqObsCtrl.text.trim().isEmpty
                  ? null
                  : _lateralEsqObsCtrl.text.trim(),
            ),
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
    );

    final fichaAtualizada = widget.ficha.copyWith(
      crimeTransitoCondicoes: condicoes,
      dataUltimaAtualizacao: DateTime.now(),
    );

    await _fichaService.salvarFicha(fichaAtualizada);

    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Condições salvas com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CrimeTransitoLevantamentoScreen(ficha: fichaAtualizada),
      ),
    );
    if (mounted && resultado == true) Navigator.of(context).pop(true);
  }

  // ── UI helpers ───────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSubLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _buildMultiSelectChips<T>({
    required Iterable<T> opcoes,
    required Set<T> selecionados,
    required String Function(T) label,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: opcoes
          .map(
            (opcao) => FilterChip(
              label: Text(label(opcao)),
              selected: selecionados.contains(opcao),
              onSelected: (_) => _alternarSelecao(selecionados, opcao),
            ),
          )
          .toList(),
    );
  }

  // ── section widgets ──────────────────────────────────────────────────────

  Widget _buildTipoViaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Urbana'),
              selected: _isUrbana,
              onSelected: (_) {
                if (!_isUrbana) {
                  setState(
                    () => _classificacaoVia = ClassificacaoVia.urbanaArterial,
                  );
                }
              },
            ),
            ChoiceChip(
              label: const Text('Rural'),
              selected: _isRural,
              onSelected: (_) {
                if (!_isRural) {
                  setState(
                    () => _classificacaoVia = ClassificacaoVia.ruralRodovia,
                  );
                }
              },
            ),
          ],
        ),
        if (_isUrbana) ...[
          const SizedBox(height: 12),
          Text(
            'Classificação da via urbana',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                [
                      ClassificacaoVia.urbanaTransitoRapido,
                      ClassificacaoVia.urbanaArterial,
                      ClassificacaoVia.urbanaColetora,
                      ClassificacaoVia.urbanaLocal,
                    ]
                    .map(
                      (v) => ChoiceChip(
                        label: Text(_labelClassificacao(v)),
                        selected: _classificacaoVia == v,
                        onSelected: (_) =>
                            setState(() => _classificacaoVia = v),
                      ),
                    )
                    .toList(),
          ),
        ],
        if (_isRural) ...[
          const SizedBox(height: 12),
          Text(
            'Tipo de via rural',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                [ClassificacaoVia.ruralRodovia, ClassificacaoVia.ruralEstrada]
                    .map(
                      (v) => ChoiceChip(
                        label: Text(_labelClassificacao(v)),
                        selected: _classificacaoVia == v,
                        onSelected: (_) =>
                            setState(() => _classificacaoVia = v),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildVelocidadeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Velocidade indicada por sinalização expressa'),
          value: _velocidadePorSinalizacao,
          onChanged: (v) => setState(() {
            _velocidadePorSinalizacao = v;
            if (v) _velocidadePorCTB = false;
          }),
        ),
        if (_velocidadePorSinalizacao)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _velocidadeMaxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Velocidade máxima permitida (km/h)',
                hintText: 'Ex: 60',
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Velocidade conforme CTB/1997 (Art. 61, §1º)'),
          subtitle: const Text(
            'Quando não houver sinalização indicando limite diferente.',
          ),
          value: _velocidadePorCTB,
          onChanged: (v) => setState(() {
            _velocidadePorCTB = v;
            if (v) {
              _velocidadePorSinalizacao = false;
              _velocidadeMaxCtrl.clear();
            } else {
              _tipoPistaRodoviaCTB = null;
              _categoriaVeiculoCTB = null;
            }
          }),
        ),
        if (_velocidadePorCTB && _isRodovia) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<TipoPistaRodovia>(
            key: ValueKey(_tipoPistaRodoviaCTB),
            isExpanded: true,
            initialValue: _tipoPistaRodoviaCTB,
            decoration: const InputDecoration(
              labelText: 'Tipo de pista da rodovia',
            ),
            hint: const Text('Pista simples ou dupla'),
            items: TipoPistaRodovia.values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e == TipoPistaRodovia.simples
                          ? 'Pista simples'
                          : 'Pista dupla',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _tipoPistaRodoviaCTB = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_CategoriaVeiculoCTB>(
            key: ValueKey(_categoriaVeiculoCTB),
            isExpanded: true,
            initialValue: _categoriaVeiculoCTB,
            decoration: const InputDecoration(
              labelText: 'Categoria do veículo (CTB)',
            ),
            hint: const Text('Selecione a categoria'),
            items: _CategoriaVeiculoCTB.values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(switch (e) {
                      _CategoriaVeiculoCTB.automoveisMotos =>
                        'Automóveis e motos',
                      _CategoriaVeiculoCTB.onibusMicroonibus =>
                        'Ônibus e micro-ônibus',
                      _CategoriaVeiculoCTB.caminhoes => 'Caminhões',
                    }),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _categoriaVeiculoCTB = v),
          ),
        ],
        if (_velocidadePorCTB) ...[
          const SizedBox(height: 12),
          if (_velocidadeCTBParaClassificacao() != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Limite: ${_velocidadeCTBParaClassificacao()} km/h',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              _isRodovia
                  ? 'Selecione o tipo de pista e a categoria do veículo acima.'
                  : 'Selecione o tipo de via para calcular o limite.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }

  Widget _buildLateralSection({
    required String titulo,
    required Set<ElementoLateral> elementos,
    required TextEditingController larguraCtrl,
    required TextEditingController obsCtrl,
    required ConservacaoEstado? conservacao,
    required void Function(ConservacaoEstado?) onConservacaoChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(titulo),
        _buildMultiSelectChips<ElementoLateral>(
          opcoes: ElementoLateral.values,
          selecionados: elementos,
          label: (v) => switch (v) {
            ElementoLateral.meioFio => 'Meio-fio',
            ElementoLateral.faixaPintada => 'Faixa pintada',
            ElementoLateral.acostamento => 'Acostamento',
            ElementoLateral.muretaConcreto => 'Mureta de concreto',
            ElementoLateral.outro => 'Outro',
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: larguraCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Largura (m)',
            hintText: 'Ex: 3,5',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ConservacaoEstado>(
          key: ValueKey(conservacao),
          initialValue: conservacao,
          decoration: const InputDecoration(labelText: 'Conservação'),
          items: ConservacaoEstado.values
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e == ConservacaoEstado.boa ? 'Boa' : 'Ruim'),
                ),
              )
              .toList(),
          onChanged: onConservacaoChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: obsCtrl,
          decoration: InputDecoration(
            labelText: 'Observações — ${titulo.toLowerCase()}',
          ),
        ),
      ],
    );
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Condições da Via'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. TIPO DE VIA ──────────────────────────────────────────
            _buildSectionTitle('Tipo de Via'),
            _buildTipoViaSection(),

            if (_classificacaoVia == null) ...[
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Selecione o tipo de via para preencher as demais informações',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ],

            if (_classificacaoVia != null) ...[
              // ─── 2. CONDIÇÕES DO LOCAL ───────────────────────────────
              _buildSectionTitle('Condições do Local'),
              _buildSubLabel('Estado do solo / pista'),
              _buildMultiSelectChips<CondicaoSoloLocal>(
                opcoes: CondicaoSoloLocal.values,
                selecionados: _soloSelecionado,
                label: (v) => switch (v) {
                  CondicaoSoloLocal.seco => 'Seco',
                  CondicaoSoloLocal.umido => 'Úmido',
                  CondicaoSoloLocal.molhado => 'Molhado',
                },
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Iluminação'),
              _buildMultiSelectChips<IluminacaoLocal>(
                opcoes: IluminacaoLocal.values,
                selecionados: _iluminacaoSelecionada,
                label: (v) => switch (v) {
                  IluminacaoLocal.artificial => 'Artificial',
                  IluminacaoLocal.naturalDia => 'Natural (dia)',
                  IluminacaoLocal.ausente => 'Ausente (noturno)',
                },
              ),

              // ─── 3. TRAÇADO E GEOMETRIA ──────────────────────────────
              _buildSectionTitle('Traçado e Geometria'),
              _buildSubLabel('Traçado da pista'),
              _buildMultiSelectChips<TracadoPista>(
                opcoes: TracadoPista.values,
                selecionados: _tracadoSelecionado,
                label: (v) => switch (v) {
                  TracadoPista.curvaEsquerda => 'Curva à esquerda',
                  TracadoPista.curvaDireita => 'Curva à direita',
                  TracadoPista.reto => 'Reto',
                  TracadoPista.raioAmplo => 'Raio amplo',
                  TracadoPista.raioPequeno => 'Raio pequeno',
                  TracadoPista.cruzamento => 'Cruzamento',
                },
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Tipo de pista'),
              _buildMultiSelectChips<TipoPistaRodovia>(
                opcoes: TipoPistaRodovia.values,
                selecionados: _tipoPistaSelecionado,
                label: (v) =>
                    v == TipoPistaRodovia.simples ? 'Simples' : 'Dupla',
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Sentido de tráfego'),
              _buildMultiSelectChips<SentidoPista>(
                opcoes: SentidoPista.values,
                selecionados: _sentidoSelecionado,
                label: (v) => v == SentidoPista.unico ? 'Único' : 'Duplo',
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Orientação da via'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: OrientacaoVia.values
                    .map(
                      (opcao) => FilterChip(
                        label: Text(switch (opcao) {
                          OrientacaoVia.norteSul => 'Norte–Sul',
                          OrientacaoVia.lesteOeste => 'Leste–Oeste',
                          OrientacaoVia.nordesteSudoeste => 'Nordeste–Sudoeste',
                          OrientacaoVia.noroesteSudeste => 'Noroeste–Sudeste',
                        }),
                        selected: _orientacaoVia == opcao,
                        onSelected: (_) => setState(() {
                          _orientacaoVia = _orientacaoVia == opcao
                              ? null
                              : opcao;
                          _ladosAcostamento.clear();
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Acostamento — lados existentes'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _opcoesAcostamento()
                    .map(
                      (lado) => FilterChip(
                        label: Text(lado),
                        selected: _ladosAcostamento.contains(lado),
                        onSelected: (_) => setState(() {
                          if (lado == 'Nenhum') {
                            _ladosAcostamento
                              ..clear()
                              ..add('Nenhum');
                          } else {
                            _ladosAcostamento.remove('Nenhum');
                            if (_ladosAcostamento.contains(lado)) {
                              _ladosAcostamento.remove(lado);
                            } else {
                              _ladosAcostamento.add(lado);
                            }
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Perfil longitudinal'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    [PerfilPista.plano, PerfilPista.aclive, PerfilPista.declive]
                        .map(
                          (opcao) => FilterChip(
                            label: Text(switch (opcao) {
                              PerfilPista.plano => 'Plano',
                              PerfilPista.aclive => 'Aclive (subida)',
                              PerfilPista.declive => 'Declive (descida)',
                              _ => opcao.name,
                            }),
                            selected: _perfilDirecao == opcao,
                            onSelected: (_) => setState(() {
                              _perfilDirecao = _perfilDirecao == opcao
                                  ? null
                                  : opcao;
                              if (_perfilDirecao != PerfilPista.aclive &&
                                  _perfilDirecao != PerfilPista.declive) {
                                _perfilIntensidade = null;
                              }
                            }),
                          ),
                        )
                        .toList(),
              ),
              if (_perfilDirecao == PerfilPista.aclive ||
                  _perfilDirecao == PerfilPista.declive) ...[
                const SizedBox(height: 8),
                _buildSubLabel('Intensidade do perfil'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      [
                            PerfilPista.suave,
                            PerfilPista.moderado,
                            PerfilPista.acentuado,
                          ]
                          .map(
                            (opcao) => FilterChip(
                              label: Text(switch (opcao) {
                                PerfilPista.suave => 'Suave',
                                PerfilPista.moderado => 'Moderado',
                                PerfilPista.acentuado => 'Acentuado',
                                _ => opcao.name,
                              }),
                              selected: _perfilIntensidade == opcao,
                              onSelected: (_) => setState(() {
                                _perfilIntensidade = _perfilIntensidade == opcao
                                    ? null
                                    : opcao;
                              }),
                            ),
                          )
                          .toList(),
                ),
              ],

              // ─── 4. DIMENSÕES ────────────────────────────────────────
              _buildSectionTitle('Dimensões'),
              TextField(
                controller: _larguraPistaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Largura total da pista (m)',
                  hintText: 'Ex: 7,0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _numeroFaixasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de faixas de rolamento',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _largurasFaixasCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                maxLines: 3,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.\n\r\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Largura de cada faixa de rolamento (m)',
                  hintText: 'Ex: 3,5\n4,0\n3,5',
                  helperText: 'Uma por linha ou separadas por vírgula',
                ),
              ),

              // ─── 5. PAVIMENTAÇÃO ─────────────────────────────────────
              _buildSectionTitle('Pavimentação'),
              _buildSubLabel(
                _isEstrada
                    ? 'Tipo de revestimento da estrada'
                    : 'Tipo de pavimento',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: TipoPavimento.values
                    .where(
                      (opcao) => _isEstrada
                          ? const {
                              TipoPavimento.cascalho,
                              TipoPavimento.terraBatida,
                              TipoPavimento.terraSolta,
                            }.contains(opcao)
                          : true,
                    )
                    .map(
                      (opcao) => FilterChip(
                        label: Text(switch (opcao) {
                          TipoPavimento.asfalto => 'Asfalto',
                          TipoPavimento.concreto => 'Concreto',
                          TipoPavimento.paralelepipedo => 'Paralelepípedo',
                          TipoPavimento.cascalho => 'Cascalho',
                          TipoPavimento.terraBatida => 'Terra batida',
                          TipoPavimento.terraSolta => 'Terra solta',
                        }),
                        selected: _tipoPavimento == opcao,
                        onSelected: (_) => setState(() {
                          _tipoPavimento = _tipoPavimento == opcao
                              ? null
                              : opcao;
                          if (_tipoPavimento == null ||
                              _tipoPavimento == TipoPavimento.asfalto ||
                              _tipoPavimento == TipoPavimento.concreto ||
                              _tipoPavimento == TipoPavimento.paralelepipedo) {
                            _condicoesNaoPavimentada.clear();
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _buildSubLabel('Condições de conservação'),
              _buildMultiSelectChips<CondicaoViaOpcao>(
                opcoes: CondicaoViaOpcao.values,
                selecionados: _condicoesViaSelecionadas,
                label: (v) => switch (v) {
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
                },
              ),
              if (_condicoesViaSelecionadas.contains(
                CondicaoViaOpcao.comContaminantes,
              )) ...[
                const SizedBox(height: 8),
                _buildSubLabel('Tipos de contaminante'),
                _buildMultiSelectChips<ContaminanteTipo>(
                  opcoes: ContaminanteTipo.values,
                  selecionados: _contaminantes,
                  label: (v) => switch (v) {
                    ContaminanteTipo.oleo => 'Óleo',
                    ContaminanteTipo.areia => 'Areia',
                    ContaminanteTipo.combustivel => 'Combustível',
                    ContaminanteTipo.outro => 'Outro',
                  },
                ),
              ],
              if (_condicoesViaSelecionadas.contains(
                CondicaoViaOpcao.outro,
              )) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _condicaoOutroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva "Outro"',
                  ),
                ),
              ],

              // Condições específicas de estrada não pavimentada
              if (_isEstrada ||
                  _tipoPavimento == TipoPavimento.cascalho ||
                  _tipoPavimento == TipoPavimento.terraBatida ||
                  _tipoPavimento == TipoPavimento.terraSolta) ...[
                const SizedBox(height: 12),
                _buildSubLabel(
                  _isEstrada
                      ? 'Condições específicas de estrada'
                      : 'Condições de via não pavimentada',
                ),
                _buildMultiSelectChips<CondicaoViaNaoPavimentada>(
                  opcoes: CondicaoViaNaoPavimentada.values,
                  selecionados: _condicoesNaoPavimentada,
                  label: (v) => switch (v) {
                    CondicaoViaNaoPavimentada.comErosao =>
                      'Com erosão (ravinas, sulcos)',
                    CondicaoViaNaoPavimentada.comValetas =>
                      'Com valetas / drenos',
                    CondicaoViaNaoPavimentada.poeiraSuspensao =>
                      'Poeira em suspensão',
                    CondicaoViaNaoPavimentada.alagada => 'Alagada / com lama',
                    CondicaoViaNaoPavimentada.vegetacaoNaPista =>
                      'Vegetação invadindo a pista',
                    CondicaoViaNaoPavimentada.acostamentoIndefinido =>
                      'Acostamento indefinido',
                  },
                ),
              ],

              // ─── 6. SINALIZAÇÃO ──────────────────────────────────────
              _buildSectionTitle('Sinalização'),
              _buildSubLabel('Sinalização vertical'),
              _buildMultiSelectChips<PlacaVertical>(
                opcoes: PlacaVertical.values,
                selecionados: _placasVerticais,
                label: (v) => switch (v) {
                  PlacaVertical.paradaObrigatoria => 'Parada obrigatória',
                  PlacaVertical.deAPreferencia => 'Dê a preferência',
                  PlacaVertical.advertencia => 'Advertência',
                },
              ),
              if (_placasVerticais.contains(PlacaVertical.advertencia)) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _sinalizacaoObsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qual placa de advertência?',
                    hintText: 'Ex: Curva perigosa, Cruzamento...',
                  ),
                ),
              ],
              if (_placasVerticais.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSubLabel('Conservação da sinalização vertical'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: ConservacaoSinalizacao.values
                      .map(
                        (opcao) => FilterChip(
                          label: Text(switch (opcao) {
                            ConservacaoSinalizacao.boa => 'Boa (nova)',
                            ConservacaoSinalizacao.regular => 'Regular',
                            ConservacaoSinalizacao.ruim => 'Ruim',
                          }),
                          selected: _conservacaoVertical == opcao,
                          onSelected: (_) => setState(() {
                            _conservacaoVertical = _conservacaoVertical == opcao
                                ? null
                                : opcao;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],

              // Sinalização horizontal — não se aplica a estradas
              if (!_isEstrada) ...[
                const SizedBox(height: 16),
                _buildSubLabel('Sinalização horizontal — marcação de faixas'),
                _buildMultiSelectChips<SeparacaoFaixasOpcao>(
                  opcoes: SeparacaoFaixasOpcao.values,
                  selecionados: _separacaoFaixas,
                  label: (v) => switch (v) {
                    SeparacaoFaixasOpcao.simplesContinua => 'Simples contínua',
                    SeparacaoFaixasOpcao.duplaContinua => 'Dupla contínua',
                    SeparacaoFaixasOpcao.simplesSeccionada =>
                      'Simples seccionada',
                    SeparacaoFaixasOpcao.duplaContinuaSeccionada =>
                      'Dupla contínua/seccionada',
                  },
                ),
                const SizedBox(height: 8),
                _buildSubLabel('Cor das faixas'),
                _buildMultiSelectChips<CorFaixa>(
                  opcoes: CorFaixa.values,
                  selecionados: _corFaixas,
                  label: (v) => v == CorFaixa.amarela ? 'Amarela' : 'Branca',
                ),
              ],

              // ─── 7. VELOCIDADE E REGIME ──────────────────────────────
              _buildSectionTitle('Velocidade e Regime de Tráfego'),
              _buildVelocidadeSection(),
              const SizedBox(height: 16),
              _buildSubLabel('Regime de tráfego no momento da perícia'),
              RadioGroup<RegimeTrafego>(
                groupValue: _regime,
                onChanged: (v) => setState(() => _regime = v),
                child: Column(
                  children: RegimeTrafego.values
                      .map(
                        (opcao) => RadioListTile<RegimeTrafego>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(switch (opcao) {
                            RegimeTrafego.intenso => 'Intenso',
                            RegimeTrafego.moderado => 'Moderado',
                            RegimeTrafego.leve => 'Leve',
                            RegimeTrafego.outro => 'Outro',
                          }),
                          value: opcao,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_regime == RegimeTrafego.outro)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _regimeOutroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descreva o regime de tráfego',
                    ),
                  ),
                ),

              // ─── 8. VISIBILIDADE ─────────────────────────────────────
              _buildSectionTitle('Visibilidade'),
              RadioGroup<VisibilidadeTipo>(
                groupValue: _visibilidade,
                onChanged: (v) => setState(() => _visibilidade = v),
                child: Column(
                  children: VisibilidadeTipo.values
                      .map(
                        (opcao) => RadioListTile<VisibilidadeTipo>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            opcao == VisibilidadeTipo.boa ? 'Boa' : 'Reduzida',
                          ),
                          value: opcao,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_visibilidade == VisibilidadeTipo.reduzida)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _visibilidadeDescricaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo da visibilidade reduzida',
                    ),
                  ),
                ),

              // ─── 9. SEPARAÇÃO DAS PISTAS (não se aplica a estradas) ──
              if (!_isEstrada) ...[
                _buildSectionTitle('Separação das Pistas'),
                _buildMultiSelectChips<SeparacaoPistasOpcao>(
                  opcoes: SeparacaoPistasOpcao.values,
                  selecionados: _separacaoPistas,
                  label: (v) => switch (v) {
                    SeparacaoPistasOpcao.canteiro => 'Canteiro',
                    SeparacaoPistasOpcao.muretaConcreto => 'Mureta de concreto',
                    SeparacaoPistasOpcao.tachoes => 'Tachões',
                    SeparacaoPistasOpcao.defensa => 'Defensa / Guard rail',
                    SeparacaoPistasOpcao.nenhum => 'Nenhum',
                    SeparacaoPistasOpcao.outro => 'Outro',
                  },
                ),
              ],

              // ─── 10. LATERAIS ────────────────────────────────────────
              _buildLateralSection(
                titulo: 'Lateral Direita da Pista',
                elementos: _lateralDirElementos,
                larguraCtrl: _lateralDirLarguraCtrl,
                obsCtrl: _lateralDirObsCtrl,
                conservacao: _lateralDirConservacao,
                onConservacaoChanged: (v) =>
                    setState(() => _lateralDirConservacao = v),
              ),
              _buildLateralSection(
                titulo: 'Lateral Esquerda da Pista',
                elementos: _lateralEsqElementos,
                larguraCtrl: _lateralEsqLarguraCtrl,
                obsCtrl: _lateralEsqObsCtrl,
                conservacao: _lateralEsqConservacao,
                onConservacaoChanged: (v) =>
                    setState(() => _lateralEsqConservacao = v),
              ),

              // ─── 11. OBSERVAÇÕES ─────────────────────────────────────
              _buildSectionTitle('Observações Gerais'),
              TextField(
                controller: _observacoesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Observações relevantes sobre a via',
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_salvando ? 'Salvando...' : 'Salvar condições'),
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
