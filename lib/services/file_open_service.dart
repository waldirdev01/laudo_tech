import 'dart:io';

import 'package:flutter/services.dart';

class FileOpenService {
  static const MethodChannel _channel = MethodChannel('laudo_tech/file_open');

  static Future<bool> open(String path) async {
    if (!Platform.isAndroid) return false;
    if (!await File(path).exists()) return false;

    try {
      final opened = await _channel.invokeMethod<bool>('openFile', {
        'path': path,
      });
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
