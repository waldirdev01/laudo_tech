import 'package:flutter/material.dart';

import '../models/solicitacao_model.dart';
import '../models/tipo_ocorrencia.dart';
import 'preenchimento_ficha_screen.dart';
import 'upload_pdf_screen.dart';

class SelecaoTipoOcorrenciaScreen extends StatelessWidget {
  const SelecaoTipoOcorrenciaScreen({super.key});

  void _abrirComRequisicao(BuildContext context, TipoOcorrencia tipo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UploadPdfScreen(tipoOcorrencia: tipo),
      ),
    );
  }

  void _abrirSemRequisicao(BuildContext context, TipoOcorrencia tipo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreenchimentoFichaScreen(
          tipoOcorrencia: tipo,
          dadosSolicitacao: SolicitacaoModel(),
        ),
      ),
    );
  }

  Future<void> _escolherComoIniciar(
      BuildContext context, TipoOcorrencia tipo) async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Como deseja iniciar?'),
        content: const Text(
          'Você já possui o PDF da requisição de perícia ou foi acionado apenas por telefone/outro meio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('pdf'),
            child: const Text('Tenho a requisição (PDF)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('manual'),
            child: const Text('Sem requisição – preencher manualmente'),
          ),
        ],
      ),
    );
    if (!context.mounted || escolha == null) return;
    if (escolha == 'pdf') {
      _abrirComRequisicao(context, tipo);
    } else {
      _abrirSemRequisicao(context, tipo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Ocorrência'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Selecione o tipo de ocorrência:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: TipoOcorrencia.tiposDisponiveis.length,
                itemBuilder: (context, index) {
                  final tipo = TipoOcorrencia.tiposDisponiveis[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: Icon(
                        Icons.description_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        tipo.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _escolherComoIniciar(context, tipo),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

