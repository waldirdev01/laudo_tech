enum TipoExameComplementar {
  necroscopico('Exame necroscópico'),
  balistico('Exame balístico'),
  pesquisaDna('Pesquisa por DNA'),
  analiseImpressoesPapilares('Análise de fragmentos de impressões papilares'),
  caracterizacaoObjetos('Caracterização de objetos'),
  caracterizacaoElementosMunicao('Caracterização de elementos de munição'),
  outro('Outro');

  final String label;
  const TipoExameComplementar(this.label);
}

enum TipoDestinoExameComplementar {
  unidade('Unidade'),
  laboratorio('Laboratório');

  final String label;
  const TipoDestinoExameComplementar(this.label);
}

class ExameComplementarModel {
  final String id;
  final TipoExameComplementar tipo;
  final String? nomePersonalizado;
  final bool solicitado;
  final TipoDestinoExameComplementar? tipoDestino;
  final String? destinoId;
  final String? destinoNome;
  final String? observacao;

  ExameComplementarModel({
    required this.id,
    required this.tipo,
    this.nomePersonalizado,
    this.solicitado = false,
    this.tipoDestino,
    this.destinoId,
    this.destinoNome,
    this.observacao,
  });

  String get nomeExibicao {
    if (tipo == TipoExameComplementar.outro) {
      final nome = nomePersonalizado?.trim() ?? '';
      if (nome.isNotEmpty) return nome;
    }
    return tipo.label;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'nomePersonalizado': nomePersonalizado,
    'solicitado': solicitado,
    'tipoDestino': tipoDestino?.name,
    'destinoId': destinoId,
    'destinoNome': destinoNome,
    'observacao': observacao,
  };

  factory ExameComplementarModel.fromJson(Map<String, dynamic> json) {
    TipoExameComplementar tipo = TipoExameComplementar.outro;
    if (json['tipo'] != null) {
      tipo = TipoExameComplementar.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoExameComplementar.outro,
      );
    }

    TipoDestinoExameComplementar? tipoDestino;
    if (json['tipoDestino'] != null) {
      tipoDestino = TipoDestinoExameComplementar.values.firstWhere(
        (e) => e.name == json['tipoDestino'],
        orElse: () => TipoDestinoExameComplementar.unidade,
      );
    }

    return ExameComplementarModel(
      id: json['id'] as String,
      tipo: tipo,
      nomePersonalizado: json['nomePersonalizado'] as String?,
      solicitado: json['solicitado'] as bool? ?? false,
      tipoDestino: tipoDestino,
      destinoId: json['destinoId'] as String?,
      destinoNome: json['destinoNome'] as String?,
      observacao: json['observacao'] as String?,
    );
  }

  ExameComplementarModel copyWith({
    String? id,
    TipoExameComplementar? tipo,
    String? nomePersonalizado,
    bool? solicitado,
    TipoDestinoExameComplementar? tipoDestino,
    String? destinoId,
    String? destinoNome,
    String? observacao,
  }) {
    return ExameComplementarModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      nomePersonalizado: nomePersonalizado ?? this.nomePersonalizado,
      solicitado: solicitado ?? this.solicitado,
      tipoDestino: tipoDestino ?? this.tipoDestino,
      destinoId: destinoId ?? this.destinoId,
      destinoNome: destinoNome ?? this.destinoNome,
      observacao: observacao ?? this.observacao,
    );
  }
}
