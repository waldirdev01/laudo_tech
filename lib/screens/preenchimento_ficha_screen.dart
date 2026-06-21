import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ficha_completa_model.dart';
import '../models/solicitacao_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import '../services/pdf_extraction_service.dart';
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

  final _fichaService = FichaService();
  final _pdfService = PdfExtractionService();
  late final String _fichaId;
  bool _salvando = false;

  /// Quando a requisição é importada por PDF numa ficha já existente
  SolicitacaoModel? _solicitacaoImportada;

  SolicitacaoModel get _dadosSolicitacaoEfetivos =>
      _solicitacaoImportada ??
      widget.fichaExistente?.dadosSolicitacao ??
      widget.dadosSolicitacao;

  @override
  void initState() {
    super.initState();
    // Se está editando, usar ID existente. Senão, criar novo
    _fichaId = widget.fichaExistente?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Se está editando, preencher campos da ficha existente
    if (widget.fichaExistente != null) {
      _dataHoraDeslocamentoController.text =
          widget.fichaExistente!.dataHoraDeslocamento ?? '';
      _dataHoraInicioController.text =
          widget.fichaExistente!.dataHoraInicio ?? '';
      _dataHoraTerminoController.text =
          widget.fichaExistente!.dataHoraTermino ?? '';
    } else {
      // Se é uma nova ficha, preencher com dados extraídos do PDF (se disponíveis)
      _dataHoraDeslocamentoController.text =
          _dadosSolicitacaoEfetivos.dataHoraDeslocamento ?? '';
      _dataHoraInicioController.text =
          _dadosSolicitacaoEfetivos.dataHoraInicio ?? '';
      _dataHoraTerminoController.text =
          _dadosSolicitacaoEfetivos.dataHoraTermino ?? '';
    }

    // Debug: verificar dados recebidos
  }

  @override
  void dispose() {
    _dataHoraDeslocamentoController.dispose();
    _dataHoraInicioController.dispose();
    _dataHoraTerminoController.dispose();
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
      final ficha = widget.fichaExistente?.copyWith(
            dadosSolicitacao: _dadosSolicitacaoEfetivos,
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
            dataUltimaAtualizacao: DateTime.now(),
          ) ??
          FichaCompletaModel(
            id: _fichaId,
            tipoOcorrencia: widget.tipoOcorrencia,
            dadosSolicitacao: _dadosSolicitacaoEfetivos,
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

  Future<void> _importarRequisicaoPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null ||
          result.files.isEmpty ||
          result.files.single.bytes == null) {
        return;
      }
      final bytes = result.files.single.bytes!;
      setState(() => _salvando = true);
      final dados = await _pdfService.extrairDadosSolicitacaoBytesAsync(bytes);
      if (!mounted) return;
      setState(() {
        _solicitacaoImportada = dados;
        // Preservar dados já preenchidos pelo usuário; preencher só o que estiver vazio
        if (_dataHoraDeslocamentoController.text.trim().isEmpty) {
          _dataHoraDeslocamentoController.text =
              dados.dataHoraDeslocamento ?? '';
        }
        if (_dataHoraInicioController.text.trim().isEmpty) {
          _dataHoraInicioController.text = dados.dataHoraInicio ?? '';
        }
        if (_dataHoraTerminoController.text.trim().isEmpty) {
          _dataHoraTerminoController.text = dados.dataHoraTermino ?? '';
        }
        _salvando = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Requisição importada do PDF. Revise os campos e salve se necessário.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preencher Ficha'),
        centerTitle: true,
        actions: [
          if (widget.fichaExistente != null)
            IconButton(
              onPressed: _salvando ? null : _importarRequisicaoPdf,
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importar requisição (PDF)',
            ),
        ],
      ),
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
                        _dadosSolicitacaoEfetivos.raiNumero ?? '',
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
                        _dadosSolicitacaoEfetivos.naturezaOcorrencia ??
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
                        _dadosSolicitacaoEfetivos.dataHoraComunicacao ?? '',
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
                        _dadosSolicitacaoEfetivos.unidadeOrigem ?? '',
                        isReadOnly: true,
                      ),
                      _buildTableCell(
                        'Número da Ocorrência:',
                        _dadosSolicitacaoEfetivos.numeroOcorrencia ?? '',
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
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dadosSolicitacaoEfetivos.unidadeAfeta?.isEmpty ??
                                    true
                                ? '-'
                                : _dadosSolicitacaoEfetivos.unidadeAfeta!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
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
              const SizedBox(
                height: 80,
              ), // Padding extra no final para garantir que o botão fique visível
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
