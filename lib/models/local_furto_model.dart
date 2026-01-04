/// Modelo para dados do local específico de furto/dano
class LocalFurtoModel {
  // Classificação
  final bool? classificacaoMediato;
  final bool? classificacaoImediato;
  final bool? classificacaoRelacionado;

  // Condições do Piso
  final bool? pisoSeco;
  final bool? pisoUmido;
  final bool? pisoMolhado;

  // Iluminação
  final bool? iluminacaoArtificial;
  final bool? iluminacaoNatural;
  final bool? iluminacaoAusente;

  // Descrições
  final String? descricaoViasAcesso;
  final String? sinaisArrombamentoDescricao;
  final String? descricaoLocal;
  final String? demaisObservacoes;

  // Sinais de Arrombamento
  final bool? sinaisArrombamentoSim;
  final bool? sinaisArrombamentoNao;
  final bool? sinaisArrombamentoNaoSeAplica;

  LocalFurtoModel({
    this.classificacaoMediato,
    this.classificacaoImediato,
    this.classificacaoRelacionado,
    this.pisoSeco,
    this.pisoUmido,
    this.pisoMolhado,
    this.iluminacaoArtificial,
    this.iluminacaoNatural,
    this.iluminacaoAusente,
    this.descricaoViasAcesso,
    this.sinaisArrombamentoDescricao,
    this.descricaoLocal,
    this.demaisObservacoes,
    this.sinaisArrombamentoSim,
    this.sinaisArrombamentoNao,
    this.sinaisArrombamentoNaoSeAplica,
  });

  Map<String, dynamic> toJson() => {
        'classificacaoMediato': classificacaoMediato,
        'classificacaoImediato': classificacaoImediato,
        'classificacaoRelacionado': classificacaoRelacionado,
        'pisoSeco': pisoSeco,
        'pisoUmido': pisoUmido,
        'pisoMolhado': pisoMolhado,
        'iluminacaoArtificial': iluminacaoArtificial,
        'iluminacaoNatural': iluminacaoNatural,
        'iluminacaoAusente': iluminacaoAusente,
        'descricaoViasAcesso': descricaoViasAcesso,
        'sinaisArrombamentoDescricao': sinaisArrombamentoDescricao,
        'descricaoLocal': descricaoLocal,
        'demaisObservacoes': demaisObservacoes,
        'sinaisArrombamentoSim': sinaisArrombamentoSim,
        'sinaisArrombamentoNao': sinaisArrombamentoNao,
        'sinaisArrombamentoNaoSeAplica': sinaisArrombamentoNaoSeAplica,
      };

  factory LocalFurtoModel.fromJson(Map<String, dynamic> json) =>
      LocalFurtoModel(
        classificacaoMediato: json['classificacaoMediato'] as bool?,
        classificacaoImediato: json['classificacaoImediato'] as bool?,
        classificacaoRelacionado: json['classificacaoRelacionado'] as bool?,
        pisoSeco: json['pisoSeco'] as bool?,
        pisoUmido: json['pisoUmido'] as bool?,
        pisoMolhado: json['pisoMolhado'] as bool?,
        iluminacaoArtificial: json['iluminacaoArtificial'] as bool?,
        iluminacaoNatural: json['iluminacaoNatural'] as bool?,
        iluminacaoAusente: json['iluminacaoAusente'] as bool?,
        descricaoViasAcesso: json['descricaoViasAcesso'] as String?,
        sinaisArrombamentoDescricao: json['sinaisArrombamentoDescricao'] as String?,
        descricaoLocal: json['descricaoLocal'] as String?,
        demaisObservacoes: json['demaisObservacoes'] as String?,
        sinaisArrombamentoSim: json['sinaisArrombamentoSim'] as bool?,
        sinaisArrombamentoNao: json['sinaisArrombamentoNao'] as bool?,
        sinaisArrombamentoNaoSeAplica: json['sinaisArrombamentoNaoSeAplica'] as bool?,
      );

  LocalFurtoModel copyWith({
    bool? classificacaoMediato,
    bool? classificacaoImediato,
    bool? classificacaoRelacionado,
    bool? pisoSeco,
    bool? pisoUmido,
    bool? pisoMolhado,
    bool? iluminacaoArtificial,
    bool? iluminacaoNatural,
    bool? iluminacaoAusente,
    String? descricaoViasAcesso,
    String? sinaisArrombamentoDescricao,
    String? descricaoLocal,
    String? demaisObservacoes,
    bool? sinaisArrombamentoSim,
    bool? sinaisArrombamentoNao,
    bool? sinaisArrombamentoNaoSeAplica,
  }) {
    return LocalFurtoModel(
      classificacaoMediato: classificacaoMediato ?? this.classificacaoMediato,
      classificacaoImediato: classificacaoImediato ?? this.classificacaoImediato,
      classificacaoRelacionado: classificacaoRelacionado ?? this.classificacaoRelacionado,
      pisoSeco: pisoSeco ?? this.pisoSeco,
      pisoUmido: pisoUmido ?? this.pisoUmido,
      pisoMolhado: pisoMolhado ?? this.pisoMolhado,
      iluminacaoArtificial: iluminacaoArtificial ?? this.iluminacaoArtificial,
      iluminacaoNatural: iluminacaoNatural ?? this.iluminacaoNatural,
      iluminacaoAusente: iluminacaoAusente ?? this.iluminacaoAusente,
      descricaoViasAcesso: descricaoViasAcesso ?? this.descricaoViasAcesso,
      sinaisArrombamentoDescricao: sinaisArrombamentoDescricao ?? this.sinaisArrombamentoDescricao,
      descricaoLocal: descricaoLocal ?? this.descricaoLocal,
      demaisObservacoes: demaisObservacoes ?? this.demaisObservacoes,
      sinaisArrombamentoSim: sinaisArrombamentoSim ?? this.sinaisArrombamentoSim,
      sinaisArrombamentoNao: sinaisArrombamentoNao ?? this.sinaisArrombamentoNao,
      sinaisArrombamentoNaoSeAplica: sinaisArrombamentoNaoSeAplica ?? this.sinaisArrombamentoNaoSeAplica,
    );
  }
}

