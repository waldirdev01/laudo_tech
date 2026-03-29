import 'package:flutter/material.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'atropelamento_calculo_screen.dart';
import 'dinamica_fato_transito_screen.dart';

/// Tela para seleção da natureza da ocorrência (antes do cálculo de velocidade).
/// Define o tipo de acidente e direciona para a tela de cálculo correspondente.
class NaturezaOcorrenciaTransitoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const NaturezaOcorrenciaTransitoScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<NaturezaOcorrenciaTransitoScreen> createState() =>
      _NaturezaOcorrenciaTransitoScreenState();
}

class _NaturezaOcorrenciaTransitoScreenState
    extends State<NaturezaOcorrenciaTransitoScreen> {
  final _fichaService = FichaService();
  final _outroCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  final Set<CrimeTransitoFormaInteracao> _selecionados = {};
  bool _salvando = false;

  static const List<CrimeTransitoFormaInteracao> _simples = [
    CrimeTransitoFormaInteracao.saidaPista,
    CrimeTransitoFormaInteracao.capotamento,
    CrimeTransitoFormaInteracao.tombamento,
    CrimeTransitoFormaInteracao.queda,
    CrimeTransitoFormaInteracao.atropelamento,
    CrimeTransitoFormaInteracao.outro,
  ];

  static const List<CrimeTransitoFormaInteracao> _compostosTipos = [
    CrimeTransitoFormaInteracao.colisao,
    CrimeTransitoFormaInteracao.abalroamento,
    CrimeTransitoFormaInteracao.choque,
  ];

  static const List<CrimeTransitoFormaInteracao> _compostosDirecoes = [
    CrimeTransitoFormaInteracao.colisaoFrontal,
    CrimeTransitoFormaInteracao.colisaoTraseira,
    CrimeTransitoFormaInteracao.colisaoLateral,
    CrimeTransitoFormaInteracao.colisaoLongitudinal,
  ];

  static const List<CrimeTransitoFormaInteracao> _formasDirecoes = [
    CrimeTransitoFormaInteracao.colisaoOposta,
    CrimeTransitoFormaInteracao.colisaoTransversal,
    CrimeTransitoFormaInteracao.colisaoObliqua,
    CrimeTransitoFormaInteracao.colisaoOrtogonal,
  ];

  static const List<CrimeTransitoFormaInteracao> _formasEntidades = [
    CrimeTransitoFormaInteracao.objetoFixo,
    CrimeTransitoFormaInteracao.veiculoEstacionado,
    CrimeTransitoFormaInteracao.veiculoParado,
    CrimeTransitoFormaInteracao.pedestre,
    CrimeTransitoFormaInteracao.animal,
  ];

  @override
  void initState() {
    super.initState();
    final natureza = widget.ficha.crimeTransitoNatureza;
    if (natureza != null) {
      _selecionados.addAll(natureza.formasInteracao ?? []);
      _observacoesCtrl.text = natureza.observacoes ?? '';
      if (natureza.materialDescricao != null &&
          natureza.materialDescricao!.startsWith('Outro: ')) {
        _outroCtrl.text =
            natureza.materialDescricao!.replaceFirst('Outro: ', '').trim();
      }
    }
  }

  @override
  void dispose() {
    _outroCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  String _label(CrimeTransitoFormaInteracao e) {
    return switch (e) {
      CrimeTransitoFormaInteracao.saidaPista => 'Saída de Pista',
      CrimeTransitoFormaInteracao.capotamento => 'Capotamento',
      CrimeTransitoFormaInteracao.tombamento => 'Tombamento',
      CrimeTransitoFormaInteracao.queda => 'Queda',
      CrimeTransitoFormaInteracao.atropelamento => 'Atropelamento',
      CrimeTransitoFormaInteracao.outro => 'Outro',
      CrimeTransitoFormaInteracao.colisao => 'Colisão',
      CrimeTransitoFormaInteracao.abalroamento => 'Abalroamento',
      CrimeTransitoFormaInteracao.choque => 'Choque',
      CrimeTransitoFormaInteracao.colisaoFrontal => 'Frontal',
      CrimeTransitoFormaInteracao.colisaoTraseira => 'Traseira',
      CrimeTransitoFormaInteracao.colisaoLateral => 'Lateral',
      CrimeTransitoFormaInteracao.colisaoLongitudinal => 'Longitudinal',
      CrimeTransitoFormaInteracao.colisaoOposta => 'Oposto',
      CrimeTransitoFormaInteracao.colisaoTransversal => 'Transversal',
      CrimeTransitoFormaInteracao.colisaoObliqua => 'Oblíqua',
      CrimeTransitoFormaInteracao.colisaoOrtogonal => 'Ortogonal',
      CrimeTransitoFormaInteracao.objetoFixo => 'Objeto Fixo',
      CrimeTransitoFormaInteracao.veiculoEstacionado => 'V. Estacionado',
      CrimeTransitoFormaInteracao.veiculoParado => 'V. Parado',
      CrimeTransitoFormaInteracao.pedestre => 'Pedestre',
      CrimeTransitoFormaInteracao.animal => 'Animal',
    };
  }

  bool get _temAtropelamento => _selecionados.contains(CrimeTransitoFormaInteracao.atropelamento);

  CrimeTransitoNaturezaTipo? get _tipoDerivado {
    final temSimples = _simples.any((e) => _selecionados.contains(e));
    final temComposto = [..._compostosTipos, ..._compostosDirecoes]
        .any((e) => _selecionados.contains(e));
    if (temComposto) return CrimeTransitoNaturezaTipo.composta;
    if (temSimples) return CrimeTransitoNaturezaTipo.simples;
    return null;
  }

  int? get _quantidadeUnidades {
    if (_tipoDerivado == CrimeTransitoNaturezaTipo.composta) return 2;
    if (_tipoDerivado == CrimeTransitoNaturezaTipo.simples) return 1;
    return null;
  }

  Future<FichaCompletaModel?> _salvar() async {
    setState(() => _salvando = true);
    final partesObs = <String>[];
    if (_selecionados.contains(CrimeTransitoFormaInteracao.outro) &&
        _outroCtrl.text.trim().isNotEmpty) {
      partesObs.add('Outro: ${_outroCtrl.text.trim()}');
    }
    if (_observacoesCtrl.text.trim().isNotEmpty) {
      partesObs.add(_observacoesCtrl.text.trim());
    }
    final observacoes =
        partesObs.isEmpty ? null : partesObs.join('. ');

    final natureza = CrimeTransitoNaturezaModel(
      tipo: _tipoDerivado,
      quantidadeUnidades: _quantidadeUnidades,
      formasInteracao:
          _selecionados.isEmpty ? null : _selecionados.toList(),
      materialDescricao: _selecionados.contains(CrimeTransitoFormaInteracao.outro) &&
              _outroCtrl.text.trim().isNotEmpty
          ? 'Outro: ${_outroCtrl.text.trim()}'
          : null,
      observacoes: observacoes,
    );

    final fichaAtualizada = widget.ficha.copyWith(
      crimeTransitoNatureza: natureza,
      dataUltimaAtualizacao: DateTime.now(),
    );
    await _fichaService.salvarFicha(fichaAtualizada);
    if (!mounted) return null;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Natureza da ocorrência salva.'),
        backgroundColor: Colors.green,
      ),
    );
    return fichaAtualizada;
  }

  Future<void> _avancarParaCalculoVelocidade() async {
    final fichaAtual = await _salvar();
    if (!mounted || fichaAtual == null) return;
    if (_temAtropelamento) {
      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AtropelamentoCalculoScreen(ficha: fichaAtual),
        ),
      );
      if (resultado == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Not a crash with velocity calculation yet → go to dynamics-of-fact screen
      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) =>
              DinamicaFatoTransitoScreen(ficha: fichaAtual),
        ),
      );
      if (resultado == true && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildSecao({
    required String titulo,
    required List<CrimeTransitoFormaInteracao> opcoes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: opcoes.map((e) {
            final sel = _selecionados.contains(e);
            return FilterChip(
              label: Text(_label(e)),
              selected: sel,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selecionados.add(e);
                  } else {
                    _selecionados.remove(e);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natureza da Ocorrência'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvando ? null : _salvar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NATUREZA DA OCORRÊNCIA',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildSecao(
                      titulo: 'Simples (01 unidade)',
                      opcoes: _simples,
                    ),
                    if (_selecionados.contains(CrimeTransitoFormaInteracao.outro)) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _outroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Outro (descreva)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildSecao(
                      titulo: 'Compostos (02 ou + unidades)',
                      opcoes: [..._compostosTipos, ..._compostosDirecoes],
                    ),
                    const SizedBox(height: 20),
                    _buildSecao(
                      titulo: 'Formas de Interação',
                      opcoes: [..._formasDirecoes, ..._formasEntidades],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _observacoesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _avancarParaCalculoVelocidade,
              icon: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.speed),
              label: Text(
                _salvando
                    ? 'Salvando...'
                    : 'Avançar para Cálculo de velocidade',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se Atropelamento estiver selecionado, abre a tela de cálculo de velocidade. Nos demais tipos, abre a tela Dinâmica do Fato (cálculos de velocidade para outros tipos em versões futuras).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
