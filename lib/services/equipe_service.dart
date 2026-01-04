import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/membro_equipe_model.dart';

/// Serviço para gerenciar membros da equipe
class EquipeService {
  static const String _equipeKey = 'equipe_membros';

  /// Adiciona um membro à equipe
  Future<void> adicionarMembro(MembroEquipeModel membro) async {
    final equipe = await listarEquipe();
    equipe.add(membro);
    await _salvarEquipe(equipe);
  }

  /// Atualiza um membro da equipe
  Future<void> atualizarMembro(MembroEquipeModel membro) async {
    final equipe = await listarEquipe();
    final index = equipe.indexWhere((m) => m.id == membro.id);
    if (index >= 0) {
      equipe[index] = membro;
      await _salvarEquipe(equipe);
    }
  }

  /// Remove um membro da equipe
  Future<void> removerMembro(String id) async {
    final equipe = await listarEquipe();
    equipe.removeWhere((m) => m.id == id);
    await _salvarEquipe(equipe);
  }

  /// Lista todos os membros da equipe
  Future<List<MembroEquipeModel>> listarEquipe() async {
    final prefs = await SharedPreferences.getInstance();
    final equipeJson = prefs.getStringList(_equipeKey) ?? [];
    
    return equipeJson
        .map((json) => MembroEquipeModel.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Lista membros por cargo
  Future<List<MembroEquipeModel>> listarPorCargo(String cargo) async {
    final equipe = await listarEquipe();
    return equipe.where((m) => m.cargo == cargo).toList();
  }

  Future<void> _salvarEquipe(List<MembroEquipeModel> equipe) async {
    final prefs = await SharedPreferences.getInstance();
    final equipeJson = equipe
        .map((m) => jsonEncode(m.toJson()))
        .toList();
    await prefs.setStringList(_equipeKey, equipeJson);
  }
}

