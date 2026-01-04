/// Modelo para dados do local da ocorrência
class LocalFichaModel {
  final String? endereco;
  final String? municipio;
  final double? latitude; // Coordenada S (Sul) em formato decimal
  final double? longitude; // Coordenada W (Oeste) em formato decimal

  LocalFichaModel({
    this.endereco,
    this.municipio,
    this.latitude,
    this.longitude,
  });

  /// Converte coordenadas decimais para formato DMS (Graus, Minutos, Segundos)
  String? get coordenadasSFormatada {
    if (latitude == null) return null;
    return _converterParaDMS(latitude!.abs(), 'S');
  }

  String? get coordenadasWFormatada {
    if (longitude == null) return null;
    return _converterParaDMS(longitude!.abs(), 'W');
  }

  String _converterParaDMS(double decimal, String direcao) {
    final graus = decimal.floor();
    final minutosDecimal = (decimal - graus) * 60;
    final minutos = minutosDecimal.floor();
    final segundos = ((minutosDecimal - minutos) * 60).toStringAsFixed(2);
    
    return '$direcao: $graus° $minutos\' $segundos"';
  }

  Map<String, dynamic> toJson() => {
        'endereco': endereco,
        'municipio': municipio,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LocalFichaModel.fromJson(Map<String, dynamic> json) =>
      LocalFichaModel(
        endereco: json['endereco'] as String?,
        municipio: json['municipio'] as String?,
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      );

  LocalFichaModel copyWith({
    String? endereco,
    String? municipio,
    double? latitude,
    double? longitude,
  }) {
    return LocalFichaModel(
      endereco: endereco ?? this.endereco,
      municipio: municipio ?? this.municipio,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

