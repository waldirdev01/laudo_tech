import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  final bool enabled;
  final String provider;
  final String model;
  final bool hasApiKey;

  const AiSettings({
    required this.enabled,
    required this.provider,
    required this.model,
    required this.hasApiKey,
  });

  bool get canUse =>
      enabled &&
      AiSettingsService.supportedProviders.contains(provider) &&
      hasApiKey;
}

class AiSettingsService {
  static const openAiProvider = 'openai';
  static const deepSeekProvider = 'deepseek';

  static const defaultOpenAiModel = 'gpt-4.1-mini';
  static const defaultDeepSeekModel = 'deepseek-v4-flash';

  static const supportedProviders = <String>[
    openAiProvider,
    deepSeekProvider,
  ];

  static const _enabledKey = 'ai_enabled';
  static const _providerKey = 'ai_provider';
  static const _legacyModelKey = 'ai_model';
  static const _openAiModelKey = 'openai_model';
  static const _deepSeekModelKey = 'deepseek_model';
  static const _openAiApiKey = 'openai_api_key';
  static const _deepSeekApiKey = 'deepseek_api_key';

  static const _secureStorage = FlutterSecureStorage();

  static String normalizeProvider(String provider) {
    return supportedProviders.contains(provider) ? provider : openAiProvider;
  }

  static String defaultModelFor(String provider) {
    return switch (normalizeProvider(provider)) {
      deepSeekProvider => defaultDeepSeekModel,
      _ => defaultOpenAiModel,
    };
  }

  static String providerLabel(String provider) {
    return switch (normalizeProvider(provider)) {
      deepSeekProvider => 'DeepSeek',
      _ => 'OpenAI / ChatGPT',
    };
  }

  static bool providerSupportsImages(String provider) {
    return switch (normalizeProvider(provider)) {
      deepSeekProvider => false,
      _ => true,
    };
  }

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider =
        prefs.getString(_providerKey) ?? openAiProvider;
    return loadForProvider(provider);
  }

  Future<AiSettings> loadForProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedProvider = normalizeProvider(provider);
    return AiSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      provider: normalizedProvider,
      model: _modelForProvider(normalizedProvider, prefs),
      hasApiKey: await hasApiKeyFor(normalizedProvider),
    );
  }

  Future<void> save({
    required bool enabled,
    required String provider,
    required String model,
    String? apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedProvider = normalizeProvider(provider);
    final cleanModel = model.trim().isEmpty
        ? defaultModelFor(normalizedProvider)
        : model.trim();

    await prefs.setBool(_enabledKey, enabled);
    await prefs.setString(_providerKey, normalizedProvider);
    await prefs.setString(_legacyModelKey, cleanModel);
    await prefs.setString(_modelKeyForProvider(normalizedProvider), cleanModel);

    if (apiKey != null) {
      final cleanKey = apiKey.trim();
      final storageKey = _apiKeyStorageKey(normalizedProvider);
      if (cleanKey.isEmpty) {
        await _secureStorage.delete(key: storageKey);
      } else {
        await _secureStorage.write(key: storageKey, value: cleanKey);
      }
    }
  }

  Future<String> getModelFor(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    return _modelForProvider(normalizeProvider(provider), prefs);
  }

  Future<bool> hasApiKeyFor(String provider) async {
    final apiKey = await getApiKey(provider);
    return apiKey != null && apiKey.trim().isNotEmpty;
  }

  Future<String?> getApiKey(String provider) {
    return _secureStorage.read(key: _apiKeyStorageKey(normalizeProvider(provider)));
  }

  Future<void> clearApiKey(String provider) {
    return _secureStorage.delete(key: _apiKeyStorageKey(normalizeProvider(provider)));
  }

  String _modelForProvider(String provider, SharedPreferences prefs) {
    final storedModel = prefs.getString(_modelKeyForProvider(provider));
    if (storedModel != null && storedModel.trim().isNotEmpty) {
      return storedModel;
    }

    if (provider == openAiProvider) {
      final legacyModel = prefs.getString(_legacyModelKey);
      if (legacyModel != null && legacyModel.trim().isNotEmpty) {
        return legacyModel;
      }
    }

    return defaultModelFor(provider);
  }

  String _modelKeyForProvider(String provider) {
    return switch (provider) {
      deepSeekProvider => _deepSeekModelKey,
      _ => _openAiModelKey,
    };
  }

  static String _apiKeyStorageKey(String provider) {
    return switch (provider) {
      deepSeekProvider => _deepSeekApiKey,
      _ => _openAiApiKey,
    };
  }

  Future<String?> getOpenAiApiKey() => _secureStorage.read(key: _openAiApiKey);

  Future<void> clearOpenAiApiKey() => _secureStorage.delete(key: _openAiApiKey);
}
