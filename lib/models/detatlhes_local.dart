import 'vestigio_local_model.dart';
import 'marco_zero_local_model.dart';

/// Modelo para dados do local específico de furto/dano
class LocalFurtoModel {
  // Classificação
  final bool? classificacaoMediato;
  final bool? classificacaoImediato;
  final bool? classificacaoRelacionado;

  // Condições do Piso - Mediato
  final bool? pisoSecoMediato;
  final bool? pisoUmidoMediato;
  final bool? pisoMolhadoMediato;
  
  // Iluminação - Mediato
  final bool? iluminacaoArtificialMediato;
  final bool? iluminacaoNaturalMediato;
  final bool? iluminacaoAusenteMediato;

  // Condições do Piso - Imediato
  final bool? pisoSecoImediato;
  final bool? pisoUmidoImediato;
  final bool? pisoMolhadoImediato;
  
  // Iluminação - Imediato
  final bool? iluminacaoArtificialImediato;
  final bool? iluminacaoNaturalImediato;
  final bool? iluminacaoAusenteImediato;

  // Condições do Piso - Relacionado
  final bool? pisoSecoRelacionado;
  final bool? pisoUmidoRelacionado;
  final bool? pisoMolhadoRelacionado;
  
  // Iluminação - Relacionado
  final bool? iluminacaoArtificialRelacionado;
  final bool? iluminacaoNaturalRelacionado;
  final bool? iluminacaoAusenteRelacionado;

  // Descrições
  final String? descricaoViasAcesso;
  final String? sinaisArrombamentoDescricao;
  final String? descricaoLocal;
  final String? demaisObservacoes;

  // Descrições detalhadas por local
  final String? descricaoLocalMediato;
  final String? descricaoLocalImediato;
  final String? descricaoLocalRelacionado;

  // Marco Zero por local
  final MarcoZeroLocalModel? marcoZeroMediato;
  final MarcoZeroLocalModel? marcoZeroImediato;
  final MarcoZeroLocalModel? marcoZeroRelacionado;

  // Vestígios por local
  final List<VestigioLocalModel>? vestigiosMediato;
  final List<VestigioLocalModel>? vestigiosImediato;
  final List<VestigioLocalModel>? vestigiosRelacionado;

  // Flags de "sem vestígios"
  final bool? semVestigiosMediato;
  final bool? semVestigiosImediato;
  final bool? semVestigiosRelacionado;

  // Sinais de Arrombamento
  final bool? sinaisArrombamentoSim;
  final bool? sinaisArrombamentoNao;
  final bool? sinaisArrombamentoNaoSeAplica;

  LocalFurtoModel({
    this.classificacaoMediato,
    this.classificacaoImediato,
    this.classificacaoRelacionado,
    this.pisoSecoMediato,
    this.pisoUmidoMediato,
    this.pisoMolhadoMediato,
    this.iluminacaoArtificialMediato,
    this.iluminacaoNaturalMediato,
    this.iluminacaoAusenteMediato,
    this.pisoSecoImediato,
    this.pisoUmidoImediato,
    this.pisoMolhadoImediato,
    this.iluminacaoArtificialImediato,
    this.iluminacaoNaturalImediato,
    this.iluminacaoAusenteImediato,
    this.pisoSecoRelacionado,
    this.pisoUmidoRelacionado,
    this.pisoMolhadoRelacionado,
    this.iluminacaoArtificialRelacionado,
    this.iluminacaoNaturalRelacionado,
    this.iluminacaoAusenteRelacionado,
    this.descricaoViasAcesso,
    this.sinaisArrombamentoDescricao,
    this.descricaoLocal,
    this.demaisObservacoes,
    this.descricaoLocalMediato,
    this.descricaoLocalImediato,
    this.descricaoLocalRelacionado,
    this.marcoZeroMediato,
    this.marcoZeroImediato,
    this.marcoZeroRelacionado,
    this.vestigiosMediato,
    this.vestigiosImediato,
    this.vestigiosRelacionado,
    this.semVestigiosMediato,
    this.semVestigiosImediato,
    this.semVestigiosRelacionado,
    this.sinaisArrombamentoSim,
    this.sinaisArrombamentoNao,
    this.sinaisArrombamentoNaoSeAplica,
  });

  Map<String, dynamic> toJson() => {
        'classificacaoMediato': classificacaoMediato,
        'classificacaoImediato': classificacaoImediato,
        'classificacaoRelacionado': classificacaoRelacionado,
        'pisoSecoMediato': pisoSecoMediato,
        'pisoUmidoMediato': pisoUmidoMediato,
        'pisoMolhadoMediato': pisoMolhadoMediato,
        'iluminacaoArtificialMediato': iluminacaoArtificialMediato,
        'iluminacaoNaturalMediato': iluminacaoNaturalMediato,
        'iluminacaoAusenteMediato': iluminacaoAusenteMediato,
        'pisoSecoImediato': pisoSecoImediato,
        'pisoUmidoImediato': pisoUmidoImediato,
        'pisoMolhadoImediato': pisoMolhadoImediato,
        'iluminacaoArtificialImediato': iluminacaoArtificialImediato,
        'iluminacaoNaturalImediato': iluminacaoNaturalImediato,
        'iluminacaoAusenteImediato': iluminacaoAusenteImediato,
        'pisoSecoRelacionado': pisoSecoRelacionado,
        'pisoUmidoRelacionado': pisoUmidoRelacionado,
        'pisoMolhadoRelacionado': pisoMolhadoRelacionado,
        'iluminacaoArtificialRelacionado': iluminacaoArtificialRelacionado,
        'iluminacaoNaturalRelacionado': iluminacaoNaturalRelacionado,
        'iluminacaoAusenteRelacionado': iluminacaoAusenteRelacionado,
        'descricaoViasAcesso': descricaoViasAcesso,
        'sinaisArrombamentoDescricao': sinaisArrombamentoDescricao,
        'descricaoLocal': descricaoLocal,
        'demaisObservacoes': demaisObservacoes,
        'descricaoLocalMediato': descricaoLocalMediato,
        'descricaoLocalImediato': descricaoLocalImediato,
        'descricaoLocalRelacionado': descricaoLocalRelacionado,
        'marcoZeroMediato': marcoZeroMediato?.toJson(),
        'marcoZeroImediato': marcoZeroImediato?.toJson(),
        'marcoZeroRelacionado': marcoZeroRelacionado?.toJson(),
        'vestigiosMediato': vestigiosMediato?.map((v) => v.toJson()).toList(),
        'vestigiosImediato': vestigiosImediato?.map((v) => v.toJson()).toList(),
        'vestigiosRelacionado': vestigiosRelacionado?.map((v) => v.toJson()).toList(),
        'semVestigiosMediato': semVestigiosMediato,
        'semVestigiosImediato': semVestigiosImediato,
        'semVestigiosRelacionado': semVestigiosRelacionado,
        'sinaisArrombamentoSim': sinaisArrombamentoSim,
        'sinaisArrombamentoNao': sinaisArrombamentoNao,
        'sinaisArrombamentoNaoSeAplica': sinaisArrombamentoNaoSeAplica,
      };

  factory LocalFurtoModel.fromJson(Map<String, dynamic> json) =>
      LocalFurtoModel(
        classificacaoMediato: json['classificacaoMediato'] as bool?,
        classificacaoImediato: json['classificacaoImediato'] as bool?,
        classificacaoRelacionado: json['classificacaoRelacionado'] as bool?,
        pisoSecoMediato: json['pisoSecoMediato'] as bool?,
        pisoUmidoMediato: json['pisoUmidoMediato'] as bool?,
        pisoMolhadoMediato: json['pisoMolhadoMediato'] as bool?,
        iluminacaoArtificialMediato: json['iluminacaoArtificialMediato'] as bool?,
        iluminacaoNaturalMediato: json['iluminacaoNaturalMediato'] as bool?,
        iluminacaoAusenteMediato: json['iluminacaoAusenteMediato'] as bool?,
        pisoSecoImediato: json['pisoSecoImediato'] as bool?,
        pisoUmidoImediato: json['pisoUmidoImediato'] as bool?,
        pisoMolhadoImediato: json['pisoMolhadoImediato'] as bool?,
        iluminacaoArtificialImediato: json['iluminacaoArtificialImediato'] as bool?,
        iluminacaoNaturalImediato: json['iluminacaoNaturalImediato'] as bool?,
        iluminacaoAusenteImediato: json['iluminacaoAusenteImediato'] as bool?,
        pisoSecoRelacionado: json['pisoSecoRelacionado'] as bool?,
        pisoUmidoRelacionado: json['pisoUmidoRelacionado'] as bool?,
        pisoMolhadoRelacionado: json['pisoMolhadoRelacionado'] as bool?,
        iluminacaoArtificialRelacionado: json['iluminacaoArtificialRelacionado'] as bool?,
        iluminacaoNaturalRelacionado: json['iluminacaoNaturalRelacionado'] as bool?,
        iluminacaoAusenteRelacionado: json['iluminacaoAusenteRelacionado'] as bool?,
        descricaoViasAcesso: json['descricaoViasAcesso'] as String?,
        sinaisArrombamentoDescricao: json['sinaisArrombamentoDescricao'] as String?,
        descricaoLocal: json['descricaoLocal'] as String?,
        demaisObservacoes: json['demaisObservacoes'] as String?,
        descricaoLocalMediato: json['descricaoLocalMediato'] as String?,
        descricaoLocalImediato: json['descricaoLocalImediato'] as String?,
        descricaoLocalRelacionado: json['descricaoLocalRelacionado'] as String?,
        marcoZeroMediato: json['marcoZeroMediato'] != null
            ? MarcoZeroLocalModel.fromJson(json['marcoZeroMediato'] as Map<String, dynamic>)
            : null,
        marcoZeroImediato: json['marcoZeroImediato'] != null
            ? MarcoZeroLocalModel.fromJson(json['marcoZeroImediato'] as Map<String, dynamic>)
            : null,
        marcoZeroRelacionado: json['marcoZeroRelacionado'] != null
            ? MarcoZeroLocalModel.fromJson(json['marcoZeroRelacionado'] as Map<String, dynamic>)
            : null,
        vestigiosMediato: (json['vestigiosMediato'] as List<dynamic>?)
            ?.map((e) => VestigioLocalModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        vestigiosImediato: (json['vestigiosImediato'] as List<dynamic>?)
            ?.map((e) => VestigioLocalModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        vestigiosRelacionado: (json['vestigiosRelacionado'] as List<dynamic>?)
            ?.map((e) => VestigioLocalModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        semVestigiosMediato: json['semVestigiosMediato'] as bool?,
        semVestigiosImediato: json['semVestigiosImediato'] as bool?,
        semVestigiosRelacionado: json['semVestigiosRelacionado'] as bool?,
        sinaisArrombamentoSim: json['sinaisArrombamentoSim'] as bool?,
        sinaisArrombamentoNao: json['sinaisArrombamentoNao'] as bool?,
        sinaisArrombamentoNaoSeAplica: json['sinaisArrombamentoNaoSeAplica'] as bool?,
      );

  LocalFurtoModel copyWith({
    bool? classificacaoMediato,
    bool? classificacaoImediato,
    bool? classificacaoRelacionado,
    bool? pisoSecoMediato,
    bool? pisoUmidoMediato,
    bool? pisoMolhadoMediato,
    bool? iluminacaoArtificialMediato,
    bool? iluminacaoNaturalMediato,
    bool? iluminacaoAusenteMediato,
    bool? pisoSecoImediato,
    bool? pisoUmidoImediato,
    bool? pisoMolhadoImediato,
    bool? iluminacaoArtificialImediato,
    bool? iluminacaoNaturalImediato,
    bool? iluminacaoAusenteImediato,
    bool? pisoSecoRelacionado,
    bool? pisoUmidoRelacionado,
    bool? pisoMolhadoRelacionado,
    bool? iluminacaoArtificialRelacionado,
    bool? iluminacaoNaturalRelacionado,
    bool? iluminacaoAusenteRelacionado,
    String? descricaoViasAcesso,
    String? sinaisArrombamentoDescricao,
    String? descricaoLocal,
    String? demaisObservacoes,
    String? descricaoLocalMediato,
    String? descricaoLocalImediato,
    String? descricaoLocalRelacionado,
    MarcoZeroLocalModel? marcoZeroMediato,
    MarcoZeroLocalModel? marcoZeroImediato,
    MarcoZeroLocalModel? marcoZeroRelacionado,
    List<VestigioLocalModel>? vestigiosMediato,
    List<VestigioLocalModel>? vestigiosImediato,
    List<VestigioLocalModel>? vestigiosRelacionado,
    bool? semVestigiosMediato,
    bool? semVestigiosImediato,
    bool? semVestigiosRelacionado,
    bool? sinaisArrombamentoSim,
    bool? sinaisArrombamentoNao,
    bool? sinaisArrombamentoNaoSeAplica,
  }) {
    return LocalFurtoModel(
      classificacaoMediato: classificacaoMediato ?? this.classificacaoMediato,
      classificacaoImediato: classificacaoImediato ?? this.classificacaoImediato,
      classificacaoRelacionado: classificacaoRelacionado ?? this.classificacaoRelacionado,
      pisoSecoMediato: pisoSecoMediato ?? this.pisoSecoMediato,
      pisoUmidoMediato: pisoUmidoMediato ?? this.pisoUmidoMediato,
      pisoMolhadoMediato: pisoMolhadoMediato ?? this.pisoMolhadoMediato,
      iluminacaoArtificialMediato: iluminacaoArtificialMediato ?? this.iluminacaoArtificialMediato,
      iluminacaoNaturalMediato: iluminacaoNaturalMediato ?? this.iluminacaoNaturalMediato,
      iluminacaoAusenteMediato: iluminacaoAusenteMediato ?? this.iluminacaoAusenteMediato,
      pisoSecoImediato: pisoSecoImediato ?? this.pisoSecoImediato,
      pisoUmidoImediato: pisoUmidoImediato ?? this.pisoUmidoImediato,
      pisoMolhadoImediato: pisoMolhadoImediato ?? this.pisoMolhadoImediato,
      iluminacaoArtificialImediato: iluminacaoArtificialImediato ?? this.iluminacaoArtificialImediato,
      iluminacaoNaturalImediato: iluminacaoNaturalImediato ?? this.iluminacaoNaturalImediato,
      iluminacaoAusenteImediato: iluminacaoAusenteImediato ?? this.iluminacaoAusenteImediato,
      pisoSecoRelacionado: pisoSecoRelacionado ?? this.pisoSecoRelacionado,
      pisoUmidoRelacionado: pisoUmidoRelacionado ?? this.pisoUmidoRelacionado,
      pisoMolhadoRelacionado: pisoMolhadoRelacionado ?? this.pisoMolhadoRelacionado,
      iluminacaoArtificialRelacionado: iluminacaoArtificialRelacionado ?? this.iluminacaoArtificialRelacionado,
      iluminacaoNaturalRelacionado: iluminacaoNaturalRelacionado ?? this.iluminacaoNaturalRelacionado,
      iluminacaoAusenteRelacionado: iluminacaoAusenteRelacionado ?? this.iluminacaoAusenteRelacionado,
      descricaoViasAcesso: descricaoViasAcesso ?? this.descricaoViasAcesso,
      sinaisArrombamentoDescricao: sinaisArrombamentoDescricao ?? this.sinaisArrombamentoDescricao,
      descricaoLocal: descricaoLocal ?? this.descricaoLocal,
      demaisObservacoes: demaisObservacoes ?? this.demaisObservacoes,
      descricaoLocalMediato: descricaoLocalMediato ?? this.descricaoLocalMediato,
      descricaoLocalImediato: descricaoLocalImediato ?? this.descricaoLocalImediato,
      descricaoLocalRelacionado: descricaoLocalRelacionado ?? this.descricaoLocalRelacionado,
      marcoZeroMediato: marcoZeroMediato ?? this.marcoZeroMediato,
      marcoZeroImediato: marcoZeroImediato ?? this.marcoZeroImediato,
      marcoZeroRelacionado: marcoZeroRelacionado ?? this.marcoZeroRelacionado,
      vestigiosMediato: vestigiosMediato ?? this.vestigiosMediato,
      vestigiosImediato: vestigiosImediato ?? this.vestigiosImediato,
      vestigiosRelacionado: vestigiosRelacionado ?? this.vestigiosRelacionado,
      semVestigiosMediato: semVestigiosMediato ?? this.semVestigiosMediato,
      semVestigiosImediato: semVestigiosImediato ?? this.semVestigiosImediato,
      semVestigiosRelacionado: semVestigiosRelacionado ?? this.semVestigiosRelacionado,
      sinaisArrombamentoSim: sinaisArrombamentoSim ?? this.sinaisArrombamentoSim,
      sinaisArrombamentoNao: sinaisArrombamentoNao ?? this.sinaisArrombamentoNao,
      sinaisArrombamentoNaoSeAplica: sinaisArrombamentoNaoSeAplica ?? this.sinaisArrombamentoNaoSeAplica,
    );
  }
}

