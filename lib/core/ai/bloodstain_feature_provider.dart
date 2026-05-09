import 'package:flutter/material.dart';

import '../../models/bloodstain_feature_config_model.dart';
import '../../services/bloodstain_asset_service.dart';

class BloodstainFeatureProvider extends ChangeNotifier {
  final BloodstainAssetService _assetService;

  BloodstainFeatureBundle? _bundle;
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _errorMessage;

  BloodstainFeatureProvider({
    BloodstainAssetService? assetService,
  }) : _assetService = assetService ?? BloodstainAssetService();

  BloodstainFeatureBundle? get bundle => _bundle;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null && _errorMessage!.isNotEmpty;

  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }
    if (_isLoaded && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _bundle = await _assetService.loadBundle();
      _isLoaded = true;
    } catch (_) {
      _bundle = null;
      _isLoaded = false;
      _errorMessage =
          'Falha ao carregar a configuracao da analise assistiva de manchas de sangue.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() {
    return load(forceRefresh: true);
  }
}
