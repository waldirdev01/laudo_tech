import 'membro_equipe_resgate_model.dart';

/// Tipo de equipe de resgate
enum TipoEquipeResgate {
  cbm('CBM - Corpo de Bombeiros Militar'),
  samu('SAMU - Serviço de Atendimento Móvel de Urgência'),
  outros('Outros');

  final String label;
  const TipoEquipeResgate(this.label);
}

/// Modelo para equipe de resgate em uma ficha
class EquipeResgateModel {
  final TipoEquipeResgate tipo;
  final String? outrosTipo; // Se tipo for "outros", especificar qual
  final String? unidadeNumero; // Número da unidade
  final List<MembroEquipeResgateModel> membros;
  final bool naoEstavaNoLocal; // Indica se não estava no local, mas esteve presente

  EquipeResgateModel({
    required this.tipo,
    this.outrosTipo,
    this.unidadeNumero,
    this.membros = const [],
    this.naoEstavaNoLocal = false,
  });

  Map<String, dynamic> toJson() => {
        'tipo': tipo.name,
        'outrosTipo': outrosTipo,
        'unidadeNumero': unidadeNumero,
        'membros': membros.map((m) => m.toJson()).toList(),
        'naoEstavaNoLocal': naoEstavaNoLocal,
      };

  factory EquipeResgateModel.fromJson(Map<String, dynamic> json) {
    return EquipeResgateModel(
      tipo: TipoEquipeResgate.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoEquipeResgate.cbm,
      ),
      outrosTipo: json['outrosTipo'] as String?,
      unidadeNumero: json['unidadeNumero'] as String?,
      membros: (json['membros'] as List<dynamic>?)
              ?.map((m) => MembroEquipeResgateModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      naoEstavaNoLocal: json['naoEstavaNoLocal'] as bool? ?? false,
    );
  }
}
