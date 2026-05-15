import '../models/equipe_resgate_model.dart';
import '../models/tipo_equipe_policial.dart';

class EquipeHierarchy {
  static const List<String> graduacoesMilitaresBaixoParaCima = [
    'Soldado',
    'Cabo',
    '3º Sargento',
    '2º Sargento',
    '1º Sargento',
    'Subtenente',
    'Aspirante a Oficial',
    '2º Tenente',
    '1º Tenente',
    'Capitão',
    'Major',
    'Tenente-Coronel',
    'Coronel',
  ];

  static const List<String> cargosPoliciaCivil = [
    'Agente',
    'Escrivão',
    'Papiloscopista',
    'Delegado',
  ];

  static int ordemQualificacaoPolicial(
    TipoEquipePolicial tipo,
    String? qualificacao,
  ) {
    final valor = (qualificacao ?? '').trim();
    if (valor.isEmpty) return 999;

    switch (tipo) {
      case TipoEquipePolicial.policiaMilitar:
        return _ordemEmLista(graduacoesMilitaresBaixoParaCima, valor);
      case TipoEquipePolicial.policiaCivil:
        return _ordemEmLista(cargosPoliciaCivil, valor);
      case TipoEquipePolicial.prf:
      case TipoEquipePolicial.gcm:
      case TipoEquipePolicial.outros:
        return 999;
    }
  }

  static int ordemQualificacaoResgate(
    TipoEquipeResgate tipo,
    String? qualificacao,
  ) {
    if (tipo != TipoEquipeResgate.cbm) return 999;
    return _ordemEmLista(graduacoesMilitaresBaixoParaCima, qualificacao ?? '');
  }

  static int _ordemEmLista(List<String> itens, String valor) {
    final normalizado = _normalizar(valor);
    for (var i = 0; i < itens.length; i++) {
      if (_normalizar(itens[i]) == normalizado) return i;
    }
    return 999;
  }

  static String _normalizar(String valor) {
    return valor
        .toLowerCase()
        .replaceAll('º', '')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
