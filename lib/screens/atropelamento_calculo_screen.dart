import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/atropelamento_calculo_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/atropelamento_velocidade_service.dart';
import '../services/ficha_service.dart';

/// Presets de Ep (frente do veículo + perfil do pedestre / altura do CG)
enum EpPreset {
  adultoFrenteBaixa(0.64),
  adultoFrenteAlta(0.744),
  criancaFrenteBaixa(0.727),
  criancaFrenteAlta(0.831),
  manual(null);

  final double? value;
  const EpPreset(this.value);
}

/// Cálculo de velocidade – Atropelamento (Searle / Northwestern).
/// Primeiro o perito escolhe: forward projection → Northwestern; senão → Searle (frente do carro + perfil do pedestre).
class AtropelamentoCalculoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const AtropelamentoCalculoScreen({super.key, required this.ficha});

  @override
  State<AtropelamentoCalculoScreen> createState() =>
      _AtropelamentoCalculoScreenState();
}

class _AtropelamentoCalculoScreenState extends State<AtropelamentoCalculoScreen> {
  final _fichaService = FichaService();

  final _sCtrl = TextEditingController();
  final _muCustomCtrl = TextEditingController();
  final _muMinCtrl = TextEditingController();
  final _muMaxCtrl = TextEditingController();
  final _epManualCtrl = TextEditingController();

  /// true = Northwestern (forward), false = Searle (frente + perfil)
  bool _forwardProjection = true;

  AtropelamentoTipoPiso? _presetMu;
  bool _usarMuManual = false;
  EpPreset _epPreset = EpPreset.adultoFrenteBaixa;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.ficha.atropelamentoCalculo;
    if (d != null) {
      _sCtrl.text = _str(d.dt);
      _muCustomCtrl.text = _str(d.muCustom);
      _muMinCtrl.text = _str(d.muMin);
      _muMaxCtrl.text = _str(d.muMax);
      _epManualCtrl.text = _str(d.epCustom);
      _presetMu = d.tipoPiso;
      _usarMuManual = d.muCustom != null;
      _forwardProjection = d.useNorthwestern ??
          (d.tipoVitima == null && d.frontalVeiculo == null && d.epCustom == null);
      if (d.epCustom != null) {
        _epPreset = EpPreset.manual;
      } else if (d.tipoVitima != null && d.frontalVeiculo != null) {
        if (d.tipoVitima == AtropelamentoTipoVitima.adulto &&
            d.frontalVeiculo == AtropelamentoFrontalVeiculo.baixo) {
          _epPreset = EpPreset.adultoFrenteBaixa;
        } else if (d.tipoVitima == AtropelamentoTipoVitima.adulto &&
            d.frontalVeiculo == AtropelamentoFrontalVeiculo.alto) {
          _epPreset = EpPreset.adultoFrenteAlta;
        } else if (d.tipoVitima == AtropelamentoTipoVitima.crianca &&
            d.frontalVeiculo == AtropelamentoFrontalVeiculo.baixo) {
          _epPreset = EpPreset.criancaFrenteBaixa;
        } else if (d.tipoVitima == AtropelamentoTipoVitima.crianca &&
            d.frontalVeiculo == AtropelamentoFrontalVeiculo.alto) {
          _epPreset = EpPreset.criancaFrenteAlta;
        }
      }
    }
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  @override
  void dispose() {
    _sCtrl.dispose();
    _muCustomCtrl.dispose();
    _muMinCtrl.dispose();
    _muMaxCtrl.dispose();
    _epManualCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String s) {
    final t = s.trim().replaceFirst(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  bool get _sValido {
    final s = _parseDouble(_sCtrl.text);
    return s != null && s > 0;
  }

  bool _muValido(double? mu) => mu != null && mu > 0 && mu <= 1;

  bool _epValido(double? ep) => ep != null && ep > 0 && ep < 1;

  double? get _muEfetivo {
    if (_usarMuManual) return _parseDouble(_muCustomCtrl.text);
    return _presetMu?.mu;
  }

  double? get _epEfetivo {
    if (_epPreset == EpPreset.manual) return _parseDouble(_epManualCtrl.text);
    return _epPreset.value;
  }

  void _salvar() {
    final s = _parseDouble(_sCtrl.text);
    final mu = _muEfetivo;
    if (s == null || s <= 0 || !_muValido(mu)) return;

    if (!_forwardProjection) {
      final ep = _epEfetivo;
      if (!_epValido(ep)) return;
    }

    final muMin = _parseDouble(_muMinCtrl.text);
    final muMax = _parseDouble(_muMaxCtrl.text);
    AtropelamentoTipoVitima? vitima;
    AtropelamentoFrontalVeiculo? frontal;
    double? epCustom;
    if (!_forwardProjection) {
      if (_epPreset == EpPreset.adultoFrenteBaixa) {
        vitima = AtropelamentoTipoVitima.adulto;
        frontal = AtropelamentoFrontalVeiculo.baixo;
      } else if (_epPreset == EpPreset.adultoFrenteAlta) {
        vitima = AtropelamentoTipoVitima.adulto;
        frontal = AtropelamentoFrontalVeiculo.alto;
      } else if (_epPreset == EpPreset.criancaFrenteBaixa) {
        vitima = AtropelamentoTipoVitima.crianca;
        frontal = AtropelamentoFrontalVeiculo.baixo;
      } else if (_epPreset == EpPreset.criancaFrenteAlta) {
        vitima = AtropelamentoTipoVitima.crianca;
        frontal = AtropelamentoFrontalVeiculo.alto;
      } else {
        epCustom = _epEfetivo;
      }
    }

    final model = AtropelamentoCalculoModel(
      dt: s,
      tipoPiso: _usarMuManual ? null : _presetMu,
      muCustom: _usarMuManual ? mu : null,
      tipoVitima: vitima,
      frontalVeiculo: frontal,
      epCustom: epCustom,
      muMin: (muMin != null && muMin > 0 && muMin <= 1) ? muMin : null,
      muMax: (muMax != null && muMax > 0 && muMax <= 1) ? muMax : null,
      useNorthwestern: _forwardProjection,
    );
    setState(() => _salvando = true);
    _fichaService
        .salvarFicha(
      widget.ficha.copyWith(
        atropelamentoCalculo: model,
        dataUltimaAtualizacao: DateTime.now(),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() => _salvando = false);
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _parseDouble(_sCtrl.text);
    final mu = _muEfetivo;
    final ep = _epEfetivo;
    final muMin = _parseDouble(_muMinCtrl.text);
    final muMax = _parseDouble(_muMaxCtrl.text);

    final useRange = _muValido(muMin) && _muValido(muMax) && (muMin ?? 0) <= (muMax ?? 0);

    final podeNorthwestern = _sValido && _muValido(mu);
    final resultadoNorthwestern = podeNorthwestern && s != null && mu != null
        ? calcularSoNorthwestern(
            s: s,
            mu: mu,
            muMin: useRange ? muMin : null,
            muMax: useRange ? muMax : null,
          )
        : null;

    final podeSearle = _sValido && _muValido(mu) && _epValido(ep);
    final resultadoSearle = podeSearle && s != null && mu != null && ep != null
        ? calcularAtropelamento(
            s: s,
            mu: mu,
            muMin: useRange ? muMin : null,
            muMax: useRange ? muMax : null,
            ep: ep,
          )
        : null;

    final podeSalvar = _forwardProjection ? podeNorthwestern : podeSearle;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cálculo de velocidade – Atropelamento (Searle / Northwestern)',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1) Tipo de projeção (define o método) ──
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'É projeção para frente (forward projection)?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<bool>(
                      groupValue: _forwardProjection,
                      onChanged: (v) {
                        if (v != null) setState(() => _forwardProjection = v);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<bool>(
                            title: const Text('Sim → Northwestern'),
                            subtitle: const Text(
                              'Usa só distância de projeção (s) e atrito (µ).',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: true,
                          ),
                          RadioListTile<bool>(
                            title: const Text('Não → Searle'),
                            subtitle: const Text(
                              'Defina frente do veículo e perfil do pedestre (altura do CG).',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 2) Entradas comuns: s e µ ──
            Text(
              'Distância total de projeção (throw distance)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _sCtrl,
              decoration: InputDecoration(
                labelText: 's (m)',
                hintText: 'Metros',
                helperText:
                    'Do ponto de impacto (POI) ao repouso final do pedestre (POR), '
                    'independente de voo/contato/arraste.',
                border: const OutlineInputBorder(),
                errorText: _sCtrl.text.trim().isNotEmpty && !_sValido
                    ? 'Informe s > 0'
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Text(
              'Coeficiente de atrito pedestre–solo (µ_ped)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _usarMuManual,
                  onChanged: (v) => setState(() => _usarMuManual = v ?? false),
                ),
                const Text('Valor manual'),
              ],
            ),
            if (!_usarMuManual)
              DropdownButtonFormField<AtropelamentoTipoPiso>(
                initialValue: _presetMu,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Preset',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AtropelamentoTipoPiso.asfaltoSeco,
                    child: Text('Asfalto seco (µ = 0,66)'),
                  ),
                  DropdownMenuItem(
                    value: AtropelamentoTipoPiso.asfaltoMolhado,
                    child: Text('Asfalto molhado (µ = 0,50)'),
                  ),
                  DropdownMenuItem(
                    value: AtropelamentoTipoPiso.terraGrama,
                    child: Text('Terra/grama (µ = 0,79)'),
                  ),
                ],
                onChanged: (v) => setState(() => _presetMu = v),
              )
            else
              TextFormField(
                controller: _muCustomCtrl,
                decoration: InputDecoration(
                  labelText: 'µ (0 < µ ≤ 1)',
                  border: const OutlineInputBorder(),
                  errorText: _muCustomCtrl.text.trim().isNotEmpty &&
                          !_muValido(_parseDouble(_muCustomCtrl.text))
                      ? 'Use valor entre 0 e 1'
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 12),
            Text(
              'Faixa opcional (intervalo de velocidade)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _muMinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'µ mín',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _muMaxCtrl,
                    decoration: const InputDecoration(
                      labelText: 'µ máx',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 3) Só para Searle: frente do veículo + perfil do pedestre ──
            if (!_forwardProjection) ...[
              Text(
                'Frente do veículo e perfil do pedestre (altura do CG)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<EpPreset>(
                initialValue: _epPreset,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: EpPreset.adultoFrenteBaixa,
                    child: Text('Adulto, frente baixa (0,64)'),
                  ),
                  DropdownMenuItem(
                    value: EpPreset.adultoFrenteAlta,
                    child: Text('Adulto, frente alta (0,74)'),
                  ),
                  DropdownMenuItem(
                    value: EpPreset.criancaFrenteBaixa,
                    child: Text('Criança, frente baixa (0,73)'),
                  ),
                  DropdownMenuItem(
                    value: EpPreset.criancaFrenteAlta,
                    child: Text('Criança, frente alta (0,83)'),
                  ),
                  DropdownMenuItem(
                    value: EpPreset.manual,
                    child: Text('Ep manual'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _epPreset = v ?? EpPreset.adultoFrenteBaixa),
              ),
              if (_epPreset == EpPreset.manual) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _epManualCtrl,
                  decoration: InputDecoration(
                    labelText: 'Ep (0 < Ep < 1)',
                    border: const OutlineInputBorder(),
                    errorText: _epManualCtrl.text.trim().isNotEmpty &&
                            !_epValido(_parseDouble(_epManualCtrl.text))
                        ? 'Use valor entre 0 e 1'
                        : null,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // ── 4) Um único card de resultado ──
            if (_forwardProjection && resultadoNorthwestern != null)
              _buildCardNorthwestern(context, resultadoNorthwestern)
            else if (!_forwardProjection && resultadoSearle != null)
              _buildCardSearle(context, resultadoSearle),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (podeSalvar && !_salvando) ? _salvar : null,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSearle(
      BuildContext context, ResultadosAtropelamento r) {
    final vp = r.searleVp;
    final vc = r.searleVc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado – Searle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (vp.isIntervalo)
              _row('Vp (min–max):',
                  '${vp.vMinKmh?.toStringAsFixed(1)} – ${vp.vMaxKmh?.toStringAsFixed(1)} km/h')
            else
              _row('Vp:',
                  '${vp.vKmh?.toStringAsFixed(1)} km/h (${vp.vMs?.toStringAsFixed(2)} m/s)'),
            if (vc.isIntervalo)
              _row('Vc (min–max):',
                  '${vc.vMinKmh?.toStringAsFixed(1)} – ${vc.vMaxKmh?.toStringAsFixed(1)} km/h')
            else
              _row('Vc:',
                  '${vc.vKmh?.toStringAsFixed(1)} km/h (${vc.vMs?.toStringAsFixed(2)} m/s)'),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNorthwestern(
      BuildContext context, ResultadoVelocidade vc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado – Northwestern',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (vc.isIntervalo)
              _row('Vc (min–max):',
                  '${vc.vMinKmh?.toStringAsFixed(1)} – ${vc.vMaxKmh?.toStringAsFixed(1)} km/h')
            else
              _row('Vc:',
                  '${vc.vKmh?.toStringAsFixed(1)} km/h (${vc.vMs?.toStringAsFixed(2)} m/s)'),
            const SizedBox(height: 6),
            Text(
              'Válido para forward projection.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
              child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
