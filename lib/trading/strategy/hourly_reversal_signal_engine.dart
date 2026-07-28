import '../models/candle.dart';
import 'signal_engine.dart' show IndexSignalCandidate, SignalDirection;

class HourlyReversalSignalEngine {
  final double rrMultiple;

  HourlyReversalSignalEngine({this.rrMultiple = 3});

  List<IndexSignalCandidate> generateSignals(List<Candle> oneMinCandles) {
    if (oneMinCandles.length < 20) return [];

    final sorted = [...oneMinCandles]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final latestDate = sorted.last.timestamp;
    final todays = sorted.where((c) =>
        c.timestamp.year == latestDate.year &&
        c.timestamp.month == latestDate.month &&
        c.timestamp.day == latestDate.day).toList();
    if (todays.length < 20) return [];

    final sessionStart = todays.first.timestamp;
    final firstHourEnd = sessionStart.add(const Duration(hours: 1));

    final firstHourCandles = todays.where((c) => c.timestamp.isBefore(firstHourEnd)).toList();
    final afterFirstHour = todays.where((c) => !c.timestamp.isBefore(firstHourEnd)).toList();

    if (firstHourCandles.isEmpty || afterFirstHour.isEmpty) return [];

    final hourOpen = firstHourCandles.first.open;
    final hourClose = firstHourCandles.last.close;
    final hourHigh = firstHourCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final hourLow = firstHourCandles.map((c) => c.low).reduce((a, b) => a < b ? a : b);

    SignalDirection? bias;
    double zoneLevel;
    if (hourClose > hourOpen) {
      bias = SignalDirection.bullish;
      zoneLevel = hourLow;
    } else if (hourClose < hourOpen) {
      bias = SignalDirection.bearish;
      zoneLevel = hourHigh;
    } else {
      return [];
    }

    final fiveMin = _resampleTo5Min(afterFirstHour);
    if (fiveMin.length < 2) return [];

    final signals = <IndexSignalCandidate>[];

    for (int i = 1; i < fiveMin.length; i++) {
      final rejection = fiveMin[i - 1];
      final confirm = fiveMin[i];

      if (bias == SignalDirection.bullish) {
        final touchedAndRejected =
            rejection.low <= zoneLevel && rejection.close > zoneLevel && rejection.close < rejection.open;
        final confirmsBullish = confirm.close > confirm.open && confirm.close > rejection.close;

        if (touchedAndRejected && confirmsBullish) {
          signals.add(IndexSignalCandidate(
            timestamp: confirm.timestamp,
            direction: SignalDirection.bullish,
            triggerPrice: confirm.high,
            stopLossIndexPrice: confirm.low,
          ));
        }
      } else {
        final touchedAndRejected =
            rejection.high >= zoneLevel && rejection.close < zoneLevel && rejection.close > rejection.open;
        final confirmsBearish = confirm.close < confirm.open && confirm.close < rejection.close;

        if (touchedAndRejected && confirmsBearish) {
          signals.add(IndexSignalCandidate(
            timestamp: confirm.timestamp,
            direction: SignalDirection.bearish,
            triggerPrice: confirm.low,
            stopLossIndexPrice: confirm.high,
          ));
        }
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
}