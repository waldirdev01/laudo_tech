import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';

/// Last screen in the traffic flow when the nature of the occurrence does not
/// have a velocity calculation yet (e.g. not Atropelamento). Shows the dynamics
/// of the fact, allows a free-text complement, and on "Concluir" finalizes the
/// ficha (sets data/hora término) like other flows.
class DinamicaFatoTransitoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const DinamicaFatoTransitoScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<DinamicaFatoTransitoScreen> createState() =>
      _DinamicaFatoTransitoScreenState();
}

class _DinamicaFatoTransitoScreenState extends State<DinamicaFatoTransitoScreen> {
  final _fichaService = FichaService();
  final _complementoCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final complemento =
        widget.ficha.crimeTransitoNatureza?.complementoDinamicaFato ?? '';
    _complementoCtrl.text = complemento;
  }

  @override
  void dispose() {
    _complementoCtrl.dispose();
    super.dispose();
  }

  static String _labelForma(CrimeTransitoFormaInteracao e) {
    return switch (e) {
      CrimeTransitoFormaInteracao.saidaPista => 'Saída de Pista',
      CrimeTransitoFormaInteracao.capotamento => 'Capotamento',
      CrimeTransitoFormaInteracao.tombamento => 'Tombamento',
      CrimeTransitoFormaInteracao.queda => 'Queda',
      CrimeTransitoFormaInteracao.atropelamento => 'Atropelamento',
      CrimeTransitoFormaInteracao.outro => 'Outro',
      CrimeTransitoFormaInteracao.colisao => 'Colisão',
      CrimeTransitoFormaInteracao.abalroamento => 'Abalroamento',
      CrimeTransitoFormaInteracao.choque => 'Choque',
      CrimeTransitoFormaInteracao.colisaoFrontal => 'Frontal',
      CrimeTransitoFormaInteracao.colisaoTraseira => 'Traseira',
      CrimeTransitoFormaInteracao.colisaoLateral => 'Lateral',
      CrimeTransitoFormaInteracao.colisaoLongitudinal => 'Longitudinal',
      CrimeTransitoFormaInteracao.colisaoOposta => 'Oposto',
      CrimeTransitoFormaInteracao.colisaoTransversal => 'Transversal',
      CrimeTransitoFormaInteracao.colisaoObliqua => 'Oblíqua',
      CrimeTransitoFormaInteracao.colisaoOrtogonal => 'Ortogonal',
      CrimeTransitoFormaInteracao.objetoFixo => 'Objeto Fixo',
      CrimeTransitoFormaInteracao.veiculoEstacionado => 'V. Estacionado',
      CrimeTransitoFormaInteracao.veiculoParado => 'V. Parado',
      CrimeTransitoFormaInteracao.pedestre => 'Pedestre',
      CrimeTransitoFormaInteracao.animal => 'Animal',
    };
  }

  Future<void> _finalizar() async {
    setState(() => _salvando = true);
    try {
      final natureza = widget.ficha.crimeTransitoNatureza;
      final naturezaAtualizada = natureza?.copyWith(
            complementoDinamicaFato: _complementoCtrl.text.trim().isEmpty
                ? null
                : _complementoCtrl.text.trim(),
          ) ??
          CrimeTransitoNaturezaModel(
            complementoDinamicaFato: _complementoCtrl.text.trim().isEmpty
                ? null
                : _complementoCtrl.text.trim(),
          );

      String? dataHoraTermino = widget.ficha.dataHoraTermino;
      if (dataHoraTermino == null || dataHoraTermino.trim().isEmpty) {
        dataHoraTermino =
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      }

      final fichaAtualizada = widget.ficha.copyWith(
        crimeTransitoNatureza: naturezaAtualizada,
        dataHoraTermino: dataHoraTermino,
        dataUltimaAtualizacao: DateTime.now(),
      );
      await _fichaService.salvarFicha(fichaAtualizada);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ficha finalizada com sucesso.'),
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
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final natureza = widget.ficha.crimeTransitoNatureza;
    final tipoStr = natureza?.tipo == CrimeTransitoNaturezaTipo.simples
        ? 'Simples (1 unidade)'
        : natureza?.tipo == CrimeTransitoNaturezaTipo.composta
            ? 'Composta (2 ou mais unidades)'
            : null;
    final formas = natureza?.formasInteracao ?? [];
    final formasLabel =
        formas.isEmpty ? 'Não informado' : formas.map(_labelForma).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinâmica do Fato'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DINÂMICA DO FATO',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (tipoStr != null) ...[
                      _rowLabel(context, 'Natureza', tipoStr),
                      const SizedBox(height: 12),
                    ],
                    if (natureza?.quantidadeUnidades != null) ...[
                      _rowLabel(
                        context,
                        'Unidades envolvidas',
                        natureza!.quantidadeUnidades.toString(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _rowLabel(context, 'Formas de interação', formasLabel),
                    if (natureza?.observacoes != null &&
                        natureza!.observacoes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _rowLabel(
                        context,
                        'Observações',
                        natureza.observacoes!.trim(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _complementoCtrl,
              decoration: const InputDecoration(
                labelText: 'Complemento / Ajuste na dinâmica do fato',
                hintText:
                    'Se desejar, descreva ou ajuste algo na dinâmica do fato.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cálculo de velocidade',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Para o tipo de ocorrência selecionado, o cálculo de velocidade ainda não está disponível neste aplicativo. Será incluído em versões futuras.\n\nPara ocorrências do tipo Atropelamento, retorne à tela Natureza da Ocorrência e selecione Atropelamento para acessar o cálculo (Searle/Northwestern).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvando ? null : _finalizar,
              icon: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_salvando ? 'Finalizando...' : 'Concluir e finalizar ficha'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowLabel(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
