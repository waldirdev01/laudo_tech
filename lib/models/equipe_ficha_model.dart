/// Modelo para equipe selecionada em uma ficha específica
class EquipeFichaModel {
  final String?
      peritoCriminalId; // ID do membro selecionado como Perito Criminal
  final List<String> demaisServidoresIds; // Lista de IDs dos demais servidores

  EquipeFichaModel({
    this.peritoCriminalId,
    this.demaisServidoresIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'peritoCriminalId': peritoCriminalId,
        'demaisServidoresIds': demaisServidoresIds,
      };

  factory EquipeFichaModel.fromJson(Map<String, dynamic> json) =>
      EquipeFichaModel(
        peritoCriminalId: json['peritoCriminalId'] as String?,
        demaisServidoresIds: (() {
          final ids = <String>{
            ...(json['demaisServidoresIds'] as List<dynamic>? ?? const [])
                .map((e) => e as String),
          };
          final fotografo =
              (json['fotografoCriminalisticoId'] as String?)?.trim();
          if (fotografo != null && fotografo.isNotEmpty) {
            ids.add(fotografo);
          }
          return ids.toList();
        })(),
      );

  EquipeFichaModel copyWith({
    String? peritoCriminalId,
    List<String>? demaisServidoresIds,
  }) {
    return EquipeFichaModel(
      peritoCriminalId: peritoCriminalId ?? this.peritoCriminalId,
      demaisServidoresIds: demaisServidoresIds ?? this.demaisServidoresIds,
    );
  }
}
