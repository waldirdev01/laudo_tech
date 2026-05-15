import 'package:flutter/material.dart';

import '../services/ai_model_catalog_service.dart';
import '../services/ai_settings_service.dart';
import '../services/openai_service.dart';

class AiConfiguracoesScreen extends StatefulWidget {
  const AiConfiguracoesScreen({super.key});

  @override
  State<AiConfiguracoesScreen> createState() => _AiConfiguracoesScreenState();
}

class _AiConfiguracoesScreenState extends State<AiConfiguracoesScreen> {
  final _settingsService = AiSettingsService();
  late final _modelCatalogService = AiModelCatalogService(
    settingsService: _settingsService,
  );
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  bool _enabled = false;
  String _provider = AiSettingsService.openAiProvider;
  bool _hasSavedKey = false;
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _loadingModels = false;
  List<String> _loadedModels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _provider = settings.provider;
      _hasSavedKey = settings.hasApiKey;
      _modelController.text = settings.model;
      _loadedModels = const [];
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _settingsService.save(
        enabled: _enabled,
        provider: _provider,
        model: _modelController.text,
        apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
      );
      _apiKeyController.clear();
      final settings = await _settingsService.load();
      if (!mounted) return;
      setState(() {
        _provider = settings.provider;
        _hasSavedKey = settings.hasApiKey;
      });
      _showMessage('Configuração de IA salva.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearKey() async {
    await _settingsService.clearApiKey(_provider);
    if (!mounted) return;
    setState(() {
      _hasSavedKey = false;
      _apiKeyController.clear();
    });
    _showMessage('Chave removida.');
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      await _save();
      await AiSuggestionService(
        settingsService: _settingsService,
      ).testConnection();
      if (!mounted) return;
      _showMessage(
        'Conexão com ${AiSettingsService.providerLabel(_provider)} validada.',
      );
    } on AiServiceException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível validar a conexão com ${AiSettingsService.providerLabel(_provider)}.',
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _changeProvider(String provider) async {
    final normalizedProvider = AiSettingsService.normalizeProvider(provider);
    if (normalizedProvider == _provider) return;

    final model = await _settingsService.getModelFor(normalizedProvider);
    final hasApiKey = await _settingsService.hasApiKeyFor(normalizedProvider);
    if (!mounted) return;
    setState(() {
      _provider = normalizedProvider;
      _hasSavedKey = hasApiKey;
      _modelController.text = model;
      _apiKeyController.clear();
      _loadedModels = const [];
    });
  }

  Future<void> _loadAvailableModels() async {
    setState(() => _loadingModels = true);
    try {
      final models = await _modelCatalogService.fetchModels(
        provider: _provider,
        apiKeyOverride: _apiKeyController.text,
      );
      if (!mounted) return;
      setState(() => _loadedModels = models);
      if (models.isEmpty) {
        _showMessage('Nenhum modelo compatível foi retornado.');
        return;
      }
      _showMessage('${models.length} modelo(s) disponível(is).');
      await _selectModel();
    } on AiServiceException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível carregar a lista de modelos.');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = AiSettingsService.providerLabel(_provider);
    final selectedModel = _modelController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteligência Artificial'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativar IA no aplicativo'),
                  subtitle: const Text(
                    'Os campos continuam manuais. A IA aparece somente como sugestão.',
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Provedor',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: AiSettingsService.openAiProvider,
                              icon: Icon(Icons.image_search_outlined),
                              label: Text('OpenAI / ChatGPT'),
                            ),
                            ButtonSegment<String>(
                              value: AiSettingsService.deepSeekProvider,
                              icon: Icon(Icons.text_fields),
                              label: Text('DeepSeek'),
                            ),
                          ],
                          selected: {_provider},
                          onSelectionChanged: _saving || _testing
                              ? null
                              : (selection) => _changeProvider(selection.first),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _provider == AiSettingsService.deepSeekProvider
                                ? Icons.text_fields
                                : Icons.image_search_outlined,
                          ),
                          title: Text(providerLabel),
                          subtitle: Text(
                            _provider == AiSettingsService.deepSeekProvider
                                ? 'Sugestões em texto pela chave de API do usuário.'
                                : 'Texto e imagens pela chave de API do usuário.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_provider == AiSettingsService.deepSeekProvider)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Nesta integração, o DeepSeek usa apenas texto. Para análise com foto, mantenha o OpenAI selecionado.',
                            ),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Modelo do $providerLabel'),
                          subtitle: Text(
                            selectedModel.isEmpty
                                ? 'Carregue os modelos permitidos pela chave e selecione um.'
                                : selectedModel,
                          ),
                          trailing: _loadingModels
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.keyboard_arrow_down),
                          onTap: _saving || _testing || _loadingModels
                              ? null
                              : () async {
                                  if (_loadedModels.isEmpty) {
                                    await _loadAvailableModels();
                                  } else {
                                    await _selectModel();
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _saving || _testing || _loadingModels
                              ? null
                              : _loadAvailableModels,
                          icon: _loadingModels
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_sync_outlined),
                          label: const Text('Carregar modelos da chave'),
                        ),
                        if (_loadedModels.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${_loadedModels.length} modelo(s) carregado(s) pela chave. Somente o modelo selecionado será usado.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: _hasSavedKey
                                ? 'Nova chave de API, opcional'
                                : 'Chave de API do $providerLabel',
                            helperText: _hasSavedKey
                                ? 'Há uma chave de $providerLabel salva com segurança neste aparelho.'
                                : 'A chave fica armazenada no Keychain/Keystore do aparelho.',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscureKey
                                  ? 'Mostrar chave'
                                  : 'Ocultar chave',
                              onPressed: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        if (_hasSavedKey) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _saving || _testing ? null : _clearKey,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover chave salva'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Salvar configuração'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text('Testar conexão com $providerLabel'),
                ),
              ],
            ),
    );
  }

  Future<void> _selectModel() async {
    if (_loadedModels.isEmpty) {
      _showMessage('Carregue os modelos da chave antes de selecionar.');
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _loadedModels.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final model = _loadedModels[index];
              final isSelected = model == _modelController.text.trim();
              return ListTile(
                title: Text(model),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(model),
              );
            },
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() => _modelController.text = selected);
  }
}
