import '../../trading/models/candle.dart';
import 'screener_match.dart';

/// Pure pattern matcher — no I/O. Feed it a symbol's previous-day
/// H/L/C and today's CLOSED 1H candles (chronologically ordered),
/// and it returns every consecutive-candle-pair match for the three
/// screener patterns. Checks every pair in the session, not just the
/// latest, so more than one match per symbol per day is expected.
class PrevDayLevelScreenerEngine {
  List<ScreenerMatch> scan({
    required String symbol,
    required double prevHigh,
    required double prevLow,
    required double prevClose,
    required List<Candle> todaysClosedHourlyCandles,
  }) {
    if (todaysClosedHourlyCandles.length < 2) return [];

    final pivot = (prevHigh + prevLow + prevClose) / 3;
    final matches = <ScreenerMatch>[];

    for (int i = 0; i < todaysClosedHourlyCandles.length - 1; i++) {
      final first = todaysClosedHourlyCandles[i];
      final second = todaysClosedHourlyCandles[i + 1];

      // Pattern 1: false breakout above prev-day high
      if (first.close > prevHigh && second.close < prevHigh) {
        matches.add(ScreenerMatch(
          symbol: symbol,
          pattern: ScreenerPattern.falseBreakoutHigh,
          firstCandleTime: first.timestamp,
          secondCandleTime: second.timestamp,
          firstClose: first.close,
          secondClose: second.close,
          referenceLevels: {'Prev Day High': prevHigh},
        ));
      }

      // Pattern 2: false breakdown below prev-day low
      if (first.close < prevLow && second.close > prevLow) {
        matches.add(ScreenerMatch(
          symbol: symbol,
          pattern: ScreenerPattern.falseBreakdownLow,
          firstCandleTime: first.timestamp,
          secondCandleTime: second.timestamp,
          firstClose: first.close,
          secondClose: second.close,
          referenceLevels: {'Prev Day Low': prevLow},
        ));
      }

      // Pattern 3: rejection from above both prev-close and pivot
      if (first.close > prevClose &&
          first.close > pivot &&
          second.close < prevClose &&
          second.close < pivot) {
        matches.add(ScreenerMatch(
          symbol: symbol,
          pattern: ScreenerPattern.pivotRejection,
          firstCandleTime: first.timestamp,
          secondCandleTime: second.timestamp,
          firstClose: first.close,
          secondClose: second.close,
          referenceLevels: {'Prev Close': prevClose, 'Pivot': pivot},
        ));
      }
    }

    return matches;
  }
}