import '../models/candle.dart';

enum SignalDirection { bullish, bearish }

class IndexSignalCandidate {
  final DateTime timestamp;
  final SignalDirection direction;
  final double triggerPrice; // entry trigger: candle high (bullish) or low (bearish)
  final double stopLossIndexPrice; // candle low (bullish) or high (bearish)
  final double riskPoints;

  IndexSignalCandidate({
    required this.timestamp,
    required this.direction,
    required this.triggerPrice,
    required this.stopLossIndexPrice,
  }) : riskPoints = (triggerPrice - stopLossIndexPrice).abs();
}

class SignalEngine {
  /// Resamples 1-min index candles into 5-min candles, computes a running
  /// session VWAP, and looks for: VWAP cross + a candle with a small wick
  /// on the breakout side, closing beyond the previous candle's high/low.
  List<IndexSignalCandidate> generateSignals(List<Candle> oneMinCandles) {
    if (oneMinCandles.length < 10) return [];

    final sorted = [...oneMinCandles]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final fiveMin = _resampleTo5Min(sorted);
    if (fiveMin.length < 3) return [];

    final vwapSeries = _computeVwap(fiveMin);
    final signals = <IndexSignalCandidate>[];

    for (int i = 1; i < fiveMin.length; i++) {
      final prev = fiveMin[i - 1];
      final curr = fiveMin[i];
      final prevVwap = vwapSeries[i - 1];
      final currVwap = vwapSeries[i];

      final range = curr.high - curr.low;
      if (range <= 0) continue;

      final upperWick = curr.high - (curr.close > curr.open ? curr.close : curr.open);
      final lowerWick = (curr.close < curr.open ? curr.close : curr.open) - curr.low;

      // Bullish: VWAP cross up, small wick on top, closes above previous high.
      final crossedAboveVwap = prev.close <= prevVwap && curr.close > currVwap;
      final smallTopWick = upperWick <= range * 0.25;
      final closedAbovePrevHigh = curr.close > prev.high;

      if (crossedAboveVwap && smallTopWick && closedAbovePrevHigh) {
        signals.add(IndexSignalCandidate(
          timestamp: curr.timestamp,
          direction: SignalDirection.bullish,
          triggerPrice: curr.high,
          stopLossIndexPrice: curr.low,
        ));
        continue;
      }

      // Bearish: VWAP cross down, small wick on bottom, closes below previous low.
      final crossedBelowVwap = prev.close >= prevVwap && curr.close < currVwap;
      final smallBottomWick = lowerWick <= range * 0.25;
      final closedBelowPrevLow = curr.close < prev.low;

      if (crossedBelowVwap && smallBottomWick && closedBelowPrevLow) {
        signals.add(IndexSignalCandidate(
          timestamp: curr.timestamp,
          direction: SignalDirection.bearish,
          triggerPrice: curr.low,
          stopLossIndexPrice: curr.high,
        ));
      }
    }

    return signals;
  }

  List<Candle> _resampleTo5Min(List<Candle> oneMin) {
    final Map<DateTime, List<Candle>> buckets = {};
    for (final c in oneMin) {
      final bucketMinute = (c.timestamp.minute ~/ 5) * 5;
      final bucketTime = DateTime(
        c.timestamp.year, c.timestamp.month, c.timestamp.day,
        c.timestamp.hour, bucketMinute,
      );
      buckets.putIfAbsent(bucketTime, () => []).add(c);
    }

    final keys = buckets.keys.toList()..sort();
    return keys.map((k) {
      final group = buckets[k]!..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return Candle(
        timestamp: k,
        open: group.first.open,
        high: group.map((c) => c.high).reduce((a, b) => a > b ? a : b),
        low: group.map((c) => c.low).reduce((a, b) => a < b ? a : b),
        close: group.last.close,
        volume: group.fold(0, (sum, c) => sum + c.volume),
      );
    }).toList();
  }

  /// Cumulative session VWAP using typical price. Assumes the candles
  /// passed in are all from a single trading day.
  List<double> _computeVwap(List<Candle> candles) {
    double cumPV = 0;
    double cumVol = 0;
    final result = <double>[];
    for (final c in candles) {
      final typicalPrice = (c.high + c.low + c.close) / 3;
      final vol = c.volume > 0 ? c.volume : 1;
      cumPV += typicalPrice * vol;
      cumVol += vol;
      result.add(cumVol > 0 ? cumPV / cumVol : typicalPrice);
    }
    return result;
  }
}