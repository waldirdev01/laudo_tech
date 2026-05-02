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

  /// Nome ou título curto (opcional), para identificação no laudo e legendas.
  final String? nome;

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

  /// Fotos vinculadas a este vestígio (paths locais).
  final List<String> fotosPaths;

  /// Números das fotografias no anexo do laudo (preenchido na geração do laudo).
  final List<int>? numerosFotografias;

  VestigioVeiculoModel({
    required this.id,
    this.nome,
    this.descricao,
    this.localizacao,
    this.tipoAcao,
    this.tipoDestino,
    this.destinoId,
    this.coletadoPor,
    this.dataHoraColeta,
    this.numeroLacre,
    this.isSangueHumano = false,
    this.fotosPaths = const [],
    this.numerosFotografias,
  });

  /// Nome + descrição (traço longo), para tabelas e resumos.
  String get rotuloNomeDescricao {
    final n = nome?.trim() ?? '';
    final d = (descricao ?? '').trim();
    if (n.isEmpty) return d;
    if (d.isEmpty) return n;
    return '$n — $d';
  }

  /// Texto corrido para legenda de foto: descrição/nome + local no veículo.
  String get textoLegendaFoto {
    final r = rotuloNomeDescricao;
    final l = (localizacao ?? '').trim();
    if (r.isEmpty && l.isEmpty) return 'vestígio';
    if (l.isEmpty) return r;
    if (r.isEmpty) return l;
    return '$r, no veículo em $l';
  }

  /// Descrição + localização para células Word (uma frase).
  String get textoDescricaoLocalWord {
    final r = rotuloNomeDescricao;
    final l = (localizacao ?? '').trim();
    if (r.isEmpty && l.isEmpty) return '';
    if (l.isEmpty) return r;
    if (r.isEmpty) return 'Localização: $l';
    return '$r. Localização no veículo: $l';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'descricao': descricao,
        'localizacao': localizacao,
        'tipoAcao': tipoAcao?.name,
        'tipoDestino': tipoDestino?.name,
        'destinoId': destinoId,
        'coletadoPor': coletadoPor,
        'dataHoraColeta': dataHoraColeta,
        'numeroLacre': numeroLacre,
        'isSangueHumano': isSangueHumano,
        'fotosPaths': fotosPaths,
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
      nome: json['nome'] as String?,
      descricao: json['descricao'] as String?,
      localizacao: json['localizacao'] as String?,
      tipoAcao: tipoAcao,
      tipoDestino: tipoDestino,
      destinoId: json['destinoId'] as String?,
      coletadoPor: json['coletadoPor'] as String?,
      dataHoraColeta: json['dataHoraColeta'] as String?,
      numeroLacre: json['numeroLacre'] as String?,
      isSangueHumano: json['isSangueHumano'] as bool? ?? false,
      fotosPaths: (json['fotosPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  VestigioVeiculoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? localizacao,
    TipoAcaoVestigioVeiculo? tipoAcao,
    TipoDestinoVestigioVeiculo? tipoDestino,
    String? destinoId,
    String? coletadoPor,
    String? dataHoraColeta,
    String? numeroLacre,
    bool? isSangueHumano,
    List<String>? fotosPaths,
    List<int>? numerosFotografias,
  }) {
    return VestigioVeiculoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      localizacao: localizacao ?? this.localizacao,
      tipoAcao: tipoAcao ?? this.tipoAcao,
      tipoDestino: tipoDestino ?? this.tipoDestino,
      destinoId: destinoId ?? this.destinoId,
      coletadoPor: coletadoPor ?? this.coletadoPor,
      dataHoraColeta: dataHoraColeta ?? this.dataHoraColeta,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      isSangueHumano: isSangueHumano ?? this.isSangueHumano,
      fotosPaths: fotosPaths ?? this.fotosPaths,
      numerosFotografias: numerosFotografias ?? this.numerosFotografias,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
