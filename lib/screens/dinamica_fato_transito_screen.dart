import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/causas_determinantes_transito.dart';
import '../models/crime_transito_levantamento_model.dart';
import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import '../services/openai_service.dart';
import '../widgets/ai_suggestion_button.dart';

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
  final Set<String> _causasSelecionadas = {};
  bool _salvando = false;

  DinamicaAcidente? get _dinamicaPrincipal {
    final lev = widget.ficha.crimeTransitoLevantamento;
    if (lev?.dinamica != null) return lev!.dinamica;
    return CausasDeterminantesCatalogo.derivarDinamica(
      widget.ficha.crimeTransitoNatureza?.formasInteracao,
    );
  }

  @override
  void initState() {
    super.initState();
    final nat = widget.ficha.crimeTransitoNatureza;
    final complemento = nat?.complementoDinamicaFato ?? '';
    _complementoCtrl.text = complemento;
    final d = _dinamicaPrincipal;
    final validIds = d == null
        ? <String>{}
        : CausasDeterminantesCatalogo.opcoesPara(d).map((e) => e.id).toSet();
    for (final id in nat?.causasDeterminantesIds ?? const <String>[]) {
      if (validIds.contains(id)) _causasSelecionadas.add(id);
    }
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

  String _buildAiContextComplemento() {
    final natureza = widget.ficha.crimeTransitoNatureza;
    final partes = <String>['Tipo de ocorrência: crime de trânsito.'];

    if (natureza?.tipo != null) {
      partes.add(
        'Natureza: ${natureza!.tipo == CrimeTransitoNaturezaTipo.simples ? 'simples' : 'composta'}.',
      );
    }

    final formas =
        natureza?.formasInteracao ?? const <CrimeTransitoFormaInteracao>[];
    if (formas.isNotEmpty) {
      partes.add('Formas de interação: ${formas.map(_labelForma).join(', ')}.');
    }

    if (_dinamicaPrincipal != null) {
      partes.add(
        'Dinâmica principal derivada: ${CausasDeterminantesCatalogo.labelDinamica(_dinamicaPrincipal!)}.',
      );
    }

    if (natureza?.observacoes?.trim().isNotEmpty == true) {
      partes.add('Observações da natureza: ${natureza!.observacoes!.trim()}.');
    }

    if (_causasSelecionadas.isNotEmpty && _dinamicaPrincipal != null) {
      final opcoes = CausasDeterminantesCatalogo.opcoesPara(_dinamicaPrincipal!)
          .where((c) => _causasSelecionadas.contains(c.id))
          .map((c) => '${c.referencia} - ${c.titulo}')
          .toList();
      if (opcoes.isNotEmpty) {
        partes.add('Causas determinantes marcadas: ${opcoes.join('; ')}.');
      }
    }

    return partes.join('\n');
  }

  void _replaceComplemento(String text) {
    setState(() => _complementoCtrl.text = text.trim());
  }

  void _appendComplemento(String text) {
    final atual = _complementoCtrl.text.trim();
    setState(() {
      _complementoCtrl.text = atual.isEmpty
          ? text.trim()
          : '$atual\n\n${text.trim()}';
    });
  }

  Future<void> _finalizar() async {
    setState(() => _salvando = true);
    try {
      final natureza = widget.ficha.crimeTransitoNatureza;
      final causasIds = _causasSelecionadas.isEmpty
          ? null
          : _causasSelecionadas.toList();
      final naturezaAtualizada = natureza?.copyWith(
            complementoDinamicaFato: _complementoCtrl.text.trim().isEmpty
                ? null
                : _complementoCtrl.text.trim(),
            causasDeterminantesIds: causasIds,
          ) ??
          CrimeTransitoNaturezaModel(
            complementoDinamicaFato: _complementoCtrl.text.trim().isEmpty
                ? null
                : _complementoCtrl.text.trim(),
            causasDeterminantesIds: causasIds,
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
                    if (_dinamicaPrincipal != null) ...[
                      const SizedBox(height: 12),
                      _rowLabel(
                        context,
                        'Dinâmica principal (levantamento)',
                        CausasDeterminantesCatalogo.labelDinamica(
                          _dinamicaPrincipal!,
                        ),
                      ),
                    ],
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
            if (_dinamicaPrincipal != null) ...[
              Text(
                'Modelos de causa (SDT / IC-PCDF)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Conforme a dinâmica principal indicada no levantamento, '
                'marque as linhas do documento de referência que melhor descrevem o caso. '
                'Você pode marcar mais de uma.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ...CausasDeterminantesCatalogo.opcoesPara(_dinamicaPrincipal!).map(
                (c) => CheckboxListTile(
                  value: _causasSelecionadas.contains(c.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _causasSelecionadas.add(c.id);
                      } else {
                        _causasSelecionadas.remove(c.id);
                      }
                    });
                  },
                  title: Text('${c.referencia} — ${c.titulo}'),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Não foi possível determinar a dinâmica principal a partir do levantamento. '
                  'Conclua o levantamento fotográfico marcando uma forma de interação principal, '
                  'ou use o complemento abaixo para descrever a dinâmica.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
            const SizedBox(height: 8),
            AiSuggestionButton(
              fieldLabel: 'Complemento da dinâmica do fato',
              currentText: _complementoCtrl.text,
              currentTextBuilder: () => _complementoCtrl.text,
              contextTextBuilder: _buildAiContextComplemento,
              profile: AiSuggestionProfile.crimeTransito,
              onReplace: _replaceComplemento,
              onAppend: _appendComplemento,
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
