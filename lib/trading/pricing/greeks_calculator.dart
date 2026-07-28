import 'dart:math';
import '../models/option_contract.dart';

/// Simplified Black-Scholes pricer + Newton-Raphson IV solver.
/// Good enough to approximate delta/IV for backtest purposes —
/// NOT precise enough to trust for live pricing decisions.
class GreeksCalculator {
  const GreeksCalculator();

  static const double _riskFreeRate = 0.065; // approx India risk-free rate

  double _normCdf(double x) => 0.5 * (1 + _erf(x / sqrt(2)));

  double _erf(double x) {
    // Abramowitz-Stegun approximation
    const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
    const a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
    final sign = x < 0 ? -1.0 : 1.0;
    x = x.abs();
    final t = 1.0 / (1.0 + p * x);
    final y = 1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x);
    return sign * y;
  }

  double _bsPrice({
    required double spot,
    required double strike,
    required double t, // years to expiry
    required double vol,
    required bool isCall,
  }) {
    if (t <= 0 || vol <= 0) return max(0, isCall ? spot - strike : strike - spot);
    final d1 = (log(spot / strike) + (_riskFreeRate + 0.5 * vol * vol) * t) /
        (vol * sqrt(t));
    final d2 = d1 - vol * sqrt(t);
    if (isCall) {
      return spot * _normCdf(d1) -
          strike * exp(-_riskFreeRate * t) * _normCdf(d2);
    } else {
      return strike * exp(-_riskFreeRate * t) * _normCdf(-d2) -
          spot * _normCdf(-d1);
    }
  }

  double _delta({
    required double spot,
    required double strike,
    required double t,
    required double vol,
    required bool isCall,
  }) {
    if (t <= 0 || vol <= 0) return isCall ? (spot > strike ? 1 : 0) : (spot < strike ? -1 : 0);
    final d1 = (log(spot / strike) + (_riskFreeRate + 0.5 * vol * vol) * t) /
        (vol * sqrt(t));
    return isCall ? _normCdf(d1) : _normCdf(d1) - 1;
  }

  /// Back out implied vol from market price via Newton-Raphson, then
  /// return the contract enriched with iv + delta. Returns null if
  /// the solver fails to converge (bad/stale price).
  OptionContract? enrichWithGreeks({
    required OptionContract contract,
    required double ltp,
    required double spot,
    required DateTime now,
  }) {
    final t = contract.expiry.difference(now).inMinutes / (60 * 24 * 365);
    if (t <= 0 || ltp <= 0) return null;
    final isCall = contract.type == OptionType.CE;

    double vol = 0.2; // initial guess
    for (int i = 0; i < 50; i++) {
      final price = _bsPrice(
          spot: spot, strike: contract.strike, t: t, vol: vol, isCall: isCall);
      final diff = price - ltp;
      if (diff.abs() < 0.01) break;
      // vega approximation for Newton step
      final vega = spot *
          sqrt(t) *
          exp(-0.5 *
              pow(
                  (log(spot / contract.strike) +
                          (_riskFreeRate + 0.5 * vol * vol) * t) /
                      (vol * sqrt(t)),
                  2)) /
          sqrt(2 * pi);
      if (vega.abs() < 1e-6) break;
      vol -= diff / vega;
      if (vol <= 0.01) vol = 0.01;
      if (vol > 3) vol = 3;
    }

    final delta =
        _delta(spot: spot, strike: contract.strike, t: t, vol: vol, isCall: isCall);

    return contract.copyWith(ltp: ltp, iv: vol, delta: delta);
  }
}