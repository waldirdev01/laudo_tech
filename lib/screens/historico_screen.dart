import 'package:flutter/material.dart';

import '../models/ficha_base_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'isolamento_screen.dart';

class HistoricoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const HistoricoScreen({super.key, required this.ficha});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _fichaService = FichaService();
  final _historicoController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    // Carregar histórico já salvo (se estiver editando)
    if (widget.ficha.dadosFichaBase?.historico != null) {
      _historicoController.text = widget.ficha.dadosFichaBase!.historico!;
      return;
    }
    _historicoController.text = _montarHistoricoInicial();
  }

  String _montarHistoricoInicial() {
    final origem = widget.ficha.dadosSolicitacao;
    final localEndereco = widget.ficha.local?.endereco ?? origem.endereco;
    final localMunicipio = widget.ficha.local?.municipio ?? origem.municipio;
    final dataHoraFato = origem.dataHoraComunicacao?.trim();

    final temDataHora = dataHoraFato != null && dataHoraFato.isNotEmpty;
    final temLocal =
        (localEndereco != null && localEndereco.trim().isNotEmpty) ||
        (localMunicipio != null && localMunicipio.trim().isNotEmpty);

    String trechoDataHora;
    if (temDataHora) {
      final partes = dataHoraFato.split(' ');
      final data = partes.isNotEmpty ? partes.first.trim() : '';
      final hora = partes.length > 1 ? partes[1].trim() : '';
      if (data.isNotEmpty && hora.isNotEmpty) {
        final horaFormatada = _formatarHora(hora);
        trechoDataHora = 'no dia $data, por volta de $horaFormatada';
      } else if (data.isNotEmpty) {
        trechoDataHora = 'na data de $data';
      } else {
        trechoDataHora = 'em data e horário não determinados';
      }
    } else {
      trechoDataHora = 'em data e horário não determinados';
    }

    String trechoLocal;
    if (temLocal) {
      final partesLocal = <String>[];
      if (localEndereco != null && localEndereco.trim().isNotEmpty) {
        partesLocal.add(localEndereco.trim());
      }
      if (localMunicipio != null && localMunicipio.trim().isNotEmpty) {
        partesLocal.add(localMunicipio.trim());
      }
      trechoLocal = 'no local ${partesLocal.join(', ')}';
    } else {
      trechoLocal = 'em local não determinado';
    }

    return 'Segundo o apurado, o fato teria ocorrido $trechoDataHora, $trechoLocal.';
  }

  String _formatarHora(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return hora;
    return '${partes[0]}h${partes[1]}min';
  }

  @override
  void dispose() {
    _historicoController.dispose();
    super.dispose();
  }

  Future<void> _salvarHistorico() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Criar ou atualizar dados da ficha base
      final fichaBase =
          widget.ficha.dadosFichaBase?.copyWith(
            historico: _historicoController.text.trim().isEmpty
                ? null
                : _historicoController.text.trim(),
          ) ??
          FichaBaseModel(
            historico: _historicoController.text.trim().isEmpty
                ? null
                : _historicoController.text.trim(),
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
            content: Text('Histórico salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de isolamento
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => IsolamentoScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou do isolamento, retornar true para atualizar lista
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
      appBar: AppBar(title: const Text('Histórico'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Área de texto
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.all(
                  Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruções
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '(Redação sugerida: "Segundo o apurado, o fato teria ocorrido...").',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(Incluir, quando possível, data, hora e local do fato; se desconhecidos, registrar como não determinados).',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Campo de texto
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextFormField(
                      controller: _historicoController,
                      decoration: const InputDecoration(
                        hintText: 'Descreva o histórico da ocorrência...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      maxLines: null,
                      minLines: 10,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      // O sistema iOS/Android já oferece voz para texto nativamente
                      // através do teclado, não precisa configurar nada especial
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarHistorico,
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
