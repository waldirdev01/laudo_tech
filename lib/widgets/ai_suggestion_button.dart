import 'package:flutter/material.dart';

import '../services/openai_service.dart';

class AiSuggestionButton extends StatefulWidget {
  final String fieldLabel;
  final String currentText;
  final String Function()? currentTextBuilder;
  final String contextText;
  final String Function()? contextTextBuilder;
  final List<String> imagePaths;
  final List<String> Function()? imagePathsBuilder;
  final ValueChanged<String> onReplace;
  final ValueChanged<String>? onAppend;
  final AiSuggestionProfile profile;

  const AiSuggestionButton({
    super.key,
    required this.fieldLabel,
    required this.currentText,
    required this.onReplace,
    this.currentTextBuilder,
    this.contextText = '',
    this.contextTextBuilder,
    this.imagePaths = const [],
    this.imagePathsBuilder,
    this.onAppend,
    this.profile = AiSuggestionProfile.general,
  });

  @override
  State<AiSuggestionButton> createState() => _AiSuggestionButtonState();
}

class _AiSuggestionButtonState extends State<AiSuggestionButton> {
  final _aiService = AiSuggestionService();
  bool _loading = false;

  Future<void> _selectStyleAndGenerate() async {
    final style = await showModalBottomSheet<AiSuggestionStyle>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Estilo da sugestão'),
                subtitle: Text('Escolha como a IA deve redigir este campo.'),
              ),
              ...AiSuggestionStyle.values.map(
                (style) => ListTile(
                  leading: Icon(_iconForStyle(style)),
                  title: Text(style.label),
                  subtitle: Text(_subtitleForStyle(style)),
                  onTap: () => Navigator.of(ctx).pop(style),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (style == null) return;
    await _generate(style);
  }

  Future<void> _generate(AiSuggestionStyle style) async {
    setState(() => _loading = true);
    try {
      final suggestion = await _aiService.generateSuggestion(
        AiSuggestionRequest(
          fieldLabel: widget.fieldLabel,
          currentText: widget.currentTextBuilder?.call() ?? widget.currentText,
          contextText: widget.contextTextBuilder?.call() ?? widget.contextText,
          imagePaths: widget.imagePathsBuilder?.call() ?? widget.imagePaths,
          style: style,
          profile: widget.profile,
        ),
      );
      if (!mounted) return;
      await _showSuggestionDialog(suggestion);
    } on AiServiceException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível gerar a sugestão com IA.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconForStyle(AiSuggestionStyle style) {
    return switch (style) {
      AiSuggestionStyle.technical => Icons.description_outlined,
      AiSuggestionStyle.concise => Icons.short_text,
      AiSuggestionStyle.objective => Icons.fact_check_outlined,
      AiSuggestionStyle.reviseCurrent => Icons.edit_note,
    };
  }

  String _subtitleForStyle(AiSuggestionStyle style) {
    return switch (style) {
      AiSuggestionStyle.technical =>
        'Descrição técnica com detalhes relevantes.',
      AiSuggestionStyle.concise => 'Texto mais curto, em um parágrafo.',
      AiSuggestionStyle.objective => 'Texto direto, factual e sem floreios.',
      AiSuggestionStyle.reviseCurrent =>
        'Melhora o texto atual sem criar fatos novos.',
    };
  }

  Future<void> _showSuggestionDialog(String suggestion) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sugestão da IA'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(suggestion)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Descartar'),
          ),
          if (widget.onAppend != null)
            TextButton(
              onPressed: () {
                widget.onAppend!(suggestion);
                Navigator.of(ctx).pop();
              },
              child: const Text('Inserir ao final'),
            ),
          FilledButton(
            onPressed: () {
              widget.onReplace(suggestion);
              Navigator.of(ctx).pop();
            },
            child: const Text('Substituir campo'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _selectStyleAndGenerate,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(_loading ? 'Gerando sugestão...' : 'Gerar sugestão com IA'),
      ),
    );
  }
}
