import 'package:flutter/material.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';

class CrimeTransitoNaturezaScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const CrimeTransitoNaturezaScreen({super.key, required this.ficha});

  @override
  State<CrimeTransitoNaturezaScreen> createState() =>
      _CrimeTransitoNaturezaScreenState();
}

class _CrimeTransitoNaturezaScreenState
    extends State<CrimeTransitoNaturezaScreen> {
  final _fichaService = FichaService();
  final _quantidadeCtrl = TextEditingController();
  final _materialDescricaoCtrl = TextEditingController();
  final _laboratorioCtrl = TextEditingController();
  final _examesCtrl = TextEditingController();
  final _croquiCtrl = TextEditingController();

  CrimeTransitoNaturezaTipo? _tipo;
  final Set<CrimeTransitoFormaInteracao> _formas = {};
  bool? _materialRecolhido;
  bool? _solicitouExames;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final dados = widget.ficha.crimeTransitoNatureza;
    if (dados != null) {
      _tipo = dados.tipo;
      _quantidadeCtrl.text = dados.quantidadeUnidades?.toString() ?? '';
      _formas.addAll(dados.formasInteracao ?? const []);
      _materialRecolhido = dados.materialRecolhido;
      _materialDescricaoCtrl.text = dados.materialDescricao ?? '';
      _solicitouExames = dados.solicitacaoExamesComplementares;
      _laboratorioCtrl.text = dados.laboratorioDestino ?? '';
      _examesCtrl.text = dados.examesDinamica ?? '';
      _croquiCtrl.text = dados.croquiObservacoes ?? '';
    }
  }

  @override
  void dispose() {
    _quantidadeCtrl.dispose();
    _materialDescricaoCtrl.dispose();
    _laboratorioCtrl.dispose();
    _examesCtrl.dispose();
    _croquiCtrl.dispose();
    super.dispose();
  }

  void _alternarForma(CrimeTransitoFormaInteracao forma) {
    setState(() {
      if (_formas.contains(forma)) {
        _formas.remove(forma);
      } else {
        _formas.add(forma);
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);

    final natureza = CrimeTransitoNaturezaModel(
      tipo: _tipo,
      quantidadeUnidades: int.tryParse(_quantidadeCtrl.text.trim()),
      formasInteracao: _formas.toList(),
      materialRecolhido: _materialRecolhido,
      materialDescricao: _materialDescricaoCtrl.text.trim().isEmpty
          ? null
          : _materialDescricaoCtrl.text.trim(),
      solicitacaoExamesComplementares: _solicitouExames,
      laboratorioDestino: _laboratorioCtrl.text.trim().isEmpty
          ? null
          : _laboratorioCtrl.text.trim(),
      examesDinamica:
          _examesCtrl.text.trim().isEmpty ? null : _examesCtrl.text.trim(),
      croquiObservacoes:
          _croquiCtrl.text.trim().isEmpty ? null : _croquiCtrl.text.trim(),
    );

    final fichaAtualizada = widget.ficha.copyWith(
      crimeTransitoNatureza: natureza,
      dataUltimaAtualizacao: DateTime.now(),
    );
    await _fichaService.salvarFicha(fichaAtualizada);

    if (!mounted) return;
    setState(() => _salvando = false);
    Navigator.of(context).pop(true);
  }

  Widget _buildFormasInteracao() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: CrimeTransitoFormaInteracao.values
          .map(
            (forma) => FilterChip(
              label: Text(
                switch (forma) {
                  CrimeTransitoFormaInteracao.saidaPista => 'Saída de pista',
                  CrimeTransitoFormaInteracao.colisao => 'Colisão',
                  CrimeTransitoFormaInteracao.colisaoFrontal =>
                    'Colisão frontal',
                  CrimeTransitoFormaInteracao.colisaoOposta => 'Colisão oposta',
                  CrimeTransitoFormaInteracao.objetoFixo => 'Objeto fixo',
                  CrimeTransitoFormaInteracao.capotamento => 'Capotamento',
                  CrimeTransitoFormaInteracao.abalroamento => 'Abalroamento',
                  CrimeTransitoFormaInteracao.colisaoTraseira =>
                    'Colisão traseira',
                  CrimeTransitoFormaInteracao.colisaoTransversal =>
                    'Colisão transversal',
                  CrimeTransitoFormaInteracao.veiculoEstacionado =>
                    'Veículo estacionado',
                  CrimeTransitoFormaInteracao.tombamento => 'Tombamento',
                  CrimeTransitoFormaInteracao.choque => 'Choque',
                  CrimeTransitoFormaInteracao.colisaoLateral =>
                    'Colisão lateral',
                  CrimeTransitoFormaInteracao.colisaoObliqua =>
                    'Colisão oblíqua',
                  CrimeTransitoFormaInteracao.veiculoParado => 'Veículo parado',
                  CrimeTransitoFormaInteracao.colisaoLongitudinal =>
                    'Colisão longitudinal',
                  CrimeTransitoFormaInteracao.colisaoOrtogonal =>
                    'Colisão ortogonal',
                  CrimeTransitoFormaInteracao.pedestre => 'Pedestre',
                  CrimeTransitoFormaInteracao.queda => 'Queda',
                  CrimeTransitoFormaInteracao.atropelamento => 'Atropelamento',
                  CrimeTransitoFormaInteracao.animal => 'Animal',
                  CrimeTransitoFormaInteracao.outro => 'Outro',
                },
              ),
              selected: _formas.contains(forma),
              onSelected: (_) => _alternarForma(forma),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natureza da Ocorrência'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<CrimeTransitoNaturezaTipo>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: CrimeTransitoNaturezaTipo.values
                  .map(
                    (tipo) => DropdownMenuItem(
                      value: tipo,
                      child: Text(
                        tipo == CrimeTransitoNaturezaTipo.simples
                            ? 'Simples (1 unidade)'
                            : 'Composta (2 ou mais unidades)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (valor) => setState(() => _tipo = valor),
            ),
            TextField(
              controller: _quantidadeCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantidade de unidades envolvidas',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text('Formas de interação',
                style: Theme.of(context).textTheme.titleSmall),
            _buildFormasInteracao(),
            const SizedBox(height: 16),
            DropdownButtonFormField<bool?>(
            initialValue: _materialRecolhido,
              decoration:
                  const InputDecoration(labelText: 'Material recolhido?'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Não informado')),
                DropdownMenuItem(value: true, child: Text('Sim')),
                DropdownMenuItem(value: false, child: Text('Não')),
              ],
              onChanged: (valor) => setState(() => _materialRecolhido = valor),
            ),
            TextField(
              controller: _materialDescricaoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Material recolhido (descrição)'),
            ),
            DropdownButtonFormField<bool?>(
              initialValue: _solicitouExames,
              decoration: const InputDecoration(
                labelText: 'Solicitou exames complementares?',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Não informado')),
                DropdownMenuItem(value: true, child: Text('Sim')),
                DropdownMenuItem(value: false, child: Text('Não')),
              ],
              onChanged: (valor) => setState(() => _solicitouExames = valor),
            ),
            TextField(
              controller: _laboratorioCtrl,
              decoration: const InputDecoration(
                  labelText: 'Laboratório/Seção (se solicitado)'),
            ),
            TextField(
              controller: _examesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Exames/Dinâmica'),
            ),
            TextField(
              controller: _croquiCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Observações do croqui'),
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
                label: Text(_salvando ? 'Salvando...' : 'Salvar natureza'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
