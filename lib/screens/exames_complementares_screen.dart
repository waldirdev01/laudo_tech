import 'package:flutter/material.dart';

import '../models/exame_complementar_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/ficha_service.dart';

class ExamesComplementaresScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const ExamesComplementaresScreen({super.key, required this.ficha});

  @override
  State<ExamesComplementaresScreen> createState() =>
      _ExamesComplementaresScreenState();
}

class _ExamesComplementaresScreenState
    extends State<ExamesComplementaresScreen> {
  final _fichaService = FichaService();

  late FichaCompletaModel _ficha;
  final List<ExameComplementarModel> _exames = [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _ficha = await _fichaService.obterFicha(widget.ficha.id) ?? widget.ficha;
    _montarExamesIniciais();
    if (!mounted) return;
    setState(() => _carregando = false);
  }

  void _montarExamesIniciais() {
    final examesAtuais = List<ExameComplementarModel>.from(
      _ficha.examesComplementares ?? const <ExameComplementarModel>[],
    );
    final vestigiosColetados = _resumoVestigiosColetados();
    final resumoVestigios = vestigiosColetados
        .map((v) => v.descricao)
        .where((d) => d.isNotEmpty)
        .toList();
    final bool temSangueHumano = vestigiosColetados.any(
      (v) => v.isSangueHumano,
    );
    final bool temPapilar = vestigiosColetados.any((v) => v.temIndicioPapilar);

    ExameComplementarModel criarExameBase(
      TipoExameComplementar tipo, {
      required bool solicitadoPadrao,
      String? observacaoPadrao,
    }) {
      ExameComplementarModel? existente;
      for (final e in examesAtuais) {
        if (e.tipo == tipo) {
          existente = e;
          break;
        }
      }
      if (existente != null) {
        if (tipo == TipoExameComplementar.necroscopico &&
            existente.solicitado == false) {
          return existente.copyWith(solicitado: true);
        }
        if ((existente.observacao == null || existente.observacao!.isEmpty) &&
            observacaoPadrao != null &&
            observacaoPadrao.isNotEmpty) {
          return existente.copyWith(observacao: observacaoPadrao);
        }
        return existente;
      }

      return ExameComplementarModel(
        id: DateTime.now().microsecondsSinceEpoch.toString() + tipo.name,
        tipo: tipo,
        solicitado: tipo == TipoExameComplementar.necroscopico
            ? true
            : solicitadoPadrao,
        observacao: observacaoPadrao,
      );
    }

    final principais = <ExameComplementarModel>[
      criarExameBase(
        TipoExameComplementar.pesquisaDna,
        solicitadoPadrao: temSangueHumano,
      ),
      criarExameBase(
        TipoExameComplementar.analiseImpressoesPapilares,
        solicitadoPadrao: temPapilar,
      ),
      criarExameBase(
        TipoExameComplementar.caracterizacaoObjetos,
        solicitadoPadrao: resumoVestigios.isNotEmpty,
        observacaoPadrao: resumoVestigios.isEmpty
            ? null
            : 'Vestígios coletados: ${resumoVestigios.join('; ')}.',
      ),
      criarExameBase(
        TipoExameComplementar.caracterizacaoElementosMunicao,
        solicitadoPadrao: false,
      ),
      criarExameBase(TipoExameComplementar.balistico, solicitadoPadrao: false),
      criarExameBase(
        TipoExameComplementar.necroscopico,
        solicitadoPadrao: true,
      ),
    ];

    final outros = examesAtuais
        .where(
          (e) =>
              e.tipo == TipoExameComplementar.outro &&
              (e.nomePersonalizado?.trim().isNotEmpty ?? false),
        )
        .toList();

    _exames
      ..clear()
      ..addAll(principais)
      ..addAll(outros);
  }

  List<_VestigioResumo> _resumoVestigiosColetados() {
    final resumo = <_VestigioResumo>[];
    final local = _ficha.localFurto;

    final vestigiosLocais = <VestigioLocalModel>[
      ...?local?.vestigiosMediato,
      ...?local?.vestigiosImediato,
      ...?local?.vestigiosRelacionado,
    ];
    for (final v in vestigiosLocais) {
      if (v.tipoAcao != TipoAcaoVestigio.coletado) continue;
      final nome = (v.nome ?? '').trim();
      final descricao = (v.descricao ?? '').trim();
      final texto = nome.isNotEmpty ? '$nome ($descricao)' : descricao;
      resumo.add(
        _VestigioResumo(
          descricao: texto,
          isSangueHumano: v.isSangueHumano,
          temIndicioPapilar: _textoTemIndicioPapilar('$nome $descricao'),
        ),
      );
    }

    final veiculos = _ficha.veiculos ?? const [];
    for (final veiculo in veiculos) {
      final vestigios = veiculo.vestigios ?? const <VestigioVeiculoModel>[];
      for (final v in vestigios) {
        if (v.tipoAcao != TipoAcaoVestigioVeiculo.coletado) continue;
        final nome = (v.nome ?? '').trim();
        final descricao = (v.descricao ?? '').trim();
        final texto = nome.isNotEmpty ? '$nome ($descricao)' : descricao;
        resumo.add(
          _VestigioResumo(
            descricao: texto,
            isSangueHumano: v.isSangueHumano,
            temIndicioPapilar: _textoTemIndicioPapilar('$nome $descricao'),
          ),
        );
      }
    }

    return resumo;
  }

  bool _textoTemIndicioPapilar(String texto) {
    final t = texto.toLowerCase();
    return t.contains('papilar') ||
        t.contains('impress') ||
        t.contains('digital');
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final fichaBaseAtual =
          await _fichaService.obterFicha(widget.ficha.id) ?? _ficha;
      final fichaAtualizada = fichaBaseAtual.copyWith(
        examesComplementares: List<ExameComplementarModel>.from(_exames),
        dataUltimaAtualizacao: DateTime.now(),
      );
      await _fichaService.salvarFicha(fichaAtualizada);
      _ficha = fichaAtualizada;
      if (!mounted) return;
      Navigator.of(context).pop(fichaAtualizada);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _atualizarExame(String id, ExameComplementarModel novoExame) {
    final idx = _exames.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    setState(() {
      _exames[idx] = novoExame;
    });
  }

  Future<void> _adicionarOutroExame() async {
    final nomeCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Novo exame complementar'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do exame *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observação (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nomeCtrl.text.trim().isEmpty) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true) return;

    setState(() {
      _exames.add(
        ExameComplementarModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          tipo: TipoExameComplementar.outro,
          nomePersonalizado: nomeCtrl.text.trim(),
          solicitado: true,
          tipoDestino: null,
          destinoId: null,
          destinoNome: null,
          observacao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        ),
      );
    });
  }

  Widget _buildCardExame(ExameComplementarModel exame) {
    final fixo = exame.tipo == TipoExameComplementar.necroscopico;
    final solicitado = fixo ? true : exame.solicitado;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exame.nomeExibicao,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (fixo)
                  const Chip(
                    label: Text('Fixo'),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Switch(
                    value: solicitado,
                    onChanged: (value) {
                      _atualizarExame(
                        exame.id,
                        exame.copyWith(
                          solicitado: value,
                          tipoDestino: null,
                          destinoId: null,
                          destinoNome: null,
                        ),
                      );
                    },
                  ),
                if (exame.tipo == TipoExameComplementar.outro)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _exames.removeWhere((e) => e.id == exame.id);
                      });
                    },
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (solicitado) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: exame.observacao,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações do exame (opcional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final idx = _exames.indexWhere((e) => e.id == exame.id);
                  if (idx < 0) return;
                  _exames[idx] = _exames[idx].copyWith(
                    observacao: value.trim().isEmpty ? null : value.trim(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exames Complementares'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _carregando ? null : _adicionarOutroExame,
            tooltip: 'Adicionar exame',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Selecione os exames aplicáveis ao caso. '
                    'O exame necroscópico permanece fixo e é apresentado ao final da lista. '
                    'Os demais exames ficam disponíveis para seleção conforme a necessidade do caso.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._exames.map(_buildCardExame),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar e continuar'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _VestigioResumo {
  final String descricao;
  final bool isSangueHumano;
  final bool temIndicioPapilar;

  _VestigioResumo({
    required this.descricao,
    required this.isSangueHumano,
    required this.temIndicioPapilar,
  });
}
