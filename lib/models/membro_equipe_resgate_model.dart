/// Modelo para membro de equipe de resgate
class MembroEquipeResgateModel {
  final String id;
  final String nome;
  final String? cargo; // Ex: Médico, Enfermeiro, Técnico, etc.
  final String? matricula;
  final String? crm; // Apenas para médicos
  final String? unidadeNumero; // Número da unidade (CBM, SAMU, etc.)

  MembroEquipeResgateModel({
    required this.id,
    required this.nome,
    this.cargo,
    this.matricula,
    this.crm,
    this.unidadeNumero,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cargo': cargo,
        'matricula': matricula,
        'crm': crm,
        'unidadeNumero': unidadeNumero,
      };

  factory MembroEquipeResgateModel.fromJson(Map<String, dynamic> json) =>
      MembroEquipeResgateModel(
        id: json['id'] as String,
        nome: json['nome'] as String,
        cargo: json['cargo'] as String?,
        matricula: json['matricula'] as String?,
        crm: json['crm'] as String?,
        unidadeNumero: json['unidadeNumero'] as String?,
      );
}
