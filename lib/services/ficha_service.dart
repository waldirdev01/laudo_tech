import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ficha_completa_model.dart';

class FichaService {
  static const String _migrationKey = 'fichas_migradas_v2';
  static const String _migrationInProgressKey = 'fichas_migracao_v2_em_andamento';
  static const String _legacyKey = 'fichas_salvas';

  Future<Directory> _fichasDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fichas');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Migra fichas do SharedPreferences para arquivos individuais na primeira execução.
  // A migração é idempotente: pode rodar mais de uma vez sem duplicar/invalidar,
  // pois cada ficha é gravada no mesmo arquivo por id.
  Future<void> _migrarSeNecessario() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;
    await prefs.setBool(_migrationInProgressKey, true);

    final fichasJson = prefs.getStringList(_legacyKey) ?? [];
    for (final item in fichasJson) {
      try {
        final ficha = FichaCompletaModel.fromJson(jsonDecode(item));
        await _escreverArquivo(ficha);
      } catch (_) {
        // ignora registros inválidos do storage antigo
      }
    }

    await prefs.setBool(_migrationKey, true);
    await prefs.remove(_migrationInProgressKey);
    await prefs.remove(_legacyKey);
  }

  Future<void> _escreverArquivo(FichaCompletaModel ficha) async {
    final dir = await _fichasDir();
    final file = File('${dir.path}/${ficha.id}.json');
    await file.writeAsString(jsonEncode(ficha.toJson()));
  }

  Future<void> salvarFicha(FichaCompletaModel ficha) async {
    await _migrarSeNecessario();
    await _escreverArquivo(ficha);
  }

  Future<List<FichaCompletaModel>> listarFichas() async {
    await _migrarSeNecessario();
    final dir = await _fichasDir();
    final fichas = <FichaCompletaModel>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          fichas.add(FichaCompletaModel.fromJson(jsonDecode(content)));
        } catch (_) {
          // ignora arquivos corrompidos individualmente
        }
      }
    }

    fichas.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    return fichas;
  }

  Future<FichaCompletaModel?> obterFicha(String id) async {
    await _migrarSeNecessario();
    final dir = await _fichasDir();
    final file = File('${dir.path}/$id.json');
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return FichaCompletaModel.fromJson(jsonDecode(content));
    } catch (_) {
      return null;
    }
  }

  Future<bool> removerFicha(String id) async {
    await _migrarSeNecessario();
    final dir = await _fichasDir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) await file.delete();
    return true;
  }
}
