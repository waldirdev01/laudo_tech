import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/detatlhes_local.dart';
import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/marco_zero_local_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/unidade_model.dart';
import '../models/vestigio_local_model.dart';
import '../services/ficha_service.dart';
import '../services/laboratorio_service.dart';
import '../services/perito_service.dart';
import '../services/unidade_service.dart';
import 'evidencias_furto_screen.dart';
import 'lista_veiculos_screen.dart';

class LocalFurtoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const LocalFurtoScreen({super.key, required this.ficha});

  @override
  State<LocalFurtoScreen> createState() => _LocalFurtoScreenState();
}

class _LocalFurtoScreenState extends State<LocalFurtoScreen> {
  final _fichaService = FichaService();
  final _peritoService = PeritoService();
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();
  final _viasAcessoController = TextEditingController();
  final _sinaisArrombamentoController = TextEditingController();
  final _descricaoLocalController = TextEditingController();
  final _descricaoMediatoController = TextEditingController();
  final _descricaoImediatoController = TextEditingController();
  final _descricaoRelacionadoController = TextEditingController();
  final _demaisObservacoesController = TextEditingController();
  bool _salvando = false;

  // Marco Zero por local
  final _marcoZeroDescricaoMediatoController = TextEditingController();
  final _marcoZeroXMediatoController = TextEditingController(text: '0');
  final _marcoZeroYMediatoController = TextEditingController(text: '0');
  final _marcoZeroDescricaoImediatoController = TextEditingController();
  final _marcoZeroXImediatoController = TextEditingController(text: '0');
  final _marcoZeroYImediatoController = TextEditingController(text: '0');
  final _marcoZeroDescricaoRelacionadoController = TextEditingController();
  final _marcoZeroXRelacionadoController = TextEditingController(text: '0');
  final _marcoZeroYRelacionadoController = TextEditingController(text: '0');

  // Estados dos checkboxes
  bool? _classificacaoMediato;
  bool? _classificacaoImediato;
  bool? _classificacaoRelacionado;

  // Piso e Iluminação - Mediato
  bool? _pisoSecoMediato;
  bool? _pisoUmidoMediato;
  bool? _pisoMolhadoMediato;
  bool? _iluminacaoArtificialMediato;
  bool? _iluminacaoNaturalMediato;
  bool? _iluminacaoAusenteMediato;

  // Piso e Iluminação - Imediato
  bool? _pisoSecoImediato;
  bool? _pisoUmidoImediato;
  bool? _pisoMolhadoImediato;
  bool? _iluminacaoArtificialImediato;
  bool? _iluminacaoNaturalImediato;
  bool? _iluminacaoAusenteImediato;

  // Piso e Iluminação - Relacionado
  bool? _pisoSecoRelacionado;
  bool? _pisoUmidoRelacionado;
  bool? _pisoMolhadoRelacionado;
  bool? _iluminacaoArtificialRelacionado;
  bool? _iluminacaoNaturalRelacionado;
  bool? _iluminacaoAusenteRelacionado;

  bool? _sinaisArrombamentoSim;
  bool? _sinaisArrombamentoNao;
  bool? _sinaisArrombamentoNaoSeAplica;

  // Vestígios por local
  List<VestigioLocalModel> _vestigiosMediato = [];
  List<VestigioLocalModel> _vestigiosImediato = [];
  List<VestigioLocalModel> _vestigiosRelacionado = [];
  bool _semVestigiosMediato = false;
  bool _semVestigiosImediato = false;
  bool _semVestigiosRelacionado = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.localFurto;
    if (dados != null) {
      _classificacaoMediato = dados.classificacaoMediato;
      _classificacaoImediato = dados.classificacaoImediato;
      _classificacaoRelacionado = dados.classificacaoRelacionado;
      _pisoSecoMediato = dados.pisoSecoMediato;
      _pisoUmidoMediato = dados.pisoUmidoMediato;
      _pisoMolhadoMediato = dados.pisoMolhadoMediato;
      _iluminacaoArtificialMediato = dados.iluminacaoArtificialMediato;
      _iluminacaoNaturalMediato = dados.iluminacaoNaturalMediato;
      _iluminacaoAusenteMediato = dados.iluminacaoAusenteMediato;
      _pisoSecoImediato = dados.pisoSecoImediato;
      _pisoUmidoImediato = dados.pisoUmidoImediato;
      _pisoMolhadoImediato = dados.pisoMolhadoImediato;
      _iluminacaoArtificialImediato = dados.iluminacaoArtificialImediato;
      _iluminacaoNaturalImediato = dados.iluminacaoNaturalImediato;
      _iluminacaoAusenteImediato = dados.iluminacaoAusenteImediato;
      _pisoSecoRelacionado = dados.pisoSecoRelacionado;
      _pisoUmidoRelacionado = dados.pisoUmidoRelacionado;
      _pisoMolhadoRelacionado = dados.pisoMolhadoRelacionado;
      _iluminacaoArtificialRelacionado = dados.iluminacaoArtificialRelacionado;
      _iluminacaoNaturalRelacionado = dados.iluminacaoNaturalRelacionado;
      _iluminacaoAusenteRelacionado = dados.iluminacaoAusenteRelacionado;
      _sinaisArrombamentoSim = dados.sinaisArrombamentoSim;
      _sinaisArrombamentoNao = dados.sinaisArrombamentoNao;
      _sinaisArrombamentoNaoSeAplica = dados.sinaisArrombamentoNaoSeAplica;
      _viasAcessoController.text = dados.descricaoViasAcesso ?? '';
      _sinaisArrombamentoController.text =
          dados.sinaisArrombamentoDescricao ?? '';
      _descricaoLocalController.text = dados.descricaoLocal ?? '';
      _descricaoMediatoController.text = dados.descricaoLocalMediato ?? '';
      _descricaoImediatoController.text = dados.descricaoLocalImediato ?? '';
      _descricaoRelacionadoController.text =
          dados.descricaoLocalRelacionado ?? '';
      _marcoZeroDescricaoMediatoController.text =
          dados.marcoZeroMediato?.descricao ?? '';
      _marcoZeroXMediatoController.text =
          dados.marcoZeroMediato?.coordenadaX ?? '0';
      _marcoZeroYMediatoController.text =
          dados.marcoZeroMediato?.coordenadaY ?? '0';
      _marcoZeroDescricaoImediatoController.text =
          dados.marcoZeroImediato?.descricao ?? '';
      _marcoZeroXImediatoController.text =
          dados.marcoZeroImediato?.coordenadaX ?? '0';
      _marcoZeroYImediatoController.text =
          dados.marcoZeroImediato?.coordenadaY ?? '0';
      _marcoZeroDescricaoRelacionadoController.text =
          dados.marcoZeroRelacionado?.descricao ?? '';
      _marcoZeroXRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaX ?? '0';
      _marcoZeroYRelacionadoController.text =
          dados.marcoZeroRelacionado?.coordenadaY ?? '0';
      _vestigiosMediato = List<VestigioLocalModel>.from(
        dados.vestigiosMediato ?? [],
      );
      _vestigiosImediato = List<VestigioLocalModel>.from(
        dados.vestigiosImediato ?? [],
      );
      _vestigiosRelacionado = List<VestigioLocalModel>.from(
        dados.vestigiosRelacionado ?? [],
      );
      _semVestigiosMediato = dados.semVestigiosMediato ?? false;
      _semVestigiosImediato = dados.semVestigiosImediato ?? false;
      _semVestigiosRelacionado = dados.semVestigiosRelacionado ?? false;
      _demaisObservacoesController.text = dados.demaisObservacoes ?? '';
    }
  }

  @override
  void dispose() {
    _viasAcessoController.dispose();
    _sinaisArrombamentoController.dispose();
    _descricaoLocalController.dispose();
    _descricaoMediatoController.dispose();
    _descricaoImediatoController.dispose();
    _descricaoRelacionadoController.dispose();
    _demaisObservacoesController.dispose();
    _marcoZeroDescricaoMediatoController.dispose();
    _marcoZeroXMediatoController.dispose();
    _marcoZeroYMediatoController.dispose();
    _marcoZeroDescricaoImediatoController.dispose();
    _marcoZeroXImediatoController.dispose();
    _marcoZeroYImediatoController.dispose();
    _marcoZeroDescricaoRelacionadoController.dispose();
    _marcoZeroXRelacionadoController.dispose();
    _marcoZeroYRelacionadoController.dispose();
    super.dispose();
  }

  void _onClassificacaoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'mediato':
          _classificacaoMediato = value ?? false;
          break;
        case 'imediato':
          _classificacaoImediato = value ?? false;
          break;
        case 'relacionado':
          _classificacaoRelacionado = value ?? false;
          break;
      }
    });
  }

  void _onPisoChanged(bool? value, String tipo, String local) {
    setState(() {
      switch (local) {
        case 'mediato':
          switch (tipo) {
            case 'seco':
              _pisoSecoMediato = value ?? false;
              if (value == true) {
                _pisoUmidoMediato = false;
                _pisoMolhadoMediato = false;
              }
              break;
            case 'umido':
              _pisoUmidoMediato = value ?? false;
              if (value == true) {
                _pisoSecoMediato = false;
                _pisoMolhadoMediato = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoMediato = value ?? false;
              if (value == true) {
                _pisoSecoMediato = false;
                _pisoUmidoMediato = false;
              }
              break;
          }
          break;
        case 'imediato':
          switch (tipo) {
            case 'seco':
              _pisoSecoImediato = value ?? false;
              if (value == true) {
                _pisoUmidoImediato = false;
                _pisoMolhadoImediato = false;
              }
              break;
            case 'umido':
              _pisoUmidoImediato = value ?? false;
              if (value == true) {
                _pisoSecoImediato = false;
                _pisoMolhadoImediato = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoImediato = value ?? false;
              if (value == true) {
                _pisoSecoImediato = false;
                _pisoUmidoImediato = false;
              }
              break;
          }
          break;
        case 'relacionado':
          switch (tipo) {
            case 'seco':
              _pisoSecoRelacionado = value ?? false;
              if (value == true) {
                _pisoUmidoRelacionado = false;
                _pisoMolhadoRelacionado = false;
              }
              break;
            case 'umido':
              _pisoUmidoRelacionado = value ?? false;
              if (value == true) {
                _pisoSecoRelacionado = false;
                _pisoMolhadoRelacionado = false;
              }
              break;
            case 'molhado':
              _pisoMolhadoRelacionado = value ?? false;
              if (value == true) {
                _pisoSecoRelacionado = false;
                _pisoUmidoRelacionado = false;
              }
              break;
          }
          break;
      }
    });
  }

  void _onIluminacaoChanged(bool? value, String tipo, String local) {
    setState(() {
      switch (local) {
        case 'mediato':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialMediato = value ?? false;
              if (value == true) {
                _iluminacaoNaturalMediato = false;
                _iluminacaoAusenteMediato = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalMediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialMediato = false;
                _iluminacaoAusenteMediato = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteMediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialMediato = false;
                _iluminacaoNaturalMediato = false;
              }
              break;
          }
          break;
        case 'imediato':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialImediato = value ?? false;
              if (value == true) {
                _iluminacaoNaturalImediato = false;
                _iluminacaoAusenteImediato = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalImediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialImediato = false;
                _iluminacaoAusenteImediato = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteImediato = value ?? false;
              if (value == true) {
                _iluminacaoArtificialImediato = false;
                _iluminacaoNaturalImediato = false;
              }
              break;
          }
          break;
        case 'relacionado':
          switch (tipo) {
            case 'artificial':
              _iluminacaoArtificialRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoNaturalRelacionado = false;
                _iluminacaoAusenteRelacionado = false;
              }
              break;
            case 'natural':
              _iluminacaoNaturalRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoArtificialRelacionado = false;
                _iluminacaoAusenteRelacionado = false;
              }
              break;
            case 'ausente':
              _iluminacaoAusenteRelacionado = value ?? false;
              if (value == true) {
                _iluminacaoArtificialRelacionado = false;
                _iluminacaoNaturalRelacionado = false;
              }
              break;
          }
          break;
      }
    });
  }

  void _onSinaisArrombamentoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'sim':
          _sinaisArrombamentoSim = value ?? false;
          if (value == true) {
            _sinaisArrombamentoNao = false;
            _sinaisArrombamentoNaoSeAplica = false;
          }
          break;
        case 'nao':
          _sinaisArrombamentoNao = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNaoSeAplica = false;
          }
          break;
        case 'naoSeAplica':
          _sinaisArrombamentoNaoSeAplica = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNao = false;
          }
          break;
      }
    });
  }

  String _gerarIdVestigio() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _adicionarOuEditarVestigio(
    String secao, {
    VestigioLocalModel? existente,
  }) async {
    final descricaoCtrl = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final coordenadaXCtrl = TextEditingController(
      text: existente?.coordenadaX ?? '',
    );
    final coordenadaYCtrl = TextEditingController(
      text: existente?.coordenadaY ?? '',
    );
    final alturaCtrl = TextEditingController(
      text: existente?.alturaRelacaoPiso ?? '',
    );

    TipoAcaoVestigio? tipoAcaoSelecionado = existente?.tipoAcao;
    TipoDestinoVestigio? tipoDestinoSelecionado = existente?.tipoDestino;
    String? destinoIdSelecionado = existente?.destinoId;
    final numeroLacreCtrl = TextEditingController(
      text: existente?.numeroLacre ?? '',
    );
    bool isSangueHumano = existente?.isSangueHumano ?? false;

    if (!mounted) return;

    // Obter nome do perito
    final perito = await _peritoService.obterPerito();
    final nomePerito = perito?.nome ?? '';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        String? erroMensagem;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existente == null ? 'Adicionar vestígio' : 'Editar vestígio',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (erroMensagem != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                erroMensagem!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextFormField(
                      controller: descricaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do vestígio *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: coordenadaXCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Coordenada X *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: coordenadaYCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Coordenada Y *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: alturaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Altura em relação ao piso (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Sangue humano'),
                      subtitle: const Text(
                        'Marque se este vestígio é sangue humano (para textos específicos no laudo)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isSangueHumano,
                      onChanged: (value) {
                        setDialogState(() {
                          isSangueHumano = value ?? false;
                        });
                      },
                      activeColor: Colors.red.shade700,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'O vestígio será coletado ou apenas registrado?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<TipoAcaoVestigio>(
                      groupValue: tipoAcaoSelecionado,
                      onChanged: (value) {
                        setDialogState(() {
                          tipoAcaoSelecionado = value;
                          if (value != TipoAcaoVestigio.coletado) {
                            tipoDestinoSelecionado = null;
                            destinoIdSelecionado = null;
                          }
                        });
                      },
                      child: Column(
                        children: [
                          ListTile(
                            leading: Radio<TipoAcaoVestigio>(
                              value: TipoAcaoVestigio.registrado,
                            ),
                            title: const Text('Apenas Registrado'),
                            onTap: () {
                              setDialogState(() {
                                tipoAcaoSelecionado =
                                    TipoAcaoVestigio.registrado;
                                tipoDestinoSelecionado = null;
                                destinoIdSelecionado = null;
                              });
                            },
                          ),
                          ListTile(
                            leading: Radio<TipoAcaoVestigio>(
                              value: TipoAcaoVestigio.coletado,
                            ),
                            title: const Text('Coletado'),
                            onTap: () {
                              setDialogState(() {
                                tipoAcaoSelecionado = TipoAcaoVestigio.coletado;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (tipoAcaoSelecionado == TipoAcaoVestigio.coletado) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Será analisado na Unidade ou encaminhado para laboratório?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<TipoDestinoVestigio>(
                        groupValue: tipoDestinoSelecionado,
                        onChanged: (value) {
                          setDialogState(() {
                            tipoDestinoSelecionado = value;
                            destinoIdSelecionado = null;
                          });
                        },
                        child: Column(
                          children: [
                            ListTile(
                              leading: Radio<TipoDestinoVestigio>(
                                value: TipoDestinoVestigio.unidade,
                              ),
                              title: const Text('Unidade'),
                              onTap: () {
                                setDialogState(() {
                                  tipoDestinoSelecionado =
                                      TipoDestinoVestigio.unidade;
                                  destinoIdSelecionado = null;
                                });
                              },
                            ),
                            ListTile(
                              leading: Radio<TipoDestinoVestigio>(
                                value: TipoDestinoVestigio.laboratorio,
                              ),
                              title: const Text('Laboratório'),
                              onTap: () {
                                setDialogState(() {
                                  tipoDestinoSelecionado =
                                      TipoDestinoVestigio.laboratorio;
                                  destinoIdSelecionado = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      if (tipoDestinoSelecionado != null) ...[
                        const SizedBox(height: 12),
                        FutureBuilder<List<dynamic>>(
                          future:
                              tipoDestinoSelecionado ==
                                  TipoDestinoVestigio.unidade
                              ? _unidadeService.listarUnidades()
                              : _laboratorioService.listarLaboratorios(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final lista = snapshot.data ?? [];
                            if (lista.isEmpty) {
                              final tipoTexto =
                                  tipoDestinoSelecionado ==
                                      TipoDestinoVestigio.unidade
                                  ? 'unidade'
                                  : 'laboratório';
                              return Text(
                                'Nenhuma $tipoTexto cadastrada. Cadastre em Configurações.',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: destinoIdSelecionado,
                              decoration: InputDecoration(
                                labelText:
                                    tipoDestinoSelecionado ==
                                        TipoDestinoVestigio.unidade
                                    ? 'Selecione a Unidade'
                                    : 'Selecione o Laboratório',
                                border: const OutlineInputBorder(),
                              ),
                              selectedItemBuilder: (context) {
                                return lista.map<Widget>((item) {
                                  final nome =
                                      tipoDestinoSelecionado ==
                                          TipoDestinoVestigio.unidade
                                      ? (item as UnidadeModel).nome
                                      : (item as LaboratorioModel).nome;
                                  return Text(
                                    nome,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  );
                                }).toList();
                              },
                              items: lista.map<DropdownMenuItem<String>>((
                                item,
                              ) {
                                final nome =
                                    tipoDestinoSelecionado ==
                                        TipoDestinoVestigio.unidade
                                    ? (item as UnidadeModel).nome
                                    : (item as LaboratorioModel).nome;
                                final id = item.id;
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(nome),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  destinoIdSelecionado = value;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: numeroLacreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Número do lacre (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    setDialogState(() {
                      erroMensagem = null;
                    });

                    if (descricaoCtrl.text.trim().isEmpty ||
                        coordenadaXCtrl.text.trim().isEmpty ||
                        coordenadaYCtrl.text.trim().isEmpty) {
                      setDialogState(() {
                        erroMensagem = 'Preencha descrição e coordenadas X e Y';
                      });
                      return;
                    }

                    if (tipoAcaoSelecionado == TipoAcaoVestigio.coletado) {
                      if (tipoDestinoSelecionado == null) {
                        setDialogState(() {
                          erroMensagem =
                              'Selecione se será analisado na Unidade ou encaminhado para laboratório';
                        });
                        return;
                      }

                      // Verificar se há itens disponíveis
                      final lista =
                          tipoDestinoSelecionado == TipoDestinoVestigio.unidade
                          ? await _unidadeService.listarUnidades()
                          : await _laboratorioService.listarLaboratorios();

                      if (lista.isEmpty) {
                        final tipoTexto =
                            tipoDestinoSelecionado ==
                                TipoDestinoVestigio.unidade
                            ? 'unidade'
                            : 'laboratório';
                        setDialogState(() {
                          erroMensagem =
                              'Nenhuma $tipoTexto cadastrada. Cadastre em Configurações antes de salvar.';
                        });
                        return;
                      }

                      if (destinoIdSelecionado == null) {
                        setDialogState(() {
                          final tipoTexto =
                              tipoDestinoSelecionado ==
                                  TipoDestinoVestigio.unidade
                              ? 'unidade'
                              : 'laboratório';
                          erroMensagem = 'Selecione a $tipoTexto de destino';
                        });
                        return;
                      }
                    }

                    String? coletadoPor;
                    String? dataHoraColeta;
                    if (tipoAcaoSelecionado == TipoAcaoVestigio.coletado) {
                      coletadoPor = nomePerito;
                      final agora = DateTime.now();
                      dataHoraColeta = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(agora);
                    }

                    final novo = VestigioLocalModel(
                      id: existente?.id ?? _gerarIdVestigio(),
                      descricao: descricaoCtrl.text.trim(),
                      coordenadaX: coordenadaXCtrl.text.trim(),
                      coordenadaY: coordenadaYCtrl.text.trim(),
                      alturaRelacaoPiso: alturaCtrl.text.trim().isEmpty
                          ? null
                          : alturaCtrl.text.trim(),
                      tipoAcao: tipoAcaoSelecionado,
                      tipoDestino: tipoDestinoSelecionado,
                      destinoId: destinoIdSelecionado,
                      coletadoPor: coletadoPor,
                      dataHoraColeta: dataHoraColeta,
                      numeroLacre: numeroLacreCtrl.text.trim().isEmpty
                          ? null
                          : numeroLacreCtrl.text.trim(),
                      isSangueHumano: isSangueHumano,
                    );

                    setState(() {
                      List<VestigioLocalModel> alvo;
                      switch (secao) {
                        case 'mediato':
                          alvo = _vestigiosMediato;
                          _semVestigiosMediato = false;
                          break;
                        case 'imediato':
                          alvo = _vestigiosImediato;
                          _semVestigiosImediato = false;
                          break;
                        default:
                          alvo = _vestigiosRelacionado;
                          _semVestigiosRelacionado = false;
                          break;
                      }

                      final idx = alvo.indexWhere((e) => e.id == novo.id);
                      if (idx >= 0) {
                        alvo[idx] = novo;
                      } else {
                        alvo.add(novo);
                      }
                    });
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removerVestigio(String secao, String id) {
    setState(() {
      switch (secao) {
        case 'mediato':
          _vestigiosMediato.removeWhere((v) => v.id == id);
          break;
        case 'imediato':
          _vestigiosImediato.removeWhere((v) => v.id == id);
          break;
        default:
          _vestigiosRelacionado.removeWhere((v) => v.id == id);
          break;
      }
    });
  }

  Future<void> _salvarLocalFurto() async {
    setState(() {
      _salvando = true;
    });

    try {
      final partesDescricao = <String>[];
      final mediatoTexto = _descricaoMediatoController.text.trim();
      final imediatoTexto = _descricaoImediatoController.text.trim();
      final relacionadoTexto = _descricaoRelacionadoController.text.trim();
      if (mediatoTexto.isNotEmpty) {
        partesDescricao.add('Mediato: $mediatoTexto');
      }
      if (imediatoTexto.isNotEmpty) {
        partesDescricao.add('Imediato: $imediatoTexto');
      }
      if (relacionadoTexto.isNotEmpty) {
        partesDescricao.add('Relacionado: $relacionadoTexto');
      }
      final descricaoLocalAgrupada = partesDescricao.isEmpty
          ? null
          : partesDescricao.join('\n\n');

      final localFurto = LocalFurtoModel(
        classificacaoMediato: _classificacaoMediato,
        classificacaoImediato: _classificacaoImediato,
        classificacaoRelacionado: _classificacaoRelacionado,
        pisoSecoMediato: _pisoSecoMediato,
        pisoUmidoMediato: _pisoUmidoMediato,
        pisoMolhadoMediato: _pisoMolhadoMediato,
        iluminacaoArtificialMediato: _iluminacaoArtificialMediato,
        iluminacaoNaturalMediato: _iluminacaoNaturalMediato,
        iluminacaoAusenteMediato: _iluminacaoAusenteMediato,
        pisoSecoImediato: _pisoSecoImediato,
        pisoUmidoImediato: _pisoUmidoImediato,
        pisoMolhadoImediato: _pisoMolhadoImediato,
        iluminacaoArtificialImediato: _iluminacaoArtificialImediato,
        iluminacaoNaturalImediato: _iluminacaoNaturalImediato,
        iluminacaoAusenteImediato: _iluminacaoAusenteImediato,
        pisoSecoRelacionado: _pisoSecoRelacionado,
        pisoUmidoRelacionado: _pisoUmidoRelacionado,
        pisoMolhadoRelacionado: _pisoMolhadoRelacionado,
        iluminacaoArtificialRelacionado: _iluminacaoArtificialRelacionado,
        iluminacaoNaturalRelacionado: _iluminacaoNaturalRelacionado,
        iluminacaoAusenteRelacionado: _iluminacaoAusenteRelacionado,
        descricaoViasAcesso: _viasAcessoController.text.trim().isEmpty
            ? null
            : _viasAcessoController.text.trim(),
        sinaisArrombamentoDescricao:
            _sinaisArrombamentoController.text.trim().isEmpty
            ? null
            : _sinaisArrombamentoController.text.trim(),
        descricaoLocal: descricaoLocalAgrupada,
        demaisObservacoes: _demaisObservacoesController.text.trim().isEmpty
            ? null
            : _demaisObservacoesController.text.trim(),
        descricaoLocalMediato: _descricaoMediatoController.text.trim().isEmpty
            ? null
            : _descricaoMediatoController.text.trim(),
        descricaoLocalImediato: _descricaoImediatoController.text.trim().isEmpty
            ? null
            : _descricaoImediatoController.text.trim(),
        descricaoLocalRelacionado:
            _descricaoRelacionadoController.text.trim().isEmpty
            ? null
            : _descricaoRelacionadoController.text.trim(),
        marcoZeroMediato: (_classificacaoMediato == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoMediatoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoMediatoController.text.trim(),
                coordenadaX: _marcoZeroXMediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXMediatoController.text.trim(),
                coordenadaY: _marcoZeroYMediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYMediatoController.text.trim(),
              )
            : null,
        marcoZeroImediato: (_classificacaoImediato == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoImediatoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoImediatoController.text.trim(),
                coordenadaX: _marcoZeroXImediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXImediatoController.text.trim(),
                coordenadaY: _marcoZeroYImediatoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYImediatoController.text.trim(),
              )
            : null,
        marcoZeroRelacionado: (_classificacaoRelacionado == true)
            ? MarcoZeroLocalModel(
                descricao:
                    _marcoZeroDescricaoRelacionadoController.text.trim().isEmpty
                    ? null
                    : _marcoZeroDescricaoRelacionadoController.text.trim(),
                coordenadaX:
                    _marcoZeroXRelacionadoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroXRelacionadoController.text.trim(),
                coordenadaY:
                    _marcoZeroYRelacionadoController.text.trim().isEmpty
                    ? '0'
                    : _marcoZeroYRelacionadoController.text.trim(),
              )
            : null,
        vestigiosMediato: _semVestigiosMediato ? [] : _vestigiosMediato,
        vestigiosImediato: _semVestigiosImediato ? [] : _vestigiosImediato,
        vestigiosRelacionado: _semVestigiosRelacionado
            ? []
            : _vestigiosRelacionado,
        semVestigiosMediato: _semVestigiosMediato,
        semVestigiosImediato: _semVestigiosImediato,
        semVestigiosRelacionado: _semVestigiosRelacionado,
        sinaisArrombamentoSim: _sinaisArrombamentoSim,
        sinaisArrombamentoNao: _sinaisArrombamentoNao,
        sinaisArrombamentoNaoSeAplica: _sinaisArrombamentoNaoSeAplica,
      );

      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        localFurto: localFurto,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Mostrar alerta sobre o croqui
        await _mostrarAlertaCroqui();

        if (!mounted) return;

        // Verificar tipo de ocorrência
        if (fichaAtualizada.tipoOcorrencia == TipoOcorrencia.cvli) {
          // Para CVLI, navegar para tela de veículos e aguardar retorno
          final resultadoVeiculos = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ListaVeiculosScreen(ficha: fichaAtualizada),
            ),
          );

          // Se voltou de veículos com sucesso, apenas propagar o sucesso
          if (mounted && resultadoVeiculos != null) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Para crimes patrimoniais, navegar para tela de evidências
          final resultado = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  EvidenciasFurtoScreen(ficha: fichaAtualizada),
            ),
          );

          // Se voltou das evidências, retornar true para atualizar lista
          if (mounted && resultado == true) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Future<void> _mostrarAlertaCroqui() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.draw, size: 48, color: Colors.orange),
        title: const Text('Lembrete: Croqui'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Não esqueça de fazer o croqui do local!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'O croqui deve relacionar os principais vestígios encontrados, '
              'indicando suas posições em relação ao marco zero definido.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(String label, List<Map<String, dynamic>> opcoes) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: opcoes.map((opcao) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: opcao['value'] as bool? ?? false,
                      onChanged: opcao['onChanged'] as void Function(bool?)?,
                    ),
                    Flexible(child: Text(opcao['label'] as String)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoLocalDetalhado({
    required String titulo,
    required String local,
    required TextEditingController descricaoController,
    required TextEditingController marcoZeroDescricaoController,
    required TextEditingController marcoZeroXController,
    required TextEditingController marcoZeroYController,
    required List<VestigioLocalModel> vestigios,
    required bool semVestigios,
    required ValueChanged<bool> onSemVestigiosChanged,
    required VoidCallback onAdicionarVestigio,
    required void Function(String id) onRemoverVestigio,
    required void Function(VestigioLocalModel existente) onEditarVestigio,
    required bool? pisoSeco,
    required bool? pisoUmido,
    required bool? pisoMolhado,
    required bool? iluminacaoArtificial,
    required bool? iluminacaoNatural,
    required bool? iluminacaoAusente,
    required void Function(bool?, String) onPisoChanged,
    required void Function(bool?, String) onIluminacaoChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Descrição (do geral para o particular)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    hintText: 'Descreva o local...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: null,
                  minLines: 5,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Marco Zero',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: marcoZeroDescricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do Marco Zero',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: null,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: marcoZeroXController,
                        decoration: const InputDecoration(
                          labelText: 'Coordenada X',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: marcoZeroYController,
                        decoration: const InputDecoration(
                          labelText: 'Coordenada Y',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Condições do Piso',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoSeco ?? false,
                          onChanged: (value) => onPisoChanged(value, 'seco'),
                        ),
                        const Text('Seco'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoUmido ?? false,
                          onChanged: (value) => onPisoChanged(value, 'umido'),
                        ),
                        const Text('Úmido'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: pisoMolhado ?? false,
                          onChanged: (value) => onPisoChanged(value, 'molhado'),
                        ),
                        const Text('Molhado'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Iluminação',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoArtificial ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'artificial'),
                        ),
                        const Text('Artificial'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoNatural ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'natural'),
                        ),
                        const Text('Natural'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: iluminacaoAusente ?? false,
                          onChanged: (value) =>
                              onIluminacaoChanged(value, 'ausente'),
                        ),
                        const Text('Ausente'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sem vestígios neste local'),
                  value: semVestigios,
                  onChanged: (value) {
                    onSemVestigiosChanged(value);
                  },
                ),
                if (!semVestigios) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onAdicionarVestigio,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar vestígio'),
                    ),
                  ),
                  if (vestigios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhum vestígio adicionado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ...vestigios.map(
                    (v) => Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Vestígio',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar',
                                      onPressed: () => onEditarVestigio(v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Remover',
                                      onPressed: () => onRemoverVestigio(v.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (v.descricao != null && v.descricao!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Descrição: ${v.descricao}'),
                              ),
                            if (v.coordenadaX != null && v.coordenadaY != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Coordenadas: X=${v.coordenadaX}, Y=${v.coordenadaY}',
                                ),
                              ),
                            if (v.alturaRelacaoPiso != null &&
                                v.alturaRelacaoPiso!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Altura em relação ao piso: ${v.alturaRelacaoPiso}',
                                ),
                              ),
                            if (v.tipoAcao != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Tipo: ${v.tipoAcao!.label}'),
                              ),
                            if (v.tipoAcao == TipoAcaoVestigio.coletado) ...[
                              if (v.coletadoPor != null &&
                                  v.coletadoPor!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Coletado por: ${v.coletadoPor}'),
                                ),
                              if (v.dataHoraColeta != null &&
                                  v.dataHoraColeta!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Data/Hora coleta: ${v.dataHoraColeta}',
                                  ),
                                ),
                              if (v.tipoDestino != null && v.destinoId != null)
                                FutureBuilder<dynamic>(
                                  future:
                                      v.tipoDestino ==
                                          TipoDestinoVestigio.unidade
                                      ? _unidadeService.listarUnidades()
                                      : _laboratorioService
                                            .listarLaboratorios(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final lista = snapshot.data as List;
                                      final items = lista.where(
                                        (item) => item.id == v.destinoId,
                                      );
                                      if (items.isNotEmpty) {
                                        final item = items.first;
                                        final nome =
                                            v.tipoDestino ==
                                                TipoDestinoVestigio.unidade
                                            ? (item as UnidadeModel).nome
                                            : (item as LaboratorioModel).nome;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Destino: ${v.tipoDestino!.label} - $nome',
                                          ),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              if (v.numeroLacre != null &&
                                  v.numeroLacre!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Número do lacre: ${v.numeroLacre}',
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarInstrucoes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instruções - Descrição do Local'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Descrever objetivamente os seguintes itens:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Classificar o tipo de imóvel (ex.: imóvel residencial, comercial, industrial, religioso, educacional, prisional etc.);',
              ),
              const Text(
                '• Descrever o tipo de delimitação (Ex.: muros de alvenaria);',
              ),
              const Text(
                '• Descrever os acessos de entrada e saída (Ex.: portão e portas); e',
              ),
              const Text(
                '• Descrever as estruturas pertinentes ao exame (Ex.: cadeados, fechaduras, paredes, janelas e coberturas).',
              ),
              const SizedBox(height: 16),
              const Text(
                'Exemplo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Tratava-se de prédio comercial de 03 pavimentos. Não existia muro ou qualquer outro tipo de cerca delimitando o terreno. As portas eram metálicas de enrolar, sendo que em duas dessas portas existiam portas de vidro temperado, internamente às portas metálicas.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local - Detalhes do Local'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInstrucoes,
            tooltip: 'Instruções de uso',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título da seção
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Tabela de dados
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  // Classificação
                  _buildCheckboxRow('Classificação', [
                    {
                      'label': 'Mediato',
                      'value': _classificacaoMediato ?? false,
                      'onChanged': (value) =>
                          _onClassificacaoChanged(value, 'mediato'),
                    },
                    {
                      'label': 'Imediato',
                      'value': _classificacaoImediato ?? false,
                      'onChanged': (value) =>
                          _onClassificacaoChanged(value, 'imediato'),
                    },
                    {
                      'label': 'Relacionado',
                      'value': _classificacaoRelacionado ?? false,
                      'onChanged': (value) =>
                          _onClassificacaoChanged(value, 'relacionado'),
                    },
                  ]),
                  const Divider(height: 1),
                  // Descrição das Vias de Acesso
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição das Vias de Acesso:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _viasAcessoController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva as vias de acesso...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Sinais de Arrombamento
                  _buildCheckboxRow('Sinais de Arrombamento', [
                    {
                      'label': 'Sim',
                      'value': _sinaisArrombamentoSim ?? false,
                      'onChanged': (value) =>
                          _onSinaisArrombamentoChanged(value, 'sim'),
                    },
                    {
                      'label': 'Não',
                      'value': _sinaisArrombamentoNao ?? false,
                      'onChanged': (value) =>
                          _onSinaisArrombamentoChanged(value, 'nao'),
                    },
                    {
                      'label': 'Não Se Aplica',
                      'value': _sinaisArrombamentoNaoSeAplica ?? false,
                      'onChanged': (value) =>
                          _onSinaisArrombamentoChanged(value, 'naoSeAplica'),
                    },
                  ]),
                  const Divider(height: 1),
                  // Descrição dos Sinais de Arrombamento
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição dos Sinais de Arrombamento:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sinaisArrombamentoController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva os sinais de arrombamento...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Descrição dos Locais (Mediato, Imediato, Relacionado) + Vestígios
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Descrições por Local e Vestígios:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Descrever detalhadamente os Locais Mediato, Imediato e Relacionado (nesta ordem), do geral para o particular. Em cada local, registrar os vestígios encontrados e sua posição no cenário.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        if ((_classificacaoMediato ?? false)) ...[
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Mediato',
                            local: 'mediato',
                            descricaoController: _descricaoMediatoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoMediatoController,
                            marcoZeroXController: _marcoZeroXMediatoController,
                            marcoZeroYController: _marcoZeroYMediatoController,
                            vestigios: _vestigiosMediato,
                            semVestigios: _semVestigiosMediato,
                            onSemVestigiosChanged: (value) {
                              setState(() {
                                _semVestigiosMediato = value;
                                if (value) _vestigiosMediato.clear();
                              });
                            },
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('mediato'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('mediato', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'mediato',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoMediato,
                            pisoUmido: _pisoUmidoMediato,
                            pisoMolhado: _pisoMolhadoMediato,
                            iluminacaoArtificial: _iluminacaoArtificialMediato,
                            iluminacaoNatural: _iluminacaoNaturalMediato,
                            iluminacaoAusente: _iluminacaoAusenteMediato,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'mediato'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(value, tipo, 'mediato'),
                          ),
                        ],
                        if ((_classificacaoImediato ?? false)) ...[
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Imediato',
                            local: 'imediato',
                            descricaoController: _descricaoImediatoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoImediatoController,
                            marcoZeroXController: _marcoZeroXImediatoController,
                            marcoZeroYController: _marcoZeroYImediatoController,
                            vestigios: _vestigiosImediato,
                            semVestigios: _semVestigiosImediato,
                            onSemVestigiosChanged: (value) {
                              setState(() {
                                _semVestigiosImediato = value;
                                if (value) _vestigiosImediato.clear();
                              });
                            },
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('imediato'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('imediato', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'imediato',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoImediato,
                            pisoUmido: _pisoUmidoImediato,
                            pisoMolhado: _pisoMolhadoImediato,
                            iluminacaoArtificial: _iluminacaoArtificialImediato,
                            iluminacaoNatural: _iluminacaoNaturalImediato,
                            iluminacaoAusente: _iluminacaoAusenteImediato,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'imediato'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(value, tipo, 'imediato'),
                          ),
                        ],
                        if ((_classificacaoRelacionado ?? false)) ...[
                          _buildSecaoLocalDetalhado(
                            titulo: 'Local Relacionado',
                            local: 'relacionado',
                            descricaoController:
                                _descricaoRelacionadoController,
                            marcoZeroDescricaoController:
                                _marcoZeroDescricaoRelacionadoController,
                            marcoZeroXController:
                                _marcoZeroXRelacionadoController,
                            marcoZeroYController:
                                _marcoZeroYRelacionadoController,
                            vestigios: _vestigiosRelacionado,
                            semVestigios: _semVestigiosRelacionado,
                            onSemVestigiosChanged: (value) {
                              setState(() {
                                _semVestigiosRelacionado = value;
                                if (value) _vestigiosRelacionado.clear();
                              });
                            },
                            onAdicionarVestigio: () =>
                                _adicionarOuEditarVestigio('relacionado'),
                            onRemoverVestigio: (id) =>
                                _removerVestigio('relacionado', id),
                            onEditarVestigio: (v) => _adicionarOuEditarVestigio(
                              'relacionado',
                              existente: v,
                            ),
                            pisoSeco: _pisoSecoRelacionado,
                            pisoUmido: _pisoUmidoRelacionado,
                            pisoMolhado: _pisoMolhadoRelacionado,
                            iluminacaoArtificial:
                                _iluminacaoArtificialRelacionado,
                            iluminacaoNatural: _iluminacaoNaturalRelacionado,
                            iluminacaoAusente: _iluminacaoAusenteRelacionado,
                            onPisoChanged: (value, tipo) =>
                                _onPisoChanged(value, tipo, 'relacionado'),
                            onIluminacaoChanged: (value, tipo) =>
                                _onIluminacaoChanged(
                                  value,
                                  tipo,
                                  'relacionado',
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Demais Observações
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demais Observações:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _demaisObservacoesController,
                          decoration: const InputDecoration(
                            hintText: 'Digite observações adicionais...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 4,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarLocalFurto,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Salvar e Continuar'),
            ),
            const SizedBox(
              height: 80,
            ), // Padding extra no final para garantir que o botão fique visível
          ],
        ),
      ),
    );
  }
}
