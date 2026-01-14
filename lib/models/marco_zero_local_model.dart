/// Representa o marco zero de um local (mediato, imediato ou relacionado)
class MarcoZeroLocalModel {
  final String? descricao;
  final String? coordenadaX;
  final String? coordenadaY;

  MarcoZeroLocalModel({
    this.descricao,
    this.coordenadaX,
    this.coordenadaY,
  });

  Map<String, dynamic> toJson() => {
        'descricao': descricao,
        'coordenadaX': coordenadaX,
        'coordenadaY': coordenadaY,
      };

  factory MarcoZeroLocalModel.fromJson(Map<String, dynamic> json) => MarcoZeroLocalModel(
        descricao: json['descricao'] as String?,
        coordenadaX: json['coordenadaX'] as String?,
        coordenadaY: json['coordenadaY'] as String?,
      );

  MarcoZeroLocalModel copyWith({
    String? descricao,
    String? coordenadaX,
    String? coordenadaY,
  }) {
    return MarcoZeroLocalModel(
      descricao: descricao ?? this.descricao,
      coordenadaX: coordenadaX ?? this.coordenadaX,
      coordenadaY: coordenadaY ?? this.coordenadaY,
    );
  }
}
