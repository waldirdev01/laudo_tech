import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ficha_completa_model.dart';

class FichaService {
  static const String _migrationKey = 'fichas_migradas_v2';
  static const String _migrationInProgressKey =
      'fichas_migracao_v2_em_andamento';
  static const String _rootJsonRecoveryKey = 'fichas_jsons_raiz_recuperados_v1';
  static const String _legacyKey = 'fichas_salvas';

  Future<Directory> _fichasDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fichas');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _migrarItensLegados(List<String> fichasJson) async {
    for (final item in fichasJson) {
      try {
        final ficha = FichaCompletaModel.fromJson(jsonDecode(item));
        await _escreverArquivo(ficha);
      } catch (_) {
        // ignora registros inválidos do storage antigo
      }
    }
  }

  Future<void> _recuperarJsonsNaRaiz() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rootJsonRecoveryKey) == true) return;

    final base = await getApplicationDocumentsDirectory();
    await for (final entity in base.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final content = await entity.readAsString();
        final ficha = FichaCompletaModel.fromJson(jsonDecode(content));
        await _escreverArquivo(ficha);
      } catch (_) {
        // ignora JSONs da raiz que não sejam fichas válidas
      }
    }

    await prefs.setBool(_rootJsonRecoveryKey, true);
  }

  // Migra fichas do SharedPreferences para arquivos individuais.
  // Também cobre casos em que a versão antiga gravou novos itens após a flag
  // de migração já estar marcada, preservando fichas criadas na loja.
  Future<void> _migrarSeNecessario() async {
    final prefs = await SharedPreferences.getInstance();
    final fichasJson = prefs.getStringList(_legacyKey) ?? [];

    if (prefs.getBool(_migrationKey) == true) {
      if (fichasJson.isNotEmpty) {
        await _migrarItensLegados(fichasJson);
        await prefs.remove(_legacyKey);
      }
      await _recuperarJsonsNaRaiz();
      return;
    }

    await prefs.setBool(_migrationInProgressKey, true);

    await _migrarItensLegados(fichasJson);
    await _recuperarJsonsNaRaiz();

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
