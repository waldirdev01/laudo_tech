import 'dart:io';

import 'package:flutter/material.dart';
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

  /// Salva na galeria e exibe aviso via SnackBar se falhar.
  /// Recebe o [ScaffoldMessengerState] já capturado antes de qualquer await
  /// para evitar o uso de BuildContext através de gaps assíncronos.
  static Future<void> saveToGalleryWithFeedback(
    ScaffoldMessengerState messenger,
    String path,
  ) async {
    final ok = await saveToGallery(path);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Foto salva no app. O backup na galeria falhou.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
