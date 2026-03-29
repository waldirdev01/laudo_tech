import 'dart:math';

import '../models/atropelamento_calculo_model.dart';

/// Resultado do cálculo Searle 1983 (velocidades em m/s e km/h)
class Searle1983Resultado {
  final double vMinMs;
  final double vMaxMs;
  final double vMinKmh;
  final double vMaxKmh;
  final double? viMinKmh;
  final double? viMaxKmh;
  final double ep;

  const Searle1983Resultado({
    required this.vMinMs,
    required this.vMaxMs,
    required this.vMinKmh,
    required this.vMaxKmh,
    this.viMinKmh,
    this.viMaxKmh,
    required this.ep,
  });
}

/// Resultado do cálculo Searle 2016 (velocidade de impacto em km/h)
class Searle2016Resultado {
  final double viKmh;
  final double viMs;

  const Searle2016Resultado({required this.viKmh, required this.viMs});
}

const double _g = 9.81;

/// Eficiência de projeção E_p (Searle): [adulto/criança] x [frontal baixo/alto]
double epSearle(AtropelamentoTipoVitima vitima, AtropelamentoFrontalVeiculo frontal) {
  switch (vitima) {
    case AtropelamentoTipoVitima.adulto:
      return frontal == AtropelamentoFrontalVeiculo.baixo ? 0.640 : 0.744;
    case AtropelamentoTipoVitima.crianca:
      return frontal == AtropelamentoFrontalVeiculo.baixo ? 0.727 : 0.831;
  }
}

/// Searle 1983: velocidade mínima de projeção (m/s)
/// V_min = sqrt((2*µ*g*DT)/(1+µ²))
double vMinProjecao1983(double dtMetros, double mu) {
  final num_ = 2 * mu * _g * dtMetros;
  final den = 1 + (mu * mu);
  return sqrt(num_ / den);
}

/// Searle 1983: velocidade máxima de projeção (m/s)
/// V_max = sqrt(2*µ*g*DT)
double vMaxProjecao1983(double dtMetros, double mu) {
  return sqrt(2 * mu * _g * dtMetros);
}

/// Converte m/s para km/h
double msParaKmh(double ms) => ms * 3.6;

/// Velocidade de impacto do veículo: Vi = V_projeção / E_p
double viDeProjecao(double vProjecaoMs, double ep) => vProjecaoMs / ep;

/// Searle 2016 (com correções: massa, inclinação, transporte, altura)
/// V = ((M+m)/M) * sqrt( [ (2*µ*g*(cos α ± (1/µ)*sin α)) * ((DT-d) - µ*H) ] / (1+µ²) )
/// α em graus: + subida, - descida → uso + no termo (cos α + (1/µ)*sin α) para α>0, senão -
double viImpactoSearle2016({
  required double dtMetros,
  required double dMetros,
  required double mu,
  required double hMetros,
  required double alphaGraus,
  required double mVeiculoKg,
  required double mPedestreKg,
}) {
  final alphaRad = alphaGraus * pi / 180;
  final cosA = cos(alphaRad);
  final sinA = sin(alphaRad);
  // Correção inclinação: + para subida (α>0), - para descida (α<0)
  final termoIncl = cosA + (alphaGraus >= 0 ? 1 : -1) * (1 / mu) * sinA;
  final distEff = (dtMetros - dMetros) - (mu * hMetros);
  if (distEff <= 0) return 0;

  final num_ = (2 * mu * _g * termoIncl) * distEff;
  final den = 1 + (mu * mu);
  final vProj = sqrt(num_ / den);
  final correcaoMassa = (mVeiculoKg + mPedestreKg) / mVeiculoKg;
  return correcaoMassa * vProj;
}

/// Calcula resultados Searle 1983 a partir do modelo
Searle1983Resultado? calcularSearle1983(AtropelamentoCalculoModel m) {
  final dt = m.dt;
  final mu = m.mu;
  if (dt == null || dt <= 0 || mu == null || mu <= 0) return null;

  final ep = m.epCustom ??
      (m.tipoVitima != null && m.frontalVeiculo != null
          ? epSearle(m.tipoVitima!, m.frontalVeiculo!)
          : 0.66); // fallback asfalto adulto baixo

  final vMin = vMinProjecao1983(dt, mu);
  final vMax = vMaxProjecao1983(dt, mu);
  return Searle1983Resultado(
    vMinMs: vMin,
    vMaxMs: vMax,
    vMinKmh: msParaKmh(vMin),
    vMaxKmh: msParaKmh(vMax),
    viMinKmh: msParaKmh(viDeProjecao(vMin, ep)),
    viMaxKmh: msParaKmh(viDeProjecao(vMax, ep)),
    ep: ep,
  );
}

/// Calcula resultado Searle 2016 quando todos os parâmetros estão disponíveis
Searle2016Resultado? calcularSearle2016(AtropelamentoCalculoModel m) {
  final dt = m.dt;
  final d = m.d;
  final mu = m.mu;
  final h = m.h ?? 0;
  final alpha = m.alphaGraus ?? 0;
  final M = m.massaVeiculoKg;
  final mp = m.massaPedestreKg;

  if (dt == null || dt <= 0 || mu == null || mu <= 0) return null;
  final dSafe = d ?? 0;
  if ((dt - dSafe) - (mu * h) <= 0) return null;
  if (M == null || M <= 0 || mp == null || mp <= 0) return null;

  final viMs = viImpactoSearle2016(
    dtMetros: dt,
    dMetros: dSafe,
    mu: mu,
    hMetros: h,
    alphaGraus: alpha,
    mVeiculoKg: M,
    mPedestreKg: mp,
  );
  return Searle2016Resultado(viKmh: msParaKmh(viMs), viMs: viMs);
}
