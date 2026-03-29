import 'crime_transito_model.dart';

/// Tipo de dinâmica do acidente para orientar o checklist de fotos
enum DinamicaAcidente {
  colisaoFrontal,
  colisaoTraseira,
  colisaoTransversalLateral,
  atropelamento,
  saidaPista,
  choqueObjetoFixo,
  outro,
}

/// Tipo de vestígio encontrado na via
enum TipoVestigioVia {
  marcaFrenagem,
  marcaDerrapagem,
  sulcagem,
  raspagem,
  arraste,
  liquidos,
  fragmentos,
  outro,
}

/// Posição do vestígio em relação ao sítio de colisão / ponto de saída
enum PosicaoRelativaVestigio {
  antes,
  apos,
  noSitio,
  naoSeAplica,
}

/// Foto com legenda individual (pode sobrescrever a do grupo)
class FotoLegendaModel {
  final String path;
  final String? legendaIndividual;

  const FotoLegendaModel({required this.path, this.legendaIndividual});

  Map<String, dynamic> toJson() => {
        'path': path,
        'legendaIndividual': legendaIndividual,
      };

  factory FotoLegendaModel.fromJson(Map<String, dynamic> json) =>
      FotoLegendaModel(
        path: json['path'] as String,
        legendaIndividual: json['legendaIndividual'] as String?,
      );
}

/// Grupo de fotos com legenda compartilhada
class GrupoFotosModel {
  final String categoria;
  final String legendaGrupo;
  final List<FotoLegendaModel> fotos;

  const GrupoFotosModel({
    required this.categoria,
    this.legendaGrupo = '',
    this.fotos = const [],
  });

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'legendaGrupo': legendaGrupo,
        'fotos': fotos.map((f) => f.toJson()).toList(),
      };

  factory GrupoFotosModel.fromJson(Map<String, dynamic> json) =>
      GrupoFotosModel(
        categoria: json['categoria'] as String,
        legendaGrupo: json['legendaGrupo'] as String? ?? '',
        fotos: (json['fotos'] as List<dynamic>?)
                ?.map(
                  (f) => FotoLegendaModel.fromJson(f as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );

  GrupoFotosModel copyWith({
    String? categoria,
    String? legendaGrupo,
    List<FotoLegendaModel>? fotos,
  }) =>
      GrupoFotosModel(
        categoria: categoria ?? this.categoria,
        legendaGrupo: legendaGrupo ?? this.legendaGrupo,
        fotos: fotos ?? this.fotos,
      );
}

/// Vestígio encontrado na via
class VestigioViaModel {
  final String id;
  final TipoVestigioVia tipo;
  final String? tipoOutroDescricao;
  final String? condutorAssociado;
  final PosicaoRelativaVestigio? posicao;
  final String? medidaMetros;
  final List<FotoLegendaModel> fotos;
  final String? observacao;

  const VestigioViaModel({
    required this.id,
    required this.tipo,
    this.tipoOutroDescricao,
    this.condutorAssociado,
    this.posicao,
    this.medidaMetros,
    this.fotos = const [],
    this.observacao,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'tipoOutroDescricao': tipoOutroDescricao,
        'condutorAssociado': condutorAssociado,
        'posicao': posicao?.name,
        'medidaMetros': medidaMetros,
        'fotos': fotos.map((f) => f.toJson()).toList(),
        'observacao': observacao,
      };

  factory VestigioViaModel.fromJson(Map<String, dynamic> json) =>
      VestigioViaModel(
        id: json['id'] as String,
        tipo: TipoVestigioVia.values.firstWhere(
          (e) => e.name == json['tipo'],
          orElse: () => TipoVestigioVia.outro,
        ),
        tipoOutroDescricao: json['tipoOutroDescricao'] as String?,
        condutorAssociado: json['condutorAssociado'] as String?,
        posicao: json['posicao'] != null
            ? PosicaoRelativaVestigio.values.firstWhere(
                (e) => e.name == json['posicao'],
                orElse: () => PosicaoRelativaVestigio.naoSeAplica,
              )
            : null,
        medidaMetros: json['medidaMetros'] as String?,
        fotos: (json['fotos'] as List<dynamic>?)
                ?.map(
                  (f) => FotoLegendaModel.fromJson(f as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        observacao: json['observacao'] as String?,
      );
}

/// Marco zero do levantamento de trânsito
class MarcoZeroTransitoModel {
  final String? descricao;
  final String? latitude;
  final String? longitude;
  final List<String> fotos;

  const MarcoZeroTransitoModel({
    this.descricao,
    this.latitude,
    this.longitude,
    this.fotos = const [],
  });

  Map<String, dynamic> toJson() => {
        'descricao': descricao,
        'latitude': latitude,
        'longitude': longitude,
        'fotos': fotos,
      };

  factory MarcoZeroTransitoModel.fromJson(Map<String, dynamic> json) =>
      MarcoZeroTransitoModel(
        descricao: json['descricao'] as String?,
        latitude: json['latitude'] as String?,
        longitude: json['longitude'] as String?,
        fotos: (json['fotos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Helper para listas de enum no fromJson
List<CrimeTransitoFormaInteracao> _formasFromJson(List<dynamic>? raw) {
  if (raw == null) return const [];
  final result = <CrimeTransitoFormaInteracao>[];
  for (final e in raw) {
    final name = e?.toString();
    if (name == null) continue;
    for (final val in CrimeTransitoFormaInteracao.values) {
      if (val.name == name) {
        result.add(val);
        break;
      }
    }
  }
  return result;
}

/// Modelo completo do levantamento fotográfico e vestígios de trânsito
class CrimeTransitoLevantamentoModel {
  final DinamicaAcidente? dinamica;
  final String? dinamicaOutroDescricao;
  final int? quantidadeVeiculos;
  final MarcoZeroTransitoModel? marcoZero;
  final GrupoFotosModel? fotosLocalEncontrado;
  final List<GrupoFotosModel> fotosContextuais;
  final GrupoFotosModel? fotosSinalizacao;
  final List<VestigioViaModel> vestigios;
  final GrupoFotosModel? fotosComplementares;

  // Campos incorporados da antiga tela "Natureza da Ocorrência"
  final CrimeTransitoNaturezaTipo? tipoOcorrencia;
  final int? quantidadeUnidades;
  final List<CrimeTransitoFormaInteracao>? formasInteracao;
  final List<CrimeTransitoFormaInteracao>? observacoesComplementares;
  final bool? materialRecolhido;
  final String? materialDescricao;
  final bool? solicitacaoExamesComplementares;
  final String? laboratorioDestino;
  final String? examesDinamica;
  final String? croquiObservacoes;

  const CrimeTransitoLevantamentoModel({
    this.dinamica,
    this.dinamicaOutroDescricao,
    this.quantidadeVeiculos,
    this.marcoZero,
    this.fotosLocalEncontrado,
    this.fotosContextuais = const [],
    this.fotosSinalizacao,
    this.vestigios = const [],
    this.fotosComplementares,
    this.tipoOcorrencia,
    this.quantidadeUnidades,
    this.formasInteracao,
    this.observacoesComplementares,
    this.materialRecolhido,
    this.materialDescricao,
    this.solicitacaoExamesComplementares,
    this.laboratorioDestino,
    this.examesDinamica,
    this.croquiObservacoes,
  });

  Map<String, dynamic> toJson() => {
        'dinamica': dinamica?.name,
        'dinamicaOutroDescricao': dinamicaOutroDescricao,
        'quantidadeVeiculos': quantidadeVeiculos,
        'marcoZero': marcoZero?.toJson(),
        'fotosLocalEncontrado': fotosLocalEncontrado?.toJson(),
        'fotosContextuais': fotosContextuais.map((g) => g.toJson()).toList(),
        'fotosSinalizacao': fotosSinalizacao?.toJson(),
        'vestigios': vestigios.map((v) => v.toJson()).toList(),
        'fotosComplementares': fotosComplementares?.toJson(),
        'tipoOcorrencia': tipoOcorrencia?.name,
        'quantidadeUnidades': quantidadeUnidades,
        'formasInteracao': formasInteracao?.map((e) => e.name).toList(),
        'observacoesComplementares':
            observacoesComplementares?.map((e) => e.name).toList(),
        'materialRecolhido': materialRecolhido,
        'materialDescricao': materialDescricao,
        'solicitacaoExamesComplementares': solicitacaoExamesComplementares,
        'laboratorioDestino': laboratorioDestino,
        'examesDinamica': examesDinamica,
        'croquiObservacoes': croquiObservacoes,
      };

  factory CrimeTransitoLevantamentoModel.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoLevantamentoModel(
        dinamica: json['dinamica'] != null
            ? DinamicaAcidente.values.firstWhere(
                (e) => e.name == json['dinamica'],
                orElse: () => DinamicaAcidente.outro,
              )
            : null,
        dinamicaOutroDescricao: json['dinamicaOutroDescricao'] as String?,
        quantidadeVeiculos: json['quantidadeVeiculos'] as int?,
        marcoZero: json['marcoZero'] != null
            ? MarcoZeroTransitoModel.fromJson(
                json['marcoZero'] as Map<String, dynamic>,
              )
            : null,
        fotosLocalEncontrado: json['fotosLocalEncontrado'] != null
            ? GrupoFotosModel.fromJson(
                json['fotosLocalEncontrado'] as Map<String, dynamic>,
              )
            : null,
        fotosContextuais: (json['fotosContextuais'] as List<dynamic>?)
                ?.map(
                  (g) => GrupoFotosModel.fromJson(g as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        fotosSinalizacao: json['fotosSinalizacao'] != null
            ? GrupoFotosModel.fromJson(
                json['fotosSinalizacao'] as Map<String, dynamic>,
              )
            : null,
        vestigios: (json['vestigios'] as List<dynamic>?)
                ?.map(
                  (v) => VestigioViaModel.fromJson(v as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        fotosComplementares: json['fotosComplementares'] != null
            ? GrupoFotosModel.fromJson(
                json['fotosComplementares'] as Map<String, dynamic>,
              )
            : null,
        tipoOcorrencia: json['tipoOcorrencia'] != null
            ? CrimeTransitoNaturezaTipo.values.firstWhere(
                (e) => e.name == json['tipoOcorrencia'],
                orElse: () => CrimeTransitoNaturezaTipo.simples,
              )
            : null,
        quantidadeUnidades: json['quantidadeUnidades'] as int?,
        formasInteracao: (json['formasInteracao'] as List<dynamic>?) != null
            ? _formasFromJson(json['formasInteracao'] as List<dynamic>)
            : null,
        observacoesComplementares:
            (json['observacoesComplementares'] as List<dynamic>?) != null
                ? _formasFromJson(
                    json['observacoesComplementares'] as List<dynamic>,
                  )
                : null,
        materialRecolhido: json['materialRecolhido'] as bool?,
        materialDescricao: json['materialDescricao'] as String?,
        solicitacaoExamesComplementares:
            json['solicitacaoExamesComplementares'] as bool?,
        laboratorioDestino: json['laboratorioDestino'] as String?,
        examesDinamica: json['examesDinamica'] as String?,
        croquiObservacoes: json['croquiObservacoes'] as String?,
      );
}
