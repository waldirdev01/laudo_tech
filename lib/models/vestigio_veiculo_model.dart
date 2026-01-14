import 'dart:convert';

/// Tipo de ação com o vestígio
enum TipoAcaoVestigioVeiculo {
  registrado('Apenas Registrado'),
  coletado('Coletado');

  final String label;
  const TipoAcaoVestigioVeiculo(this.label);
}

/// Tipo de destino do vestígio coletado
enum TipoDestinoVestigioVeiculo {
  unidade('Unidade'),
  laboratorio('Laboratório');

  final String label;
  const TipoDestinoVestigioVeiculo(this.label);
}

/// Representa um vestígio associado a um veículo
class VestigioVeiculoModel {
  final String id;
  final String? descricao;
  
  // Localização no veículo (texto livre, sem coordenadas)
  final String? localizacao;

  // Tipo de ação
  final TipoAcaoVestigioVeiculo? tipoAcao; // registrado ou coletado

  // Se coletado: destino
  final TipoDestinoVestigioVeiculo? tipoDestino; // unidade ou laboratorio
  final String? destinoId; // ID da unidade ou laboratório

  // Dados da coleta
  final String? coletadoPor; // Perito (usuário)
  final String? dataHoraColeta;
  final String? numeroLacre; // Opcional

  // Flag para identificar sangue humano (para textos específicos no laudo)
  final bool isSangueHumano;

  VestigioVeiculoModel({
    required this.id,
    this.descricao,
    this.localizacao,
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
        'localizacao': localizacao,
        'tipoAcao': tipoAcao?.name,
        'tipoDestino': tipoDestino?.name,
        'destinoId': destinoId,
        'coletadoPor': coletadoPor,
        'dataHoraColeta': dataHoraColeta,
        'numeroLacre': numeroLacre,
        'isSangueHumano': isSangueHumano,
      };

  factory VestigioVeiculoModel.fromJson(Map<String, dynamic> json) {
    TipoAcaoVestigioVeiculo? tipoAcao;
    if (json['tipoAcao'] != null) {
      tipoAcao = TipoAcaoVestigioVeiculo.values.firstWhere(
        (e) => e.name == json['tipoAcao'],
        orElse: () => TipoAcaoVestigioVeiculo.registrado,
      );
    }

    TipoDestinoVestigioVeiculo? tipoDestino;
    if (json['tipoDestino'] != null) {
      tipoDestino = TipoDestinoVestigioVeiculo.values.firstWhere(
        (e) => e.name == json['tipoDestino'],
        orElse: () => TipoDestinoVestigioVeiculo.unidade,
      );
    }

    return VestigioVeiculoModel(
      id: json['id'] as String? ?? '',
      descricao: json['descricao'] as String?,
      localizacao: json['localizacao'] as String?,
      tipoAcao: tipoAcao,
      tipoDestino: tipoDestino,
      destinoId: json['destinoId'] as String?,
      coletadoPor: json['coletadoPor'] as String?,
      dataHoraColeta: json['dataHoraColeta'] as String?,
      numeroLacre: json['numeroLacre'] as String?,
      isSangueHumano: json['isSangueHumano'] as bool? ?? false,
    );
  }

  VestigioVeiculoModel copyWith({
    String? id,
    String? descricao,
    String? localizacao,
    TipoAcaoVestigioVeiculo? tipoAcao,
    TipoDestinoVestigioVeiculo? tipoDestino,
    String? destinoId,
    String? coletadoPor,
    String? dataHoraColeta,
    String? numeroLacre,
    bool? isSangueHumano,
  }) {
    return VestigioVeiculoModel(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      localizacao: localizacao ?? this.localizacao,
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
