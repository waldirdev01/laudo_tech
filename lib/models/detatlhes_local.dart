import 'marco_zero_local_model.dart';
import 'metodo_posicionamento_model.dart';
import 'vestigio_local_model.dart';

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

  // Descrições e estrutura do local
  final String? descricaoViasAcesso;
  final int? quantidadeAcessosMediato;
  final List<String>? tiposAcessoMediato;
  final List<String>? posicoesAcessoMediato;
  final String? abrangenciaImediato;
  final List<String>? ambientesImediato;
  final String? ambienteDestaqueImediato;
  final String? estadoConservacaoImediato;
  final String? observacaoImediato;
  final Map<String, List<String>>? acessosPorAmbienteImediato;
  final Map<String, List<String>>? comunicacaoAmbientesImediato;
  final Map<String, bool>? acessoExternoPorAmbienteImediato;
  final Map<String, MarcoZeroLocalModel>? marcosZeroAmbientesImediato;
  final MetodoPosicionamentoVestigio? metodoPosicionamentoMediato;
  final MetodoPosicionamentoVestigio? metodoPosicionamentoRelacionado;
  final Map<String, MetodoPosicionamentoVestigio>?
  metodosPosicionamentoAmbientesImediato;
  final Map<String, String>? consideracoesTecnicasAmbientesImediato;
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

  // Fotos auxiliares do local
  final List<String>? fotosVistaAmplaPaths;
  final List<String>? fotosVistaAmplaMediatoPaths;
  final List<String>? fotosVistaAmplaImediatoPaths;
  final Map<String, List<String>>? fotosVistaAmplaAmbientesImediato;
  final List<String>? fotosSinaisArrombamentoPaths;

  /// true = via pública / área aberta; false = imóvel (fechado); null = não definido
  final bool? localEmViaPublica;

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
    this.quantidadeAcessosMediato,
    this.tiposAcessoMediato,
    this.posicoesAcessoMediato,
    this.abrangenciaImediato,
    this.ambientesImediato,
    this.ambienteDestaqueImediato,
    this.estadoConservacaoImediato,
    this.observacaoImediato,
    this.acessosPorAmbienteImediato,
    this.comunicacaoAmbientesImediato,
    this.acessoExternoPorAmbienteImediato,
    this.marcosZeroAmbientesImediato,
    this.metodoPosicionamentoMediato,
    this.metodoPosicionamentoRelacionado,
    this.metodosPosicionamentoAmbientesImediato,
    this.consideracoesTecnicasAmbientesImediato,
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
    this.fotosVistaAmplaPaths,
    this.fotosVistaAmplaMediatoPaths,
    this.fotosVistaAmplaImediatoPaths,
    this.fotosVistaAmplaAmbientesImediato,
    this.fotosSinaisArrombamentoPaths,
    this.localEmViaPublica,
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
    'quantidadeAcessosMediato': quantidadeAcessosMediato,
    'tiposAcessoMediato': tiposAcessoMediato,
    'posicoesAcessoMediato': posicoesAcessoMediato,
    'abrangenciaImediato': abrangenciaImediato,
    'ambientesImediato': ambientesImediato,
    'ambienteDestaqueImediato': ambienteDestaqueImediato,
    'estadoConservacaoImediato': estadoConservacaoImediato,
    'observacaoImediato': observacaoImediato,
    'acessosPorAmbienteImediato': acessosPorAmbienteImediato,
    'comunicacaoAmbientesImediato': comunicacaoAmbientesImediato,
    'acessoExternoPorAmbienteImediato': acessoExternoPorAmbienteImediato,
    'marcosZeroAmbientesImediato': marcosZeroAmbientesImediato?.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'metodoPosicionamentoMediato': metodoPosicionamentoMediato?.name,
    'metodoPosicionamentoRelacionado': metodoPosicionamentoRelacionado?.name,
    'metodosPosicionamentoAmbientesImediato':
        metodosPosicionamentoAmbientesImediato?.map(
          (key, value) => MapEntry(key, value.name),
        ),
    'consideracoesTecnicasAmbientesImediato':
        consideracoesTecnicasAmbientesImediato,
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
    'vestigiosRelacionado': vestigiosRelacionado
        ?.map((v) => v.toJson())
        .toList(),
    'semVestigiosMediato': semVestigiosMediato,
    'semVestigiosImediato': semVestigiosImediato,
    'semVestigiosRelacionado': semVestigiosRelacionado,
    'sinaisArrombamentoSim': sinaisArrombamentoSim,
    'sinaisArrombamentoNao': sinaisArrombamentoNao,
    'sinaisArrombamentoNaoSeAplica': sinaisArrombamentoNaoSeAplica,
    'fotosVistaAmplaPaths': fotosVistaAmplaPaths,
    'fotosVistaAmplaMediatoPaths': fotosVistaAmplaMediatoPaths,
    'fotosVistaAmplaImediatoPaths': fotosVistaAmplaImediatoPaths,
    'fotosVistaAmplaAmbientesImediato': fotosVistaAmplaAmbientesImediato,
    'fotosSinaisArrombamentoPaths': fotosSinaisArrombamentoPaths,
    'localEmViaPublica': localEmViaPublica,
  };

  factory LocalFurtoModel.fromJson(
    Map<String, dynamic> json,
  ) => LocalFurtoModel(
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
    iluminacaoArtificialRelacionado:
        json['iluminacaoArtificialRelacionado'] as bool?,
    iluminacaoNaturalRelacionado: json['iluminacaoNaturalRelacionado'] as bool?,
    iluminacaoAusenteRelacionado: json['iluminacaoAusenteRelacionado'] as bool?,
    descricaoViasAcesso: json['descricaoViasAcesso'] as String?,
    quantidadeAcessosMediato: (json['quantidadeAcessosMediato'] as num?)
        ?.toInt(),
    tiposAcessoMediato: (json['tiposAcessoMediato'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    posicoesAcessoMediato: (json['posicoesAcessoMediato'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    abrangenciaImediato: json['abrangenciaImediato'] as String?,
    ambientesImediato: (json['ambientesImediato'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    ambienteDestaqueImediato: json['ambienteDestaqueImediato'] as String?,
    estadoConservacaoImediato: json['estadoConservacaoImediato'] as String?,
    observacaoImediato: json['observacaoImediato'] as String?,
    acessosPorAmbienteImediato:
        (json['acessosPorAmbienteImediato'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            (value as List<dynamic>).map((e) => e.toString()).toList(),
          ),
        ),
    comunicacaoAmbientesImediato:
        (json['comunicacaoAmbientesImediato'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            (value as List<dynamic>).map((e) => e.toString()).toList(),
          ),
        ),
    acessoExternoPorAmbienteImediato:
        (json['acessoExternoPorAmbienteImediato'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value as bool? ?? false)),
    marcosZeroAmbientesImediato:
        (json['marcosZeroAmbientesImediato'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            MarcoZeroLocalModel.fromJson(value as Map<String, dynamic>),
          ),
        ),
    metodoPosicionamentoMediato: MetodoPosicionamentoVestigio.fromName(
      json['metodoPosicionamentoMediato'] as String?,
    ),
    metodoPosicionamentoRelacionado: MetodoPosicionamentoVestigio.fromName(
      json['metodoPosicionamentoRelacionado'] as String?,
    ),
    metodosPosicionamentoAmbientesImediato:
        (json['metodosPosicionamentoAmbientesImediato']
                as Map<String, dynamic>?)
            ?.map(
              (key, value) => MapEntry(
                key,
                MetodoPosicionamentoVestigio.fromName(value as String?) ??
                    MetodoPosicionamentoVestigio.nenhum,
              ),
            ),
    consideracoesTecnicasAmbientesImediato:
        (json['consideracoesTecnicasAmbientesImediato']
                as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
    sinaisArrombamentoDescricao: json['sinaisArrombamentoDescricao'] as String?,
    descricaoLocal: json['descricaoLocal'] as String?,
    demaisObservacoes: json['demaisObservacoes'] as String?,
    descricaoLocalMediato: json['descricaoLocalMediato'] as String?,
    descricaoLocalImediato: json['descricaoLocalImediato'] as String?,
    descricaoLocalRelacionado: json['descricaoLocalRelacionado'] as String?,
    marcoZeroMediato: json['marcoZeroMediato'] != null
        ? MarcoZeroLocalModel.fromJson(
            json['marcoZeroMediato'] as Map<String, dynamic>,
          )
        : null,
    marcoZeroImediato: json['marcoZeroImediato'] != null
        ? MarcoZeroLocalModel.fromJson(
            json['marcoZeroImediato'] as Map<String, dynamic>,
          )
        : null,
    marcoZeroRelacionado: json['marcoZeroRelacionado'] != null
        ? MarcoZeroLocalModel.fromJson(
            json['marcoZeroRelacionado'] as Map<String, dynamic>,
          )
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
    sinaisArrombamentoNaoSeAplica:
        json['sinaisArrombamentoNaoSeAplica'] as bool?,
    fotosVistaAmplaPaths: (json['fotosVistaAmplaPaths'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    fotosVistaAmplaMediatoPaths:
        (json['fotosVistaAmplaMediatoPaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
    fotosVistaAmplaImediatoPaths:
        (json['fotosVistaAmplaImediatoPaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
    fotosVistaAmplaAmbientesImediato:
        (json['fotosVistaAmplaAmbientesImediato'] as Map<String, dynamic>?)
            ?.map(
              (key, value) => MapEntry(
                key,
                (value as List<dynamic>).map((e) => e.toString()).toList(),
              ),
            ),
    fotosSinaisArrombamentoPaths:
        (json['fotosSinaisArrombamentoPaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
    localEmViaPublica: json['localEmViaPublica'] as bool?,
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
    int? quantidadeAcessosMediato,
    List<String>? tiposAcessoMediato,
    List<String>? posicoesAcessoMediato,
    String? abrangenciaImediato,
    List<String>? ambientesImediato,
    String? ambienteDestaqueImediato,
    String? estadoConservacaoImediato,
    String? observacaoImediato,
    Map<String, List<String>>? acessosPorAmbienteImediato,
    Map<String, List<String>>? comunicacaoAmbientesImediato,
    Map<String, bool>? acessoExternoPorAmbienteImediato,
    Map<String, MarcoZeroLocalModel>? marcosZeroAmbientesImediato,
    MetodoPosicionamentoVestigio? metodoPosicionamentoMediato,
    MetodoPosicionamentoVestigio? metodoPosicionamentoRelacionado,
    Map<String, MetodoPosicionamentoVestigio>?
    metodosPosicionamentoAmbientesImediato,
    Map<String, String>? consideracoesTecnicasAmbientesImediato,
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
    List<String>? fotosVistaAmplaPaths,
    List<String>? fotosVistaAmplaMediatoPaths,
    List<String>? fotosVistaAmplaImediatoPaths,
    Map<String, List<String>>? fotosVistaAmplaAmbientesImediato,
    List<String>? fotosSinaisArrombamentoPaths,
    bool? localEmViaPublica,
  }) {
    return LocalFurtoModel(
      classificacaoMediato: classificacaoMediato ?? this.classificacaoMediato,
      classificacaoImediato:
          classificacaoImediato ?? this.classificacaoImediato,
      classificacaoRelacionado:
          classificacaoRelacionado ?? this.classificacaoRelacionado,
      pisoSecoMediato: pisoSecoMediato ?? this.pisoSecoMediato,
      pisoUmidoMediato: pisoUmidoMediato ?? this.pisoUmidoMediato,
      pisoMolhadoMediato: pisoMolhadoMediato ?? this.pisoMolhadoMediato,
      iluminacaoArtificialMediato:
          iluminacaoArtificialMediato ?? this.iluminacaoArtificialMediato,
      iluminacaoNaturalMediato:
          iluminacaoNaturalMediato ?? this.iluminacaoNaturalMediato,
      iluminacaoAusenteMediato:
          iluminacaoAusenteMediato ?? this.iluminacaoAusenteMediato,
      pisoSecoImediato: pisoSecoImediato ?? this.pisoSecoImediato,
      pisoUmidoImediato: pisoUmidoImediato ?? this.pisoUmidoImediato,
      pisoMolhadoImediato: pisoMolhadoImediato ?? this.pisoMolhadoImediato,
      iluminacaoArtificialImediato:
          iluminacaoArtificialImediato ?? this.iluminacaoArtificialImediato,
      iluminacaoNaturalImediato:
          iluminacaoNaturalImediato ?? this.iluminacaoNaturalImediato,
      iluminacaoAusenteImediato:
          iluminacaoAusenteImediato ?? this.iluminacaoAusenteImediato,
      pisoSecoRelacionado: pisoSecoRelacionado ?? this.pisoSecoRelacionado,
      pisoUmidoRelacionado: pisoUmidoRelacionado ?? this.pisoUmidoRelacionado,
      pisoMolhadoRelacionado:
          pisoMolhadoRelacionado ?? this.pisoMolhadoRelacionado,
      iluminacaoArtificialRelacionado:
          iluminacaoArtificialRelacionado ??
          this.iluminacaoArtificialRelacionado,
      iluminacaoNaturalRelacionado:
          iluminacaoNaturalRelacionado ?? this.iluminacaoNaturalRelacionado,
      iluminacaoAusenteRelacionado:
          iluminacaoAusenteRelacionado ?? this.iluminacaoAusenteRelacionado,
      descricaoViasAcesso: descricaoViasAcesso ?? this.descricaoViasAcesso,
      quantidadeAcessosMediato:
          quantidadeAcessosMediato ?? this.quantidadeAcessosMediato,
      tiposAcessoMediato: tiposAcessoMediato ?? this.tiposAcessoMediato,
      posicoesAcessoMediato:
          posicoesAcessoMediato ?? this.posicoesAcessoMediato,
      abrangenciaImediato: abrangenciaImediato ?? this.abrangenciaImediato,
      ambientesImediato: ambientesImediato ?? this.ambientesImediato,
      ambienteDestaqueImediato:
          ambienteDestaqueImediato ?? this.ambienteDestaqueImediato,
      estadoConservacaoImediato:
          estadoConservacaoImediato ?? this.estadoConservacaoImediato,
      observacaoImediato: observacaoImediato ?? this.observacaoImediato,
      acessosPorAmbienteImediato:
          acessosPorAmbienteImediato ?? this.acessosPorAmbienteImediato,
      comunicacaoAmbientesImediato:
          comunicacaoAmbientesImediato ?? this.comunicacaoAmbientesImediato,
      acessoExternoPorAmbienteImediato:
          acessoExternoPorAmbienteImediato ??
          this.acessoExternoPorAmbienteImediato,
      marcosZeroAmbientesImediato:
          marcosZeroAmbientesImediato ?? this.marcosZeroAmbientesImediato,
      metodoPosicionamentoMediato:
          metodoPosicionamentoMediato ?? this.metodoPosicionamentoMediato,
      metodoPosicionamentoRelacionado:
          metodoPosicionamentoRelacionado ??
          this.metodoPosicionamentoRelacionado,
      metodosPosicionamentoAmbientesImediato:
          metodosPosicionamentoAmbientesImediato ??
          this.metodosPosicionamentoAmbientesImediato,
      consideracoesTecnicasAmbientesImediato:
          consideracoesTecnicasAmbientesImediato ??
          this.consideracoesTecnicasAmbientesImediato,
      sinaisArrombamentoDescricao:
          sinaisArrombamentoDescricao ?? this.sinaisArrombamentoDescricao,
      descricaoLocal: descricaoLocal ?? this.descricaoLocal,
      demaisObservacoes: demaisObservacoes ?? this.demaisObservacoes,
      descricaoLocalMediato:
          descricaoLocalMediato ?? this.descricaoLocalMediato,
      descricaoLocalImediato:
          descricaoLocalImediato ?? this.descricaoLocalImediato,
      descricaoLocalRelacionado:
          descricaoLocalRelacionado ?? this.descricaoLocalRelacionado,
      marcoZeroMediato: marcoZeroMediato ?? this.marcoZeroMediato,
      marcoZeroImediato: marcoZeroImediato ?? this.marcoZeroImediato,
      marcoZeroRelacionado: marcoZeroRelacionado ?? this.marcoZeroRelacionado,
      vestigiosMediato: vestigiosMediato ?? this.vestigiosMediato,
      vestigiosImediato: vestigiosImediato ?? this.vestigiosImediato,
      vestigiosRelacionado: vestigiosRelacionado ?? this.vestigiosRelacionado,
      semVestigiosMediato: semVestigiosMediato ?? this.semVestigiosMediato,
      semVestigiosImediato: semVestigiosImediato ?? this.semVestigiosImediato,
      semVestigiosRelacionado:
          semVestigiosRelacionado ?? this.semVestigiosRelacionado,
      sinaisArrombamentoSim:
          sinaisArrombamentoSim ?? this.sinaisArrombamentoSim,
      sinaisArrombamentoNao:
          sinaisArrombamentoNao ?? this.sinaisArrombamentoNao,
      sinaisArrombamentoNaoSeAplica:
          sinaisArrombamentoNaoSeAplica ?? this.sinaisArrombamentoNaoSeAplica,
      fotosVistaAmplaPaths: fotosVistaAmplaPaths ?? this.fotosVistaAmplaPaths,
      fotosVistaAmplaMediatoPaths:
          fotosVistaAmplaMediatoPaths ?? this.fotosVistaAmplaMediatoPaths,
      fotosVistaAmplaImediatoPaths:
          fotosVistaAmplaImediatoPaths ?? this.fotosVistaAmplaImediatoPaths,
      fotosVistaAmplaAmbientesImediato:
          fotosVistaAmplaAmbientesImediato ??
          this.fotosVistaAmplaAmbientesImediato,
      fotosSinaisArrombamentoPaths:
          fotosSinaisArrombamentoPaths ?? this.fotosSinaisArrombamentoPaths,
      localEmViaPublica: localEmViaPublica ?? this.localEmViaPublica,
    );
  }
}
