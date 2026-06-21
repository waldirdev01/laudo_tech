import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';

class VistoriaVeiculoAvaliacaoScreen extends StatefulWidget {
  const VistoriaVeiculoAvaliacaoScreen({super.key, required this.ficha});

  final FichaCompletaModel ficha;

  @override
  State<VistoriaVeiculoAvaliacaoScreen> createState() =>
      _VistoriaVeiculoAvaliacaoScreenState();
}

class _VistoriaVeiculoAvaliacaoScreenState
    extends State<VistoriaVeiculoAvaliacaoScreen> {
  final _fichaService = FichaService();
  final _avaliacaoController = TextEditingController();
  final _conclusaoController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _avaliacaoController.text = widget.ficha.vistoriaVeiculoAvaliacao ?? '';
    _conclusaoController.text = widget.ficha.vistoriaVeiculoConclusao ?? '';
  }

  @override
  void dispose() {
    _avaliacaoController.dispose();
    _conclusaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final fichaAtual =
          await _fichaService.obterFicha(widget.ficha.id) ?? widget.ficha;
      final dataHoraTermino =
          fichaAtual.dataHoraTermino?.trim().isNotEmpty == true
          ? fichaAtual.dataHoraTermino
          : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final fichaAtualizada = fichaAtual.copyWith(
        vistoriaVeiculoAvaliacao: _avaliacaoController.text.trim(),
        vistoriaVeiculoConclusao: _conclusaoController.text.trim(),
        dataHoraTermino: dataHoraTermino,
        dataUltimaAtualizacao: DateTime.now(),
      );
      await _fichaService.salvarFicha(fichaAtualizada);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avaliação e conclusão salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
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
      appBar: AppBar(
        title: const Text('Avaliação e Conclusão'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _avaliacaoController,
              decoration: const InputDecoration(
                labelText: 'Avaliação',
                hintText:
                    'Ex.: custo estimado dos reparos ou avaliação de mercado.',
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _conclusaoController,
              decoration: const InputDecoration(
                labelText: 'Conclusão',
                hintText:
                    'Ex.: meio de ação, recência/permanência dos danos e compatibilidade técnica.',
                border: OutlineInputBorder(),
              ),
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar e Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}
