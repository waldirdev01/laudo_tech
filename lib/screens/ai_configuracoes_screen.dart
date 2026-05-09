import 'package:flutter/material.dart';

import '../services/ai_settings_service.dart';
import '../services/openai_service.dart';

class AiConfiguracoesScreen extends StatefulWidget {
  const AiConfiguracoesScreen({super.key});

  @override
  State<AiConfiguracoesScreen> createState() => _AiConfiguracoesScreenState();
}

class _AiConfiguracoesScreenState extends State<AiConfiguracoesScreen> {
  final _settingsService = AiSettingsService();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  bool _enabled = false;
  String _provider = AiSettingsService.openAiProvider;
  bool _hasSavedKey = false;
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

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
      await AiSuggestionService(settingsService: _settingsService)
          .testConnection();
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
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = AiSettingsService.providerLabel(_provider);
    final defaultModel = AiSettingsService.defaultModelFor(_provider);

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
                        TextField(
                          controller: _modelController,
                          decoration: InputDecoration(
                            labelText: 'Modelo do $providerLabel',
                            border: OutlineInputBorder(),
                            hintText: defaultModel,
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
}
