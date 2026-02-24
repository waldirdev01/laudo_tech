import 'package:flutter/material.dart';

import '../models/crime_transito_model.dart';

class CadastroEnvolvidoTransitoScreen extends StatefulWidget {
  final CrimeTransitoEnvolvidoModel envolvido;

  const CadastroEnvolvidoTransitoScreen({
    super.key,
    required this.envolvido,
  });

  @override
  State<CadastroEnvolvidoTransitoScreen> createState() =>
      _CadastroEnvolvidoTransitoScreenState();
}

class _CadastroEnvolvidoTransitoScreenState
    extends State<CadastroEnvolvidoTransitoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cnhCtrl = TextEditingController();
  final _cnhValidadeCtrl = TextEditingController();
  final _cnhCategoriaCtrl = TextEditingController();
  final _rgCtrl = TextEditingController();
  final _dataNascimentoCtrl = TextEditingController();
  final _posicaoDetalheCtrl = TextEditingController();
  final _vestesObsCtrl = TextEditingController();
  final _calcadosObsCtrl = TextEditingController();
  final _pertencesObsCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  CrimeTransitoClassificacaoEnvolvido? _classificacao;
  final Set<CrimeTransitoEquipamentoSeguranca> _equipamentos = {};
  CrimeTransitoSituacaoEnvolvido? _situacao;
  CrimeTransitoPosicaoEnvolvido? _posicao;
  bool? _vestesIntegro;
  bool? _calcadosIntegro;
  bool? _pertencesIntegro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final envolvido = widget.envolvido;
    _nomeCtrl.text = envolvido.nome ?? '';
    _cnhCtrl.text = envolvido.cnh ?? '';
    _cnhValidadeCtrl.text = envolvido.cnhValidade ?? '';
    _cnhCategoriaCtrl.text = envolvido.cnhCategoria ?? '';
    _rgCtrl.text = envolvido.rg ?? '';
    _dataNascimentoCtrl.text = envolvido.dataNascimento ?? '';
    _posicaoDetalheCtrl.text = envolvido.posicaoDetalhe ?? '';
    _vestesObsCtrl.text = envolvido.vestes?.observacoes ?? '';
    _calcadosObsCtrl.text = envolvido.calcados?.observacoes ?? '';
    _pertencesObsCtrl.text = envolvido.pertences?.observacoes ?? '';
    _observacoesCtrl.text = envolvido.observacoes ?? '';
    _classificacao = envolvido.classificacao;
    _equipamentos.addAll(envolvido.equipamentosSeguranca ?? const []);
    _situacao = envolvido.situacao;
    _posicao = envolvido.posicao;
    _vestesIntegro = envolvido.vestes?.integro;
    _calcadosIntegro = envolvido.calcados?.integro;
    _pertencesIntegro = envolvido.pertences?.integro;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnhCtrl.dispose();
    _cnhValidadeCtrl.dispose();
    _cnhCategoriaCtrl.dispose();
    _rgCtrl.dispose();
    _dataNascimentoCtrl.dispose();
    _posicaoDetalheCtrl.dispose();
    _vestesObsCtrl.dispose();
    _calcadosObsCtrl.dispose();
    _pertencesObsCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  void _alternarEquipamento(CrimeTransitoEquipamentoSeguranca equipamento) {
    setState(() {
      if (_equipamentos.contains(equipamento)) {
        _equipamentos.remove(equipamento);
      } else {
        _equipamentos.add(equipamento);
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    final envolvidoAtualizado = widget.envolvido.copyWith(
      nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
      cnh: _cnhCtrl.text.trim().isEmpty ? null : _cnhCtrl.text.trim(),
      cnhValidade: _cnhValidadeCtrl.text.trim().isEmpty
          ? null
          : _cnhValidadeCtrl.text.trim(),
      cnhCategoria: _cnhCategoriaCtrl.text.trim().isEmpty
          ? null
          : _cnhCategoriaCtrl.text.trim(),
      rg: _rgCtrl.text.trim().isEmpty ? null : _rgCtrl.text.trim(),
      dataNascimento: _dataNascimentoCtrl.text.trim().isEmpty
          ? null
          : _dataNascimentoCtrl.text.trim(),
      classificacao: _classificacao,
      equipamentosSeguranca: _equipamentos.toList(),
      situacao: _situacao,
      posicao: _posicao,
      posicaoDetalhe: _posicaoDetalheCtrl.text.trim().isEmpty
          ? null
          : _posicaoDetalheCtrl.text.trim(),
      vestes: (_vestesIntegro == null && _vestesObsCtrl.text.trim().isEmpty)
          ? null
          : IntegridadeItemModel(
              integro: _vestesIntegro,
              observacoes: _vestesObsCtrl.text.trim().isEmpty
                  ? null
                  : _vestesObsCtrl.text.trim(),
            ),
      calcados:
          (_calcadosIntegro == null && _calcadosObsCtrl.text.trim().isEmpty)
              ? null
              : IntegridadeItemModel(
                  integro: _calcadosIntegro,
                  observacoes: _calcadosObsCtrl.text.trim().isEmpty
                      ? null
                      : _calcadosObsCtrl.text.trim(),
                ),
      pertences:
          (_pertencesIntegro == null && _pertencesObsCtrl.text.trim().isEmpty)
              ? null
              : IntegridadeItemModel(
                  integro: _pertencesIntegro,
                  observacoes: _pertencesObsCtrl.text.trim().isEmpty
                      ? null
                      : _pertencesObsCtrl.text.trim(),
                ),
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop(envolvidoAtualizado);
  }

  Widget _buildEquipamentos() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: CrimeTransitoEquipamentoSeguranca.values
          .map(
            (equip) => FilterChip(
              label: Text(
                switch (equip) {
                  CrimeTransitoEquipamentoSeguranca.cinto => 'Cinto',
                  CrimeTransitoEquipamentoSeguranca.capacete => 'Capacete',
                  CrimeTransitoEquipamentoSeguranca.nenhum => 'Nenhum',
                  CrimeTransitoEquipamentoSeguranca.naoSeAplica =>
                    'Não se aplica',
                },
              ),
              selected: _equipamentos.contains(equip),
              onSelected: (_) => _alternarEquipamento(equip),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIntegridadeField({
    required String titulo,
    required bool? valor,
    required ValueChanged<bool?> onChanged,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<bool?>(
          initialValue: valor,
          decoration: InputDecoration(labelText: titulo),
          items: const [
            DropdownMenuItem(value: null, child: Text('Não informado')),
            DropdownMenuItem(value: true, child: Text('Íntegros')),
            DropdownMenuItem(value: false, child: Text('Não íntegros')),
          ],
          onChanged: onChanged,
        ),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Detalhes (se não íntegros)',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envolvido'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome (opcional)'),
              ),
              TextFormField(
                controller: _cnhCtrl,
                decoration: const InputDecoration(labelText: 'CNH n.º'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cnhValidadeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Validade CNH'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cnhCategoriaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Categoria CNH'),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _rgCtrl,
                decoration: const InputDecoration(labelText: 'RG'),
              ),
              TextFormField(
                controller: _dataNascimentoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Data de nascimento'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CrimeTransitoClassificacaoEnvolvido>(
                initialValue: _classificacao,
                decoration: const InputDecoration(labelText: 'Classificação'),
                items: CrimeTransitoClassificacaoEnvolvido.values
                    .map(
                      (valor) => DropdownMenuItem(
                        value: valor,
                        child: Text(
                          switch (valor) {
                            CrimeTransitoClassificacaoEnvolvido.condutor =>
                              'Condutor',
                            CrimeTransitoClassificacaoEnvolvido.passageiro =>
                              'Passageiro',
                            CrimeTransitoClassificacaoEnvolvido.pedestre =>
                              'Pedestre',
                          },
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (valor) => setState(() => _classificacao = valor),
              ),
              const SizedBox(height: 12),
              Text('Equipamentos de segurança',
                  style: Theme.of(context).textTheme.titleSmall),
              _buildEquipamentos(),
              const SizedBox(height: 16),
              RadioGroup<CrimeTransitoSituacaoEnvolvido>(
                groupValue: _situacao,
                onChanged: (v) => setState(() => _situacao = v),
                child: Column(
                  children: CrimeTransitoSituacaoEnvolvido.values
                      .map(
                        (valor) =>
                            RadioListTile<CrimeTransitoSituacaoEnvolvido>(
                          title: Text(
                            switch (valor) {
                              CrimeTransitoSituacaoEnvolvido.semFerimentos =>
                                'Sem ferimentos',
                              CrimeTransitoSituacaoEnvolvido.feridoGrave =>
                                'Ferido grave (hospital)',
                              CrimeTransitoSituacaoEnvolvido.obito => 'Óbito',
                            },
                          ),
                          value: valor,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<CrimeTransitoPosicaoEnvolvido>(
                groupValue: _posicao,
                onChanged: (v) => setState(() => _posicao = v),
                child: Column(
                  children: CrimeTransitoPosicaoEnvolvido.values
                      .map(
                        (valor) =>
                            RadioListTile<CrimeTransitoPosicaoEnvolvido>(
                          title: Text(
                            switch (valor) {
                              CrimeTransitoPosicaoEnvolvido.interiorVeiculo =>
                                'No interior do veículo',
                              CrimeTransitoPosicaoEnvolvido.leitoVia =>
                                'No leito da via',
                              CrimeTransitoPosicaoEnvolvido.exteriorPista =>
                                'Exterior à pista',
                            },
                          ),
                          value: valor,
                        ),
                      )
                      .toList(),
                ),
              ),
              TextField(
                controller: _posicaoDetalheCtrl,
                decoration: const InputDecoration(
                  labelText: 'Detalhe da posição (ex.: banco traseiro direito)',
                ),
              ),
              const SizedBox(height: 16),
              _buildIntegridadeField(
                titulo: 'Vestes',
                valor: _vestesIntegro,
                onChanged: (valor) => setState(() => _vestesIntegro = valor),
                controller: _vestesObsCtrl,
              ),
              _buildIntegridadeField(
                titulo: 'Calçados',
                valor: _calcadosIntegro,
                onChanged: (valor) => setState(() => _calcadosIntegro = valor),
                controller: _calcadosObsCtrl,
              ),
              _buildIntegridadeField(
                titulo: 'Pertences',
                valor: _pertencesIntegro,
                onChanged: (valor) => setState(() => _pertencesIntegro = valor),
                controller: _pertencesObsCtrl,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _observacoesCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Observações gerais'),
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
                  label: Text(_salvando ? 'Salvando...' : 'Salvar envolvido'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
