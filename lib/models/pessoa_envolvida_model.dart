/// Modelo para pessoa envolvida na ocorrência
class PessoaEnvolvidaModel {
  final String nome;
  final TipoPessoa tipo;

  PessoaEnvolvidaModel({
    required this.nome,
    required this.tipo,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'tipo': tipo.name,
      };

  factory PessoaEnvolvidaModel.fromJson(Map<String, dynamic> json) =>
      PessoaEnvolvidaModel(
        nome: json['nome'] as String,
        tipo: TipoPessoa.values.firstWhere(
          (e) => e.name == json['tipo'],
          orElse: () => TipoPessoa.outro,
        ),
      );
}

enum TipoPessoa {
  autor,
  vitima,
  vitimaComunicante,
  comunicante,
  outro,
}

