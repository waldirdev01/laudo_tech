import 'tipo_equipe_policial.dart';
import 'membro_equipe_policial_model.dart';

/// Modelo para equipe policial/de salvamento em uma ficha
class EquipePolicialFichaModel {
  final TipoEquipePolicial tipo;
  final String? outrosTipo; // Se tipo for "outros", especificar qual
  final String? viaturaNumero; // Apenas para Polícia Militar
  final List<MembroEquipePolicialModel> membros;

  EquipePolicialFichaModel({
    required this.tipo,
    this.outrosTipo,
    this.viaturaNumero,
    this.membros = const [],
  });

  Map<String, dynamic> toJson() => {
        'tipo': tipo.name,
        'outrosTipo': outrosTipo,
        'viaturaNumero': viaturaNumero,
        'membros': membros.map((m) => m.toJson()).toList(),
      };

  factory EquipePolicialFichaModel.fromJson(Map<String, dynamic> json) {
    return EquipePolicialFichaModel(
      tipo: TipoEquipePolicial.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoEquipePolicial.policiaMilitar,
      ),
      outrosTipo: json['outrosTipo'] as String?,
      viaturaNumero: json['viaturaNumero'] as String?,
      membros: (json['membros'] as List<dynamic>?)
              ?.map((m) => MembroEquipePolicialModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

