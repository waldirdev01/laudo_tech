import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/laboratorio_model.dart';

/// Serviço para gerenciar laboratórios que recebem vestígios
class LaboratorioService {
  static const String _laboratoriosKey = 'laboratorios_lista';

  /// Adiciona um laboratório
  Future<void> adicionarLaboratorio(LaboratorioModel laboratorio) async {
    final laboratorios = await listarLaboratorios();
    laboratorios.add(laboratorio);
    await _salvarLaboratorios(laboratorios);
  }

  /// Atualiza um laboratório
  Future<void> atualizarLaboratorio(LaboratorioModel laboratorio) async {
    final laboratorios = await listarLaboratorios();
    final index = laboratorios.indexWhere((l) => l.id == laboratorio.id);
    if (index >= 0) {
      laboratorios[index] = laboratorio;
      await _salvarLaboratorios(laboratorios);
    }
  }

  /// Remove um laboratório
  Future<void> removerLaboratorio(String id) async {
    final laboratorios = await listarLaboratorios();
    laboratorios.removeWhere((l) => l.id == id);
    await _salvarLaboratorios(laboratorios);
  }

  /// Lista todos os laboratórios
  Future<List<LaboratorioModel>> listarLaboratorios() async {
    final prefs = await SharedPreferences.getInstance();
    final laboratoriosJson = prefs.getStringList(_laboratoriosKey) ?? [];
    
    return laboratoriosJson
        .map((json) => LaboratorioModel.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _salvarLaboratorios(List<LaboratorioModel> laboratorios) async {
    final prefs = await SharedPreferences.getInstance();
    final laboratoriosJson = laboratorios
        .map((l) => jsonEncode(l.toJson()))
        .toList();
    await prefs.setStringList(_laboratoriosKey, laboratoriosJson);
  }
}
