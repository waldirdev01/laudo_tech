/// Modelo para uma evidência individual
class EvidenciaModel {
  final String id; // EV01, EV02, etc.
  final String identificacao; // Tipo de evidência (pré-definida)
  final String? descricao; // Descrição detalhada
  final String? coordenada1; // Coordenada 1 (referência ao marco zero)
  final String? coordenada2; // Coordenada 2 (referência ao marco zero)
  final bool? recolhidoSim;
  final bool? recolhidoNao;
  final String? observacoesEspeciais; // Para campos condicionais (altura, especificar, etc.)

  EvidenciaModel({
    required this.id,
    required this.identificacao,
    this.descricao,
    this.coordenada1,
    this.coordenada2,
    this.recolhidoSim,
    this.recolhidoNao,
    this.observacoesEspeciais,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'identificacao': identificacao,
        'descricao': descricao,
        'coordenada1': coordenada1,
        'coordenada2': coordenada2,
        'recolhidoSim': recolhidoSim,
        'recolhidoNao': recolhidoNao,
        'observacoesEspeciais': observacoesEspeciais,
      };

  factory EvidenciaModel.fromJson(Map<String, dynamic> json) => EvidenciaModel(
        id: json['id'] as String,
        identificacao: json['identificacao'] as String,
        descricao: json['descricao'] as String?,
        coordenada1: json['coordenada1'] as String?,
        coordenada2: json['coordenada2'] as String?,
        recolhidoSim: json['recolhidoSim'] as bool?,
        recolhidoNao: json['recolhidoNao'] as bool?,
        observacoesEspeciais: json['observacoesEspeciais'] as String?,
      );

  EvidenciaModel copyWith({
    String? id,
    String? identificacao,
    String? descricao,
    String? coordenada1,
    String? coordenada2,
    bool? recolhidoSim,
    bool? recolhidoNao,
    String? observacoesEspeciais,
  }) {
    return EvidenciaModel(
      id: id ?? this.id,
      identificacao: identificacao ?? this.identificacao,
      descricao: descricao ?? this.descricao,
      coordenada1: coordenada1 ?? this.coordenada1,
      coordenada2: coordenada2 ?? this.coordenada2,
      recolhidoSim: recolhidoSim ?? this.recolhidoSim,
      recolhidoNao: recolhidoNao ?? this.recolhidoNao,
      observacoesEspeciais: observacoesEspeciais ?? this.observacoesEspeciais,
    );
  }
}

/// Modelo para o marco zero (referência para coordenadas)
class MarcoZeroModel {
  final String? descricao; // Descrição do ponto de referência
  final String? coordenadaX; // Coordenada X do marco zero
  final String? coordenadaY; // Coordenada Y do marco zero

  MarcoZeroModel({
    this.descricao,
    this.coordenadaX,
    this.coordenadaY,
  });

  Map<String, dynamic> toJson() => {
        'descricao': descricao,
        'coordenadaX': coordenadaX,
        'coordenadaY': coordenadaY,
      };

  factory MarcoZeroModel.fromJson(Map<String, dynamic> json) => MarcoZeroModel(
        descricao: json['descricao'] as String?,
        coordenadaX: json['coordenadaX'] as String?,
        coordenadaY: json['coordenadaY'] as String?,
      );

  MarcoZeroModel copyWith({
    String? descricao,
    String? coordenadaX,
    String? coordenadaY,
  }) {
    return MarcoZeroModel(
      descricao: descricao ?? this.descricao,
      coordenadaX: coordenadaX ?? this.coordenadaX,
      coordenadaY: coordenadaY ?? this.coordenadaY,
    );
  }
}

/// Modelo para materiais apreendidos/encaminhados
class MaterialApreendidoModel {
  final String id;
  final String descricao;
  final bool isCustom; // Se foi adicionado pelo usuário
  final String? quantidade; // Quantidade (para meios de encaminhamento)
  final String? descricaoDetalhada; // Descrição detalhada (para materiais encontrados)

  MaterialApreendidoModel({
    required this.id,
    required this.descricao,
    this.isCustom = false,
    this.quantidade,
    this.descricaoDetalhada,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'descricao': descricao,
        'isCustom': isCustom,
        'quantidade': quantidade,
        'descricaoDetalhada': descricaoDetalhada,
      };

  factory MaterialApreendidoModel.fromJson(Map<String, dynamic> json) =>
      MaterialApreendidoModel(
        id: json['id'] as String,
        descricao: json['descricao'] as String,
        isCustom: json['isCustom'] as bool? ?? false,
        quantidade: json['quantidade'] as String?,
        descricaoDetalhada: json['descricaoDetalhada'] as String?,
      );

  MaterialApreendidoModel copyWith({
    String? id,
    String? descricao,
    bool? isCustom,
    String? quantidade,
    String? descricaoDetalhada,
  }) {
    return MaterialApreendidoModel(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      isCustom: isCustom ?? this.isCustom,
      quantidade: quantidade ?? this.quantidade,
      descricaoDetalhada: descricaoDetalhada ?? this.descricaoDetalhada,
    );
  }
}

/// Modelo completo para a seção de evidências
class EvidenciasFurtoModel {
  final MarcoZeroModel? marcoZero;
  final List<EvidenciaModel> evidencias;
  final List<MaterialApreendidoModel> materiaisApreendidos;

  EvidenciasFurtoModel({
    this.marcoZero,
    this.evidencias = const [],
    this.materiaisApreendidos = const [],
  });

  Map<String, dynamic> toJson() => {
        'marcoZero': marcoZero?.toJson(),
        'evidencias': evidencias.map((e) => e.toJson()).toList(),
        'materiaisApreendidos': materiaisApreendidos.map((m) => m.toJson()).toList(),
      };

  factory EvidenciasFurtoModel.fromJson(Map<String, dynamic> json) =>
      EvidenciasFurtoModel(
        marcoZero: json['marcoZero'] != null
            ? MarcoZeroModel.fromJson(json['marcoZero'] as Map<String, dynamic>)
            : null,
        evidencias: (json['evidencias'] as List<dynamic>?)
                ?.map((e) => EvidenciaModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        materiaisApreendidos: (json['materiaisApreendidos'] as List<dynamic>?)
                ?.map((m) => MaterialApreendidoModel.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );

  EvidenciasFurtoModel copyWith({
    MarcoZeroModel? marcoZero,
    List<EvidenciaModel>? evidencias,
    List<MaterialApreendidoModel>? materiaisApreendidos,
  }) {
    return EvidenciasFurtoModel(
      marcoZero: marcoZero ?? this.marcoZero,
      evidencias: evidencias ?? this.evidencias,
      materiaisApreendidos: materiaisApreendidos ?? this.materiaisApreendidos,
    );
  }
}

