import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/laboratorio_model.dart';

/// Serviço para gerenciar laboratórios que recebem vestígios
class LaboratorioService {
  static const String _laboratoriosKey = 'laboratorios_lista';
  static const String _seedKey = 'laboratorios_seed_v1_aplicado';
  static const List<Map<String, String>> _laboratoriosPadrao = [
    {
      'id': 'lab_lapap',
      'nome': '[ICLR] - Laboratório de Papiloscopia Forense',
      'sigla': 'LAPAP',
    },
    {
      'id': 'lab_sedna',
      'nome': '[ICLR] - Seção de DNA Forense',
      'sigla': 'SEDNA',
    },
    {
      'id': 'lab_sebio',
      'nome': '[ICLR] - Seção de Biologia Forense',
      'sigla': 'SEBIO',
    },
  ];

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
    await _aplicarSeedInicialSeNecessario(prefs);
    final laboratoriosJson = prefs.getStringList(_laboratoriosKey) ?? [];

    return laboratoriosJson
        .map((json) => LaboratorioModel.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _aplicarSeedInicialSeNecessario(SharedPreferences prefs) async {
    if (prefs.getBool(_seedKey) == true) return;

    final existentesJson = prefs.getStringList(_laboratoriosKey) ?? [];
    final existentes = existentesJson
        .map((json) => LaboratorioModel.fromJson(jsonDecode(json)))
        .toList();

    final idsExistentes = existentes.map((l) => l.id).toSet();
    for (final padrao in _laboratoriosPadrao) {
      if (!idsExistentes.contains(padrao['id'])) {
        existentes.add(
          LaboratorioModel(
            id: padrao['id']!,
            nome: padrao['nome']!,
            sigla: padrao['sigla'],
          ),
        );
      }
    }

    await prefs.setStringList(
      _laboratoriosKey,
      existentes.map((l) => jsonEncode(l.toJson())).toList(),
    );
    await prefs.setBool(_seedKey, true);
  }

  Future<void> _salvarLaboratorios(List<LaboratorioModel> laboratorios) async {
    final prefs = await SharedPreferences.getInstance();
    final laboratoriosJson = laboratorios
        .map((l) => jsonEncode(l.toJson()))
        .toList();
    await prefs.setStringList(_laboratoriosKey, laboratoriosJson);
  }
}
