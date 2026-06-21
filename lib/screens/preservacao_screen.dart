import 'package:flutter/material.dart';
import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import 'condicoes_observacoes_screen.dart';

class PreservacaoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const PreservacaoScreen({super.key, required this.ficha});

  @override
  State<PreservacaoScreen> createState() => _PreservacaoScreenState();
}

class _PreservacaoScreenState extends State<PreservacaoScreen> {
  static const String _defaultPessoasAcessaram =
      'Não foi possível identificar, com segurança, pessoas que tenham tido acesso ao veículo antes da chegada da perícia.';
  static const String _defaultAlteracoesObservadas =
      'Não foram observadas alterações relevantes no veículo no momento do exame, ressalvadas intervenções previamente informadas e compatíveis com sua guarda ou remoção.';

  final _fichaService = FichaService();
  final _pessoasAcessaramController = TextEditingController();
  final _alteracoesDetectadasController = TextEditingController();
  bool _salvando = false;

  // Estados dos checkboxes
  bool? _preservacaoSim;
  bool? _preservacaoNao;
  bool? _preservacaoInidoneo;
  bool? _preservacaoParcialmenteIdoneo;
  bool _preservacaoCuriososNoPerimetro = false;

  bool get _isVistoriaVeiculo =>
      widget.ficha.tipoOcorrencia == TipoOcorrencia.vistoriaVeiculo;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.dadosFichaBase;
    if (dados != null) {
      _preservacaoSim = dados.preservacaoSim;
      _preservacaoNao = dados.preservacaoNao;
      _preservacaoInidoneo = dados.preservacaoInidoneo;
      _preservacaoParcialmenteIdoneo = dados.preservacaoParcialmenteIdoneo;
      _preservacaoCuriososNoPerimetro =
          dados.preservacaoCuriososNoPerimetro ?? false;
      final pessoasSalvas = dados.preservacaoPessoasAcessaram?.trim();
      _pessoasAcessaramController.text =
          (pessoasSalvas == null || pessoasSalvas.isEmpty)
          ? _defaultPessoasAcessaram
          : pessoasSalvas;
      final alteracoesSalvas = dados.preservacaoAlteracoesDetectadas?.trim();
      _alteracoesDetectadasController.text =
          (alteracoesSalvas == null || alteracoesSalvas.isEmpty)
          ? _defaultAlteracoesObservadas
          : alteracoesSalvas;
    } else {
      _pessoasAcessaramController.text = _defaultPessoasAcessaram;
      _alteracoesDetectadasController.text = _defaultAlteracoesObservadas;
    }
  }

  @override
  void dispose() {
    _pessoasAcessaramController.dispose();
    _alteracoesDetectadasController.dispose();
    super.dispose();
  }

  Future<void> _salvarPreservacao() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Preservar todos os dados existentes
      final fichaBaseAtualizada =
          (widget.ficha.dadosFichaBase ?? FichaBaseModel()).copyWith(
            // Preservar histórico e isolamento
            historico: widget.ficha.dadosFichaBase?.historico,
            isolamentoSim: widget.ficha.dadosFichaBase?.isolamentoSim,
            isolamentoNao: widget.ficha.dadosFichaBase?.isolamentoNao,
            isolamentoTotal: widget.ficha.dadosFichaBase?.isolamentoTotal,
            isolamentoParcial: widget.ficha.dadosFichaBase?.isolamentoParcial,
            isolamentoViatura: widget.ficha.dadosFichaBase?.isolamentoViatura,
            isolamentoCones: widget.ficha.dadosFichaBase?.isolamentoCones,
            isolamentoFitaZebrada:
                widget.ficha.dadosFichaBase?.isolamentoFitaZebrada,
            isolamentoPresencaFisica:
                widget.ficha.dadosFichaBase?.isolamentoPresencaFisica,
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
            isolamentoObservacoes:
                widget.ficha.dadosFichaBase?.isolamentoObservacoes,
            // Dados de preservação
            preservacaoSim: _preservacaoSim,
            preservacaoNao: _preservacaoNao,
            preservacaoInidoneo: _preservacaoInidoneo,
            preservacaoParcialmenteIdoneo: _preservacaoParcialmenteIdoneo,
            preservacaoCuriososNoPerimetro: _preservacaoCuriososNoPerimetro,
            preservacaoPessoasAcessaram:
                _pessoasAcessaramController.text.trim().isEmpty
                ? null
                : _pessoasAcessaramController.text.trim(),
            preservacaoAlteracoesDetectadas:
                _alteracoesDetectadasController.text.trim().isEmpty
                ? null
                : _alteracoesDetectadasController.text.trim(),
            // Preservar condições meteorológicas e demais observações
            condicoesEstavel: widget.ficha.dadosFichaBase?.condicoesEstavel,
            condicoesNublado: widget.ficha.dadosFichaBase?.condicoesNublado,
            condicoesParcialmenteNublado:
                widget.ficha.dadosFichaBase?.condicoesParcialmenteNublado,
            condicoesChuvoso: widget.ficha.dadosFichaBase?.condicoesChuvoso,
            demaisObservacoes: widget.ficha.dadosFichaBase?.demaisObservacoes,
          );

      final fichaAtualizada = widget.ficha.copyWith(
        dadosFichaBase: fichaBaseAtualizada,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        localFurto: widget.ficha.localFurto,
        evidenciasFurto: widget.ficha.evidenciasFurto,
        modusOperandi: widget.ficha.modusOperandi,
        dano: widget.ficha.dano,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados de preservação salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para condições ambientais
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) =>
                CondicoesObservacoesScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou das condições, retornar true para atualizar lista
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
      appBar: AppBar(
        title: Text(
          _isVistoriaVeiculo ? 'Preservação do Veiculo' : 'Preservação',
        ),
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
                'PRESERVAÇÃO',
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
                  // Linha 1: Sim/Não
                  if (_isVistoriaVeiculo)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Foi possível atestar a preservação do veículo desde o fato até a vistoria?',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _preservacaoSim ?? false,
                                    onChanged: (value) {
                                      setState(() {
                                        _preservacaoSim = value;
                                        if (value == true) {
                                          _preservacaoNao = false;
                                        }
                                      });
                                    },
                                  ),
                                  const Text('Sim'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _preservacaoNao ?? false,
                                    onChanged: (value) {
                                      setState(() {
                                        _preservacaoNao = value;
                                        if (value == true) {
                                          _preservacaoSim = false;
                                        }
                                      });
                                    },
                                  ),
                                  const Text('Não'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Se não:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _preservacaoInidoneo ?? false,
                                    onChanged: (_preservacaoNao ?? false)
                                        ? (value) {
                                            setState(() {
                                              _preservacaoInidoneo = value;
                                              if (value == true) {
                                                _preservacaoParcialmenteIdoneo =
                                                    false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  const Text('Inidôneo'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value:
                                        _preservacaoParcialmenteIdoneo ?? false,
                                    onChanged: (_preservacaoNao ?? false)
                                        ? (value) {
                                            setState(() {
                                              _preservacaoParcialmenteIdoneo =
                                                  value;
                                              if (value == true) {
                                                _preservacaoInidoneo = false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  const Text('Parcialmente Idôneo'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _preservacaoSim ?? false,
                                  onChanged: (value) {
                                    setState(() {
                                      _preservacaoSim = value;
                                      if (value == true) {
                                        _preservacaoNao = false;
                                      }
                                    });
                                  },
                                ),
                                const Flexible(child: Text('Sim')),
                                const SizedBox(width: 16),
                                Checkbox(
                                  value: _preservacaoNao ?? false,
                                  onChanged: (value) {
                                    setState(() {
                                      _preservacaoNao = value;
                                      if (value == true) {
                                        _preservacaoSim = false;
                                      }
                                    });
                                  },
                                ),
                                const Flexible(child: Text('Não')),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 48,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Se não:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _preservacaoInidoneo ?? false,
                                        onChanged: (_preservacaoNao ?? false)
                                            ? (value) {
                                                setState(() {
                                                  _preservacaoInidoneo = value;
                                                  if (value == true) {
                                                    _preservacaoParcialmenteIdoneo =
                                                        false;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      const Flexible(child: Text('Inidôneo')),
                                      const SizedBox(width: 16),
                                      Checkbox(
                                        value:
                                            _preservacaoParcialmenteIdoneo ??
                                            false,
                                        onChanged: (_preservacaoNao ?? false)
                                            ? (value) {
                                                setState(() {
                                                  _preservacaoParcialmenteIdoneo =
                                                      value;
                                                  if (value == true) {
                                                    _preservacaoInidoneo =
                                                        false;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      const Flexible(
                                        child: Text('Parcialmente Idôneo'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  // Linha 2: Curiosos no perímetro
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isVistoriaVeiculo
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Veículo permaneceu em local de acesso restrito?',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Checkbox(
                                value: _preservacaoCuriososNoPerimetro,
                                onChanged: (value) {
                                  setState(() {
                                    _preservacaoCuriososNoPerimetro =
                                        value ?? false;
                                  });
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Curiosos no perímetro:',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Checkbox(
                                value: _preservacaoCuriososNoPerimetro,
                                onChanged: (value) {
                                  setState(() {
                                    _preservacaoCuriososNoPerimetro =
                                        value ?? false;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  // Linha 3: Pessoas que acessaram
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVistoriaVeiculo
                              ? 'Pessoas que tiveram acesso ao veículo:'
                              : 'Pessoas que acessaram:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pessoasAcessaramController,
                          decoration: InputDecoration(
                            hintText: _isVistoriaVeiculo
                                ? 'Ex.: vítima, investigador, servidor da delegacia, guincho.'
                                : 'Descreva as pessoas que acessaram o local',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Linha 4: Alterações observadas
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVistoriaVeiculo
                              ? 'Alterações observadas no veículo:'
                              : 'Alterações observadas:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _alteracoesDetectadasController,
                          decoration: InputDecoration(
                            hintText: _isVistoriaVeiculo
                                ? 'Descreva remoções, manuseios, reparos, limpeza ou outras alterações relevantes no veículo.'
                                : 'Descreva as alterações detectadas no local',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarPreservacao,
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
