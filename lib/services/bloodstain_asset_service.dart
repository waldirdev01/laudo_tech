import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/bloodstain_feature_config_model.dart';

class BloodstainAssetService {
  static const String configAssetPath =
      'assets/ai/bloodstain/bloodstain_config.json';

  Future<BloodstainFeatureConfig> loadConfig({
    String assetPath = configAssetPath,
  }) async {
    final jsonMap = await loadJsonAsset(assetPath);
    return BloodstainFeatureConfig.fromJson(jsonMap);
  }

  Future<BloodstainFeatureBundle> loadBundle({
    String configPath = configAssetPath,
  }) async {
    final config = await loadConfig(assetPath: configPath);
    final linkedAssets = config.linkedAssets.toAssetMap();
    final loadedAssets = <String, Map<String, dynamic>>{};

    for (final assetKey in config.loadOrder) {
      final path = linkedAssets[assetKey];
      if (path == null || path.isEmpty) {
        continue;
      }
      loadedAssets[assetKey] = await loadJsonAsset(path);
    }

    for (final entry in linkedAssets.entries) {
      if (entry.value.isEmpty || loadedAssets.containsKey(entry.key)) {
        continue;
      }
      loadedAssets[entry.key] = await loadJsonAsset(entry.value);
    }

    return BloodstainFeatureBundle(
      config: config,
      knowledgeBase:
          loadedAssets['knowledge_base'] ?? const <String, dynamic>{},
      responseTemplates:
          loadedAssets['response_templates'] ?? const <String, dynamic>{},
      uiMessages: loadedAssets['ui_messages'] ?? const <String, dynamic>{},
      glossary: loadedAssets['glossary'] ?? const <String, dynamic>{},
      analysisLevels:
          loadedAssets['analysis_levels'] ?? const <String, dynamic>{},
      loadedAssets: loadedAssets,
    );
  }

  Future<Map<String, dynamic>> loadJsonAsset(String assetPath) async {
    final rawJson = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'O asset $assetPath nao contem um objeto JSON valido.',
      );
    }
    return decoded;
  }
}
