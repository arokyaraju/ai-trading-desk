/// lib/trading/rrg/rrg_calculator.dart
///
/// Computes JdK-style RS-Ratio and RS-Momentum series from aligned
/// daily closing prices of a symbol and a benchmark.
///
/// This is the widely-used open approximation of the JdK RRG formula:
///   RS          = (symbolClose / benchmarkClose) * 100
///   RS-Ratio    = 100 * RS / SMA(RS, rsRatioWindow)
///   RS-Momentum = 100 * RS-Ratio / SMA(RS-Ratio, momentumWindow)
///
/// Both series are naturally centered on 100, which is what makes the
/// four-quadrant (Leading / Weakening / Lagging / Improving) layout work.
///
/// NOTE: This is a standard open-source approximation, not the exact
/// proprietary StockCharts/Optuma formula — visually and behaviorally
/// equivalent for spotting rotation, but numeric values won't match
/// StockCharts to the decimal.

import 'rrg_models.dart';

class RRGCalculator {
  /// [dates], [symbolCloses], [benchmarkCloses] must be the same length,
  /// chronologically ordered (oldest first), and aligned by trading day
  /// (i.e. index i in all three arrays refers to the same date).
  static List<RRGPoint> compute({
    required List<DateTime> dates,
    required List<double> symbolCloses,
    required List<double> benchmarkCloses,
    int rsRatioWindow = 10,
    int momentumWindow = 10,
  }) {
    final n = symbolCloses.length;
    if (benchmarkCloses.length != n || dates.length != n) {
      throw ArgumentError(
        'dates (${dates.length}), symbolCloses ($n), '
        'benchmarkCloses (${benchmarkCloses.length}) must all be equal length',
      );
    }
    if (n < rsRatioWindow + momentumWindow) {
      // Not enough history to produce even one valid point.
      return const [];
    }

    // Step 1: raw relative strength
    final rs = List<double>.generate(
      n,
      (i) => (symbolCloses[i] / benchmarkCloses[i]) * 100,
    );

    // Step 2: RS-Ratio = 100 * rs / SMA(rs, rsRatioWindow)
    final rsRatio = List<double?>.filled(n, null);
    for (int i = rsRatioWindow - 1; i < n; i++) {
      final window = rs.sublist(i - rsRatioWindow + 1, i + 1);
      final avg = window.reduce((a, b) => a + b) / rsRatioWindow;
      rsRatio[i] = avg == 0 ? 100 : 100 * (rs[i] / avg);
    }

    // Step 3: RS-Momentum = 100 * rsRatio / SMA(rsRatio, momentumWindow)
    final rsMomentum = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      if (rsRatio[i] == null) continue;
      final start = i - momentumWindow + 1;
      if (start < 0) continue;

      final slice = <double>[];
      var valid = true;
      for (int j = start; j <= i; j++) {
        final v = rsRatio[j];
        if (v == null) {
          valid = false;
          break;
        }
        slice.add(v);
      }
      if (!valid) continue;

      final avg = slice.reduce((a, b) => a + b) / momentumWindow;
      rsMomentum[i] = avg == 0 ? 100 : 100 * (rsRatio[i]! / avg);
    }

    final result = <RRGPoint>[];
    for (int i = 0; i < n; i++) {
      final r = rsRatio[i];
      final m = rsMomentum[i];
      if (r != null && m != null) {
        result.add(RRGPoint(date: dates[i], rsRatio: r, rsMomentum: m));
      }
    }
    return result;
  }

  /// Convenience: builds a full [RRGSeries], keeping only the last
  /// [tailLength] points (the "tail" you see trailing behind each dot
  /// on the graph, e.g. last 10-15 trading days).
  static RRGSeries buildSeries({
    required String symbolKey,
    required String displayName,
    required List<DateTime> dates,
    required List<double> symbolCloses,
    required List<double> benchmarkCloses,
    int rsRatioWindow = 10,
    int momentumWindow = 10,
    int tailLength = 12,
  }) {
    final all = compute(
      dates: dates,
      symbolCloses: symbolCloses,
      benchmarkCloses: benchmarkCloses,
      rsRatioWindow: rsRatioWindow,
      momentumWindow: momentumWindow,
    );
    final tail = all.length <= tailLength
        ? all
        : all.sublist(all.length - tailLength);
    return RRGSeries(symbolKey: symbolKey, displayName: displayName, points: tail);
  }
}