import 'package:flutter/material.dart';
import '../models/tipo_ocorrencia.dart';
import 'upload_pdf_screen.dart';

class SelecaoTipoOcorrenciaScreen extends StatelessWidget {
  const SelecaoTipoOcorrenciaScreen({super.key});

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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UploadPdfScreen(
                              tipoOcorrencia: tipo,
                            ),
                          ),
                        );
                      },
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

