import 'package:flutter/material.dart';
import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'condicoes_observacoes_screen.dart';

class PreservacaoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const PreservacaoScreen({super.key, required this.ficha});

  @override
  State<PreservacaoScreen> createState() => _PreservacaoScreenState();
}

class _PreservacaoScreenState extends State<PreservacaoScreen> {
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
      _preservacaoCuriososNoPerimetro = dados.preservacaoCuriososNoPerimetro ?? false;
      _pessoasAcessaramController.text = dados.preservacaoPessoasAcessaram ?? '';
      _alteracoesDetectadasController.text = dados.preservacaoAlteracoesDetectadas ?? '';
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
      final fichaBaseAtualizada = (widget.ficha.dadosFichaBase ?? FichaBaseModel()).copyWith(
        // Preservar histórico e isolamento
        historico: widget.ficha.dadosFichaBase?.historico,
        isolamentoSim: widget.ficha.dadosFichaBase?.isolamentoSim,
        isolamentoNao: widget.ficha.dadosFichaBase?.isolamentoNao,
        isolamentoTotal: widget.ficha.dadosFichaBase?.isolamentoTotal,
        isolamentoParcial: widget.ficha.dadosFichaBase?.isolamentoParcial,
        isolamentoViatura: widget.ficha.dadosFichaBase?.isolamentoViatura,
        isolamentoCones: widget.ficha.dadosFichaBase?.isolamentoCones,
        isolamentoFitaZebrada: widget.ficha.dadosFichaBase?.isolamentoFitaZebrada,
        isolamentoPresencaFisica: widget.ficha.dadosFichaBase?.isolamentoPresencaFisica,
        isolamentoCuriososVoltaCorpo: widget.ficha.dadosFichaBase?.isolamentoCuriososVoltaCorpo,
        isolamentoCorpoCobertoMovimentado: widget.ficha.dadosFichaBase?.isolamentoCorpoCobertoMovimentado,
        isolamentoDocumentosManuseados: widget.ficha.dadosFichaBase?.isolamentoDocumentosManuseados,
        isolamentoVestigiosRecolhidos: widget.ficha.dadosFichaBase?.isolamentoVestigiosRecolhidos,
        isolamentoAmpliacaoPerimetro: widget.ficha.dadosFichaBase?.isolamentoAmpliacaoPerimetro,
        isolamentoObservacoes: widget.ficha.dadosFichaBase?.isolamentoObservacoes,
        // Dados de preservação
        preservacaoSim: _preservacaoSim,
        preservacaoNao: _preservacaoNao,
        preservacaoInidoneo: _preservacaoInidoneo,
        preservacaoParcialmenteIdoneo: _preservacaoParcialmenteIdoneo,
        preservacaoCuriososNoPerimetro: _preservacaoCuriososNoPerimetro,
        preservacaoPessoasAcessaram: _pessoasAcessaramController.text.trim().isEmpty
            ? null
            : _pessoasAcessaramController.text.trim(),
        preservacaoAlteracoesDetectadas: _alteracoesDetectadasController.text.trim().isEmpty
            ? null
            : _alteracoesDetectadasController.text.trim(),
        // Preservar condições meteorológicas e demais observações
        condicoesEstavel: widget.ficha.dadosFichaBase?.condicoesEstavel,
        condicoesNublado: widget.ficha.dadosFichaBase?.condicoesNublado,
        condicoesParcialmenteNublado: widget.ficha.dadosFichaBase?.condicoesParcialmenteNublado,
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
            content: Text('Preservação salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para condições ambientais
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => CondicoesObservacoesScreen(ficha: fichaAtualizada),
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
        title: const Text('Preservação'),
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
                                  style: TextStyle(fontWeight: FontWeight.w500),
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
                                                  _preservacaoParcialmenteIdoneo = false;
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                    const Flexible(child: Text('Inidôneo')),
                                    const SizedBox(width: 16),
                                    Checkbox(
                                      value: _preservacaoParcialmenteIdoneo ?? false,
                                      onChanged: (_preservacaoNao ?? false)
                                          ? (value) {
                                              setState(() {
                                                _preservacaoParcialmenteIdoneo = value;
                                                if (value == true) {
                                                  _preservacaoInidoneo = false;
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                    const Flexible(child: Text('Parcialmente Idôneo')),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Curiosos no perímetro:',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        Checkbox(
                          value: _preservacaoCuriososNoPerimetro,
                          onChanged: (value) {
                            setState(() {
                              _preservacaoCuriososNoPerimetro = value ?? false;
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
                          'Pessoas que acessaram:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pessoasAcessaramController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva as pessoas que acessaram o local',
                            border: OutlineInputBorder(),
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
                          'Alterações observadas:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _alteracoesDetectadasController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva as alterações detectadas no local',
                            border: OutlineInputBorder(),
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
          ],
        ),
      ),
    );
  }
}

