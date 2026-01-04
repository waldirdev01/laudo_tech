/// Modelo para membro da equipe de perícia
class MembroEquipeModel {
  final String id;
  final String cargo;
  final String nome;
  final String matricula;

  MembroEquipeModel({
    required this.id,
    required this.cargo,
    required this.nome,
    required this.matricula,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cargo': cargo,
        'nome': nome,
        'matricula': matricula,
      };

  factory MembroEquipeModel.fromJson(Map<String, dynamic> json) =>
      MembroEquipeModel(
        id: json['id'] as String,
        cargo: json['cargo'] as String,
        nome: json['nome'] as String,
        matricula: json['matricula'] as String,
      );
}

/// Cargos possíveis na equipe
enum CargoEquipe {
  peritoCriminal('Perito Criminal'),
  fotografoCriminalistico('Fotógrafo Criminalístico'),
  demaisServidores('Demais Servidores Policiais');

  final String label;
  const CargoEquipe(this.label);
}

