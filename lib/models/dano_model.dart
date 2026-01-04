/// Modelo para dados específicos de investigação de dano (art. 163 - CP/1940)
class DanoModel {
  // 1. Houve o emprego de substância inflamável ou explosiva?
  final bool? substanciaInflamavelExplosivaSim;
  final bool? substanciaInflamavelExplosivaNao;

  // 2. O dano foi contra o patrimônio da União, Estado, Município, empresa concessionária de serviços públicos ou sociedade de economia mista?
  final bool? danoPatrimonioPublicoSim;
  final bool? danoPatrimonioPublicoNao;

  // 3. Houve prejuízo considerável para a vítima?
  final bool? prejuizoConsideravelSim;
  final bool? prejuizoConsideravelNao;

  // 4. É possível identificar o instrumento e/ou substância empregados no evento? Qual?
  final bool? identificarInstrumentoSubstanciaSim;
  final bool? identificarInstrumentoSubstanciaNao;
  final String? qualInstrumentoSubstancia;

  // 5. O local examinado possibilitou a identificação de algum vestígio? Em caso positivo, qual?
  final bool? identificacaoVestigioSim;
  final bool? identificacaoVestigioNao;
  final String? qualVestigio;

  // 6. Qual foi o dano causado e qual é o valor estimado dos prejuízos?
  final String? danoCausado;
  final String? valorEstimadoPrejuizos;

  // 7. É possível identificar o número de pessoas que participaram do evento?
  final bool? identificarNumeroPessoasSim;
  final bool? identificarNumeroPessoasNao;
  final String? numeroPessoas;

  // 8. Existem vestígios no local que possam indicar a autoria do delito? Caso positivo, quais?
  final bool? vestigiosAutoriaSim;
  final bool? vestigiosAutoriaNao;
  final String? quaisVestigiosAutoria;

  // 9. É possível identificar como foi a dinâmica do evento?
  final bool? identificarDinamicaSim;
  final bool? identificarDinamicaNao;
  final String? dinamicaEvento;

  DanoModel({
    this.substanciaInflamavelExplosivaSim,
    this.substanciaInflamavelExplosivaNao,
    this.danoPatrimonioPublicoSim,
    this.danoPatrimonioPublicoNao,
    this.prejuizoConsideravelSim,
    this.prejuizoConsideravelNao,
    this.identificarInstrumentoSubstanciaSim,
    this.identificarInstrumentoSubstanciaNao,
    this.qualInstrumentoSubstancia,
    this.identificacaoVestigioSim,
    this.identificacaoVestigioNao,
    this.qualVestigio,
    this.danoCausado,
    this.valorEstimadoPrejuizos,
    this.identificarNumeroPessoasSim,
    this.identificarNumeroPessoasNao,
    this.numeroPessoas,
    this.vestigiosAutoriaSim,
    this.vestigiosAutoriaNao,
    this.quaisVestigiosAutoria,
    this.identificarDinamicaSim,
    this.identificarDinamicaNao,
    this.dinamicaEvento,
  });

  Map<String, dynamic> toJson() => {
        'substanciaInflamavelExplosivaSim': substanciaInflamavelExplosivaSim,
        'substanciaInflamavelExplosivaNao': substanciaInflamavelExplosivaNao,
        'danoPatrimonioPublicoSim': danoPatrimonioPublicoSim,
        'danoPatrimonioPublicoNao': danoPatrimonioPublicoNao,
        'prejuizoConsideravelSim': prejuizoConsideravelSim,
        'prejuizoConsideravelNao': prejuizoConsideravelNao,
        'identificarInstrumentoSubstanciaSim': identificarInstrumentoSubstanciaSim,
        'identificarInstrumentoSubstanciaNao': identificarInstrumentoSubstanciaNao,
        'qualInstrumentoSubstancia': qualInstrumentoSubstancia,
        'identificacaoVestigioSim': identificacaoVestigioSim,
        'identificacaoVestigioNao': identificacaoVestigioNao,
        'qualVestigio': qualVestigio,
        'danoCausado': danoCausado,
        'valorEstimadoPrejuizos': valorEstimadoPrejuizos,
        'identificarNumeroPessoasSim': identificarNumeroPessoasSim,
        'identificarNumeroPessoasNao': identificarNumeroPessoasNao,
        'numeroPessoas': numeroPessoas,
        'vestigiosAutoriaSim': vestigiosAutoriaSim,
        'vestigiosAutoriaNao': vestigiosAutoriaNao,
        'quaisVestigiosAutoria': quaisVestigiosAutoria,
        'identificarDinamicaSim': identificarDinamicaSim,
        'identificarDinamicaNao': identificarDinamicaNao,
        'dinamicaEvento': dinamicaEvento,
      };

  factory DanoModel.fromJson(Map<String, dynamic> json) => DanoModel(
        substanciaInflamavelExplosivaSim: json['substanciaInflamavelExplosivaSim'] as bool?,
        substanciaInflamavelExplosivaNao: json['substanciaInflamavelExplosivaNao'] as bool?,
        danoPatrimonioPublicoSim: json['danoPatrimonioPublicoSim'] as bool?,
        danoPatrimonioPublicoNao: json['danoPatrimonioPublicoNao'] as bool?,
        prejuizoConsideravelSim: json['prejuizoConsideravelSim'] as bool?,
        prejuizoConsideravelNao: json['prejuizoConsideravelNao'] as bool?,
        identificarInstrumentoSubstanciaSim: json['identificarInstrumentoSubstanciaSim'] as bool?,
        identificarInstrumentoSubstanciaNao: json['identificarInstrumentoSubstanciaNao'] as bool?,
        qualInstrumentoSubstancia: json['qualInstrumentoSubstancia'] as String?,
        identificacaoVestigioSim: json['identificacaoVestigioSim'] as bool?,
        identificacaoVestigioNao: json['identificacaoVestigioNao'] as bool?,
        qualVestigio: json['qualVestigio'] as String?,
        danoCausado: json['danoCausado'] as String?,
        valorEstimadoPrejuizos: json['valorEstimadoPrejuizos'] as String?,
        identificarNumeroPessoasSim: json['identificarNumeroPessoasSim'] as bool?,
        identificarNumeroPessoasNao: json['identificarNumeroPessoasNao'] as bool?,
        numeroPessoas: json['numeroPessoas'] as String?,
        vestigiosAutoriaSim: json['vestigiosAutoriaSim'] as bool?,
        vestigiosAutoriaNao: json['vestigiosAutoriaNao'] as bool?,
        quaisVestigiosAutoria: json['quaisVestigiosAutoria'] as String?,
        identificarDinamicaSim: json['identificarDinamicaSim'] as bool?,
        identificarDinamicaNao: json['identificarDinamicaNao'] as bool?,
        dinamicaEvento: json['dinamicaEvento'] as String?,
      );

  DanoModel copyWith({
    bool? substanciaInflamavelExplosivaSim,
    bool? substanciaInflamavelExplosivaNao,
    bool? danoPatrimonioPublicoSim,
    bool? danoPatrimonioPublicoNao,
    bool? prejuizoConsideravelSim,
    bool? prejuizoConsideravelNao,
    bool? identificarInstrumentoSubstanciaSim,
    bool? identificarInstrumentoSubstanciaNao,
    String? qualInstrumentoSubstancia,
    bool? identificacaoVestigioSim,
    bool? identificacaoVestigioNao,
    String? qualVestigio,
    String? danoCausado,
    String? valorEstimadoPrejuizos,
    bool? identificarNumeroPessoasSim,
    bool? identificarNumeroPessoasNao,
    String? numeroPessoas,
    bool? vestigiosAutoriaSim,
    bool? vestigiosAutoriaNao,
    String? quaisVestigiosAutoria,
    bool? identificarDinamicaSim,
    bool? identificarDinamicaNao,
    String? dinamicaEvento,
  }) {
    return DanoModel(
      substanciaInflamavelExplosivaSim: substanciaInflamavelExplosivaSim ?? this.substanciaInflamavelExplosivaSim,
      substanciaInflamavelExplosivaNao: substanciaInflamavelExplosivaNao ?? this.substanciaInflamavelExplosivaNao,
      danoPatrimonioPublicoSim: danoPatrimonioPublicoSim ?? this.danoPatrimonioPublicoSim,
      danoPatrimonioPublicoNao: danoPatrimonioPublicoNao ?? this.danoPatrimonioPublicoNao,
      prejuizoConsideravelSim: prejuizoConsideravelSim ?? this.prejuizoConsideravelSim,
      prejuizoConsideravelNao: prejuizoConsideravelNao ?? this.prejuizoConsideravelNao,
      identificarInstrumentoSubstanciaSim: identificarInstrumentoSubstanciaSim ?? this.identificarInstrumentoSubstanciaSim,
      identificarInstrumentoSubstanciaNao: identificarInstrumentoSubstanciaNao ?? this.identificarInstrumentoSubstanciaNao,
      qualInstrumentoSubstancia: qualInstrumentoSubstancia ?? this.qualInstrumentoSubstancia,
      identificacaoVestigioSim: identificacaoVestigioSim ?? this.identificacaoVestigioSim,
      identificacaoVestigioNao: identificacaoVestigioNao ?? this.identificacaoVestigioNao,
      qualVestigio: qualVestigio ?? this.qualVestigio,
      danoCausado: danoCausado ?? this.danoCausado,
      valorEstimadoPrejuizos: valorEstimadoPrejuizos ?? this.valorEstimadoPrejuizos,
      identificarNumeroPessoasSim: identificarNumeroPessoasSim ?? this.identificarNumeroPessoasSim,
      identificarNumeroPessoasNao: identificarNumeroPessoasNao ?? this.identificarNumeroPessoasNao,
      numeroPessoas: numeroPessoas ?? this.numeroPessoas,
      vestigiosAutoriaSim: vestigiosAutoriaSim ?? this.vestigiosAutoriaSim,
      vestigiosAutoriaNao: vestigiosAutoriaNao ?? this.vestigiosAutoriaNao,
      quaisVestigiosAutoria: quaisVestigiosAutoria ?? this.quaisVestigiosAutoria,
      identificarDinamicaSim: identificarDinamicaSim ?? this.identificarDinamicaSim,
      identificarDinamicaNao: identificarDinamicaNao ?? this.identificarDinamicaNao,
      dinamicaEvento: dinamicaEvento ?? this.dinamicaEvento,
    );
  }
}

