import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
      final perito = PeritoModel.fromJson(map);
      return await _corrigirCaminhoTemplateSeNecessario(perito);
    } catch (e) {
      return null;
    }
  }

  Future<PeritoModel> _corrigirCaminhoTemplateSeNecessario(
    PeritoModel perito,
  ) async {
    final caminho = perito.caminhoTemplate;
    if (caminho != null && caminho.isNotEmpty) {
      final f = File(caminho);
      if (await f.exists()) {
        return perito;
      }
    }

    // Tentar recuperar automaticamente do diretório persistente do app
    try {
      final dir = await getApplicationDocumentsDirectory();
      final templatesDir = Directory('${dir.path}/templates');
      if (!await templatesDir.exists()) {
        return perito;
      }

      final arquivos = templatesDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final p = f.path.toLowerCase();
            return p.endsWith('.docx') || p.endsWith('.doc');
          })
          .toList();

      if (arquivos.isEmpty) {
        return perito;
      }

      arquivos.sort((a, b) {
        final ta = a.lastModifiedSync();
        final tb = b.lastModifiedSync();
        return tb.compareTo(ta); // mais recente primeiro
      });

      final recuperado = arquivos.first.path;
      final peritoCorrigido = PeritoModel(
        nome: perito.nome,
        matricula: perito.matricula,
        unidadePericial: perito.unidadePericial,
        cidade: perito.cidade,
        caminhoTemplate: recuperado,
      );

      // Persistir automaticamente a correção
      await salvarPerito(peritoCorrigido);
      return peritoCorrigido;
    } catch (_) {
      return perito;
    }
  }

  /// Verifica se já existe um perito cadastrado
  Future<bool> temPeritoCadastrado() async {
    final perito = await obterPerito();
    return perito != null;
  }
}

