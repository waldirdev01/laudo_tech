/// Modelo para unidade que recebe vestígios
class UnidadeModel {
  final String id;
  final String nome;
  final String? sigla;

  UnidadeModel({
    required this.id,
    required this.nome,
    this.sigla,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sigla': sigla,
      };

  factory UnidadeModel.fromJson(Map<String, dynamic> json) => UnidadeModel(
        id: json['id'] as String,
        nome: json['nome'] as String,
        sigla: json['sigla'] as String?,
      );

  UnidadeModel copyWith({
    String? id,
    String? nome,
    String? sigla,
  }) {
    return UnidadeModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      sigla: sigla ?? this.sigla,
    );
  }
}
