/// Tipos de ocorrência disponíveis no sistema
enum TipoOcorrencia {
  furtoDanoExameLocal('FURTO / DANO / EXAME DE LOCAL'),
  cvli('CVLI - CRIMES VIOLENTOS LETAIS INTENCIONAIS'),
  morteEsclarecer('MORTE A ESCLARECER'),
  crimeTransito('CRIME DE TRÂNSITO')
  // vistoriaVeiculo('VISTORIA EM VEÍCULO'),
  ;

  final String label;
  const TipoOcorrencia(this.label);

  static List<TipoOcorrencia> get tiposDisponiveis => [
    furtoDanoExameLocal,
    cvli,
    morteEsclarecer,
    crimeTransito,
  ];
}
