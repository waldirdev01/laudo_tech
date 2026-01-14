import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ficha_completa_model.dart';

/// Serviço para gerenciar fichas salvas
class FichaService {
  static const String _fichasKey = 'fichas_salvas';

  /// Salva uma ficha
  Future<void> salvarFicha(FichaCompletaModel ficha) async {
    final fichas = await listarFichas();
    
    // Se já existe, atualiza. Senão, adiciona nova
    final index = fichas.indexWhere((f) => f.id == ficha.id);
    if (index >= 0) {
      // Usar a ficha passada diretamente (já vem com dataUltimaAtualizacao atualizada)
      fichas[index] = ficha;
    } else {
      fichas.add(ficha);
    }
    
    await _atualizarListaFichas(fichas);
  }

  /// Lista todas as fichas salvas
  Future<List<FichaCompletaModel>> listarFichas() async {
    final prefs = await SharedPreferences.getInstance();
    final fichasJson = prefs.getStringList(_fichasKey) ?? [];
    
    return fichasJson
        .map((json) => FichaCompletaModel.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao)); // Mais recentes primeiro
  }

  /// Obtém uma ficha por ID
  Future<FichaCompletaModel?> obterFicha(String id) async {
    final fichas = await listarFichas();
    try {
      return fichas.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Remove uma ficha
  Future<bool> removerFicha(String id) async {
    final fichas = await listarFichas();
    final fichasAtualizadas = fichas.where((f) => f.id != id).toList();
    await _atualizarListaFichas(fichasAtualizadas);
    return true;
  }

  Future<void> _atualizarListaFichas(List<FichaCompletaModel> fichas) async {
    final prefs = await SharedPreferences.getInstance();
    final fichasJson = fichas
        .map((f) => jsonEncode(f.toJson()))
        .toList();
    await prefs.setStringList(_fichasKey, fichasJson);
  }
}

