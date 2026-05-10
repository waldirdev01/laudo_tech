import '../utils/coordinate_formatter.dart';

/// Modelo para dados do local da ocorrência
class LocalFichaModel {
  final String? endereco;
  final String? municipio;
  final double? latitude; // Coordenada S (Sul) em formato decimal
  final double? longitude; // Coordenada W (Oeste) em formato decimal
  /// Caminho local da imagem de captura de tela do mapa (para incluir no laudo).
  final String? capturaTelaLocalPath;

  LocalFichaModel({
    this.endereco,
    this.municipio,
    this.latitude,
    this.longitude,
    this.capturaTelaLocalPath,
  });

  String? get coordenadasSFormatada {
    return CoordinateFormatter.formatLatitude(latitude);
  }

  String? get coordenadasWFormatada {
    return CoordinateFormatter.formatLongitude(longitude);
  }

  String? get coordenadasFormatadas {
    return CoordinateFormatter.formatPair(
      latitude: coordenadasSFormatada,
      longitude: coordenadasWFormatada,
    );
  }

  Map<String, dynamic> toJson() => {
    'endereco': endereco,
    'municipio': municipio,
    'latitude': latitude,
    'longitude': longitude,
    'capturaTelaLocalPath': capturaTelaLocalPath,
  };

  factory LocalFichaModel.fromJson(Map<String, dynamic> json) =>
      LocalFichaModel(
        endereco: json['endereco'] as String?,
        municipio: json['municipio'] as String?,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        capturaTelaLocalPath: json['capturaTelaLocalPath'] as String?,
      );

  LocalFichaModel copyWith({
    String? endereco,
    String? municipio,
    double? latitude,
    double? longitude,
    String? capturaTelaLocalPath,
  }) {
    return LocalFichaModel(
      endereco: endereco ?? this.endereco,
      municipio: municipio ?? this.municipio,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capturaTelaLocalPath: capturaTelaLocalPath ?? this.capturaTelaLocalPath,
    );
  }
}
