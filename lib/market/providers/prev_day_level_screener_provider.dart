import 'dart:async';
import 'package:flutter/material.dart';

import '../../trading/data/fyers_historical_service.dart';
import '../../trading/data/instrument_master_service.dart';
import '../screener/prev_day_level_screener_engine.dart';
import '../screener/screener_match.dart';

class PrevDayLevelScreenerProvider extends ChangeNotifier {
  final FyersHistoricalService _historicalService = FyersHistoricalService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();
  final PrevDayLevelScreenerEngine _engine = PrevDayLevelScreenerEngine();

  List<ScreenerMatch> matches = [];
  bool isLoading = false;
  String? error;

  Timer? _refreshTimer;
  bool _disposed = false;

  Future<void> start({Duration refreshInterval = const Duration(minutes: 5)}) async {
    await refresh();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_disposed || isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final underlyings = await _instrumentMasterService.getFnoStockUnderlyings();
      final symbols = underlyings.map(_instrumentMasterService.equitySymbolFor).toList();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final dailyFrom = now.subtract(const Duration(days: 10));

      final allMatches = <ScreenerMatch>[];

      // Smaller batch + longer pause between batches to avoid Cloudflare 429s.
      const batchSize = 4;
      const delayBetweenBatches = Duration(milliseconds: 800);

      for (var i = 0; i < symbols.length; i += batchSize) {
        final batch = symbols.skip(i).take(batchSize);
        await Future.wait(batch.map((symbol) async {
          try {
            final dailyCandles = await _getHistoricalWithRetry<List<Candle>>(
              symbol: symbol,
              resolution: 'D',
              from: dailyFrom,
              to: now,
            );
            final priorDays = dailyCandles
                .where((c) => c.timestamp.isBefore(todayStart))
                .toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
            if (priorDays.isEmpty) return;
            final prevDay = priorDays.last;

            final hourlyCandles = await _getHistoricalWithRetry<List<Candle>>(
              symbol: symbol,
              resolution: '60',
              from: todayStart,
              to: now,
            );
            final currentHourBucket =
                DateTime(now.year, now.month, now.day, now.hour);
            final todaysClosed = hourlyCandles
                .where((c) =>
                    !c.timestamp.isBefore(todayStart) &&
                    c.timestamp.isBefore(currentHourBucket))
                .toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

            if (todaysClosed.length < 2) return;

            final symbolMatches = _engine.scan(
              symbol: symbol,
              prevHigh: prevDay.high,
              prevLow: prevDay.low,
              prevClose: prevDay.close,
              todaysClosedHourlyCandles: todaysClosed,
            );

            allMatches.addAll(symbolMatches);
          } catch (e) {
            debugPrint('Screener: failed for $symbol: $e');
          }
        }));

        if (i + batchSize < symbols.length) {
          await Future.delayed(delayBetweenBatches);
        }
      }

      allMatches.sort((a, b) => b.secondCandleTime.compareTo(a.secondCandleTime));
      matches = allMatches;
    } catch (e) {
      error = 'Failed to run screener: $e';
    }

    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  /// Wraps getHistoricalCandles with exponential backoff on 429 / rate-limit errors.
  ///
  /// Callers must supply the type argument explicitly (e.g.
  /// `_getHistoricalWithRetry<List<Candle>>(...)`), since T does not
  /// appear in any parameter and can't be inferred from the call site.
  Future<T> _getHistoricalWithRetry<T>({
    required String symbol,
    required String resolution,
    required DateTime from,
    required DateTime to,
    int maxAttempts = 5,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await _historicalService.getHistoricalCandles(
          symbol: symbol,
          resolution: resolution,
          from: from,
          to: to,
        ) as T;
      } catch (e) {
        final isRateLimited = e.toString().contains('429') ||
            e.toString().contains('1015');

        if (isRateLimited && attempt < maxAttempts) {
          attempt++;
          final waitTime = Duration(milliseconds: 500 * (1 << attempt)); // 1s,2s,4s,8s,16s
          debugPrint(
            'Screener: 429 for $symbol ($resolution), retry $attempt/$maxAttempts in ${waitTime.inMilliseconds}ms',
          );
          await Future.delayed(waitTime);
          continue;
        }
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}