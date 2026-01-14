import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/unidade_model.dart';

/// Serviço para gerenciar unidades que recebem vestígios
class UnidadeService {
  static const String _unidadesKey = 'unidades_lista';

  /// Adiciona uma unidade
  Future<void> adicionarUnidade(UnidadeModel unidade) async {
    final unidades = await listarUnidades();
    unidades.add(unidade);
    await _salvarUnidades(unidades);
  }

  /// Atualiza uma unidade
  Future<void> atualizarUnidade(UnidadeModel unidade) async {
    final unidades = await listarUnidades();
    final index = unidades.indexWhere((u) => u.id == unidade.id);
    if (index >= 0) {
      unidades[index] = unidade;
      await _salvarUnidades(unidades);
    }
  }

  /// Remove uma unidade
  Future<void> removerUnidade(String id) async {
    final unidades = await listarUnidades();
    unidades.removeWhere((u) => u.id == id);
    await _salvarUnidades(unidades);
  }

  /// Lista todas as unidades
  Future<List<UnidadeModel>> listarUnidades() async {
    final prefs = await SharedPreferences.getInstance();
    final unidadesJson = prefs.getStringList(_unidadesKey) ?? [];
    
    return unidadesJson
        .map((json) => UnidadeModel.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _salvarUnidades(List<UnidadeModel> unidades) async {
    final prefs = await SharedPreferences.getInstance();
    final unidadesJson = unidades
        .map((u) => jsonEncode(u.toJson()))
        .toList();
    await prefs.setStringList(_unidadesKey, unidadesJson);
  }
}
