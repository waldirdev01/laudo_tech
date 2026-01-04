/// Modelo base (ficha mãe) com campos comuns a todas as 4 fichas
/// 
/// Campos iguais até "CONDIÇÕES METEOROLÓGICAS"
class FichaBaseModel {
  // HISTÓRICO
  final String? historico; // Breve resumo do histórico da ocorrência

  // ISOLAMENTO
  final bool? isolamentoSim;
  final bool? isolamentoNao;
  final bool? isolamentoTotal;
  final bool? isolamentoParcial;
  final bool? isolamentoViatura;
  final bool? isolamentoCones;
  final bool? isolamentoFitaZebrada;
  final bool? isolamentoPresencaFisica;
  final bool? isolamentoCuriososVoltaCorpo;
  final bool? isolamentoCorpoCobertoMovimentado;
  final bool? isolamentoDocumentosManuseados;
  final bool? isolamentoVestigiosRecolhidos;
  final bool? isolamentoAmpliacaoPerimetro;
  final String? isolamentoObservacoes;

  // PRESERVAÇÃO
  final bool? preservacaoSim;
  final bool? preservacaoNao;
  final bool? preservacaoInidoneo;
  final bool? preservacaoParcialmenteIdoneo;
  final bool? preservacaoCuriososNoPerimetro;
  final String? preservacaoPessoasAcessaram;
  final String? preservacaoAlteracoesDetectadas;

  // CONDIÇÕES METEOROLÓGICAS
  final bool? condicoesEstavel;
  final bool? condicoesNublado;
  final bool? condicoesParcialmenteNublado;
  final bool? condicoesChuvoso;

  // DEMAIS OBSERVAÇÕES
  final String? demaisObservacoes;

  FichaBaseModel({
    this.historico,
    this.isolamentoSim,
    this.isolamentoNao,
    this.isolamentoTotal,
    this.isolamentoParcial,
    this.isolamentoViatura,
    this.isolamentoCones,
    this.isolamentoFitaZebrada,
    this.isolamentoPresencaFisica,
    this.isolamentoCuriososVoltaCorpo,
    this.isolamentoCorpoCobertoMovimentado,
    this.isolamentoDocumentosManuseados,
    this.isolamentoVestigiosRecolhidos,
    this.isolamentoAmpliacaoPerimetro,
    this.isolamentoObservacoes,
    this.preservacaoSim,
    this.preservacaoNao,
    this.preservacaoInidoneo,
    this.preservacaoParcialmenteIdoneo,
    this.preservacaoCuriososNoPerimetro,
    this.preservacaoPessoasAcessaram,
    this.preservacaoAlteracoesDetectadas,
    this.condicoesEstavel,
    this.condicoesNublado,
    this.condicoesParcialmenteNublado,
    this.condicoesChuvoso,
    this.demaisObservacoes,
  });

  /// Converte para mapa de chaves/valores para preenchimento de template Word
  Map<String, String> toTemplateMap() {
    return {
      'historico': historico ?? '',
      'isolamentoSim': isolamentoSim == true ? 'X' : '',
      'isolamentoNao': isolamentoNao == true ? 'X' : '',
      'isolamentoTotal': isolamentoTotal == true ? 'X' : '',
      'isolamentoParcial': isolamentoParcial == true ? 'X' : '',
      'isolamentoViatura': isolamentoViatura == true ? 'X' : '',
      'isolamentoCones': isolamentoCones == true ? 'X' : '',
      'isolamentoFitaZebrada': isolamentoFitaZebrada == true ? 'X' : '',
      'isolamentoPresencaFisica': isolamentoPresencaFisica == true ? 'X' : '',
      'isolamentoCuriososVoltaCorpo': isolamentoCuriososVoltaCorpo == true ? 'X' : '',
      'isolamentoCorpoCobertoMovimentado': isolamentoCorpoCobertoMovimentado == true ? 'X' : '',
      'isolamentoDocumentosManuseados': isolamentoDocumentosManuseados == true ? 'X' : '',
      'isolamentoVestigiosRecolhidos': isolamentoVestigiosRecolhidos == true ? 'X' : '',
      'isolamentoAmpliacaoPerimetro': isolamentoAmpliacaoPerimetro == true ? 'X' : '',
      'isolamentoObservacoes': isolamentoObservacoes ?? '',
      'preservacaoSim': preservacaoSim == true ? 'X' : '',
      'preservacaoNao': preservacaoNao == true ? 'X' : '',
      'preservacaoInidoneo': preservacaoInidoneo == true ? 'X' : '',
      'preservacaoParcialmenteIdoneo': preservacaoParcialmenteIdoneo == true ? 'X' : '',
      'preservacaoCuriososNoPerimetro': preservacaoCuriososNoPerimetro == true ? 'X' : '',
      'preservacaoPessoasAcessaram': preservacaoPessoasAcessaram ?? '',
      'preservacaoAlteracoesDetectadas': preservacaoAlteracoesDetectadas ?? '',
      'condicoesEstavel': condicoesEstavel == true ? 'X' : '',
      'condicoesNublado': condicoesNublado == true ? 'X' : '',
      'condicoesParcialmenteNublado': condicoesParcialmenteNublado == true ? 'X' : '',
      'condicoesChuvoso': condicoesChuvoso == true ? 'X' : '',
      'demaisObservacoes': demaisObservacoes ?? '',
    };
  }

  Map<String, dynamic> toJson() => {
        'historico': historico,
        'isolamentoSim': isolamentoSim,
        'isolamentoNao': isolamentoNao,
        'isolamentoTotal': isolamentoTotal,
        'isolamentoParcial': isolamentoParcial,
        'isolamentoViatura': isolamentoViatura,
        'isolamentoCones': isolamentoCones,
        'isolamentoFitaZebrada': isolamentoFitaZebrada,
        'isolamentoPresencaFisica': isolamentoPresencaFisica,
        'isolamentoCuriososVoltaCorpo': isolamentoCuriososVoltaCorpo,
        'isolamentoCorpoCobertoMovimentado': isolamentoCorpoCobertoMovimentado,
        'isolamentoDocumentosManuseados': isolamentoDocumentosManuseados,
        'isolamentoVestigiosRecolhidos': isolamentoVestigiosRecolhidos,
        'isolamentoAmpliacaoPerimetro': isolamentoAmpliacaoPerimetro,
        'isolamentoObservacoes': isolamentoObservacoes,
        'preservacaoSim': preservacaoSim,
        'preservacaoNao': preservacaoNao,
        'preservacaoInidoneo': preservacaoInidoneo,
        'preservacaoParcialmenteIdoneo': preservacaoParcialmenteIdoneo,
        'preservacaoCuriososNoPerimetro': preservacaoCuriososNoPerimetro,
        'preservacaoPessoasAcessaram': preservacaoPessoasAcessaram,
        'preservacaoAlteracoesDetectadas': preservacaoAlteracoesDetectadas,
        'condicoesEstavel': condicoesEstavel,
        'condicoesNublado': condicoesNublado,
        'condicoesParcialmenteNublado': condicoesParcialmenteNublado,
        'condicoesChuvoso': condicoesChuvoso,
        'demaisObservacoes': demaisObservacoes,
      };

  factory FichaBaseModel.fromJson(Map<String, dynamic> json) => FichaBaseModel(
        historico: json['historico'] as String?,
        isolamentoSim: json['isolamentoSim'] as bool?,
        isolamentoNao: json['isolamentoNao'] as bool?,
        isolamentoTotal: json['isolamentoTotal'] as bool?,
        isolamentoParcial: json['isolamentoParcial'] as bool?,
        isolamentoViatura: json['isolamentoViatura'] as bool?,
        isolamentoCones: json['isolamentoCones'] as bool?,
        isolamentoFitaZebrada: json['isolamentoFitaZebrada'] as bool?,
        isolamentoPresencaFisica: json['isolamentoPresencaFisica'] as bool?,
        isolamentoCuriososVoltaCorpo: json['isolamentoCuriososVoltaCorpo'] as bool?,
        isolamentoCorpoCobertoMovimentado: json['isolamentoCorpoCobertoMovimentado'] as bool?,
        isolamentoDocumentosManuseados: json['isolamentoDocumentosManuseados'] as bool?,
        isolamentoVestigiosRecolhidos: json['isolamentoVestigiosRecolhidos'] as bool?,
        isolamentoAmpliacaoPerimetro: json['isolamentoAmpliacaoPerimetro'] as bool?,
        isolamentoObservacoes: json['isolamentoObservacoes'] as String?,
        preservacaoSim: json['preservacaoSim'] as bool?,
        preservacaoNao: json['preservacaoNao'] as bool?,
        preservacaoInidoneo: json['preservacaoInidoneo'] as bool?,
        preservacaoParcialmenteIdoneo: json['preservacaoParcialmenteIdoneo'] as bool?,
        preservacaoCuriososNoPerimetro: json['preservacaoCuriososNoPerimetro'] as bool?,
        preservacaoPessoasAcessaram: json['preservacaoPessoasAcessaram'] as String?,
        preservacaoAlteracoesDetectadas: json['preservacaoAlteracoesDetectadas'] as String?,
        condicoesEstavel: json['condicoesEstavel'] as bool?,
        condicoesNublado: json['condicoesNublado'] as bool?,
        condicoesParcialmenteNublado: json['condicoesParcialmenteNublado'] as bool?,
        condicoesChuvoso: json['condicoesChuvoso'] as bool?,
        demaisObservacoes: json['demaisObservacoes'] as String?,
      );

  FichaBaseModel copyWith({
    String? historico,
    bool? isolamentoSim,
    bool? isolamentoNao,
    bool? isolamentoTotal,
    bool? isolamentoParcial,
    bool? isolamentoViatura,
    bool? isolamentoCones,
    bool? isolamentoFitaZebrada,
    bool? isolamentoPresencaFisica,
    bool? isolamentoCuriososVoltaCorpo,
    bool? isolamentoCorpoCobertoMovimentado,
    bool? isolamentoDocumentosManuseados,
    bool? isolamentoVestigiosRecolhidos,
    bool? isolamentoAmpliacaoPerimetro,
    String? isolamentoObservacoes,
    bool? preservacaoSim,
    bool? preservacaoNao,
    bool? preservacaoInidoneo,
    bool? preservacaoParcialmenteIdoneo,
    bool? preservacaoCuriososNoPerimetro,
    String? preservacaoPessoasAcessaram,
    String? preservacaoAlteracoesDetectadas,
    bool? condicoesEstavel,
    bool? condicoesNublado,
    bool? condicoesParcialmenteNublado,
    bool? condicoesChuvoso,
    String? demaisObservacoes,
  }) {
    return FichaBaseModel(
      historico: historico ?? this.historico,
      isolamentoSim: isolamentoSim ?? this.isolamentoSim,
      isolamentoNao: isolamentoNao ?? this.isolamentoNao,
      isolamentoTotal: isolamentoTotal ?? this.isolamentoTotal,
      isolamentoParcial: isolamentoParcial ?? this.isolamentoParcial,
      isolamentoViatura: isolamentoViatura ?? this.isolamentoViatura,
      isolamentoCones: isolamentoCones ?? this.isolamentoCones,
      isolamentoFitaZebrada: isolamentoFitaZebrada ?? this.isolamentoFitaZebrada,
      isolamentoPresencaFisica: isolamentoPresencaFisica ?? this.isolamentoPresencaFisica,
      isolamentoCuriososVoltaCorpo: isolamentoCuriososVoltaCorpo ?? this.isolamentoCuriososVoltaCorpo,
      isolamentoCorpoCobertoMovimentado: isolamentoCorpoCobertoMovimentado ?? this.isolamentoCorpoCobertoMovimentado,
      isolamentoDocumentosManuseados: isolamentoDocumentosManuseados ?? this.isolamentoDocumentosManuseados,
      isolamentoVestigiosRecolhidos: isolamentoVestigiosRecolhidos ?? this.isolamentoVestigiosRecolhidos,
      isolamentoAmpliacaoPerimetro: isolamentoAmpliacaoPerimetro ?? this.isolamentoAmpliacaoPerimetro,
      isolamentoObservacoes: isolamentoObservacoes ?? this.isolamentoObservacoes,
      preservacaoSim: preservacaoSim ?? this.preservacaoSim,
      preservacaoNao: preservacaoNao ?? this.preservacaoNao,
      preservacaoInidoneo: preservacaoInidoneo ?? this.preservacaoInidoneo,
      preservacaoParcialmenteIdoneo: preservacaoParcialmenteIdoneo ?? this.preservacaoParcialmenteIdoneo,
      preservacaoCuriososNoPerimetro: preservacaoCuriososNoPerimetro ?? this.preservacaoCuriososNoPerimetro,
      preservacaoPessoasAcessaram: preservacaoPessoasAcessaram ?? this.preservacaoPessoasAcessaram,
      preservacaoAlteracoesDetectadas: preservacaoAlteracoesDetectadas ?? this.preservacaoAlteracoesDetectadas,
      condicoesEstavel: condicoesEstavel ?? this.condicoesEstavel,
      condicoesNublado: condicoesNublado ?? this.condicoesNublado,
      condicoesParcialmenteNublado: condicoesParcialmenteNublado ?? this.condicoesParcialmenteNublado,
      condicoesChuvoso: condicoesChuvoso ?? this.condicoesChuvoso,
      demaisObservacoes: demaisObservacoes ?? this.demaisObservacoes,
    );
  }
}

