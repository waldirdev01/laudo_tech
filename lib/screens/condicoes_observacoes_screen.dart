import 'package:flutter/material.dart';

import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import 'detalhes_local_screen.dart';

class CondicoesObservacoesScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const CondicoesObservacoesScreen({super.key, required this.ficha});

  @override
  State<CondicoesObservacoesScreen> createState() =>
      _CondicoesObservacoesScreenState();
}

class _CondicoesObservacoesScreenState
    extends State<CondicoesObservacoesScreen> {
  final _fichaService = FichaService();
  final _demaisObservacoesController = TextEditingController();
  bool _salvando = false;

  // Estados dos checkboxes de condições meteorológicas
  bool _condicoesEstavel = false;
  bool _condicoesNublado = false;
  bool _condicoesParcialmenteNublado = false;
  bool _condicoesChuvoso = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.dadosFichaBase;
    if (dados != null) {
      _condicoesEstavel = dados.condicoesEstavel ?? false;
      _condicoesNublado = dados.condicoesNublado ?? false;
      _condicoesParcialmenteNublado =
          dados.condicoesParcialmenteNublado ?? false;
      _condicoesChuvoso = dados.condicoesChuvoso ?? false;
      _demaisObservacoesController.text = dados.demaisObservacoes ?? '';
    }
  }

  @override
  void dispose() {
    _demaisObservacoesController.dispose();
    super.dispose();
  }

  void _onCondicaoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'estavel':
          _condicoesEstavel = value ?? false;
          if (value == true) {
            _condicoesNublado = false;
            _condicoesParcialmenteNublado = false;
            _condicoesChuvoso = false;
          }
          break;
        case 'nublado':
          _condicoesNublado = value ?? false;
          if (value == true) {
            _condicoesEstavel = false;
            _condicoesParcialmenteNublado = false;
            _condicoesChuvoso = false;
          }
          break;
        case 'parcialmenteNublado':
          _condicoesParcialmenteNublado = value ?? false;
          if (value == true) {
            _condicoesEstavel = false;
            _condicoesNublado = false;
            _condicoesChuvoso = false;
          }
          break;
        case 'chuvoso':
          _condicoesChuvoso = value ?? false;
          if (value == true) {
            _condicoesEstavel = false;
            _condicoesNublado = false;
            _condicoesParcialmenteNublado = false;
          }
          break;
      }
    });
  }

  Future<void> _salvarCondicoesObservacoes() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Criar ou atualizar dados da ficha base
      final fichaBase =
          widget.ficha.dadosFichaBase?.copyWith(
            historico: widget.ficha.dadosFichaBase?.historico,
            // Preservar isolamento
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
            // Preservar preservação
            preservacaoSim: widget.ficha.dadosFichaBase?.preservacaoSim,
            preservacaoNao: widget.ficha.dadosFichaBase?.preservacaoNao,
            preservacaoInidoneo:
                widget.ficha.dadosFichaBase?.preservacaoInidoneo,
            preservacaoParcialmenteIdoneo:
                widget.ficha.dadosFichaBase?.preservacaoParcialmenteIdoneo,
            preservacaoCuriososNoPerimetro:
                widget.ficha.dadosFichaBase?.preservacaoCuriososNoPerimetro,
            preservacaoPessoasAcessaram:
                widget.ficha.dadosFichaBase?.preservacaoPessoasAcessaram,
            preservacaoAlteracoesDetectadas:
                widget.ficha.dadosFichaBase?.preservacaoAlteracoesDetectadas,
            // Atualizar condições meteorológicas
            condicoesEstavel: _condicoesEstavel,
            condicoesNublado: _condicoesNublado,
            condicoesParcialmenteNublado: _condicoesParcialmenteNublado,
            condicoesChuvoso: _condicoesChuvoso,
            // Atualizar demais observações
            demaisObservacoes: _demaisObservacoesController.text.trim().isEmpty
                ? null
                : _demaisObservacoesController.text.trim(),
          ) ??
          FichaBaseModel(
            historico: widget.ficha.dadosFichaBase?.historico,
            condicoesEstavel: _condicoesEstavel,
            condicoesNublado: _condicoesNublado,
            condicoesParcialmenteNublado: _condicoesParcialmenteNublado,
            condicoesChuvoso: _condicoesChuvoso,
            demaisObservacoes: _demaisObservacoesController.text.trim().isEmpty
                ? null
                : _demaisObservacoesController.text.trim(),
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
            content: Text('Dados salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de Local Furto (tela 9) para FURTO/DANO e CVLI
        if (widget.ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
            widget.ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
          if (!mounted) return;
          final resultado = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LocalFurtoScreen(ficha: fichaAtualizada),
            ),
          );

          // Se voltou do local furto, retornar true para atualizar lista
          if (mounted && resultado == true) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Para outros tipos de ocorrência, voltar
          if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condições e Observações'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tabela 1: CONDIÇÕES AMBIENTAIS
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
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
                      'CONDIÇÕES AMBIENTAIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Conteúdo
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Condições Meteorológicas:',
                            style: TextStyle(fontWeight: FontWeight.w500),
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
                                    value: _condicoesEstavel,
                                    onChanged: (value) =>
                                        _onCondicaoChanged(value, 'estavel'),
                                  ),
                                  const Text('Estável'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _condicoesNublado,
                                    onChanged: (value) =>
                                        _onCondicaoChanged(value, 'nublado'),
                                  ),
                                  const Text('Nublado'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _condicoesParcialmenteNublado,
                                    onChanged: (value) => _onCondicaoChanged(
                                      value,
                                      'parcialmenteNublado',
                                    ),
                                  ),
                                  const Text('Parcialmente Nublado'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _condicoesChuvoso,
                                    onChanged: (value) =>
                                        _onCondicaoChanged(value, 'chuvoso'),
                                  ),
                                  const Text('Chuvoso'),
                                ],
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
            // Tabela 2: DEMAIS OBSERVAÇÕES
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
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
                      'DEMAIS OBSERVAÇÕES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Conteúdo
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextFormField(
                        controller: _demaisObservacoesController,
                        decoration: const InputDecoration(
                          hintText: 'Digite observações adicionais...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        maxLines: null,
                        minLines: 6,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _salvando ? null : _salvarCondicoesObservacoes,
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
