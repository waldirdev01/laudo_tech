import 'package:flutter/material.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';

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
  final _intensidadePerfilCtrl = TextEditingController();
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

  final Set<CondicaoSoloLocal> _soloSelecionado = {};
  final Set<IluminacaoLocal> _iluminacaoSelecionada = {};
  final Set<TracadoPista> _tracadoSelecionado = {};
  final Set<TipoPistaRodovia> _tipoPistaSelecionado = {};
  final Set<SentidoPista> _sentidoSelecionado = {};
  final Set<PerfilPista> _perfilSelecionado = {};
  final Set<CondicaoViaOpcao> _condicoesViaSelecionadas = {};
  final Set<SinalizacaoTipo> _sinalizacaoTipos = {};
  final Set<SinalizacaoSituacao> _sinalizacaoSituacoes = {};
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
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.crimeTransitoCondicoes;
    if (dados == null) return;

    _soloSelecionado.addAll(dados.condicoesSolo ?? const []);
    _iluminacaoSelecionada.addAll(dados.iluminacao ?? const []);
    _tracadoSelecionado.addAll(dados.tracados ?? const []);
    _tipoPistaSelecionado.addAll(dados.tiposPista ?? const []);
    _sentidoSelecionado.addAll(dados.sentidos ?? const []);
    _perfilSelecionado.addAll(dados.perfis ?? const []);
    _condicoesViaSelecionadas.addAll(dados.condicoesVia ?? const []);
    _sinalizacaoTipos.addAll(dados.sinalizacao?.tipos ?? const []);
    _sinalizacaoSituacoes.addAll(dados.sinalizacao?.situacoes ?? const []);
    _separacaoFaixas.addAll(dados.separacoesFaixas ?? const []);
    _corFaixas.addAll(dados.corFaixas ?? const []);
    _separacaoPistas.addAll(dados.separacoesPistas ?? const []);
    _lateralDirElementos.addAll(dados.lateralDireita?.elementos ?? const []);
    _lateralEsqElementos.addAll(dados.lateralEsquerda?.elementos ?? const []);
    _regime = dados.regimeTrafego;
    _visibilidade = dados.visibilidade;
    _lateralDirConservacao = dados.lateralDireita?.conservacao;
    _lateralEsqConservacao = dados.lateralEsquerda?.conservacao;
    _velocidadePorSinalizacao = dados.velocidadePorSinalizacao ?? false;
    _velocidadePorCTB = dados.velocidadePorCTB ?? false;

    _larguraPistaCtrl.text = dados.larguraPista ?? '';
    _intensidadePerfilCtrl.text = dados.intensidadePerfil ?? '';
    _condicaoOutroCtrl.text = dados.condicaoViaOutroDescricao ?? '';
    _velocidadeMaxCtrl.text = dados.velocidadeMaxima ?? '';
    _numeroFaixasCtrl.text =
        dados.numeroFaixas != null ? dados.numeroFaixas.toString() : '';
    _largurasFaixasCtrl.text = (dados.largurasFaixas ?? const [])
        .where((e) => e.isNotEmpty)
        .join('\n');
    _visibilidadeDescricaoCtrl.text = dados.visibilidadeReducaoDescricao ?? '';
    _sinalizacaoObsCtrl.text = dados.sinalizacao?.observacoes ?? '';
    _regimeOutroCtrl.text = dados.regimeTrafegoOutro ?? '';
    _observacoesCtrl.text = dados.observacoes ?? '';
    _lateralDirLarguraCtrl.text = dados.lateralDireita?.largura ?? '';
    _lateralDirObsCtrl.text = dados.lateralDireita?.observacoes ?? '';
    _lateralEsqLarguraCtrl.text = dados.lateralEsquerda?.largura ?? '';
    _lateralEsqObsCtrl.text = dados.lateralEsquerda?.observacoes ?? '';
  }

  @override
  void dispose() {
    _larguraPistaCtrl.dispose();
    _intensidadePerfilCtrl.dispose();
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
      condicoesSolo: _soloSelecionado.toList(),
      iluminacao: _iluminacaoSelecionada.toList(),
      tracados: _tracadoSelecionado.toList(),
      tiposPista: _tipoPistaSelecionado.toList(),
      sentidos: _sentidoSelecionado.toList(),
      perfis: _perfilSelecionado.toList(),
      larguraPista: _larguraPistaCtrl.text.trim().isEmpty
          ? null
          : _larguraPistaCtrl.text.trim(),
      intensidadePerfil: _intensidadePerfilCtrl.text.trim().isEmpty
          ? null
          : _intensidadePerfilCtrl.text.trim(),
      condicoesVia: _condicoesViaSelecionadas.toList(),
      condicaoViaOutroDescricao: _condicaoOutroCtrl.text.trim().isEmpty
          ? null
          : _condicaoOutroCtrl.text.trim(),
      sinalizacao: (_sinalizacaoTipos.isEmpty &&
              _sinalizacaoSituacoes.isEmpty &&
              _sinalizacaoObsCtrl.text.trim().isEmpty)
          ? null
          : CrimeTransitoSinalizacaoInfo(
              tipos: _sinalizacaoTipos.toList(),
              situacoes: _sinalizacaoSituacoes.toList(),
              observacoes: _sinalizacaoObsCtrl.text.trim().isEmpty
                  ? null
                  : _sinalizacaoObsCtrl.text.trim(),
            ),
      regimeTrafego: _regime,
      regimeTrafegoOutro: _regimeOutroCtrl.text.trim().isEmpty
          ? null
          : _regimeOutroCtrl.text.trim(),
      velocidadePorSinalizacao: _velocidadePorSinalizacao,
      velocidadePorCTB: _velocidadePorCTB,
      velocidadeMaxima: _velocidadeMaxCtrl.text.trim().isEmpty
          ? null
          : _velocidadeMaxCtrl.text.trim(),
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
      separacoesFaixas: _separacaoFaixas.toList(),
      corFaixas: _corFaixas.toList(),
      separacoesPistas: _separacaoPistas.toList(),
      lateralDireita: (_lateralDirElementos.isEmpty &&
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
      lateralEsquerda: (_lateralEsqElementos.isEmpty &&
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
    Navigator.of(context).pop(true);
  }

  Widget _buildSectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condições da Via - Trânsito'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Condições do Local'),
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
            _buildSectionTitle('Iluminação'),
            _buildMultiSelectChips<IluminacaoLocal>(
              opcoes: IluminacaoLocal.values,
              selecionados: _iluminacaoSelecionada,
              label: (v) => switch (v) {
                IluminacaoLocal.artificial => 'Artificial',
                IluminacaoLocal.naturalDia => 'Natural (Dia)',
                IluminacaoLocal.ausente => 'Ausente (Noturno)',
              },
            ),
            _buildSectionTitle('Traçado da Pista'),
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
            _buildSectionTitle('Tipo de Pista'),
            _buildMultiSelectChips<TipoPistaRodovia>(
              opcoes: TipoPistaRodovia.values,
              selecionados: _tipoPistaSelecionado,
              label: (v) => v == TipoPistaRodovia.simples ? 'Simples' : 'Dupla',
            ),
            _buildSectionTitle('Sentido da Via'),
            _buildMultiSelectChips<SentidoPista>(
              opcoes: SentidoPista.values,
              selecionados: _sentidoSelecionado,
              label: (v) => v == SentidoPista.unico ? 'Único' : 'Duplo',
            ),
            _buildSectionTitle('Perfil da Via'),
            _buildMultiSelectChips<PerfilPista>(
              opcoes: PerfilPista.values,
              selecionados: _perfilSelecionado,
              label: (v) => switch (v) {
                PerfilPista.plano => 'Plano',
                PerfilPista.suave => 'Suave',
                PerfilPista.declive => 'Declive',
                PerfilPista.moderado => 'Moderado',
                PerfilPista.aclive => 'Aclive',
                PerfilPista.acentuado => 'Acentuado',
              },
            ),
            TextField(
              controller: _larguraPistaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Largura da pista (m)',
              ),
            ),
            TextField(
              controller: _intensidadePerfilCtrl,
              decoration: const InputDecoration(
                labelText: 'Intensidade (Aclive/Declive)',
              ),
            ),
            _buildSectionTitle('Condições da Via / Pavimentação'),
            _buildMultiSelectChips<CondicaoViaOpcao>(
              opcoes: CondicaoViaOpcao.values,
              selecionados: _condicoesViaSelecionadas,
              label: (v) => switch (v) {
                CondicaoViaOpcao.seca => 'Seca',
                CondicaoViaOpcao.molhada => 'Molhada',
                CondicaoViaOpcao.semDefeito => 'Sem defeito',
                CondicaoViaOpcao.emObras => 'Em obras',
                CondicaoViaOpcao.cascalho => 'Cascalho',
                CondicaoViaOpcao.terra => 'Terra',
                CondicaoViaOpcao.asfaltoRugoso => 'Asfalto rugoso',
                CondicaoViaOpcao.buracos => 'Buracos',
                CondicaoViaOpcao.ondulacoes => 'Ondulações',
                CondicaoViaOpcao.contaminantes => 'Com contaminantes',
                CondicaoViaOpcao.asfaltoLiso => 'Asfalto liso',
                CondicaoViaOpcao.outro => 'Outro',
              },
            ),
            TextField(
              controller: _condicaoOutroCtrl,
              decoration: const InputDecoration(
                labelText: 'Descreva "Outro" (se aplicável)',
              ),
            ),
            _buildSectionTitle('Sinalização presente'),
            _buildMultiSelectChips<SinalizacaoTipo>(
              opcoes: SinalizacaoTipo.values,
              selecionados: _sinalizacaoTipos,
              label: (v) => switch (v) {
                SinalizacaoTipo.vertical => 'Vertical',
                SinalizacaoTipo.horizontal => 'Horizontal',
                SinalizacaoTipo.semaforica => 'Semafórica',
              },
            ),
            const SizedBox(height: 8),
            Text('Situação da Sinalização',
                style: Theme.of(context).textTheme.titleSmall),
            _buildMultiSelectChips<SinalizacaoSituacao>(
              opcoes: SinalizacaoSituacao.values,
              selecionados: _sinalizacaoSituacoes,
              label: (v) => switch (v) {
                SinalizacaoSituacao.normal => 'Normal',
                SinalizacaoSituacao.desligado => 'Desligado',
                SinalizacaoSituacao.defeituoso => 'Defeituoso',
              },
            ),
            TextField(
              controller: _sinalizacaoObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações sobre sinalização',
              ),
            ),
            _buildSectionTitle('Regime de Tráfego'),
            RadioGroup<RegimeTrafego>(
              groupValue: _regime,
              onChanged: (value) => setState(() => _regime = value),
              child: Column(
                children: RegimeTrafego.values
                    .map(
                      (opcao) => RadioListTile<RegimeTrafego>(
                        title: Text(
                          switch (opcao) {
                            RegimeTrafego.intenso => 'Intenso',
                            RegimeTrafego.moderado => 'Moderado',
                            RegimeTrafego.leve => 'Leve',
                            RegimeTrafego.outro => 'Outro',
                          },
                        ),
                        value: opcao,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_regime == RegimeTrafego.outro)
              TextField(
                controller: _regimeOutroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descreva o regime de tráfego',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Velocidade indicada por sinalização expressa'),
              value: _velocidadePorSinalizacao,
              onChanged: (value) => setState(() {
                _velocidadePorSinalizacao = value;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Velocidade conforme CTB/1997'),
              value: _velocidadePorCTB,
              onChanged: (value) => setState(() {
                _velocidadePorCTB = value;
              }),
            ),
            TextField(
              controller: _velocidadeMaxCtrl,
              decoration: const InputDecoration(
                labelText: 'Velocidade máxima permitida',
              ),
            ),
            TextField(
              controller: _numeroFaixasCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número de faixas de rolamento',
              ),
            ),
            TextField(
              controller: _largurasFaixasCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Largura das faixas (separe por vírgula ou linha)',
              ),
            ),
            _buildSectionTitle('Visibilidade'),
            RadioGroup<VisibilidadeTipo>(
              groupValue: _visibilidade,
              onChanged: (value) => setState(() {
                _visibilidade = value;
              }),
              child: Column(
                children: VisibilidadeTipo.values
                    .map(
                      (opcao) => RadioListTile<VisibilidadeTipo>(
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
              TextField(
                controller: _visibilidadeDescricaoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Informe o motivo da visibilidade reduzida',
                ),
              ),
            _buildSectionTitle('Separação das Faixas'),
            _buildMultiSelectChips<SeparacaoFaixasOpcao>(
              opcoes: SeparacaoFaixasOpcao.values,
              selecionados: _separacaoFaixas,
              label: (v) => switch (v) {
                SeparacaoFaixasOpcao.simplesContinua => 'Simples Contínua',
                SeparacaoFaixasOpcao.duplaContinua => 'Dupla Contínua',
                SeparacaoFaixasOpcao.simplesSeccionada => 'Simples Seccionada',
                SeparacaoFaixasOpcao.duplaContinuaSeccionada =>
                  'Dupla Contínua/Seccionada',
              },
            ),
            _buildSectionTitle('Cor das Faixas'),
            _buildMultiSelectChips<CorFaixa>(
              opcoes: CorFaixa.values,
              selecionados: _corFaixas,
              label: (v) => v == CorFaixa.amarela ? 'Amarela' : 'Branca',
            ),
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
            const SizedBox(height: 16),
            _buildSectionTitle('Lateral Direita da Pista'),
            _buildMultiSelectChips<ElementoLateral>(
              opcoes: ElementoLateral.values,
              selecionados: _lateralDirElementos,
              label: (v) => switch (v) {
                ElementoLateral.meioFio => 'Meio-fio',
                ElementoLateral.faixaPintada => 'Faixa pintada',
                ElementoLateral.acostamento => 'Acostamento',
                ElementoLateral.muretaConcreto => 'Mureta de concreto',
                ElementoLateral.outro => 'Outro',
              },
            ),
            TextField(
              controller: _lateralDirLarguraCtrl,
              decoration: const InputDecoration(
                labelText: 'Largura (m)',
              ),
            ),
            DropdownButtonFormField<ConservacaoEstado>(
              initialValue: _lateralDirConservacao,
              decoration: const InputDecoration(labelText: 'Conservação'),
              items: ConservacaoEstado.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == ConservacaoEstado.boa ? 'Boa' : 'Ruim'),
                    ),
                  )
                  .toList(),
              onChanged: (valor) => setState(() {
                _lateralDirConservacao = valor;
              }),
            ),
            TextField(
              controller: _lateralDirObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações da lateral direita',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Lateral Esquerda da Pista'),
            _buildMultiSelectChips<ElementoLateral>(
              opcoes: ElementoLateral.values,
              selecionados: _lateralEsqElementos,
              label: (v) => switch (v) {
                ElementoLateral.meioFio => 'Meio-fio',
                ElementoLateral.faixaPintada => 'Faixa pintada',
                ElementoLateral.acostamento => 'Acostamento',
                ElementoLateral.muretaConcreto => 'Mureta de concreto',
                ElementoLateral.outro => 'Outro',
              },
            ),
            TextField(
              controller: _lateralEsqLarguraCtrl,
              decoration: const InputDecoration(labelText: 'Largura (m)'),
            ),
            DropdownButtonFormField<ConservacaoEstado>(
              initialValue: _lateralEsqConservacao,
              decoration: const InputDecoration(labelText: 'Conservação'),
              items: ConservacaoEstado.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == ConservacaoEstado.boa ? 'Boa' : 'Ruim'),
                    ),
                  )
                  .toList(),
              onChanged: (valor) => setState(() {
                _lateralEsqConservacao = valor;
              }),
            ),
            TextField(
              controller: _lateralEsqObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações da lateral esquerda',
              ),
            ),
            _buildSectionTitle('Observações Gerais'),
            TextField(
              controller: _observacoesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva observações relevantes sobre a via',
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
        ),
      ),
    );
  }
}
