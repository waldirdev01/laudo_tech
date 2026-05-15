import 'dart:convert';

import '../utils/coordinate_formatter.dart';
import 'metodo_posicionamento_model.dart';

/// Tipo de ação com o vestígio
enum TipoAcaoVestigio {
  registrado('Apenas Registrado'),
  coletado('Coletado');

  final String label;
  const TipoAcaoVestigio(this.label);
}

/// Tipo de destino do vestígio coletado
enum TipoDestinoVestigio {
  unidade('Unidade'),
  laboratorio('Laboratório');

  final String label;
  const TipoDestinoVestigio(this.label);
}

/// Representa um vestígio associado a um dos locais (mediato, imediato ou relacionado).
class VestigioLocalModel {
  final String id;

  /// Nome ou título curto do vestígio (opcional), para identificação rápida.
  final String? nome;

  final String? descricao;

  // Ambiente do local imediato ao qual o vestígio está vinculado.
  final String? ambiente;

  // Coordenadas (substitui posicionamento)
  final String? coordenadaX;
  final String? coordenadaY;

  // Altura em relação ao piso (opcional)
  final String? alturaRelacaoPiso;

  // Posicionamento geográfico opcional
  final double? latitude;
  final double? longitude;
  final double? precisaoGpsMetros;
  final DateTime? gpsCapturadoEm;

  // Permite exceção ao método de posicionamento definido no escopo.
  final MetodoPosicionamentoVestigio? metodoPosicionamentoOverride;

  // Tipo de ação
  final TipoAcaoVestigio? tipoAcao; // registrado ou coletado

  // Se coletado: destino
  final TipoDestinoVestigio? tipoDestino; // unidade ou laboratorio
  final String? destinoId; // ID da unidade ou laboratório

  // Dados da coleta
  final String? coletadoPor; // Perito (usuário)
  final String? dataHoraColeta;
  final String? numeroLacre; // Opcional

  // Flag para identificar sangue humano (para textos específicos no laudo)
  final bool isSangueHumano;

  // Números das fotografias do levantamento fotográfico vinculadas ao vestígio.
  // Exemplo: [3, 5, 6] => (fotos 03, 05 e 06)
  final List<int> numerosFotografias;

  // Caminhos das fotografias vinculadas ao vestígio.
  // A numeração do laudo é resolvida automaticamente pela ordem em fotosLevantamento.
  final List<String> fotosVinculadasPaths;

  VestigioLocalModel({
    required this.id,
    this.nome,
    this.descricao,
    this.ambiente,
    this.coordenadaX,
    this.coordenadaY,
    this.alturaRelacaoPiso,
    this.latitude,
    this.longitude,
    this.precisaoGpsMetros,
    this.gpsCapturadoEm,
    this.metodoPosicionamentoOverride,
    this.tipoAcao,
    this.tipoDestino,
    this.destinoId,
    this.coletadoPor,
    this.dataHoraColeta,
    this.numeroLacre,
    this.isSangueHumano = false,
    this.numerosFotografias = const [],
    this.fotosVinculadasPaths = const [],
  });

  /// Nome + descrição para textos de laudo, Word e legendas de foto.
  String get rotuloNomeDescricao {
    final n = nome?.trim() ?? '';
    final d = (descricao ?? '').trim();
    if (n.isEmpty) return d;
    if (d.isEmpty) return n;
    return '$n, $d';
  }

  String? get latitudeFormatada => CoordinateFormatter.formatLatitude(latitude);

  String? get longitudeFormatada =>
      CoordinateFormatter.formatLongitude(longitude);

  String? get coordenadasGpsFormatadas => CoordinateFormatter.formatPair(
    latitude: latitudeFormatada,
    longitude: longitudeFormatada,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'descricao': descricao,
    'ambiente': ambiente,
    'coordenadaX': coordenadaX,
    'coordenadaY': coordenadaY,
    'alturaRelacaoPiso': alturaRelacaoPiso,
    'latitude': latitude,
    'longitude': longitude,
    'precisaoGpsMetros': precisaoGpsMetros,
    'gpsCapturadoEm': gpsCapturadoEm?.toIso8601String(),
    'metodoPosicionamentoOverride': metodoPosicionamentoOverride?.name,
    'tipoAcao': tipoAcao?.name,
    'tipoDestino': tipoDestino?.name,
    'destinoId': destinoId,
    'coletadoPor': coletadoPor,
    'dataHoraColeta': dataHoraColeta,
    'numeroLacre': numeroLacre,
    'isSangueHumano': isSangueHumano,
    'numerosFotografias': numerosFotografias,
    'fotosVinculadasPaths': fotosVinculadasPaths,
  };

  factory VestigioLocalModel.fromJson(Map<String, dynamic> json) {
    TipoAcaoVestigio? tipoAcao;
    if (json['tipoAcao'] != null) {
      tipoAcao = TipoAcaoVestigio.values.firstWhere(
        (e) => e.name == json['tipoAcao'],
        orElse: () => TipoAcaoVestigio.registrado,
      );
    }

    TipoDestinoVestigio? tipoDestino;
    if (json['tipoDestino'] != null) {
      tipoDestino = TipoDestinoVestigio.values.firstWhere(
        (e) => e.name == json['tipoDestino'],
        orElse: () => TipoDestinoVestigio.unidade,
      );
    }

    return VestigioLocalModel(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String?,
      descricao: json['descricao'] as String?,
      ambiente: json['ambiente'] as String?,
      coordenadaX: json['coordenadaX'] as String?,
      coordenadaY: json['coordenadaY'] as String?,
      alturaRelacaoPiso: json['alturaRelacaoPiso'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      precisaoGpsMetros: (json['precisaoGpsMetros'] as num?)?.toDouble(),
      gpsCapturadoEm: json['gpsCapturadoEm'] != null
          ? DateTime.tryParse(json['gpsCapturadoEm'] as String)
          : null,
      metodoPosicionamentoOverride: MetodoPosicionamentoVestigio.fromName(
        json['metodoPosicionamentoOverride'] as String?,
      ),
      tipoAcao: tipoAcao,
      tipoDestino: tipoDestino,
      destinoId: json['destinoId'] as String?,
      coletadoPor: json['coletadoPor'] as String?,
      dataHoraColeta: json['dataHoraColeta'] as String?,
      numeroLacre: json['numeroLacre'] as String?,
      isSangueHumano: (json['isSangueHumano'] as bool?) ?? false,
      numerosFotografias:
          (json['numerosFotografias'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      fotosVinculadasPaths:
          (json['fotosVinculadasPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  VestigioLocalModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? ambiente,
    String? coordenadaX,
    String? coordenadaY,
    String? alturaRelacaoPiso,
    double? latitude,
    double? longitude,
    double? precisaoGpsMetros,
    DateTime? gpsCapturadoEm,
    MetodoPosicionamentoVestigio? metodoPosicionamentoOverride,
    TipoAcaoVestigio? tipoAcao,
    TipoDestinoVestigio? tipoDestino,
    String? destinoId,
    String? coletadoPor,
    String? dataHoraColeta,
    String? numeroLacre,
    bool? isSangueHumano,
    List<int>? numerosFotografias,
    List<String>? fotosVinculadasPaths,
  }) {
    return VestigioLocalModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      ambiente: ambiente ?? this.ambiente,
      coordenadaX: coordenadaX ?? this.coordenadaX,
      coordenadaY: coordenadaY ?? this.coordenadaY,
      alturaRelacaoPiso: alturaRelacaoPiso ?? this.alturaRelacaoPiso,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      precisaoGpsMetros: precisaoGpsMetros ?? this.precisaoGpsMetros,
      gpsCapturadoEm: gpsCapturadoEm ?? this.gpsCapturadoEm,
      metodoPosicionamentoOverride:
          metodoPosicionamentoOverride ?? this.metodoPosicionamentoOverride,
      tipoAcao: tipoAcao ?? this.tipoAcao,
      tipoDestino: tipoDestino ?? this.tipoDestino,
      destinoId: destinoId ?? this.destinoId,
      coletadoPor: coletadoPor ?? this.coletadoPor,
      dataHoraColeta: dataHoraColeta ?? this.dataHoraColeta,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      isSangueHumano: isSangueHumano ?? this.isSangueHumano,
      numerosFotografias: numerosFotografias ?? this.numerosFotografias,
      fotosVinculadasPaths: fotosVinculadasPaths ?? this.fotosVinculadasPaths,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
