import 'dart:math';

/// Constante gravidade (m/s²)
const double _g = 9.81;

/// Converte m/s para km/h
double msParaKmh(double ms) => ms * 3.6;

// ─── Searle (simplificado) ───────────────────────────────────────────────
// Vp = sqrt(2 * g * µ_ped * s)
// Vc_Searle = Vp / Ep

/// Velocidade de projeção (m/s): Vp = sqrt(2 * g * µ * s)
double vpProjecao(double sMetros, double mu) {
  if (sMetros <= 0 || mu <= 0 || mu > 1) return 0;
  return sqrt(2 * _g * mu * sMetros);
}

/// Velocidade de impacto veículo – Searle (m/s): Vc = Vp / Ep
double vcSearle(double vpMs, double ep) {
  if (ep <= 0 || ep >= 1) return 0;
  return vpMs / ep;
}

// ─── Northwestern (forward projection) ─────────────────────────────────────
// Para projeção para frente: Vc = sqrt(2 * g * µ * s) = Vp.
// Referência: método Northwestern para forward projection; fórmula em helper
// para fácil ajuste se o projeto adotar outra referência.

/// Velocidade de impacto – Northwestern (forward projection), m/s.
/// Vc_Northwestern = sqrt(2 * g * µ * s). Válido para forward projection.
double vcNorthwesternForward(double sMetros, double mu) {
  if (sMetros <= 0 || mu <= 0 || mu > 1) return 0;
  return sqrt(2 * _g * mu * sMetros);
}

/// Resultado único (ponto) ou intervalo (min–max)
class ResultadoVelocidade {
  final double? vMs;
  final double? vKmh;
  final double? vMinMs;
  final double? vMinKmh;
  final double? vMaxMs;
  final double? vMaxKmh;
  final bool isIntervalo;

  const ResultadoVelocidade({
    this.vMs,
    this.vKmh,
    this.vMinMs,
    this.vMinKmh,
    this.vMaxMs,
    this.vMaxKmh,
    this.isIntervalo = false,
  });
}

/// Resultados lado a lado (Searle + Northwestern)
class ResultadosAtropelamento {
  final ResultadoVelocidade searleVp;
  final ResultadoVelocidade searleVc;
  final ResultadoVelocidade northwesternVc;

  const ResultadosAtropelamento({
    required this.searleVp,
    required this.searleVc,
    required this.northwesternVc,
  });
}

/// Calcula resultados para a tela unificada.
/// [s] distância total de projeção (m), [mu] coeficiente atrito (0 < µ <= 1).
/// [muMin]/[muMax] opcional: se ambos válidos, retorna intervalos.
/// [ep] eficiência de projeção (0 < Ep < 1) para Searle.
ResultadosAtropelamento? calcularAtropelamento({
  required double s,
  required double mu,
  double? muMin,
  double? muMax,
  required double ep,
}) {
  if (s <= 0 || mu <= 0 || mu > 1 || ep <= 0 || ep >= 1) return null;

  final useIntervalo = muMin != null && muMax != null && muMin > 0 && muMin <= 1 && muMax > 0 && muMax <= 1 && muMin <= muMax;

  if (useIntervalo) {
    final vpMin = vpProjecao(s, muMin);
    final vpMax = vpProjecao(s, muMax);
    final vcSearleMin = vcSearle(vpMin, ep);
    final vcSearleMax = vcSearle(vpMax, ep);
    final vcNwMin = vcNorthwesternForward(s, muMin);
    final vcNwMax = vcNorthwesternForward(s, muMax);
    return ResultadosAtropelamento(
      searleVp: ResultadoVelocidade(
        vMinMs: vpMin,
        vMinKmh: msParaKmh(vpMin),
        vMaxMs: vpMax,
        vMaxKmh: msParaKmh(vpMax),
        isIntervalo: true,
      ),
      searleVc: ResultadoVelocidade(
        vMinMs: vcSearleMin,
        vMinKmh: msParaKmh(vcSearleMin),
        vMaxMs: vcSearleMax,
        vMaxKmh: msParaKmh(vcSearleMax),
        isIntervalo: true,
      ),
      northwesternVc: ResultadoVelocidade(
        vMinMs: vcNwMin,
        vMinKmh: msParaKmh(vcNwMin),
        vMaxMs: vcNwMax,
        vMaxKmh: msParaKmh(vcNwMax),
        isIntervalo: true,
      ),
    );
  }

  final vp = vpProjecao(s, mu);
  final vcS = vcSearle(vp, ep);
  final vcNw = vcNorthwesternForward(s, mu);
  return ResultadosAtropelamento(
    searleVp: ResultadoVelocidade(vMs: vp, vKmh: msParaKmh(vp)),
    searleVc: ResultadoVelocidade(vMs: vcS, vKmh: msParaKmh(vcS)),
    northwesternVc: ResultadoVelocidade(vMs: vcNw, vKmh: msParaKmh(vcNw)),
  );
}

/// Apenas Northwestern (forward projection): nao usa Ep.
ResultadoVelocidade? calcularSoNorthwestern({
  required double s,
  required double mu,
  double? muMin,
  double? muMax,
}) {
  if (s <= 0 || mu <= 0 || mu > 1) return null;
  final useIntervalo = muMin != null && muMax != null && muMin > 0 && muMin <= 1 && muMax > 0 && muMax <= 1 && muMin <= muMax;
  if (useIntervalo) {
    return ResultadoVelocidade(
      vMinMs: vcNorthwesternForward(s, muMin),
      vMinKmh: msParaKmh(vcNorthwesternForward(s, muMin)),
      vMaxMs: vcNorthwesternForward(s, muMax),
      vMaxKmh: msParaKmh(vcNorthwesternForward(s, muMax)),
      isIntervalo: true,
    );
  }
  final vc = vcNorthwesternForward(s, mu);
  return ResultadoVelocidade(vMs: vc, vKmh: msParaKmh(vc));
}
