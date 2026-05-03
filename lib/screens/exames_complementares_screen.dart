import 'package:flutter/material.dart';

import '../models/exame_complementar_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/unidade_model.dart';
import '../models/vestigio_local_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/ficha_service.dart';
import '../services/laboratorio_service.dart';
import '../services/unidade_service.dart';

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
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();

  late FichaCompletaModel _ficha;
  final List<ExameComplementarModel> _exames = [];
  List<UnidadeModel> _unidades = const [];
  List<LaboratorioModel> _laboratorios = const [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _ficha = widget.ficha;
    _inicializar();
  }

  Future<void> _inicializar() async {
    final unidades = await _unidadeService.listarUnidades();
    final laboratorios = await _laboratorioService.listarLaboratorios();
    _unidades = unidades;
    _laboratorios = laboratorios;
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
      final existente = _firstWhereOrNull<ExameComplementarModel>(
        examesAtuais,
        (e) => e.tipo == tipo,
      );
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
      final fichaAtualizada = _ficha.copyWith(
        examesComplementares: List<ExameComplementarModel>.from(_exames),
        dataUltimaAtualizacao: DateTime.now(),
      );
      await _fichaService.salvarFicha(fichaAtualizada);
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

  String _rotuloDestino(ExameComplementarModel exame) {
    if (exame.destinoNome != null && exame.destinoNome!.trim().isNotEmpty) {
      return exame.destinoNome!.trim();
    }
    if (exame.destinoId == null || exame.tipoDestino == null) return '';
    if (exame.tipoDestino == TipoDestinoExameComplementar.unidade) {
      final unidade = _firstWhereOrNull<UnidadeModel>(
        _unidades,
        (u) => u.id == exame.destinoId,
      );
      return unidade?.nome ?? '';
    }
    final laboratorio = _firstWhereOrNull<LaboratorioModel>(
      _laboratorios,
      (l) => l.id == exame.destinoId,
    );
    return laboratorio?.nome ?? '';
  }

  Future<void> _adicionarOutroExame() async {
    final nomeCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    TipoDestinoExameComplementar? tipoDestino;
    String? destinoId;
    String? destinoNome;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final opcoesDestino = tipoDestino == null
                ? const <dynamic>[]
                : (tipoDestino == TipoDestinoExameComplementar.unidade
                      ? _unidades
                      : _laboratorios);
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
                    DropdownButtonFormField<TipoDestinoExameComplementar>(
                      // ignore: deprecated_member_use
                      value: tipoDestino,
                      decoration: const InputDecoration(
                        labelText: 'Destino (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<TipoDestinoExameComplementar>(
                          value: TipoDestinoExameComplementar.unidade,
                          child: Text('Unidade'),
                        ),
                        const DropdownMenuItem<TipoDestinoExameComplementar>(
                          value: TipoDestinoExameComplementar.laboratorio,
                          child: Text('Laboratório'),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          tipoDestino = value;
                          destinoId = null;
                          destinoNome = null;
                        });
                      },
                    ),
                    if (tipoDestino != null && opcoesDestino.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: destinoId,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar destino',
                        ),
                        items: opcoesDestino.map<DropdownMenuItem<String>>((o) {
                          final String id;
                          final String nome;
                          if (tipoDestino ==
                              TipoDestinoExameComplementar.unidade) {
                            final unidade = o as UnidadeModel;
                            id = unidade.id;
                            nome = unidade.nome;
                          } else {
                            final laboratorio = o as LaboratorioModel;
                            id = laboratorio.id;
                            nome = laboratorio.nome;
                          }
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(nome),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            destinoId = value;
                            if (value == null) {
                              destinoNome = null;
                              return;
                            }
                            if (tipoDestino ==
                                TipoDestinoExameComplementar.unidade) {
                              destinoNome = _firstWhereOrNull<UnidadeModel>(
                                _unidades,
                                (u) => u.id == value,
                              )?.nome;
                            } else {
                              destinoNome = _firstWhereOrNull<LaboratorioModel>(
                                _laboratorios,
                                (l) => l.id == value,
                              )?.nome;
                            }
                          });
                        },
                      ),
                    ],
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
          tipoDestino: tipoDestino,
          destinoId: destinoId,
          destinoNome: destinoNome,
          observacao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        ),
      );
    });
  }

  Widget _buildCardExame(ExameComplementarModel exame) {
    final fixo = exame.tipo == TipoExameComplementar.necroscopico;
    final solicitado = fixo ? true : exame.solicitado;
    final descricaoDestino = _rotuloDestino(exame);
    final opcoesDestino = exame.tipoDestino == null
        ? const <dynamic>[]
        : (exame.tipoDestino == TipoDestinoExameComplementar.unidade
              ? _unidades
              : _laboratorios);

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
                          tipoDestino: value ? exame.tipoDestino : null,
                          destinoId: value ? exame.destinoId : null,
                          destinoNome: value ? exame.destinoNome : null,
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
              const SizedBox(height: 8),
              DropdownButtonFormField<TipoDestinoExameComplementar>(
                // ignore: deprecated_member_use
                value: exame.tipoDestino,
                decoration: const InputDecoration(
                  labelText: 'Destino (opcional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<TipoDestinoExameComplementar>(
                    value: TipoDestinoExameComplementar.unidade,
                    child: Text('Unidade'),
                  ),
                  const DropdownMenuItem<TipoDestinoExameComplementar>(
                    value: TipoDestinoExameComplementar.laboratorio,
                    child: Text('Laboratório'),
                  ),
                ],
                onChanged: fixo
                    ? null
                    : (value) {
                        _atualizarExame(
                          exame.id,
                          exame.copyWith(
                            tipoDestino: value,
                            destinoId: null,
                            destinoNome: null,
                          ),
                        );
                      },
              ),
              if (exame.tipoDestino != null && opcoesDestino.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: exame.destinoId,
                  decoration: const InputDecoration(
                    labelText: 'Selecionar destino',
                    border: OutlineInputBorder(),
                  ),
                  items: opcoesDestino.map<DropdownMenuItem<String>>((o) {
                    final String id;
                    final String nome;
                    if (exame.tipoDestino ==
                        TipoDestinoExameComplementar.unidade) {
                      final unidade = o as UnidadeModel;
                      id = unidade.id;
                      nome = unidade.nome;
                    } else {
                      final laboratorio = o as LaboratorioModel;
                      id = laboratorio.id;
                      nome = laboratorio.nome;
                    }
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(nome),
                    );
                  }).toList(),
                  onChanged: fixo
                      ? null
                      : (value) {
                          String? nomeDestino;
                          if (value != null) {
                            if (exame.tipoDestino ==
                                TipoDestinoExameComplementar.unidade) {
                              nomeDestino = _firstWhereOrNull<UnidadeModel>(
                                _unidades,
                                (u) => u.id == value,
                              )?.nome;
                            } else {
                              nomeDestino = _firstWhereOrNull<LaboratorioModel>(
                                _laboratorios,
                                (l) => l.id == value,
                              )?.nome;
                            }
                          }
                          _atualizarExame(
                            exame.id,
                            exame.copyWith(
                              destinoId: value,
                              destinoNome: nomeDestino,
                            ),
                          );
                        },
                ),
              ],
              if (descricaoDestino.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Destino selecionado: $descricaoDestino',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
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

T? _firstWhereOrNull<T>(Iterable<T> itens, bool Function(T item) test) {
  for (final item in itens) {
    if (test(item)) return item;
  }
  return null;
}
