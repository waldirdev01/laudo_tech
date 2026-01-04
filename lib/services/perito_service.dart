import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/perito_model.dart';

/// Serviço para gerenciar dados do perito
class PeritoService {
  static const String _peritoKey = 'perito_cadastrado';

  /// Salva os dados do perito
  Future<void> salvarPerito(PeritoModel perito) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(perito.toJson());
    await prefs.setString(_peritoKey, json);
  }

  /// Obtém os dados do perito cadastrado
  Future<PeritoModel?> obterPerito() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_peritoKey);
    
    if (json == null) {
      return null;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PeritoModel.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se já existe um perito cadastrado
  Future<bool> temPeritoCadastrado() async {
    final perito = await obterPerito();
    return perito != null;
  }
}

