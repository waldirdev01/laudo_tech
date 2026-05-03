import 'dart:io';

import 'package:flutter/services.dart';

class PhotoBackupService {
  static const MethodChannel _channel = MethodChannel(
    'laudo_tech/photo_backup',
  );

  static Future<bool> saveToGallery(String path) async {
    if (!await File(path).exists()) return false;
    try {
      final saved = await _channel.invokeMethod<bool>('saveToGallery', {
        'path': path,
      });
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }
}
