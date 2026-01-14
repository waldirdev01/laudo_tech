import 'dart:convert';

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
  final String? descricao;
  
  // Coordenadas (substitui posicionamento)
  final String? coordenadaX;
  final String? coordenadaY;
  
  // Altura em relação ao piso (opcional)
  final String? alturaRelacaoPiso;

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

  VestigioLocalModel({
    required this.id,
    this.descricao,
    this.coordenadaX,
    this.coordenadaY,
    this.alturaRelacaoPiso,
    this.tipoAcao,
    this.tipoDestino,
    this.destinoId,
    this.coletadoPor,
    this.dataHoraColeta,
    this.numeroLacre,
    this.isSangueHumano = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'descricao': descricao,
        'coordenadaX': coordenadaX,
        'coordenadaY': coordenadaY,
        'alturaRelacaoPiso': alturaRelacaoPiso,
        'tipoAcao': tipoAcao?.name,
        'tipoDestino': tipoDestino?.name,
        'destinoId': destinoId,
        'coletadoPor': coletadoPor,
        'dataHoraColeta': dataHoraColeta,
        'numeroLacre': numeroLacre,
        'isSangueHumano': isSangueHumano,
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
      descricao: json['descricao'] as String?,
      coordenadaX: json['coordenadaX'] as String?,
      coordenadaY: json['coordenadaY'] as String?,
      alturaRelacaoPiso: json['alturaRelacaoPiso'] as String?,
      tipoAcao: tipoAcao,
      tipoDestino: tipoDestino,
      destinoId: json['destinoId'] as String?,
      coletadoPor: json['coletadoPor'] as String?,
      dataHoraColeta: json['dataHoraColeta'] as String?,
      numeroLacre: json['numeroLacre'] as String?,
      isSangueHumano: (json['isSangueHumano'] as bool?) ?? false,
    );
  }

  VestigioLocalModel copyWith({
    String? id,
    String? descricao,
    String? coordenadaX,
    String? coordenadaY,
    String? alturaRelacaoPiso,
    TipoAcaoVestigio? tipoAcao,
    TipoDestinoVestigio? tipoDestino,
    String? destinoId,
    String? coletadoPor,
    String? dataHoraColeta,
    String? numeroLacre,
    bool? isSangueHumano,
  }) {
    return VestigioLocalModel(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      coordenadaX: coordenadaX ?? this.coordenadaX,
      coordenadaY: coordenadaY ?? this.coordenadaY,
      alturaRelacaoPiso: alturaRelacaoPiso ?? this.alturaRelacaoPiso,
      tipoAcao: tipoAcao ?? this.tipoAcao,
      tipoDestino: tipoDestino ?? this.tipoDestino,
      destinoId: destinoId ?? this.destinoId,
      coletadoPor: coletadoPor ?? this.coletadoPor,
      dataHoraColeta: dataHoraColeta ?? this.dataHoraColeta,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      isSangueHumano: isSangueHumano ?? this.isSangueHumano,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

