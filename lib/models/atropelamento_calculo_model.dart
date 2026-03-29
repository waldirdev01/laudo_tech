/// Presets de coeficiente de atrito pedestre-solo (µ_ped)
enum AtropelamentoTipoPiso {
  asfaltoSeco(0.66),
  asfaltoMolhado(0.50),
  terraGrama(0.79);

  final double mu;
  const AtropelamentoTipoPiso(this.mu);
}

/// Tipo de vítima (adulto/criança) para eficiência de projeção E_p
enum AtropelamentoTipoVitima { adulto, crianca }

/// Altura do frontal do veículo para eficiência de projeção E_p
enum AtropelamentoFrontalVeiculo { baixo, alto }

/// Vestígios e parâmetros para cálculo de velocidade de impacto em atropelamento
/// (Método de John Searle 1983 / atualizado 2016)
class AtropelamentoCalculoModel {
  /// Distância total de projeção: ponto de impacto → ponto de parada (m)
  final double? dt;

  /// Distância de transporte (corpo carregado pelo veículo antes de separar) (m)
  final double? d;

  /// Deslocamento horizontal no ar - fase aérea (m)
  final double? d1;

  /// Deslocamento horizontal no solo - saltos + deslizamento (m)
  final double? d2;

  /// Tipo de piso (define µ: asfalto 0,66; grama 0,79)
  final AtropelamentoTipoPiso? tipoPiso;

  /// Coeficiente de atrito customizado (se não usar tipoPiso)
  final double? muCustom;

  /// Tipo de vítima (adulto/criança) para tabela E_p
  final AtropelamentoTipoVitima? tipoVitima;

  /// Altura do frontal do veículo (baixo/alto) para tabela E_p
  final AtropelamentoFrontalVeiculo? frontalVeiculo;

  /// Diferença de altura entre C.G. da pessoa e o nível do piso (m) - Searle 2016
  final double? h;

  /// Inclinação do terreno em graus (+ subida, - descida) - Searle 2016
  final double? alphaGraus;

  /// Massa do veículo (kg)
  final double? massaVeiculoKg;

  /// Massa do pedestre (kg)
  final double? massaPedestreKg;

  /// Eficiência de projeção E_p (0–1). Se null, calculada pela tabela Searle.
  final double? epCustom;

  /// Faixa opcional: µ mínimo (para intervalo de velocidade)
  final double? muMin;
  /// Faixa opcional: µ máximo (para intervalo de velocidade)
  final double? muMax;

  /// true = Northwestern (forward projection), false = Searle (frente + perfil pedestre)
  final bool? useNorthwestern;

  const AtropelamentoCalculoModel({
    this.dt,
    this.d,
    this.d1,
    this.d2,
    this.tipoPiso,
    this.muCustom,
    this.tipoVitima,
    this.frontalVeiculo,
    this.h,
    this.alphaGraus,
    this.massaVeiculoKg,
    this.massaPedestreKg,
    this.epCustom,
    this.muMin,
    this.muMax,
    this.useNorthwestern,
  });

  /// Coeficiente de atrito efetivo (tipoPiso ou muCustom)
  double? get mu {
    if (muCustom != null) return muCustom;
    return tipoPiso?.mu;
  }

  Map<String, dynamic> toJson() => {
        'dt': dt,
        'd': d,
        'd1': d1,
        'd2': d2,
        'tipoPiso': tipoPiso?.name,
        'muCustom': muCustom,
        'tipoVitima': tipoVitima?.name,
        'frontalVeiculo': frontalVeiculo?.name,
        'h': h,
        'alphaGraus': alphaGraus,
        'massaVeiculoKg': massaVeiculoKg,
        'massaPedestreKg': massaPedestreKg,
        'epCustom': epCustom,
        'muMin': muMin,
        'muMax': muMax,
        'useNorthwestern': useNorthwestern,
      };

  static AtropelamentoTipoPiso? _tipoPisoFromJson(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s == 'asfalto') return AtropelamentoTipoPiso.asfaltoSeco;
    if (s == 'grama') return AtropelamentoTipoPiso.terraGrama;
    for (final e in AtropelamentoTipoPiso.values) {
      if (e.name == s) return e;
    }
    return null;
  }

  static AtropelamentoTipoVitima? _tipoVitimaFromJson(dynamic v) {
    if (v == null) return null;
    for (final e in AtropelamentoTipoVitima.values) {
      if (e.name == v) return e;
    }
    return null;
  }

  static AtropelamentoFrontalVeiculo? _frontalFromJson(dynamic v) {
    if (v == null) return null;
    for (final e in AtropelamentoFrontalVeiculo.values) {
      if (e.name == v) return e;
    }
    return null;
  }

  factory AtropelamentoCalculoModel.fromJson(Map<String, dynamic> json) =>
      AtropelamentoCalculoModel(
        dt: (json['dt'] as num?)?.toDouble(),
        d: (json['d'] as num?)?.toDouble(),
        d1: (json['d1'] as num?)?.toDouble(),
        d2: (json['d2'] as num?)?.toDouble(),
        tipoPiso: _tipoPisoFromJson(json['tipoPiso']),
        muCustom: (json['muCustom'] as num?)?.toDouble(),
        tipoVitima: _tipoVitimaFromJson(json['tipoVitima']),
        frontalVeiculo: _frontalFromJson(json['frontalVeiculo']),
        h: (json['h'] as num?)?.toDouble(),
        alphaGraus: (json['alphaGraus'] as num?)?.toDouble(),
        massaVeiculoKg: (json['massaVeiculoKg'] as num?)?.toDouble(),
        massaPedestreKg: (json['massaPedestreKg'] as num?)?.toDouble(),
        epCustom: (json['epCustom'] as num?)?.toDouble(),
        muMin: (json['muMin'] as num?)?.toDouble(),
        muMax: (json['muMax'] as num?)?.toDouble(),
        useNorthwestern: json['useNorthwestern'] as bool?,
      );

  AtropelamentoCalculoModel copyWith({
    double? dt,
    double? d,
    double? d1,
    double? d2,
    AtropelamentoTipoPiso? tipoPiso,
    double? muCustom,
    AtropelamentoTipoVitima? tipoVitima,
    AtropelamentoFrontalVeiculo? frontalVeiculo,
    double? h,
    double? alphaGraus,
    double? massaVeiculoKg,
    double? massaPedestreKg,
    double? epCustom,
    double? muMin,
    double? muMax,
    bool? useNorthwestern,
  }) {
    return AtropelamentoCalculoModel(
      dt: dt ?? this.dt,
      d: d ?? this.d,
      d1: d1 ?? this.d1,
      d2: d2 ?? this.d2,
      tipoPiso: tipoPiso ?? this.tipoPiso,
      muCustom: muCustom ?? this.muCustom,
      tipoVitima: tipoVitima ?? this.tipoVitima,
      frontalVeiculo: frontalVeiculo ?? this.frontalVeiculo,
      h: h ?? this.h,
      alphaGraus: alphaGraus ?? this.alphaGraus,
      massaVeiculoKg: massaVeiculoKg ?? this.massaVeiculoKg,
      massaPedestreKg: massaPedestreKg ?? this.massaPedestreKg,
      epCustom: epCustom ?? this.epCustom,
      muMin: muMin ?? this.muMin,
      muMax: muMax ?? this.muMax,
      useNorthwestern: useNorthwestern ?? this.useNorthwestern,
    );
  }
}
