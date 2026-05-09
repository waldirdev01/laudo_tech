import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_settings_service.dart';
import 'openai_service.dart';

class AiModelCatalogService {
  final AiSettingsService settingsService;
  final http.Client _httpClient;

  AiModelCatalogService({
    AiSettingsService? settingsService,
    http.Client? httpClient,
  })  : settingsService = settingsService ?? AiSettingsService(),
        _httpClient = httpClient ?? http.Client();

  Future<List<String>> fetchModels({
    required String provider,
    String? apiKeyOverride,
  }) async {
    final normalizedProvider = AiSettingsService.normalizeProvider(provider);
    final apiKey = apiKeyOverride?.trim().isNotEmpty == true
        ? apiKeyOverride!.trim()
        : await settingsService.getApiKey(normalizedProvider);

    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiServiceException(
        'Informe ou salve uma chave de API antes de carregar os modelos.',
      );
    }

    final response = await _httpClient.get(
      _modelsUri(normalizedProvider),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${apiKey.trim()}',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'Não foi possível carregar os modelos (${response.statusCode}). Verifique a chave e a conexão.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) return const [];

    final models = data
        .whereType<Map<String, dynamic>>()
        .map(_ModelCatalogItem.fromJson)
        .where((item) => _isSupportedModelId(normalizedProvider, item.id))
        .toList()
      ..sort(_compareNewestFirst);

    return models.map((item) => item.id).toSet().toList();
  }

  Uri _modelsUri(String provider) {
    return switch (provider) {
      AiSettingsService.deepSeekProvider =>
        Uri.parse('https://api.deepseek.com/models'),
      _ => Uri.parse('https://api.openai.com/v1/models'),
    };
  }

  bool _isSupportedModelId(String provider, String id) {
    final lower = id.toLowerCase();
    if (provider == AiSettingsService.deepSeekProvider) {
      return lower.startsWith('deepseek');
    }

    if (!lower.startsWith('gpt-') && !lower.startsWith('o')) return false;
    return !lower.contains('audio') &&
        !lower.contains('image') &&
        !lower.contains('realtime') &&
        !lower.contains('search') &&
        !lower.contains('tts') &&
        !lower.contains('transcribe');
  }

  int _compareNewestFirst(_ModelCatalogItem a, _ModelCatalogItem b) {
    final createdComparison = b.created.compareTo(a.created);
    if (createdComparison != 0) return createdComparison;
    return b.id.compareTo(a.id);
  }
}

class _ModelCatalogItem {
  final String id;
  final int created;

  const _ModelCatalogItem({
    required this.id,
    required this.created,
  });

  factory _ModelCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final created = json['created'];
    return _ModelCatalogItem(
      id: id is String ? id : '',
      created: created is int ? created : 0,
    );
  }
}
