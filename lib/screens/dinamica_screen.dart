import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';

class DinamicaScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const DinamicaScreen({super.key, required this.ficha});

  @override
  State<DinamicaScreen> createState() => _DinamicaScreenState();
}

class _DinamicaScreenState extends State<DinamicaScreen> {
  final _fichaService = FichaService();
  final _dinamicaController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    // Carregar dinâmica já salva (usando modusOperandi como campo de armazenamento para CVLI)
    if (widget.ficha.modusOperandi != null) {
      _dinamicaController.text = widget.ficha.modusOperandi!;
    }
  }

  @override
  void dispose() {
    _dinamicaController.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Preencher data/hora de término ao finalizar APENAS se ainda não estiver preenchido
      String? dataHoraTermino;
      if (widget.ficha.dataHoraTermino == null ||
          widget.ficha.dataHoraTermino!.isEmpty) {
        final agora = DateTime.now();
        dataHoraTermino = DateFormat('dd/MM/yyyy HH:mm').format(agora);
      } else {
        // Preservar o valor já existente (pode ter sido editado manualmente)
        dataHoraTermino = widget.ficha.dataHoraTermino;
      }

      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        modusOperandi: _dinamicaController.text.trim().isEmpty
            ? null
            : _dinamicaController.text.trim(),
        dataHoraTermino: dataHoraTermino,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
        localFurto: widget.ficha.localFurto,
        cadaveres: widget.ficha.cadaveres,
        veiculos: widget.ficha.veiculos,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dinâmica salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Limpar pilha de navegação e navegar para a tela inicial
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
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
        title: const Text('Dinâmica'),
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
                'DINÂMICA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Área de texto
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
                  controller: _dinamicaController,
                  decoration: const InputDecoration(
                    hintText: 'Digite a dinâmica do evento...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  maxLines: null,
                  minLines: 8,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Botão Finalizar
            FilledButton(
              onPressed: _salvando ? null : _finalizar,
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
                  : const Text('Finalizar'),
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
