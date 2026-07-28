/// lib/trading/strategy/live_signal_provider.dart
///
/// Polls today's 1-minute candles for the configured underlying on a
/// timer, feeds them into HourlyReversalSignalEngine, and turns any new
/// signal into a SignalWithLevels (computing target from rrMultiple,
/// optionally resolving a strike via StrikeSelector). Dedupes by signal
/// timestamp so the same setup isn't shown twice across polls.
///
/// This does NOT place any orders or track open positions — it only
/// detects and displays signals, by design, so you can validate the
/// strategy manually before any automation is wired in.

import 'dart:async';
import 'package:flutter/material.dart';

import '../../fyers/rest/fyers_rest_service.dart';
import '../models/candle.dart';
import 'hourly_reversal_signal_engine.dart';
import 'signal_engine.dart' show SignalDirection;
import 'signal_levels.dart';

class LiveSignalProvider extends ChangeNotifier {
  final FyersRestService restService;
  final HourlyReversalSignalEngine engine;
  final StrikeSelector? strikeSelector;
  final String underlyingSymbol; // e.g. "NSE:NIFTY50-INDEX"

  final List<SignalWithLevels> signals = [];
  bool isPolling = false;
  String? error;

  Timer? _timer;
  final Set<DateTime> _seenTimestamps = {};

  LiveSignalProvider({
    required this.restService,
    required this.underlyingSymbol,
    HourlyReversalSignalEngine? engine,
    this.strikeSelector,
  }) : engine = engine ?? HourlyReversalSignalEngine();

  void start({Duration pollInterval = const Duration(seconds: 60)}) {
    _poll();
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> _poll() async {
    isPolling = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final sessionStart = DateTime(now.year, now.month, now.day);

      final raw = await restService.getHistoricalCandles(
        symbol: underlyingSymbol,
        from: sessionStart,
        to: now,
        resolution: '1',
      );

      final candles = raw
          .map((c) => Candle(
                timestamp: c['date'] as DateTime,
                open: c['open'] as double,
                high: c['high'] as double,
                low: c['low'] as double,
                close: c['close'] as double,
                volume: (c['volume'] as double).toInt(),
              ))
          .toList();

      final rawSignals = engine.generateSignals(candles);

      for (final s in rawSignals) {
        if (_seenTimestamps.contains(s.timestamp)) continue;
        _seenTimestamps.add(s.timestamp);

        final risk = (s.triggerPrice - s.stopLossIndexPrice).abs();
        final target = s.direction == SignalDirection.bullish
            ? s.triggerPrice + engine.rrMultiple * risk
            : s.triggerPrice - engine.rrMultiple * risk;

        String? strike;
        if (strikeSelector != null) {
          try {
            strike = await strikeSelector!.selectStrike(
              direction: s.direction,
              underlyingPrice: s.triggerPrice,
            );
          } catch (_) {
            strike = null; // strike resolution failing shouldn't hide the signal
          }
        }

        signals.insert(
          0,
          SignalWithLevels(
            timestamp: s.timestamp,
            direction: s.direction,
            entryPrice: s.triggerPrice,
            stopLoss: s.stopLossIndexPrice,
            target: target,
            strikeSymbol: strike,
          ),
        );
      }

      error = null;
    } catch (e) {
      error = 'Signal poll failed: $e';
    }

    isPolling = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}