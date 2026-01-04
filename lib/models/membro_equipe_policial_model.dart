/// Modelo para membro de equipe policial/de salvamento
class MembroEquipePolicialModel {
  final String id;
  final String nome;
  final String matricula;
  final String? postoGraduacao; // Apenas para Polícia Militar

  MembroEquipePolicialModel({
    required this.id,
    required this.nome,
    required this.matricula,
    this.postoGraduacao,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'matricula': matricula,
        'postoGraduacao': postoGraduacao,
      };

  factory MembroEquipePolicialModel.fromJson(Map<String, dynamic> json) =>
      MembroEquipePolicialModel(
        id: json['id'] as String,
        nome: json['nome'] as String,
        matricula: json['matricula'] as String,
        postoGraduacao: json['postoGraduacao'] as String?,
      );
}

