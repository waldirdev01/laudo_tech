/// Tipos de ocorrência disponíveis no sistema
enum TipoOcorrencia {
  furtoDanoExameLocal('FURTO / DANO / EXAME DE LOCAL'),
  // Outros tipos serão adicionados depois
  // crimeTransito('CRIME DE TRÂNSITO'),
  // cvli('CVLI'),
  // vistoriaVeiculo('VISTORIA EM VEÍCULO'),
  ;

  final String label;
  const TipoOcorrencia(this.label);

  static List<TipoOcorrencia> get tiposDisponiveis => [
        furtoDanoExameLocal,
        // Adicionar outros conforme implementamos
      ];
}

