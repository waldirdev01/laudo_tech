import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/ai/bloodstain_feature_provider.dart';
import '../models/bloodstain_analysis_model.dart';
import '../services/ai_settings_service.dart';
import '../services/ficha_service.dart';
import '../services/openai_service.dart';
import 'ai_configuracoes_screen.dart';

class BloodstainAnalysisScreen extends StatefulWidget {
  final String fichaId;
  final String initialContextText;
  final List<String> initialOverviewImagePaths;

  const BloodstainAnalysisScreen({
    super.key,
    required this.fichaId,
    required this.initialContextText,
    this.initialOverviewImagePaths = const [],
  });

  @override
  State<BloodstainAnalysisScreen> createState() =>
      _BloodstainAnalysisScreenState();
}

class _BloodstainAnalysisScreenState extends State<BloodstainAnalysisScreen> {
  final _settingsService = AiSettingsService();
  final _fichaService = FichaService();
  final _aiService = AiSuggestionService();
  final _imagePicker = ImagePicker();

  final _contextController = TextEditingController();
  final _surfaceTypeController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  late final List<String> _overviewImagePaths;
  final List<String> _closeUpImagePaths = [];

  bool _scalePresent = false;
  String _planeOrientation = 'não informado';
  bool _loadingSettings = true;
  bool _analyzing = false;
  AiSuggestionStyle? _refiningStyle;
  AiSettings? _openAiSettings;
  String? _result;
  String? _savedAnalysisId;
  String? _errorText;

  static const _planeOrientationOptions = [
    'horizontal',
    'vertical',
    'inclinado',
    'não informado',
  ];

  @override
  void initState() {
    super.initState();
    _contextController.text = widget.initialContextText.trim();
    _overviewImagePaths = List<String>.from(widget.initialOverviewImagePaths);
    _loadOpenAiSettings();
  }

  @override
  void dispose() {
    _contextController.dispose();
    _surfaceTypeController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadOpenAiSettings() async {
    final settings = await _settingsService.loadForProvider(
      AiSettingsService.openAiProvider,
    );
    if (!mounted) return;
    setState(() {
      _openAiSettings = settings;
      _loadingSettings = false;
    });
  }

  Future<void> _addCameraImage(List<String> target) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;
    setState(() => target.add(image.path));
  }

  Future<void> _addGalleryImages(List<String> target) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList();
    if (paths.isEmpty) return;
    setState(() => target.addAll(paths));
  }

  String _uiMessage(
    Map<String, dynamic>? uiMessages,
    String key,
    String fallback,
  ) {
    final messages = uiMessages?['ui_messages'];
    if (messages is Map<String, dynamic>) {
      final value = messages[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String _validationMessage(
    Map<String, dynamic>? uiMessages,
    String key,
    String fallback,
  ) {
    final messages = uiMessages?['validation_messages'];
    if (messages is Map<String, dynamic>) {
      final value = messages[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String _buildAdditionalInstructions(
    Map<String, dynamic> knowledgeBase,
    Map<String, dynamic> responseTemplates,
    Map<String, dynamic> glossary,
    Map<String, dynamic> analysisLevels,
  ) {
    final safety =
        (knowledgeBase['safety_principles'] as List<dynamic>? ?? const [])
            .map((item) {
              if (item is Map<String, dynamic>) {
                return item['rule']?.toString() ?? '';
              }
              return item.toString();
            })
            .where((item) => item.trim().isNotEmpty)
            .join('\n- ');

    final prohibited =
        (knowledgeBase['prohibited_claims'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .join(', ');

    final uncertainty =
        (responseTemplates['uncertainty_phrases'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .join(', ');

    final featurePurpose =
        (knowledgeBase['feature_purpose'] as Map<String, dynamic>? ??
                const {})['scope']
            ?.toString() ??
        '';
    final terms = (glossary['terms'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final term = item['term']?.toString() ?? '';
          final definition = item['definition']?.toString() ?? '';
          final safeUsage = item['safe_usage']?.toString() ?? '';
          if (term.trim().isEmpty) return '';
          return '$term: $definition Uso seguro: $safeUsage';
        })
        .where((item) => item.trim().isNotEmpty)
        .take(40)
        .join('\n- ');
    final levels =
        (analysisLevels['analysis_levels'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final level = item['level']?.toString() ?? '';
              final name = item['name']?.toString() ?? '';
              final allowed = item['allowed_use']?.toString() ?? '';
              final blocked = item['must_not_do']?.toString() ?? '';
              return 'Nível $level - $name: pode $allowed; não deve $blocked';
            })
            .where((item) => item.trim().isNotEmpty)
            .join('\n- ');
    final operationalRule =
        analysisLevels['operational_rule']?.toString() ?? '';

    return '''
Contexto específico da funcionalidade: $featurePurpose
Regras obrigatórias adicionais:
- ${safety.isEmpty ? 'Separar observação visual, hipótese limitada e limitação da análise.' : safety}
- Não use nenhuma afirmação proibida, incluindo: $prohibited.
- Prefira expressões de cautela como: $uncertainty.
- Se a documentação for fraca ou ambígua, classifique como inespecífica ou indeterminada em vez de forçar uma leitura.
- Use a terminologia confiável abaixo como vocabulário de consulta, sem expandir além do que as imagens e o contexto sustentarem:
- $terms
- Respeite estes níveis de análise:
- $levels
- $operationalRule
''';
  }

  String _buildResponseDirective(Map<String, dynamic> responseSchema) {
    final schema = responseSchema['response_schema'];
    if (schema is! Map<String, dynamic> || schema.isEmpty) {
      return '''
Responda em blocos curtos com os campos:
Status da análise:
Qualidade da documentação:
Observações visuais:
Padrão principal compatível:
Padrões alternativos:
Limitações relevantes:
Dados ausentes:
Recomendações de documentação complementar:
Nível de cautela:
Necessidade de revisão humana:
''';
    }

    final fields = schema.keys
        .map((key) => '${key.replaceAll('_', ' ')}:')
        .join('\n');
    return 'Responda exatamente com os seguintes campos, nesta ordem:\n$fields';
  }

  String _buildContextText() {
    final parts = <String>[
      'Contexto resumido do local:',
      _contextController.text.trim(),
      'Tipo de superfície: ${_surfaceTypeController.text.trim()}.',
      'Orientação do plano: $_planeOrientation.',
      'Escala métrica: ${_scalePresent ? 'presente' : 'ausente'}.',
      'Imagens anexadas: ${_overviewImagePaths.length} ampla(s)/contextual(is) e ${_closeUpImagePaths.length} aproximada(s).',
    ];

    final notes = _additionalNotesController.text.trim();
    if (notes.isNotEmpty) {
      parts.add('Observações adicionais do perito: $notes.');
    }

    return parts.join('\n');
  }

  Future<void> _runAnalysis(BloodstainFeatureProvider provider) async {
    var bundle = provider.bundle;
    final uiMessages = bundle?.uiMessages;

    if (_overviewImagePaths.isEmpty) {
      _showMessage(
        _validationMessage(
          uiMessages,
          'missing_overview_image',
          'Adicione uma foto ampla do ambiente.',
        ),
      );
      return;
    }

    if (_closeUpImagePaths.isEmpty) {
      _showMessage(
        _validationMessage(
          uiMessages,
          'missing_close_image',
          'Adicione uma foto aproximada da mancha.',
        ),
      );
      return;
    }

    if (_surfaceTypeController.text.trim().isEmpty) {
      _showMessage(
        _validationMessage(
          uiMessages,
          'missing_surface_type',
          'Informe o tipo de superfície onde a mancha se encontra.',
        ),
      );
      return;
    }

    if (_contextController.text.trim().isEmpty) {
      _showMessage(
        _validationMessage(
          uiMessages,
          'missing_scene_context',
          'Informe um contexto resumido do vestígio ou do ambiente.',
        ),
      );
      return;
    }

    final settings = _openAiSettings;
    if (settings == null || !settings.enabled || !settings.hasApiKey) {
      _showMessage(
        'Configure o OpenAI / ChatGPT nas configurações de IA para usar esta funcionalidade.',
      );
      return;
    }

    if (bundle == null && !provider.isLoading) {
      await provider.reload();
      if (!mounted) return;
      bundle = provider.bundle;
    }

    if (bundle == null) {
      _showMessage(
        'A base da análise de manchas ainda não foi carregada. Tente novamente em instantes.',
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _errorText = null;
    });

    try {
      final request = AiSuggestionRequest(
        fieldLabel: 'Análise assistiva de manchas de sangue',
        currentText: '',
        contextText: _buildContextText(),
        imagePaths: [..._overviewImagePaths, ..._closeUpImagePaths],
        style: AiSuggestionStyle.objective,
        profile: AiSuggestionProfile.bloodstainAnalysis,
        providerOverride: bundle.config.providerPolicy.forcedProvider,
        additionalInstructions: _buildAdditionalInstructions(
          bundle.knowledgeBase,
          bundle.responseTemplates,
          bundle.glossary,
          bundle.analysisLevels,
        ),
        responseDirective: _buildResponseDirective(
          bundle.config.outputContract,
        ),
      );

      final response = await _aiService.generateSuggestion(request);
      await _saveAnalysisResult(response.trim());
      if (!mounted) return;
      setState(() => _result = response.trim());
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Falha ao executar a análise: $e');
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _refineAnalysis(
    BloodstainFeatureProvider provider,
    AiSuggestionStyle style,
  ) async {
    final currentResult = _result?.trim();
    if (currentResult == null || currentResult.isEmpty) {
      _showMessage('Execute a primeira análise antes de ajustar o texto.');
      return;
    }

    var bundle = provider.bundle;
    if (bundle == null && !provider.isLoading) {
      await provider.reload();
      if (!mounted) return;
      bundle = provider.bundle;
    }

    if (bundle == null) {
      _showMessage(
        'A base da análise de manchas ainda não foi carregada. Tente novamente em instantes.',
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _refiningStyle = style;
      _errorText = null;
    });

    try {
      final request = AiSuggestionRequest(
        fieldLabel: 'Revisão da análise assistiva de manchas de sangue',
        currentText: currentResult,
        contextText: _buildContextText(),
        imagePaths: [..._overviewImagePaths, ..._closeUpImagePaths],
        style: style,
        profile: AiSuggestionProfile.bloodstainAnalysis,
        providerOverride: bundle.config.providerPolicy.forcedProvider,
        additionalInstructions:
            '''
${_buildAdditionalInstructions(bundle.knowledgeBase, bundle.responseTemplates, bundle.glossary, bundle.analysisLevels)}
Reescreva o texto atual da análise no estilo solicitado.
Não acrescente achados, interpretações, conclusões ou dados que não estejam no texto atual, no contexto ou nas imagens.
Preserve as cautelas, limitações e necessidade de revisão humana quando existirem.
''',
        responseDirective: _refinementDirective(style),
      );

      final response = await _aiService.generateSuggestion(request);
      await _saveAnalysisResult(response.trim());
      if (!mounted) return;
      setState(() => _result = response.trim());
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Falha ao ajustar a análise: $e');
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _refiningStyle = null;
        });
      }
    }
  }

  String _refinementDirective(AiSuggestionStyle style) {
    return switch (style) {
      AiSuggestionStyle.concise =>
        'Reescreva em versão mais sucinta, mantendo apenas os pontos técnicos essenciais e sem perder as limitações relevantes.',
      AiSuggestionStyle.objective =>
        'Reescreva em versão mais objetiva, com frases diretas, sem floreios e sem reduzir cautelas técnicas necessárias.',
      _ =>
        'Reescreva o texto atual mantendo o conteúdo técnico e sem acrescentar fatos novos.',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveAnalysisResult(String resultText) async {
    if (resultText.trim().isEmpty) return;
    final ficha = await _fichaService.obterFicha(widget.fichaId);
    if (ficha == null) return;

    final analysisId =
        _savedAnalysisId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final analysis = BloodstainAnalysisModel(
      id: analysisId,
      createdAt: DateTime.now(),
      contextText: _contextController.text.trim(),
      surfaceType: _surfaceTypeController.text.trim(),
      planeOrientation: _planeOrientation,
      scalePresent: _scalePresent,
      overviewImagePaths: List<String>.from(_overviewImagePaths),
      closeUpImagePaths: List<String>.from(_closeUpImagePaths),
      resultText: resultText.trim(),
    );

    final analyses = List<BloodstainAnalysisModel>.from(
      ficha.analisesManchasSangue,
    );
    final existingIndex = analyses.indexWhere((item) => item.id == analysisId);
    if (existingIndex >= 0) {
      analyses[existingIndex] = analysis;
    } else {
      analyses.add(analysis);
    }

    await _fichaService.salvarFicha(
      ficha.copyWith(
        analisesManchasSangue: analyses,
        dataUltimaAtualizacao: DateTime.now(),
      ),
    );
    _savedAnalysisId = analysisId;
  }

  Widget _buildImageSection({
    required String title,
    required String description,
    required List<String> imagePaths,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _analyzing
                      ? null
                      : () => _addCameraImage(imagePaths),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Câmera'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _analyzing
                      ? null
                      : () => _addGalleryImages(imagePaths),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeria'),
                ),
              ],
            ),
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: imagePaths.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(entry.value),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 88,
                            height: 88,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          onPressed: _analyzing
                              ? null
                              : () => setState(
                                  () => imagePaths.removeAt(entry.key),
                                ),
                          icon: const Icon(Icons.close, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BloodstainFeatureProvider>();
    final bundle = provider.bundle;
    final uiMessages = bundle?.uiMessages;
    final providerPolicy = bundle?.config.providerPolicy;
    final canRunAnalysis = !_analyzing && !provider.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Manchas de Sangue'), centerTitle: true),
      body: provider.isLoading && bundle == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Análise Assistiva',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uiMessage(
                            uiMessages,
                            'feature_intro',
                            'Esta funcionalidade possui caráter exclusivamente assistivo e não substitui a análise pericial humana.',
                          ),
                        ),
                        if (providerPolicy?.reason.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 8),
                          Text(
                            providerPolicy!.reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _loadingSettings
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Modelo utilizado',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Provedor: ${AiSettingsService.providerLabel(AiSettingsService.openAiProvider)}',
                              ),
                              Text(
                                'Modelo: ${_openAiSettings?.model ?? AiSettingsService.defaultOpenAiModel}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _openAiSettings?.canUse == true
                                    ? 'A análise usará a chave e o modelo configurados pelo usuário para OpenAI / ChatGPT.'
                                    : 'OpenAI / ChatGPT ainda não está pronto para uso nesta funcionalidade.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_openAiSettings?.canUse != true) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AiConfiguracoesScreen(),
                                        ),
                                      );
                                      _loadOpenAiSettings();
                                    },
                                    icon: const Icon(Icons.settings),
                                    label: const Text(
                                      'Abrir configurações de IA',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contexto da análise',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contextController,
                          decoration: const InputDecoration(
                            labelText: 'Contexto resumido do local',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _surfaceTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de superfície',
                            hintText:
                                'Ex.: piso cerâmico, parede pintada, tecido',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _planeOrientation,
                          items: _planeOrientationOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Orientação do plano',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _planeOrientation = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _scalePresent,
                          onChanged: (value) =>
                              setState(() => _scalePresent = value),
                          title: const Text('Há escala métrica visível'),
                          subtitle: Text(
                            _uiMessage(
                              uiMessages,
                              'missing_scale',
                              'Escala métrica ausente. Isso reduz a segurança interpretativa e impede inferência dimensional.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _additionalNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Observações adicionais do perito',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildImageSection(
                  title: 'Fotos amplas e contextuais',
                  description:
                      'Inclua ao menos uma foto ampla mostrando a mancha no ambiente e sua relação com o local.',
                  imagePaths: _overviewImagePaths,
                ),
                const SizedBox(height: 12),
                _buildImageSection(
                  title: 'Fotos aproximadas da mancha',
                  description:
                      'Inclua fotos próximas e nítidas da mancha específica que será analisada.',
                  imagePaths: _closeUpImagePaths,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canRunAnalysis
                      ? () => _runAnalysis(provider)
                      : null,
                  icon: _analyzing || provider.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bloodtype_outlined),
                  label: Text(
                    _analyzing
                        ? 'Analisando...'
                        : provider.isLoading
                        ? 'Carregando base...'
                        : 'Executar análise assistiva',
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorText!),
                    ),
                  ),
                ],
                if (_result != null && _result!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resultado assistivo',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _analyzing
                                      ? null
                                      : () => _refineAnalysis(
                                          provider,
                                          AiSuggestionStyle.concise,
                                        ),
                                  icon:
                                      _refiningStyle ==
                                          AiSuggestionStyle.concise
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.short_text),
                                  label: const Text('Mais sucinto'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _analyzing
                                      ? null
                                      : () => _refineAnalysis(
                                          provider,
                                          AiSuggestionStyle.objective,
                                        ),
                                  icon:
                                      _refiningStyle ==
                                          AiSuggestionStyle.objective
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.fact_check_outlined),
                                  label: const Text('Mais objetivo'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_result!.trim()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
