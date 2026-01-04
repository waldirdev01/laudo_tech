import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ficha_completa_model.dart';
import '../models/dano_model.dart';
import '../services/ficha_service.dart';

class DanoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const DanoScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<DanoScreen> createState() => _DanoScreenState();
}

class _DanoScreenState extends State<DanoScreen> {
  final _fichaService = FichaService();
  bool _salvando = false;

  // Controllers para campos de texto
  final _qualInstrumentoSubstanciaController = TextEditingController();
  final _qualVestigioController = TextEditingController();
  final _danoCausadoController = TextEditingController();
  final _valorEstimadoController = TextEditingController();
  final _numeroPessoasController = TextEditingController();
  final _quaisVestigiosAutoriaController = TextEditingController();
  final _dinamicaEventoController = TextEditingController();

  // Estados dos checkboxes
  bool? _substanciaInflamavelExplosivaSim;
  bool? _substanciaInflamavelExplosivaNao;
  bool? _danoPatrimonioPublicoSim;
  bool? _danoPatrimonioPublicoNao;
  bool? _prejuizoConsideravelSim;
  bool? _prejuizoConsideravelNao;
  bool? _identificarInstrumentoSubstanciaSim;
  bool? _identificarInstrumentoSubstanciaNao;
  bool? _identificacaoVestigioSim;
  bool? _identificacaoVestigioNao;
  bool? _identificarNumeroPessoasSim;
  bool? _identificarNumeroPessoasNao;
  bool? _vestigiosAutoriaSim;
  bool? _vestigiosAutoriaNao;
  bool? _identificarDinamicaSim;
  bool? _identificarDinamicaNao;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.dano;
    if (dados != null) {
      _substanciaInflamavelExplosivaSim = dados.substanciaInflamavelExplosivaSim;
      _substanciaInflamavelExplosivaNao = dados.substanciaInflamavelExplosivaNao;
      _danoPatrimonioPublicoSim = dados.danoPatrimonioPublicoSim;
      _danoPatrimonioPublicoNao = dados.danoPatrimonioPublicoNao;
      _prejuizoConsideravelSim = dados.prejuizoConsideravelSim;
      _prejuizoConsideravelNao = dados.prejuizoConsideravelNao;
      _identificarInstrumentoSubstanciaSim = dados.identificarInstrumentoSubstanciaSim;
      _identificarInstrumentoSubstanciaNao = dados.identificarInstrumentoSubstanciaNao;
      _qualInstrumentoSubstanciaController.text = dados.qualInstrumentoSubstancia ?? '';
      _identificacaoVestigioSim = dados.identificacaoVestigioSim;
      _identificacaoVestigioNao = dados.identificacaoVestigioNao;
      _qualVestigioController.text = dados.qualVestigio ?? '';
      _danoCausadoController.text = dados.danoCausado ?? '';
      _valorEstimadoController.text = dados.valorEstimadoPrejuizos ?? '';
      _identificarNumeroPessoasSim = dados.identificarNumeroPessoasSim;
      _identificarNumeroPessoasNao = dados.identificarNumeroPessoasNao;
      _numeroPessoasController.text = dados.numeroPessoas ?? '';
      _vestigiosAutoriaSim = dados.vestigiosAutoriaSim;
      _vestigiosAutoriaNao = dados.vestigiosAutoriaNao;
      _quaisVestigiosAutoriaController.text = dados.quaisVestigiosAutoria ?? '';
      _identificarDinamicaSim = dados.identificarDinamicaSim;
      _identificarDinamicaNao = dados.identificarDinamicaNao;
      _dinamicaEventoController.text = dados.dinamicaEvento ?? '';
    }
  }

  @override
  void dispose() {
    _qualInstrumentoSubstanciaController.dispose();
    _qualVestigioController.dispose();
    _danoCausadoController.dispose();
    _valorEstimadoController.dispose();
    _numeroPessoasController.dispose();
    _quaisVestigiosAutoriaController.dispose();
    _dinamicaEventoController.dispose();
    super.dispose();
  }

  Future<void> _salvarDano() async {
    setState(() {
      _salvando = true;
    });

    try {
      final dano = DanoModel(
        substanciaInflamavelExplosivaSim: _substanciaInflamavelExplosivaSim,
        substanciaInflamavelExplosivaNao: _substanciaInflamavelExplosivaNao,
        danoPatrimonioPublicoSim: _danoPatrimonioPublicoSim,
        danoPatrimonioPublicoNao: _danoPatrimonioPublicoNao,
        prejuizoConsideravelSim: _prejuizoConsideravelSim,
        prejuizoConsideravelNao: _prejuizoConsideravelNao,
        identificarInstrumentoSubstanciaSim: _identificarInstrumentoSubstanciaSim,
        identificarInstrumentoSubstanciaNao: _identificarInstrumentoSubstanciaNao,
        qualInstrumentoSubstancia: _qualInstrumentoSubstanciaController.text.trim().isEmpty
            ? null
            : _qualInstrumentoSubstanciaController.text.trim(),
        identificacaoVestigioSim: _identificacaoVestigioSim,
        identificacaoVestigioNao: _identificacaoVestigioNao,
        qualVestigio: _qualVestigioController.text.trim().isEmpty
            ? null
            : _qualVestigioController.text.trim(),
        danoCausado: _danoCausadoController.text.trim().isEmpty
            ? null
            : _danoCausadoController.text.trim(),
        valorEstimadoPrejuizos: _valorEstimadoController.text.trim().isEmpty
            ? null
            : _valorEstimadoController.text.trim(),
        identificarNumeroPessoasSim: _identificarNumeroPessoasSim,
        identificarNumeroPessoasNao: _identificarNumeroPessoasNao,
        numeroPessoas: _numeroPessoasController.text.trim().isEmpty
            ? null
            : _numeroPessoasController.text.trim(),
        vestigiosAutoriaSim: _vestigiosAutoriaSim,
        vestigiosAutoriaNao: _vestigiosAutoriaNao,
        quaisVestigiosAutoria: _quaisVestigiosAutoriaController.text.trim().isEmpty
            ? null
            : _quaisVestigiosAutoriaController.text.trim(),
        identificarDinamicaSim: _identificarDinamicaSim,
        identificarDinamicaNao: _identificarDinamicaNao,
        dinamicaEvento: _dinamicaEventoController.text.trim().isEmpty
            ? null
            : _dinamicaEventoController.text.trim(),
      );

      // Preencher data/hora de término ao finalizar APENAS se ainda não estiver preenchido
      // (pode ter sido editado manualmente na primeira tela)
      String? dataHoraTermino;
      if (widget.ficha.dataHoraTermino == null || widget.ficha.dataHoraTermino!.isEmpty) {
        final agora = DateTime.now();
        dataHoraTermino = DateFormat('dd/MM/yyyy HH:mm').format(agora);
      } else {
        // Preservar o valor já existente (pode ter sido editado manualmente)
        dataHoraTermino = widget.ficha.dataHoraTermino;
      }

      final fichaAtualizada = widget.ficha.copyWith(
        dano: dano,
        dataHoraTermino: dataHoraTermino,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
        localFurto: widget.ficha.localFurto,
        evidenciasFurto: widget.ficha.evidenciasFurto,
        modusOperandi: widget.ficha.modusOperandi,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados de dano salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Retornar true para atualizar lista
        Navigator.of(context).pop(true);
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

  Widget _buildSimNaoRow({
    required String pergunta,
    required bool? simValue,
    required bool? naoValue,
    required Function(bool?) onSimChanged,
    required Function(bool?) onNaoChanged,
    Widget? campoCondicional,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pergunta,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: simValue ?? false,
                  onChanged: (value) {
                    onSimChanged(value);
                    if (value == true) {
                      onNaoChanged(false);
                    }
                  },
                ),
                const Flexible(child: Text('Sim', style: TextStyle(fontSize: 12))),
                const SizedBox(width: 16),
                Checkbox(
                  value: naoValue ?? false,
                  onChanged: (value) {
                    onNaoChanged(value);
                    if (value == true) {
                      onSimChanged(false);
                    }
                  },
                ),
                const Flexible(child: Text('Não', style: TextStyle(fontSize: 12))),
              ],
            ),
            if (campoCondicional != null && (simValue ?? false)) ...[
              const SizedBox(height: 12),
              campoCondicional,
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
        title: const Text('Investigação de Dano'),
        centerTitle: true,
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
                'ESPECÍFICO PARA INVESTIGAÇÕES DE DANO (ART. 163 – CP/1940)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Substância inflamável ou explosiva
                  _buildSimNaoRow(
                    pergunta: 'Houve o emprego de substância inflamável ou explosiva?',
                    simValue: _substanciaInflamavelExplosivaSim,
                    naoValue: _substanciaInflamavelExplosivaNao,
                    onSimChanged: (value) {
                      setState(() {
                        _substanciaInflamavelExplosivaSim = value;
                        if (value == true) {
                          _substanciaInflamavelExplosivaNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _substanciaInflamavelExplosivaNao = value;
                        if (value == true) {
                          _substanciaInflamavelExplosivaSim = false;
                        }
                      });
                    },
                  ),

                  // 2. Dano contra patrimônio público
                  _buildSimNaoRow(
                    pergunta: 'O dano foi contra o patrimônio da União, Estado, Município, empresa concessionária de serviços públicos ou sociedade de economia mista?',
                    simValue: _danoPatrimonioPublicoSim,
                    naoValue: _danoPatrimonioPublicoNao,
                    onSimChanged: (value) {
                      setState(() {
                        _danoPatrimonioPublicoSim = value;
                        if (value == true) {
                          _danoPatrimonioPublicoNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _danoPatrimonioPublicoNao = value;
                        if (value == true) {
                          _danoPatrimonioPublicoSim = false;
                        }
                      });
                    },
                  ),

                  // 3. Prejuízo considerável
                  _buildSimNaoRow(
                    pergunta: 'Houve prejuízo considerável para a vítima?',
                    simValue: _prejuizoConsideravelSim,
                    naoValue: _prejuizoConsideravelNao,
                    onSimChanged: (value) {
                      setState(() {
                        _prejuizoConsideravelSim = value;
                        if (value == true) {
                          _prejuizoConsideravelNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _prejuizoConsideravelNao = value;
                        if (value == true) {
                          _prejuizoConsideravelSim = false;
                        }
                      });
                    },
                  ),

                  // 4. Identificar instrumento/substância
                  _buildSimNaoRow(
                    pergunta: 'É possível identificar o instrumento e/ou substância empregados no evento? Qual?',
                    simValue: _identificarInstrumentoSubstanciaSim,
                    naoValue: _identificarInstrumentoSubstanciaNao,
                    onSimChanged: (value) {
                      setState(() {
                        _identificarInstrumentoSubstanciaSim = value;
                        if (value == true) {
                          _identificarInstrumentoSubstanciaNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _identificarInstrumentoSubstanciaNao = value;
                        if (value == true) {
                          _identificarInstrumentoSubstanciaSim = false;
                        }
                      });
                    },
                    campoCondicional: TextFormField(
                      controller: _qualInstrumentoSubstanciaController,
                      decoration: const InputDecoration(
                        labelText: 'Qual?',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ),

                  // 5. Identificação de vestígio
                  _buildSimNaoRow(
                    pergunta: 'O local examinado possibilitou a identificação de algum vestígio? Em caso positivo, qual?',
                    simValue: _identificacaoVestigioSim,
                    naoValue: _identificacaoVestigioNao,
                    onSimChanged: (value) {
                      setState(() {
                        _identificacaoVestigioSim = value;
                        if (value == true) {
                          _identificacaoVestigioNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _identificacaoVestigioNao = value;
                        if (value == true) {
                          _identificacaoVestigioSim = false;
                        }
                      });
                    },
                    campoCondicional: TextFormField(
                      controller: _qualVestigioController,
                      decoration: const InputDecoration(
                        labelText: 'Em caso positivo, qual?',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ),

                  // 6. Dano causado e valor estimado
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Qual foi o dano causado e qual é o valor estimado dos prejuízos (reposição ou reparação do bem danificado)?',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _danoCausadoController,
                            decoration: const InputDecoration(
                              labelText: 'Dano causado',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _valorEstimadoController,
                            decoration: const InputDecoration(
                              labelText: 'R\$: Valor estimado',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixText: 'R\$ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. Número de pessoas
                  _buildSimNaoRow(
                    pergunta: 'É possível identificar o número de pessoas que participaram do evento?',
                    simValue: _identificarNumeroPessoasSim,
                    naoValue: _identificarNumeroPessoasNao,
                    onSimChanged: (value) {
                      setState(() {
                        _identificarNumeroPessoasSim = value;
                        if (value == true) {
                          _identificarNumeroPessoasNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _identificarNumeroPessoasNao = value;
                        if (value == true) {
                          _identificarNumeroPessoasSim = false;
                        }
                      });
                    },
                    campoCondicional: TextFormField(
                      controller: _numeroPessoasController,
                      decoration: const InputDecoration(
                        labelText: 'Número de pessoas',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),

                  // 8. Vestígios de autoria
                  _buildSimNaoRow(
                    pergunta: 'Existem vestígios no local que possam indicar a autoria do delito? Caso positivo, quais?',
                    simValue: _vestigiosAutoriaSim,
                    naoValue: _vestigiosAutoriaNao,
                    onSimChanged: (value) {
                      setState(() {
                        _vestigiosAutoriaSim = value;
                        if (value == true) {
                          _vestigiosAutoriaNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _vestigiosAutoriaNao = value;
                        if (value == true) {
                          _vestigiosAutoriaSim = false;
                        }
                      });
                    },
                    campoCondicional: TextFormField(
                      controller: _quaisVestigiosAutoriaController,
                      decoration: const InputDecoration(
                        labelText: 'Caso positivo, quais?',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ),

                  // 9. Dinâmica do evento
                  _buildSimNaoRow(
                    pergunta: 'É possível identificar como foi a dinâmica do evento?',
                    simValue: _identificarDinamicaSim,
                    naoValue: _identificarDinamicaNao,
                    onSimChanged: (value) {
                      setState(() {
                        _identificarDinamicaSim = value;
                        if (value == true) {
                          _identificarDinamicaNao = false;
                        }
                      });
                    },
                    onNaoChanged: (value) {
                      setState(() {
                        _identificarDinamicaNao = value;
                        if (value == true) {
                          _identificarDinamicaSim = false;
                        }
                      });
                    },
                    campoCondicional: TextFormField(
                      controller: _dinamicaEventoController,
                      decoration: const InputDecoration(
                        labelText: 'Dinâmica do evento',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarDano,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Salvar e Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}

