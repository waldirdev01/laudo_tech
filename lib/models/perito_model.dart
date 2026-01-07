/// Modelo de dados do perito criminal
class PeritoModel {
  final String nome;
  final String matricula;
  final String unidadePericial;
  final String cidade; // Cidade do perito
  final String? caminhoTemplate; // Caminho do template Word carregado

  PeritoModel({
    required this.nome,
    required this.matricula,
    required this.unidadePericial,
    required this.cidade,
    this.caminhoTemplate,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'matricula': matricula,
        'unidadePericial': unidadePericial,
        'cidade': cidade,
        'caminhoTemplate': caminhoTemplate,
      };

  factory PeritoModel.fromJson(Map<String, dynamic> json) => PeritoModel(
        nome: json['nome'] as String,
        matricula: json['matricula'] as String,
        unidadePericial: json['unidadePericial'] as String,
        cidade: json['cidade'] as String? ?? '',
        caminhoTemplate: json['caminhoTemplate'] as String?,
      );
}

