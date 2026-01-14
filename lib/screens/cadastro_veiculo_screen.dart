import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/unidade_model.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/laboratorio_service.dart';
import '../services/perito_service.dart';
import '../services/unidade_service.dart';

class CadastroVeiculoScreen extends StatefulWidget {
  final VeiculoModel veiculo;
  final FichaCompletaModel ficha;

  const CadastroVeiculoScreen({
    super.key,
    required this.veiculo,
    required this.ficha,
  });

  @override
  State<CadastroVeiculoScreen> createState() => _CadastroVeiculoScreenState();
}

class _CadastroVeiculoScreenState extends State<CadastroVeiculoScreen> {
  final _peritoService = PeritoService();
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();

  // Controllers - Identificação
  final _tipoVeiculoOutroCtrl = TextEditingController();
  final _marcaModeloCtrl = TextEditingController();
  final _anoFabricacaoCtrl = TextEditingController();
  final _anoModeloCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  // Controllers - Localização
  final _localizacaoAmbienteCtrl = TextEditingController();
  final _coordenadaFrenteXCtrl = TextEditingController();
  final _coordenadaFrenteYCtrl = TextEditingController();
  final _alturaFrenteCtrl = TextEditingController();
  final _coordenadaTraseiraXCtrl = TextEditingController();
  final _coordenadaTraseiraYCtrl = TextEditingController();
  final _alturaTraseiraCtrl = TextEditingController();
  final _coordenadaCentroXCtrl = TextEditingController();
  final _coordenadaCentroYCtrl = TextEditingController();
  final _alturaCentroCtrl = TextEditingController();

  // Controllers - Estado e Posição
  final _posicaoLivreCtrl = TextEditingController();
  final _condicaoGeralCtrl = TextEditingController();

  // Controllers - Vestígios (legados, mantidos para compatibilidade)
  final _localizacaoSangueCtrl = TextEditingController();
  final _localizacaoProjeteisImpactosCtrl = TextEditingController();

  // Controllers - Relacionamento
  final _observacoesCtrl = TextEditingController();

  // Estados
  TipoVeiculo? _tipoVeiculo;
  PosicaoVeiculo? _posicao;
  RelacaoVeiculo? _relacao;
  // Flags legados (enquanto migramos para lista de vestígios)
  List<VestigioVeiculoModel> _vestigios = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final v = widget.veiculo;
    _tipoVeiculo = v.tipoVeiculo;
    _tipoVeiculoOutroCtrl.text = v.tipoVeiculoOutro ?? '';
    _marcaModeloCtrl.text = v.marcaModelo ?? '';
    _anoFabricacaoCtrl.text = v.anoFabricacao ?? '';
    _anoModeloCtrl.text = v.anoModelo ?? '';
    _corCtrl.text = v.cor ?? '';
    _placaCtrl.text = v.placa ?? '';

    _localizacaoAmbienteCtrl.text = v.localizacaoAmbiente ?? '';
    _coordenadaFrenteXCtrl.text = v.coordenadaFrenteX ?? '';
    _coordenadaFrenteYCtrl.text = v.coordenadaFrenteY ?? '';
    _alturaFrenteCtrl.text = v.alturaFrente ?? '';
    _coordenadaTraseiraXCtrl.text = v.coordenadaTraseiraX ?? '';
    _coordenadaTraseiraYCtrl.text = v.coordenadaTraseiraY ?? '';
    _alturaTraseiraCtrl.text = v.alturaTraseira ?? '';
    _coordenadaCentroXCtrl.text = v.coordenadaCentroX ?? '';
    _coordenadaCentroYCtrl.text = v.coordenadaCentroY ?? '';
    _alturaCentroCtrl.text = v.alturaCentro ?? '';

    _posicao = v.posicao;
    _posicaoLivreCtrl.text = v.posicaoLivre ?? '';
    _condicaoGeralCtrl.text = v.condicaoGeral ?? '';

    _vestigios = List<VestigioVeiculoModel>.from(v.vestigios ?? []);

    _relacao = v.relacao;
    _observacoesCtrl.text = v.observacoes ?? '';
  }

  @override
  void dispose() {
    _tipoVeiculoOutroCtrl.dispose();
    _marcaModeloCtrl.dispose();
    _anoFabricacaoCtrl.dispose();
    _anoModeloCtrl.dispose();
    _corCtrl.dispose();
    _placaCtrl.dispose();
    _localizacaoAmbienteCtrl.dispose();
    _coordenadaFrenteXCtrl.dispose();
    _coordenadaFrenteYCtrl.dispose();
    _alturaFrenteCtrl.dispose();
    _coordenadaTraseiraXCtrl.dispose();
    _coordenadaTraseiraYCtrl.dispose();
    _alturaTraseiraCtrl.dispose();
    _coordenadaCentroXCtrl.dispose();
    _coordenadaCentroYCtrl.dispose();
    _alturaCentroCtrl.dispose();
    _posicaoLivreCtrl.dispose();
    _condicaoGeralCtrl.dispose();
    _localizacaoSangueCtrl.dispose();
    _localizacaoProjeteisImpactosCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  VeiculoModel _construirVeiculo() {
    return widget.veiculo.copyWith(
      tipoVeiculo: _tipoVeiculo,
      tipoVeiculoOutro: _tipoVeiculoOutroCtrl.text.trim().isEmpty
          ? null
          : _tipoVeiculoOutroCtrl.text.trim(),
      marcaModelo: _marcaModeloCtrl.text.trim().isEmpty
          ? null
          : _marcaModeloCtrl.text.trim(),
      anoFabricacao: _anoFabricacaoCtrl.text.trim().isEmpty
          ? null
          : _anoFabricacaoCtrl.text.trim(),
      anoModelo: _anoModeloCtrl.text.trim().isEmpty
          ? null
          : _anoModeloCtrl.text.trim(),
      cor: _corCtrl.text.trim().isEmpty ? null : _corCtrl.text.trim(),
      placa: _placaCtrl.text.trim().isEmpty ? null : _placaCtrl.text.trim(),
      localizacaoAmbiente: _localizacaoAmbienteCtrl.text.trim().isEmpty
          ? null
          : _localizacaoAmbienteCtrl.text.trim(),
      coordenadaFrenteX: _coordenadaFrenteXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaFrenteXCtrl.text.trim(),
      coordenadaFrenteY: _coordenadaFrenteYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaFrenteYCtrl.text.trim(),
      alturaFrente: _alturaFrenteCtrl.text.trim().isEmpty
          ? null
          : _alturaFrenteCtrl.text.trim(),
      coordenadaTraseiraX: _coordenadaTraseiraXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaTraseiraXCtrl.text.trim(),
      coordenadaTraseiraY: _coordenadaTraseiraYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaTraseiraYCtrl.text.trim(),
      alturaTraseira: _alturaTraseiraCtrl.text.trim().isEmpty
          ? null
          : _alturaTraseiraCtrl.text.trim(),
      coordenadaCentroX: _coordenadaCentroXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroXCtrl.text.trim(),
      coordenadaCentroY: _coordenadaCentroYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroYCtrl.text.trim(),
      alturaCentro: _alturaCentroCtrl.text.trim().isEmpty
          ? null
          : _alturaCentroCtrl.text.trim(),
      posicao: _posicao,
      posicaoLivre: _posicaoLivreCtrl.text.trim().isEmpty
          ? null
          : _posicaoLivreCtrl.text.trim(),
      condicaoGeral: _condicaoGeralCtrl.text.trim().isEmpty
          ? null
          : _condicaoGeralCtrl.text.trim(),
      vestigios: _vestigios,
      relacao: _relacao,
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
    );
  }

  String _gerarIdVestigio() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _adicionarOuEditarVestigio({
    VestigioVeiculoModel? existente,
  }) async {
    final descricaoCtrl = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final localizacaoCtrl = TextEditingController(
      text: existente?.localizacao ?? '',
    );

    TipoAcaoVestigioVeiculo? tipoAcaoSelecionado = existente?.tipoAcao;
    TipoDestinoVestigioVeiculo? tipoDestinoSelecionado = existente?.tipoDestino;
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
                    TextFormField(
                      controller: localizacaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Localização no veículo *',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: porta do motorista, banco traseiro',
                      ),
                      maxLines: 2,
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
                    RadioGroup<TipoAcaoVestigioVeiculo>(
                      groupValue: tipoAcaoSelecionado,
                      onChanged: (value) {
                        setDialogState(() {
                          tipoAcaoSelecionado = value;
                          if (value != TipoAcaoVestigioVeiculo.coletado) {
                            tipoDestinoSelecionado = null;
                            destinoIdSelecionado = null;
                          }
                        });
                      },
                      child: Column(
                        children: [
                          ListTile(
                            leading: Radio<TipoAcaoVestigioVeiculo>(
                              value: TipoAcaoVestigioVeiculo.registrado,
                            ),
                            title: const Text('Apenas Registrado'),
                            onTap: () {
                              setDialogState(() {
                                tipoAcaoSelecionado =
                                    TipoAcaoVestigioVeiculo.registrado;
                                tipoDestinoSelecionado = null;
                                destinoIdSelecionado = null;
                              });
                            },
                          ),
                          ListTile(
                            leading: Radio<TipoAcaoVestigioVeiculo>(
                              value: TipoAcaoVestigioVeiculo.coletado,
                            ),
                            title: const Text('Coletado'),
                            onTap: () {
                              setDialogState(() {
                                tipoAcaoSelecionado =
                                    TipoAcaoVestigioVeiculo.coletado;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (tipoAcaoSelecionado ==
                        TipoAcaoVestigioVeiculo.coletado) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Será analisado na Unidade ou encaminhado para laboratório?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<TipoDestinoVestigioVeiculo>(
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
                              leading: Radio<TipoDestinoVestigioVeiculo>(
                                value: TipoDestinoVestigioVeiculo.unidade,
                              ),
                              title: const Text('Unidade'),
                              onTap: () {
                                setDialogState(() {
                                  tipoDestinoSelecionado =
                                      TipoDestinoVestigioVeiculo.unidade;
                                  destinoIdSelecionado = null;
                                });
                              },
                            ),
                            ListTile(
                              leading: Radio<TipoDestinoVestigioVeiculo>(
                                value: TipoDestinoVestigioVeiculo.laboratorio,
                              ),
                              title: const Text('Laboratório'),
                              onTap: () {
                                setDialogState(() {
                                  tipoDestinoSelecionado =
                                      TipoDestinoVestigioVeiculo.laboratorio;
                                  destinoIdSelecionado = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      if (tipoDestinoSelecionado != null) ...[
                        const SizedBox(height: 16),
                        FutureBuilder<List<dynamic>>(
                          future:
                              tipoDestinoSelecionado ==
                                  TipoDestinoVestigioVeiculo.unidade
                              ? _unidadeService.listarUnidades()
                              : _laboratorioService.listarLaboratorios(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError || !snapshot.hasData) {
                              return const Text('Erro ao carregar opções');
                            }

                            final opcoes = snapshot.data!;
                            if (opcoes.isEmpty) {
                              return const Text(
                                'Nenhuma opção disponível. Cadastre em Configurações.',
                              );
                            }

                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: destinoIdSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Selecione o destino *',
                                border: OutlineInputBorder(),
                              ),
                              items: opcoes.map((opcao) {
                                final id =
                                    tipoDestinoSelecionado ==
                                        TipoDestinoVestigioVeiculo.unidade
                                    ? (opcao as UnidadeModel).id
                                    : (opcao as LaboratorioModel).id;
                                final nome =
                                    tipoDestinoSelecionado ==
                                        TipoDestinoVestigioVeiculo.unidade
                                    ? (opcao as UnidadeModel).nome
                                    : (opcao as LaboratorioModel).nome;
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
                        const SizedBox(height: 12),
                        Text(
                          'Coletado por: $nomePerito',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
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
                  onPressed: () {
                    if (descricaoCtrl.text.trim().isEmpty) {
                      setDialogState(() {
                        erroMensagem = 'A descrição é obrigatória';
                      });
                      return;
                    }

                    if (localizacaoCtrl.text.trim().isEmpty) {
                      setDialogState(() {
                        erroMensagem = 'A localização no veículo é obrigatória';
                      });
                      return;
                    }

                    if (tipoAcaoSelecionado == null) {
                      setDialogState(() {
                        erroMensagem =
                            'Selecione se será coletado ou apenas registrado';
                      });
                      return;
                    }

                    if (tipoAcaoSelecionado ==
                            TipoAcaoVestigioVeiculo.coletado &&
                        tipoDestinoSelecionado == null) {
                      setDialogState(() {
                        erroMensagem = 'Selecione o destino';
                      });
                      return;
                    }

                    if (tipoAcaoSelecionado ==
                            TipoAcaoVestigioVeiculo.coletado &&
                        destinoIdSelecionado == null) {
                      setDialogState(() {
                        erroMensagem = 'Selecione a unidade ou laboratório';
                      });
                      return;
                    }

                    String? coletadoPor;
                    String? dataHoraColeta;
                    if (tipoAcaoSelecionado ==
                        TipoAcaoVestigioVeiculo.coletado) {
                      coletadoPor = nomePerito;
                      final agora = DateTime.now();
                      dataHoraColeta = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(agora);
                    }

                    final novo = VestigioVeiculoModel(
                      id: existente?.id ?? _gerarIdVestigio(),
                      descricao: descricaoCtrl.text.trim(),
                      localizacao: localizacaoCtrl.text.trim(),
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
                      final idx = _vestigios.indexWhere((e) => e.id == novo.id);
                      if (idx >= 0) {
                        _vestigios[idx] = novo;
                      } else {
                        _vestigios.add(novo);
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

  void _removerVestigio(String id) {
    setState(() {
      _vestigios.removeWhere((v) => v.id == id);
    });
  }

  void _salvar() {
    if (_localizacaoAmbienteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a localização do veículo no ambiente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final veiculo = _construirVeiculo();
    Navigator.of(context).pop(veiculo);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Veículo ${widget.veiculo.numero}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Identificação Básica
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IDENTIFICAÇÃO BÁSICA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDropdown<TipoVeiculo>(
                      label: 'Tipo de veículo',
                      value: _tipoVeiculo,
                      items: TipoVeiculo.values,
                      onChanged: (v) {
                        setState(() {
                          _tipoVeiculo = v;
                          if (v != TipoVeiculo.outro) {
                            _tipoVeiculoOutroCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (_tipoVeiculo == TipoVeiculo.outro) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tipoVeiculoOutroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Especifique o tipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _marcaModeloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marca/Modelo',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Ford Ka, Honda CG 160',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _anoFabricacaoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ano de Fabricação',
                              border: OutlineInputBorder(),
                              hintText: 'Ex: 2020',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _anoModeloCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ano Modelo',
                              border: OutlineInputBorder(),
                              hintText: 'Ex: 2021',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _corCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cor',
                              border: OutlineInputBorder(),
                              hintText: 'Ex: Branco, Prata',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _placaCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Placa (opcional)',
                              border: OutlineInputBorder(),
                              hintText: 'ABC-1234',
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

            // Localização no Ambiente
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
                        hintText: 'Ex: estacionado na rua, no centro da via',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Coordenadas (opcionais)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Coordenadas da Frente
                    Text(
                      'Frente',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coordenadaFrenteXCtrl,
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
                            controller: _coordenadaFrenteYCtrl,
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
                            controller: _alturaFrenteCtrl,
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
                    // Coordenadas da Traseira
                    Text(
                      'Traseira',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coordenadaTraseiraXCtrl,
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
                            controller: _coordenadaTraseiraYCtrl,
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
                            controller: _alturaTraseiraCtrl,
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
                    // Coordenadas do Centro
                    Text(
                      'Centro',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coordenadaCentroXCtrl,
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
                            controller: _coordenadaCentroYCtrl,
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
                            controller: _alturaCentroCtrl,
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

            // Estado e Posição
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTADO E POSIÇÃO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDropdown<PosicaoVeiculo>(
                      label: 'Posição',
                      value: _posicao,
                      items: PosicaoVeiculo.values,
                      onChanged: (v) {
                        setState(() {
                          _posicao = v;
                          if (v != PosicaoVeiculo.outra) {
                            _posicaoLivreCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (_posicao == PosicaoVeiculo.outra) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _posicaoLivreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descrição livre da posição',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _condicaoGeralCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Condição geral',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: danos na lateral esquerda',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Vestígios/Evidências
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
                          'VESTÍGIOS/EVIDÊNCIAS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _adicionarOuEditarVestigio,
                          tooltip: 'Adicionar vestígio',
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_vestigios.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nenhum vestígio cadastrado',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._vestigios.map((vestigio) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    vestigio.descricao ?? 'Vestígio',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (vestigio.isSangueHumano)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Sangue',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vestigio.localizacao != null)
                                  Text('Local: ${vestigio.localizacao}'),
                                if (vestigio.tipoAcao != null)
                                  Text('Tipo: ${vestigio.tipoAcao!.label}'),
                                if (vestigio.tipoAcao ==
                                        TipoAcaoVestigioVeiculo.coletado &&
                                    vestigio.coletadoPor != null)
                                  Text('Coletado por: ${vestigio.coletadoPor}'),
                                if (vestigio.dataHoraColeta != null)
                                  Text('Data/Hora: ${vestigio.dataHoraColeta}'),
                                if (vestigio.tipoDestino != null &&
                                    vestigio.destinoId != null)
                                  FutureBuilder<dynamic>(
                                    future:
                                        vestigio.tipoDestino ==
                                            TipoDestinoVestigioVeiculo.unidade
                                        ? _unidadeService.listarUnidades()
                                        : _laboratorioService
                                              .listarLaboratorios(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final lista = snapshot.data as List;
                                        final items = lista.where(
                                          (item) =>
                                              item.id == vestigio.destinoId,
                                        );
                                        if (items.isNotEmpty) {
                                          final item = items.first;
                                          final nome =
                                              vestigio.tipoDestino ==
                                                  TipoDestinoVestigioVeiculo
                                                      .unidade
                                              ? (item as UnidadeModel).nome
                                              : (item as LaboratorioModel).nome;
                                          return Text(
                                            'Destino: ${vestigio.tipoDestino!.label} - $nome',
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _adicionarOuEditarVestigio(
                                    existente: vestigio,
                                  ),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _removerVestigio(vestigio.id),
                                  tooltip: 'Excluir',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Relacionamento com o caso
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RELACIONAMENTO COM O CASO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDropdown<RelacaoVeiculo>(
                      label: 'Relação',
                      value: _relacao,
                      items: RelacaoVeiculo.values,
                      onChanged: (v) => setState(() => _relacao = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _observacoesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _salvar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Salvar Veículo'),
          ),
        ),
      ),
    );
  }
}
