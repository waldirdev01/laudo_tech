import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import '../services/photo_backup_service.dart';
import 'lista_veiculos_screen.dart';

class VistoriaVeiculoLocalScreen extends StatefulWidget {
  const VistoriaVeiculoLocalScreen({super.key, required this.ficha});

  final FichaCompletaModel ficha;

  @override
  State<VistoriaVeiculoLocalScreen> createState() =>
      _VistoriaVeiculoLocalScreenState();
}

class _VistoriaVeiculoLocalScreenState
    extends State<VistoriaVeiculoLocalScreen> {
  final _fichaService = FichaService();
  final _imagePicker = ImagePicker();
  final _descricaoController = TextEditingController();
  final List<String> _fotos = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _descricaoController.text =
        widget.ficha.vistoriaVeiculoLocalDescricao ?? '';
    _fotos.addAll(widget.ficha.vistoriaVeiculoLocalFotos);
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<String?> _persistirFoto(XFile arquivo) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.ficha.id}/vistoria_local',
      );
      if (!await pasta.exists()) {
        await pasta.create(recursive: true);
      }
      final ext = arquivo.path.contains('.')
          ? arquivo.path.split('.').last.toLowerCase()
          : 'jpg';
      final destino = File(
        '${pasta.path}/foto_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await destino.writeAsBytes(await arquivo.readAsBytes());
      await PhotoBackupService.saveToGalleryWithFeedback(
        messenger,
        destino.path,
      );
      return destino.path;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _adicionarCamera() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (foto == null) return;
    final path = await _persistirFoto(foto);
    if (path == null || !mounted) return;
    setState(() => _fotos.add(path));
  }

  Future<void> _adicionarGaleria() async {
    final fotos = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (fotos.isEmpty) return;
    for (final foto in fotos) {
      final path = await _persistirFoto(foto);
      if (path != null && mounted) {
        setState(() => _fotos.add(path));
      }
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final fichaAtual =
          await _fichaService.obterFicha(widget.ficha.id) ?? widget.ficha;
      final fichaAtualizada = fichaAtual.copyWith(
        vistoriaVeiculoLocalDescricao: _descricaoController.text.trim(),
        vistoriaVeiculoLocalFotos: List<String>.from(_fotos),
        dataUltimaAtualizacao: DateTime.now(),
      );
      await _fichaService.salvarFicha(fichaAtualizada);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local da vistoria salvo com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      final resultado = await Navigator.of(context).push<bool?>(
        MaterialPageRoute(
          builder: (context) => ListaVeiculosScreen(ficha: fichaAtualizada),
        ),
      );
      if (!mounted) return;
      if (resultado != null) {
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
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local da Vistoria'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição do local da vistoria',
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _salvando ? null : _adicionarCamera,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _salvando ? null : _adicionarGaleria,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Fotos opcionais (${_fotos.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _fotos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final path = _fotos[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filled(
                          onPressed: _salvando
                              ? null
                              : () => setState(() => _fotos.removeAt(index)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar e Ir para Veículo'),
            ),
          ],
        ),
      ),
    );
  }
}
