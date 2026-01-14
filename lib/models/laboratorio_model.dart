/// Modelo para laboratório que recebe vestígios
class LaboratorioModel {
  final String id;
  final String nome;
  final String? sigla;

  LaboratorioModel({
    required this.id,
    required this.nome,
    this.sigla,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sigla': sigla,
      };

  factory LaboratorioModel.fromJson(Map<String, dynamic> json) => LaboratorioModel(
        id: json['id'] as String,
        nome: json['nome'] as String,
        sigla: json['sigla'] as String?,
      );

  LaboratorioModel copyWith({
    String? id,
    String? nome,
    String? sigla,
  }) {
    return LaboratorioModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      sigla: sigla ?? this.sigla,
    );
  }
}
