import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/tipo_ocorrencia.dart';
import '../models/solicitacao_model.dart';
import '../models/pessoa_envolvida_model.dart';
import '../services/pdf_extraction_service.dart';
import 'preenchimento_ficha_screen.dart';

class UploadPdfScreen extends StatefulWidget {
  final TipoOcorrencia tipoOcorrencia;

  const UploadPdfScreen({
    super.key,
    required this.tipoOcorrencia,
  });

  @override
  State<UploadPdfScreen> createState() => _UploadPdfScreenState();
}

class _UploadPdfScreenState extends State<UploadPdfScreen> {
  String? _caminhoPdf;
  bool _processando = false;
  SolicitacaoModel? _dadosExtraidos;
  String? _erro;

  final _pdfService = PdfExtractionService();

  Future<void> _selecionarPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _caminhoPdf = result.files.single.path;
          _dadosExtraidos = null;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  Future<void> _extrairDados() async {
    if (_caminhoPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um arquivo PDF'),
        ),
      );
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
      _dadosExtraidos = null;
    });

    try {
      final dados = await _pdfService.extrairDadosSolicitacao(_caminhoPdf!);
      
      if (mounted) {
        setState(() {
          _dadosExtraidos = dados;
          _processando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados extraídos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de preenchimento da ficha
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreenchimentoFichaScreen(
                tipoOcorrencia: widget.tipoOcorrencia,
                dadosSolicitacao: dados,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _processando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao extrair dados: $e'),
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
        title: const Text('Upload de Solicitação'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Tipo de Ocorrência:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.tipoOcorrencia.label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'PDF de Solicitação de Perícia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione o arquivo PDF da solicitação de perícia para extrair os dados automaticamente',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _processando ? null : _selecionarPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('Selecionar PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            if (_caminhoPdf != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _caminhoPdf!.split('/').last,
                        style: TextStyle(color: Colors.blue.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _processando ? null : _extrairDados,
                icon: _processando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_processando ? 'Processando...' : 'Extrair Dados'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
            if (_processando) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Extraindo dados do PDF...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _erro!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_dadosExtraidos != null) ...[
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dados Extraídos',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      // SOLICITAÇÃO
                      if (_dadosExtraidos!.raiNumero != null ||
                          _dadosExtraidos!.numeroOcorrencia != null ||
                          _dadosExtraidos!.naturezaOcorrencia != null ||
                          _dadosExtraidos!.dataHoraComunicacao != null) ...[
                        _buildSectionTitle('SOLICITAÇÃO'),
                        const SizedBox(height: 8),
                        if (_dadosExtraidos!.raiNumero != null)
                          _buildInfoRow('RAI:', _dadosExtraidos!.raiNumero!),
                        if (_dadosExtraidos!.numeroOcorrencia != null)
                          _buildInfoRow('Ocorrência nº:', _dadosExtraidos!.numeroOcorrencia!),
                        if (_dadosExtraidos!.naturezaOcorrencia != null)
                          _buildInfoRow('Natureza:', _dadosExtraidos!.naturezaOcorrencia!),
                        if (_dadosExtraidos!.dataHoraComunicacao != null)
                          _buildInfoRow('Data/Hora Comunicação:', _dadosExtraidos!.dataHoraComunicacao!),
                        const SizedBox(height: 16),
                      ],
                      // UNIDADES
                      if (_dadosExtraidos!.unidadeOrigem != null ||
                          _dadosExtraidos!.unidadeAfeta != null) ...[
                        _buildSectionTitle('UNIDADES'),
                        const SizedBox(height: 8),
                        if (_dadosExtraidos!.unidadeOrigem != null)
                          _buildInfoRow('Unidade Requisitante:', _dadosExtraidos!.unidadeOrigem!),
                        if (_dadosExtraidos!.unidadeAfeta != null)
                          _buildInfoRow('Unidade Afeta:', _dadosExtraidos!.unidadeAfeta!),
                        const SizedBox(height: 16),
                      ],
                      // PESSOAS ENVOLVIDAS
                      if (_dadosExtraidos!.pessoasEnvolvidas != null &&
                          _dadosExtraidos!.pessoasEnvolvidas!.isNotEmpty) ...[
                        _buildSectionTitle('PESSOAS ENVOLVIDAS'),
                        const SizedBox(height: 8),
                        ..._dadosExtraidos!.pessoasEnvolvidas!.map((pessoa) {
                          String tipoLabel;
                          switch (pessoa.tipo) {
                            case TipoPessoa.autor:
                              tipoLabel = 'Autor';
                              break;
                            case TipoPessoa.vitima:
                              tipoLabel = 'Vítima';
                              break;
                            case TipoPessoa.vitimaComunicante:
                              tipoLabel = 'Vítima Comunicante';
                              break;
                            case TipoPessoa.comunicante:
                              tipoLabel = 'Comunicante';
                              break;
                            default:
                              tipoLabel = 'Outro';
                          }
                          return _buildInfoRow('$tipoLabel:', pessoa.nome);
                        }),
                        const SizedBox(height: 16),
                      ],
                      // LOCAL
                      if (_dadosExtraidos!.endereco != null ||
                          _dadosExtraidos!.municipio != null ||
                          _dadosExtraidos!.coordenadasS != null ||
                          _dadosExtraidos!.coordenadasW != null) ...[
                        _buildSectionTitle('LOCAL'),
                        const SizedBox(height: 8),
                        if (_dadosExtraidos!.endereco != null)
                          _buildInfoRow('Endereço:', _dadosExtraidos!.endereco!),
                        if (_dadosExtraidos!.municipio != null)
                          _buildInfoRow('Município:', _dadosExtraidos!.municipio!),
                        if (_dadosExtraidos!.coordenadasS != null ||
                            _dadosExtraidos!.coordenadasW != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Coordenadas:',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_dadosExtraidos!.coordenadasS != null)
                                      Text(
                                        'S: ${_dadosExtraidos!.coordenadasS}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    if (_dadosExtraidos!.coordenadasW != null)
                                      Text(
                                        'W: ${_dadosExtraidos!.coordenadasW}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
    );
  }
}

