import 'crime_transito_levantamento_model.dart';
import 'crime_transito_model.dart';

/// Item do guia de causas determinantes (modelos SDT — IC/PCDF, 2013),
/// exibido condicionalmente à [DinamicaAcidente] na tela Dinâmica do Fato.
class CausaDeterminanteTransito {
  final String id;
  final String referencia;
  final String titulo;

  const CausaDeterminanteTransito({
    required this.id,
    required this.referencia,
    required this.titulo,
  });
}

/// Catálogo e derivação da dinâmica principal (mesma prioridade do levantamento).
class CausasDeterminantesCatalogo {
  CausasDeterminantesCatalogo._();

  static DinamicaAcidente? derivarDinamica(
    Iterable<CrimeTransitoFormaInteracao>? formas,
  ) {
    if (formas == null || formas.isEmpty) return null;
    final s = formas.toSet();
    if (s.contains(CrimeTransitoFormaInteracao.atropelamento)) {
      return DinamicaAcidente.atropelamento;
    }
    if (s.contains(CrimeTransitoFormaInteracao.saidaPista)) {
      return DinamicaAcidente.saidaPista;
    }
    if (s.contains(CrimeTransitoFormaInteracao.choque) ||
        s.contains(CrimeTransitoFormaInteracao.objetoFixo)) {
      return DinamicaAcidente.choqueObjetoFixo;
    }
    if (s.contains(CrimeTransitoFormaInteracao.colisaoFrontal)) {
      return DinamicaAcidente.colisaoFrontal;
    }
    if (s.contains(CrimeTransitoFormaInteracao.colisaoTraseira)) {
      return DinamicaAcidente.colisaoTraseira;
    }
    if (s.any(
      (f) => const {
        CrimeTransitoFormaInteracao.colisaoTransversal,
        CrimeTransitoFormaInteracao.colisaoLateral,
        CrimeTransitoFormaInteracao.abalroamento,
      }.contains(f),
    )) {
      return DinamicaAcidente.colisaoTransversalLateral;
    }
    if (s.contains(CrimeTransitoFormaInteracao.outro)) {
      return DinamicaAcidente.outro;
    }
    if (s.isNotEmpty) return DinamicaAcidente.outro;
    return null;
  }

  static String labelDinamica(DinamicaAcidente d) => switch (d) {
        DinamicaAcidente.atropelamento => 'Atropelamento',
        DinamicaAcidente.colisaoFrontal => 'Colisão frontal',
        DinamicaAcidente.colisaoTraseira => 'Colisão traseira / engavetamento',
        DinamicaAcidente.colisaoTransversalLateral =>
          'Colisão transversal, lateral, interceptação ou ultrapassagem',
        DinamicaAcidente.saidaPista =>
          'Saída de pista, capotamento ou tombamento',
        DinamicaAcidente.choqueObjetoFixo =>
          'Choque / colisão com obstáculo fixo',
        DinamicaAcidente.outro => 'Outras causas ou cenários mistos',
      };

  static List<CausaDeterminanteTransito> opcoesPara(DinamicaAcidente d) {
    return switch (d) {
      DinamicaAcidente.atropelamento => _atropelamento,
      DinamicaAcidente.colisaoFrontal => _colisaoFrontal,
      DinamicaAcidente.colisaoTraseira => _colisaoTraseira,
      DinamicaAcidente.colisaoTransversalLateral => _colisaoTransversal,
      DinamicaAcidente.saidaPista => _saidaPista,
      DinamicaAcidente.choqueObjetoFixo => _choqueObjetoFixo,
      DinamicaAcidente.outro => _outro,
    };
  }

  // --- A – ATROPELAMENTO -------------------------------------------------
  static const _atropelamento = [
    CausaDeterminanteTransito(
      id: 'a1_1',
      referencia: 'A.1.1',
      titulo: 'Atropelamento sem conclusão',
    ),
    CausaDeterminanteTransito(
      id: 'a1_2',
      referencia: 'A.1.2',
      titulo: 'Atropelamento com conclusão',
    ),
    CausaDeterminanteTransito(
      id: 'a1_3',
      referencia: 'A.1.3',
      titulo: 'Atropelamento em acostamento',
    ),
    CausaDeterminanteTransito(
      id: 'a1_4',
      referencia: 'A.1.4',
      titulo: 'Atropelamento em marcha à ré',
    ),
    CausaDeterminanteTransito(
      id: 'a1_5',
      referencia: 'A.1.5',
      titulo: 'Atropelamento com mudança de direção',
    ),
    CausaDeterminanteTransito(
      id: 'a2',
      referencia: 'A.2',
      titulo: 'Atropelamento de animal',
    ),
  ];

  // --- B.11 / B.12 – COLISÃO FRONTAL ------------------------------------
  static const _colisaoFrontal = [
    CausaDeterminanteTransito(
      id: 'b11_1',
      referencia: 'B.11.1',
      titulo: 'Invasão de faixa de trânsito',
    ),
    CausaDeterminanteTransito(
      id: 'b11_2',
      referencia: 'B.11.2',
      titulo: 'Ultrapassagem em condições desfavoráveis',
    ),
    CausaDeterminanteTransito(
      id: 'b11_3',
      referencia: 'B.11.3',
      titulo: 'Ultrapassagem em local proibido',
    ),
    CausaDeterminanteTransito(
      id: 'b11_4',
      referencia: 'B.11.4',
      titulo: 'Contramão de direção',
    ),
    CausaDeterminanteTransito(
      id: 'b12_1',
      referencia: 'B.12.1',
      titulo: 'Colisão em cruzamento sinalizado — funcionamento normal',
    ),
    CausaDeterminanteTransito(
      id: 'b12_2',
      referencia: 'B.12.2',
      titulo: 'Colisão em cruzamento sinalizado — modo intermitente',
    ),
  ];

  // --- B.1 / B.2 – TRASEIRA / ENGAVETAMENTO ----------------------------
  static const _colisaoTraseira = [
    CausaDeterminanteTransito(
      id: 'b1',
      referencia: 'B.1',
      titulo: 'Colisão de traseira — dois veículos',
    ),
    CausaDeterminanteTransito(
      id: 'b2',
      referencia: 'B.2',
      titulo: 'Engavetamento (mínimo três veículos)',
    ),
    CausaDeterminanteTransito(
      id: 'b2_1',
      referencia: 'B.2.1',
      titulo: 'Constatação de um evento com impulsão',
    ),
    CausaDeterminanteTransito(
      id: 'b2_2',
      referencia: 'B.2.2',
      titulo: 'Constatação de dois eventos distintos',
    ),
    CausaDeterminanteTransito(
      id: 'b2_3',
      referencia: 'B.2.3',
      titulo: 'Indeterminação da cronologia entre os eventos',
    ),
  ];

  // --- B.3–B.10 (exceto frontal própria) --------------------------------
  static const _colisaoTransversal = [
    CausaDeterminanteTransito(
      id: 'b3',
      referencia: 'B.3',
      titulo: 'Marcha à ré',
    ),
    CausaDeterminanteTransito(
      id: 'b4',
      referencia: 'B.4',
      titulo: 'Interceptação x excesso de velocidade (eixo geral)',
    ),
    CausaDeterminanteTransito(
      id: 'b4_1',
      referencia: 'B.4.1',
      titulo: 'Entrada na pista',
    ),
    CausaDeterminanteTransito(
      id: 'b4_2',
      referencia: 'B.4.2',
      titulo: 'Entrada na faixa de trânsito / mudança de faixa',
    ),
    CausaDeterminanteTransito(
      id: 'b4_3',
      referencia: 'B.4.3',
      titulo: 'Interceptação com origem de movimentação não determinada',
    ),
    CausaDeterminanteTransito(
      id: 'b4_4',
      referencia: 'B.4.4',
      titulo: 'Manobra de conversão regular',
    ),
    CausaDeterminanteTransito(
      id: 'b4_5',
      referencia: 'B.4.5',
      titulo: 'Manobra de derivação',
    ),
    CausaDeterminanteTransito(
      id: 'b4_6',
      referencia: 'B.4.6',
      titulo: 'Cruzamento sinalizado',
    ),
    CausaDeterminanteTransito(
      id: 'b4_7',
      referencia: 'B.4.7',
      titulo: 'Cruzamento não sinalizado',
    ),
    CausaDeterminanteTransito(
      id: 'b4_8',
      referencia: 'B.4.8',
      titulo: 'Entrada em rotatória sinalizada',
    ),
    CausaDeterminanteTransito(
      id: 'b4_9',
      referencia: 'B.4.9',
      titulo: 'Entrada em rotatória não sinalizada',
    ),
    CausaDeterminanteTransito(
      id: 'b4_10',
      referencia: 'B.4.10',
      titulo: 'Excesso de velocidade em análise de interceptação',
    ),
    CausaDeterminanteTransito(
      id: 'b5',
      referencia: 'B.5',
      titulo: 'Manobra irregular',
    ),
    CausaDeterminanteTransito(
      id: 'b6',
      referencia: 'B.6',
      titulo: 'Manobra irregular de um veículo e excesso de velocidade do outro (manobra regular)',
    ),
    CausaDeterminanteTransito(
      id: 'b7',
      referencia: 'B.7',
      titulo: 'Manobra irregular e ultrapassagem em local proibido do outro',
    ),
    CausaDeterminanteTransito(
      id: 'b8',
      referencia: 'B.8',
      titulo: 'Ultrapassagem em entroncamento e manobra regular do outro',
    ),
    CausaDeterminanteTransito(
      id: 'b9',
      referencia: 'B.9',
      titulo: 'Colisão em acostamentos com bicicletas ou veículos parados',
    ),
    CausaDeterminanteTransito(
      id: 'b10',
      referencia: 'B.10',
      titulo: 'Colisão com mudança de direção',
    ),
  ];

  // --- D.1–D.3 – SAÍDA DE PISTA / CAPOTAMENTO ----------------------------
  static const _saidaPista = [
    CausaDeterminanteTransito(
      id: 'd1',
      referencia: 'D.1',
      titulo: 'Saída de pista, colisão com obstáculo fixo, capotamento ou tombamento',
    ),
    CausaDeterminanteTransito(
      id: 'd1_1',
      referencia: 'D.1.1',
      titulo: 'Desvio de direção',
    ),
    CausaDeterminanteTransito(
      id: 'd1_2',
      referencia: 'D.1.2',
      titulo: 'Perda de controle de direção',
    ),
    CausaDeterminanteTransito(
      id: 'd1_3',
      referencia: 'D.1.3',
      titulo: 'Perda de controle aliada a velocidade excessiva',
    ),
    CausaDeterminanteTransito(
      id: 'd2',
      referencia: 'D.2',
      titulo: 'Acidentes em curvas',
    ),
    CausaDeterminanteTransito(
      id: 'd2_1',
      referencia: 'D.2.1',
      titulo: 'Velocidade acima do limite da curva',
    ),
    CausaDeterminanteTransito(
      id: 'd2_2',
      referencia: 'D.2.2',
      titulo: 'Perda de controle de direção (em curva)',
    ),
    CausaDeterminanteTransito(
      id: 'd3',
      referencia: 'D.3',
      titulo: 'Acidentes relacionados à topografia do local',
    ),
  ];

  // --- Choque / objeto fixo + ausências frequentes (C) ------------------
  static const _choqueObjetoFixo = [
    CausaDeterminanteTransito(
      id: 'd1',
      referencia: 'D.1',
      titulo: 'Saída de pista / obstáculo fixo / capotamento ou tombamento',
    ),
    CausaDeterminanteTransito(
      id: 'd1_1',
      referencia: 'D.1.1',
      titulo: 'Desvio de direção',
    ),
    CausaDeterminanteTransito(
      id: 'd1_2',
      referencia: 'D.1.2',
      titulo: 'Perda de controle de direção',
    ),
    CausaDeterminanteTransito(
      id: 'c6',
      referencia: 'C.6',
      titulo: 'Ausência de elementos para cálculo preciso de velocidade',
    ),
    CausaDeterminanteTransito(
      id: 'c7',
      referencia: 'C.7',
      titulo: 'Ausência da origem de movimentação de um veículo',
    ),
    CausaDeterminanteTransito(
      id: 'c8',
      referencia: 'C.8',
      titulo: 'Ausência da origem de movimentação de ambos os veículos',
    ),
  ];

  /// “Outro”: oferece panorama por capítulo do documento de referência.
  static const _outro = [
    CausaDeterminanteTransito(
      id: 'a1_1',
      referencia: 'A.1.1',
      titulo: '(Atropelamento) Sem conclusão',
    ),
    CausaDeterminanteTransito(
      id: 'b1',
      referencia: 'B.1',
      titulo: '(Colisões) Traseira — dois veículos',
    ),
    CausaDeterminanteTransito(
      id: 'c1',
      referencia: 'C.1',
      titulo: '(Sem conclusão) Colisão lateral longitudinal',
    ),
    CausaDeterminanteTransito(
      id: 'c2',
      referencia: 'C.2',
      titulo: '(Sem conclusão) Colisão frontal nas proximidades do centro da pista',
    ),
    CausaDeterminanteTransito(
      id: 'd1',
      referencia: 'D.1',
      titulo: '(Ação direta) Saída de pista / obstáculo fixo / capotamento ou tombamento',
    ),
    CausaDeterminanteTransito(
      id: 'b13_1',
      referencia: 'B.13.1',
      titulo: '(Especial) Motocicleta x porta de veículo',
    ),
    CausaDeterminanteTransito(
      id: 'b13_2',
      referencia: 'B.13.2',
      titulo: '(Especial) Veículo x bicicleta na mesma faixa',
    ),
  ];
}
