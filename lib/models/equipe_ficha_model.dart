/// Modelo para equipe selecionada em uma ficha específica
class EquipeFichaModel {
  final String? peritoCriminalId; // ID do membro selecionado como Perito Criminal
  final String? fotografoCriminalisticoId; // ID do membro selecionado como Fotógrafo
  final List<String> demaisServidoresIds; // Lista de IDs dos demais servidores

  EquipeFichaModel({
    this.peritoCriminalId,
    this.fotografoCriminalisticoId,
    this.demaisServidoresIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'peritoCriminalId': peritoCriminalId,
        'fotografoCriminalisticoId': fotografoCriminalisticoId,
        'demaisServidoresIds': demaisServidoresIds,
      };

  factory EquipeFichaModel.fromJson(Map<String, dynamic> json) =>
      EquipeFichaModel(
        peritoCriminalId: json['peritoCriminalId'] as String?,
        fotografoCriminalisticoId: json['fotografoCriminalisticoId'] as String?,
        demaisServidoresIds: (json['demaisServidoresIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  EquipeFichaModel copyWith({
    String? peritoCriminalId,
    String? fotografoCriminalisticoId,
    List<String>? demaisServidoresIds,
  }) {
    return EquipeFichaModel(
      peritoCriminalId: peritoCriminalId ?? this.peritoCriminalId,
      fotografoCriminalisticoId:
          fotografoCriminalisticoId ?? this.fotografoCriminalisticoId,
      demaisServidoresIds: demaisServidoresIds ?? this.demaisServidoresIds,
    );
  }
}

