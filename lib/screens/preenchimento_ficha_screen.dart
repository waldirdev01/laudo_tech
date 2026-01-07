import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ficha_completa_model.dart';
import '../models/solicitacao_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import 'selecao_equipe_screen.dart';

class PreenchimentoFichaScreen extends StatefulWidget {
  final TipoOcorrencia tipoOcorrencia;
  final SolicitacaoModel dadosSolicitacao;
  final FichaCompletaModel? fichaExistente; // Para edição

  const PreenchimentoFichaScreen({
    super.key,
    required this.tipoOcorrencia,
    required this.dadosSolicitacao,
    this.fichaExistente,
  });

  @override
  State<PreenchimentoFichaScreen> createState() =>
      _PreenchimentoFichaScreenState();
}

class _PreenchimentoFichaScreenState extends State<PreenchimentoFichaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataHoraDeslocamentoController = TextEditingController();
  final _dataHoraInicioController = TextEditingController();
  final _dataHoraTerminoController = TextEditingController();
  final _pedidoDilacaoController = TextEditingController();

  final _fichaService = FichaService();
  late final String _fichaId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Se está editando, usar ID existente. Senão, criar novo
    _fichaId =
        widget.fichaExistente?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Se está editando, preencher campos
    if (widget.fichaExistente != null) {
      _dataHoraDeslocamentoController.text =
          widget.fichaExistente!.dataHoraDeslocamento ?? '';
      _dataHoraInicioController.text =
          widget.fichaExistente!.dataHoraInicio ?? '';
      _dataHoraTerminoController.text =
          widget.fichaExistente!.dataHoraTermino ?? '';
      _pedidoDilacaoController.text =
          widget.fichaExistente!.pedidoDilacao ?? '';
    }
    
    // Debug: verificar dados recebidos
    print('Dados recebidos na tela de preenchimento:');
    print('RAI: ${widget.dadosSolicitacao.raiNumero}');
    print('Data/Hora Comunicação: ${widget.dadosSolicitacao.dataHoraComunicacao}');
    print('Natureza: ${widget.dadosSolicitacao.naturezaOcorrencia}');
    print('Município: ${widget.dadosSolicitacao.municipio}');
    print('Endereço: ${widget.dadosSolicitacao.endereco}');
  }

  @override
  void dispose() {
    _dataHoraDeslocamentoController.dispose();
    _dataHoraInicioController.dispose();
    _dataHoraTerminoController.dispose();
    _pedidoDilacaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataHora(TextEditingController controller) async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (data != null && mounted) {
      final TimeOfDay? hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (hora != null && mounted) {
        final dataHora = DateTime(
          data.year,
          data.month,
          data.day,
          hora.hour,
          hora.minute,
        );
        final formatado = DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
        controller.text = formatado;
      }
    }
  }

  Future<void> _salvarFicha() async {
    // Validar apenas campos obrigatórios (Data/Hora Término é opcional)
    if (_dataHoraDeslocamentoController.text.trim().isEmpty ||
        _dataHoraInicioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha Data/Hora Deslocamento e Início'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      // Se está editando, preservar dados existentes (equipe, equipes policiais, etc.)
      final ficha =
          widget.fichaExistente?.copyWith(
            dataHoraDeslocamento:
                _dataHoraDeslocamentoController.text.trim().isEmpty
                ? null
                : _dataHoraDeslocamentoController.text.trim(),
            dataHoraInicio: _dataHoraInicioController.text.trim().isEmpty
                ? null
                : _dataHoraInicioController.text.trim(),
            dataHoraTermino: _dataHoraTerminoController.text.trim().isEmpty
                ? null
                : _dataHoraTerminoController.text
                      .trim(), // Pode ficar em branco
            pedidoDilacao: _pedidoDilacaoController.text.trim().isEmpty
                ? null
                : _pedidoDilacaoController.text.trim(),
            dataUltimaAtualizacao: DateTime.now(),
          ) ??
          FichaCompletaModel(
            id: _fichaId,
            tipoOcorrencia: widget.tipoOcorrencia,
            dadosSolicitacao: widget.dadosSolicitacao,
            dataHoraDeslocamento:
                _dataHoraDeslocamentoController.text.trim().isEmpty
                ? null
                : _dataHoraDeslocamentoController.text.trim(),
            dataHoraInicio: _dataHoraInicioController.text.trim().isEmpty
                ? null
                : _dataHoraInicioController.text.trim(),
            dataHoraTermino: _dataHoraTerminoController.text.trim().isEmpty
                ? null
                : _dataHoraTerminoController.text
                      .trim(), // Pode ficar em branco
            pedidoDilacao: _pedidoDilacaoController.text.trim().isEmpty
                ? null
                : _pedidoDilacaoController.text.trim(),
            dadosFichaBase: null, // Será preenchido nas próximas telas
            dataCriacao: DateTime.now(),
            dataUltimaAtualizacao: DateTime.now(),
          );

      await _fichaService.salvarFicha(ficha);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ficha salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para seleção de equipe
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => SelecaoEquipeScreen(ficha: ficha),
          ),
        );

        // Se voltou da seleção de equipe, retornar true para atualizar lista
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
      appBar: AppBar(title: const Text('Preencher Ficha'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título da seção SOLICITAÇÃO
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
                  'SOLICITAÇÃO (Preenchimento Obrigatório)',
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
                    // Linha 1: RAI e Data/Hora Deslocamento
                    _buildTableRow([
                      _buildTableCell(
                        'RAI n.:',
                        widget.dadosSolicitacao.raiNumero ?? '',
                        isReadOnly: true,
                      ),
                      _buildTableCellEditavel(
                        'Data/Hora Deslocamento:',
                        _dataHoraDeslocamentoController,
                        onTap: () => _selecionarDataHora(
                          _dataHoraDeslocamentoController,
                        ),
                      ),
                    ]),
                    const Divider(height: 1),
                    // Linha 2: Natureza e Data/Hora Início
                    _buildTableRow([
                      _buildTableCell(
                        'Nat. da Ocorrência:',
                        widget.dadosSolicitacao.naturezaOcorrencia ??
                            widget.tipoOcorrencia.label,
                        isReadOnly: true,
                      ),
                      _buildTableCellEditavel(
                        'Data/Hora Início:',
                        _dataHoraInicioController,
                        onTap: () =>
                            _selecionarDataHora(_dataHoraInicioController),
                      ),
                    ]),
                    const Divider(height: 1),
                    // Linha 3: Data/Hora Comunicação e Data/Hora Término
                    _buildTableRow([
                      _buildTableCell(
                        'Data/Hora Comunicação:',
                        widget.dadosSolicitacao.dataHoraComunicacao ?? '',
                        isReadOnly: true,
                      ),
                      _buildTableCellEditavel(
                        'Data/Hora Término:',
                        _dataHoraTerminoController,
                        onTap: () =>
                            _selecionarDataHora(_dataHoraTerminoController),
                      ),
                    ]),
                    const Divider(height: 1),
                    // Linha 4: Unidade Requisitante e Número da Ocorrência
                    _buildTableRow([
                      _buildTableCell(
                        'Unidade Requisitante:',
                        widget.dadosSolicitacao.unidadeOrigem ?? '',
                        isReadOnly: true,
                      ),
                      _buildTableCell(
                        'Número da Ocorrência:',
                        widget.dadosSolicitacao.numeroOcorrencia ?? '',
                        isReadOnly: true,
                      ),
                    ]),
                    const Divider(height: 1),
                    // Linha 5: Unidade Afeta (largura total)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unidade Afeta:',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.dadosSolicitacao.unidadeAfeta?.isEmpty ?? true
                                ? '-'
                                : widget.dadosSolicitacao.unidadeAfeta!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Linha 6: Pedido de Dilação (largura total)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido de Dilação (se houver, informar n. do Processo SEI):',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pedidoDilacaoController,
                            decoration: const InputDecoration(
                              hintText: 'Número do Processo SEI',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _salvando ? null : _salvarFicha,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Salvar e Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(List<Widget> cells) {
    return Row(
      children: [
        Expanded(child: cells[0]),
        Container(width: 1, height: 60, color: Colors.grey.shade300),
        Expanded(child: cells.length > 1 ? cells[1] : const SizedBox()),
      ],
    );
  }

  Widget _buildTableCell(
    String label,
    String value, {
    bool isReadOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          if (isReadOnly)
            Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            )
          else
            Text(
              value.isEmpty ? '___ / ___ / ___ : ___' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildTableCellEditavel(
    String label,
    TextEditingController controller, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: IgnorePointer(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '___ / ___ / ___ : ___',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
