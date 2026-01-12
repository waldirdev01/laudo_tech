import 'package:flutter/material.dart';

import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'preservacao_screen.dart';

class IsolamentoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const IsolamentoScreen({super.key, required this.ficha});

  @override
  State<IsolamentoScreen> createState() => _IsolamentoScreenState();
}

class _IsolamentoScreenState extends State<IsolamentoScreen> {
  final _fichaService = FichaService();
  final _observacoesController = TextEditingController();
  bool _salvando = false;

  // Estados dos checkboxes
  bool? _isolamentoSim;
  bool? _isolamentoNao;
  bool? _isolamentoTotal;
  bool? _isolamentoParcial;
  bool _isolamentoViatura = false;
  bool _isolamentoCones = false;
  bool _isolamentoFitaZebrada = false;
  bool _isolamentoPresencaFisica = false;
  bool _isolamentoOutros = false;
  final _outrosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.dadosFichaBase;
    if (dados != null) {
      _isolamentoSim = dados.isolamentoSim;
      _isolamentoNao = dados.isolamentoNao;
      _isolamentoTotal = dados.isolamentoTotal;
      _isolamentoParcial = dados.isolamentoParcial;
      _isolamentoViatura = dados.isolamentoViatura ?? false;
      _isolamentoCones = dados.isolamentoCones ?? false;
      _isolamentoFitaZebrada = dados.isolamentoFitaZebrada ?? false;
      _isolamentoPresencaFisica = dados.isolamentoPresencaFisica ?? false;
      _observacoesController.text = dados.isolamentoObservacoes ?? '';

      // Verificar se tem "outros" marcado (pode ser inferido se não tem nenhum dos outros)
      // Por enquanto, vamos deixar false e o usuário pode marcar novamente
    }
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    _outrosController.dispose();
    super.dispose();
  }

  void _onSimChanged(bool? value) {
    setState(() {
      _isolamentoSim = value == true;
      _isolamentoNao = value == false ? true : false;
      if (value != true) {
        _isolamentoTotal = false;
        _isolamentoParcial = false;
      }
    });
  }

  void _onNaoChanged(bool? value) {
    setState(() {
      _isolamentoNao = value == true;
      _isolamentoSim = value == false ? true : false;
      if (value == true) {
        _isolamentoTotal = false;
        _isolamentoParcial = false;
      }
    });
  }

  Future<void> _salvarIsolamento() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Criar ou atualizar dados da ficha base
      final fichaBase =
          widget.ficha.dadosFichaBase?.copyWith(
            historico: widget.ficha.dadosFichaBase?.historico,
            isolamentoSim: _isolamentoSim,
            isolamentoNao: _isolamentoNao,
            isolamentoTotal: _isolamentoTotal,
            isolamentoParcial: _isolamentoParcial,
            isolamentoViatura: _isolamentoViatura,
            isolamentoCones: _isolamentoCones,
            isolamentoFitaZebrada: _isolamentoFitaZebrada,
            isolamentoPresencaFisica: _isolamentoPresencaFisica,
            // Outros campos de isolamento que podem existir no modelo
            isolamentoCuriososVoltaCorpo:
                widget.ficha.dadosFichaBase?.isolamentoCuriososVoltaCorpo,
            isolamentoCorpoCobertoMovimentado:
                widget.ficha.dadosFichaBase?.isolamentoCorpoCobertoMovimentado,
            isolamentoDocumentosManuseados:
                widget.ficha.dadosFichaBase?.isolamentoDocumentosManuseados,
            isolamentoVestigiosRecolhidos:
                widget.ficha.dadosFichaBase?.isolamentoVestigiosRecolhidos,
            isolamentoAmpliacaoPerimetro:
                widget.ficha.dadosFichaBase?.isolamentoAmpliacaoPerimetro,
            isolamentoObservacoes: _observacoesController.text.trim().isEmpty
                ? null
                : _observacoesController.text.trim(),
          ) ??
          FichaBaseModel(
            historico: widget.ficha.dadosFichaBase?.historico,
            isolamentoSim: _isolamentoSim,
            isolamentoNao: _isolamentoNao,
            isolamentoTotal: _isolamentoTotal,
            isolamentoParcial: _isolamentoParcial,
            isolamentoViatura: _isolamentoViatura,
            isolamentoCones: _isolamentoCones,
            isolamentoFitaZebrada: _isolamentoFitaZebrada,
            isolamentoPresencaFisica: _isolamentoPresencaFisica,
            isolamentoObservacoes: _observacoesController.text.trim().isEmpty
                ? null
                : _observacoesController.text.trim(),
          );

      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        dadosFichaBase: fichaBase,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Isolamento salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para preservação
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => PreservacaoScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou da preservação, retornar true para atualizar lista
        if (!mounted) return;
        if (resultado == true) {
          navigator.pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Isolamento'), centerTitle: true),
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
                'ISOLAMENTO',
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
                  // Linha 1: Sim/Não e Total/Parcial
                  Row(
                    children: [
                      // Lado esquerdo: Sim/Não
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isolamentoSim ?? false,
                                onChanged: (value) => _onSimChanged(value),
                              ),
                              const Flexible(child: Text('Sim')),
                              const SizedBox(width: 8),
                              Checkbox(
                                value: _isolamentoNao ?? false,
                                onChanged: (value) => _onNaoChanged(value),
                              ),
                              const Flexible(child: Text('Não')),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.grey.shade300,
                      ),
                      // Lado direito: Total/Parcial
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Se sim:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isolamentoTotal ?? false,
                                    onChanged: _isolamentoSim == true
                                        ? (value) {
                                            setState(() {
                                              _isolamentoTotal = value ?? false;
                                              if (value == true) {
                                                _isolamentoParcial = false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  const Flexible(child: Text('Total')),
                                  const SizedBox(width: 8),
                                  Checkbox(
                                    value: _isolamentoParcial ?? false,
                                    onChanged: _isolamentoSim == true
                                        ? (value) {
                                            setState(() {
                                              _isolamentoParcial =
                                                  value ?? false;
                                              if (value == true) {
                                                _isolamentoTotal = false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  const Flexible(child: Text('Parcial')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  // Linha 2: Meios utilizados e observações
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meios utilizados e observações:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        // Checkboxes dos meios
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Presença física'),
                              value: _isolamentoPresencaFisica,
                              onChanged: (value) {
                                setState(() {
                                  _isolamentoPresencaFisica = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Viatura'),
                              value: _isolamentoViatura,
                              onChanged: (value) {
                                setState(() {
                                  _isolamentoViatura = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Cone'),
                              value: _isolamentoCones,
                              onChanged: (value) {
                                setState(() {
                                  _isolamentoCones = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Fita zebrada'),
                              value: _isolamentoFitaZebrada,
                              onChanged: (value) {
                                setState(() {
                                  _isolamentoFitaZebrada = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Outros'),
                              value: _isolamentoOutros,
                              onChanged: (value) {
                                setState(() {
                                  _isolamentoOutros = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                        // Campo de texto para "Outros"
                        if (_isolamentoOutros) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _outrosController,
                            decoration: const InputDecoration(
                              hintText: 'Especifique outros meios utilizados',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 2,
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Campo de observações
                        TextFormField(
                          controller: _observacoesController,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            hintText: 'Digite observações adicionais...',
                            border: OutlineInputBorder(),
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
              onPressed: _salvando ? null : _salvarIsolamento,
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
            const SizedBox(height: 80), // Padding extra no final para garantir que o botão fique visível
          ],
        ),
      ),
    );
  }
}
