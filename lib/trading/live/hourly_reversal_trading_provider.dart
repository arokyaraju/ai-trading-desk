import 'dart:async';
import 'package:flutter/material.dart';

import '../../market/providers/market_provider.dart';
import '../data/instrument_master_service.dart';
import '../data/option_chain_service.dart';
import '../../fyers/rest/fyers_rest_service.dart';
import '../models/candle.dart';
import '../models/option_contract.dart';
import '../models/signal.dart';
import '../models/trade.dart';
import '../strategy/hourly_reversal_signal_engine.dart';
import '../strategy/signal_engine.dart' show IndexSignalCandidate, SignalDirection;
import '../strategy/strike_selector.dart';

const String kLiveNiftyUnderlying = 'NSE:NIFTY50-INDEX';

class HourlyReversalTradingProvider extends ChangeNotifier {
  final OptionChainService _optionChainService = OptionChainService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();
  final FyersRestService _restService = FyersRestService();
  final HourlyReversalSignalEngine _signalEngine = HourlyReversalSignalEngine();

  final List<Candle> _indexCandles = [];
  DateTime? _currentMinuteBucket;
  Candle? _buildingCandle;
  DateTime? _lastSignalCheckedThrough;
  bool _isSelectingContract = false;
  bool _disposed = false;

  Timer? _premiumPollTimer;

  Trade? openTrade;
  final List<Trade> closedTrades = [];
  String status = 'Waiting for market data...';

  double _slPremium = 0;
  double _targetPremium = 0;

  void onMarketUpdate(MarketProvider marketProvider) {
    final matches = marketProvider.quotes.where((q) => q.symbol == kLiveNiftyUnderlying);
    if (matches.isEmpty) return;
    final ltp = matches.first.ltp;
    if (ltp <= 0) return;

    _ingestTick(ltp, DateTime.now());
  }

  void _ingestTick(double ltp, DateTime time) {
    final bucketMinute = DateTime(time.year, time.month, time.day, time.hour, time.minute);

    if (_currentMinuteBucket == null) {
      _currentMinuteBucket = bucketMinute;
      _buildingCandle = Candle(timestamp: bucketMinute, open: ltp, high: ltp, low: ltp, close: ltp);
    } else if (bucketMinute != _currentMinuteBucket) {
      if (_buildingCandle != null) {
        _indexCandles.add(_buildingCandle!);
        _onCandleClosed();
      }
      _currentMinuteBucket = bucketMinute;
      _buildingCandle = Candle(timestamp: bucketMinute, open: ltp, high: ltp, low: ltp, close: ltp);
    } else {
      final c = _buildingCandle!;
      _buildingCandle = Candle(
        timestamp: c.timestamp,
        open: c.open,
        high: ltp > c.high ? ltp : c.high,
        low: ltp < c.low ? ltp : c.low,
        close: ltp,
      );
    }

    if (!_disposed) notifyListeners();
  }

  void _onCandleClosed() {
    if (_indexCandles.length < 20) return;

    final candidates = _signalEngine.generateSignals(_indexCandles);
    if (candidates.isEmpty) return;

    final latest = candidates.last;
    if (_lastSignalCheckedThrough != null && !latest.timestamp.isAfter(_lastSignalCheckedThrough!)) {
      return;
    }
    _lastSignalCheckedThrough = latest.timestamp;

    if (openTrade != null) {
      status = 'Signal seen but already in a position — skipped (one trade at a time).';
      if (!_disposed) notifyListeners();
      return;
    }

    _openTradeFromSignal(latest);
  }

  Future<void> _openTradeFromSignal(IndexSignalCandidate candidate) async {
    if (_isSelectingContract) return;
    _isSelectingContract = true;
    status = 'Signal detected — selecting weekly strike under ₹70...';
    if (!_disposed) notifyListeners();

    try {
      final chain = await _optionChainService.getOptionChain(
        underlyingSymbol: kLiveNiftyUnderlying,
        strikeCount: 20,
      );

      final optionType =
          candidate.direction == SignalDirection.bullish ? OptionType.CE : OptionType.PE;

      final contract = StrikeSelector.selectUnderPremium(
        chain: chain,
        type: optionType,
        maxPremium: 70,
      );

      if (contract == null) {
        status = 'No contract under ₹70 found — signal skipped.';
        if (!_disposed) notifyListeners();
        return;
      }

      final entryPremium = contract.ltp ?? (contract.bid != null && contract.ask != null
          ? (contract.bid! + contract.ask!) / 2
          : null);
      if (entryPremium == null || entryPremium <= 0) {
        status = 'Contract had no usable price — signal skipped.';
        if (!_disposed) notifyListeners();
        return;
      }

      final riskRatio = entryPremium / candidate.triggerPrice;
      final riskPremium = candidate.riskPoints * riskRatio;

      final signal = Signal(
        contract: contract,
        side: TradeSide.long,
        entryPrice: entryPremium,
        stopLoss: entryPremium - riskPremium,
        target: entryPremium + riskPremium * _signalEngine.rrMultiple,
        timestamp: DateTime.now(),
      );

      final lotSize = await _instrumentMasterService.getLotSize(contract.symbol) ?? 75;

      openTrade = Trade(signal: signal, quantity: lotSize);
      _slPremium = signal.stopLoss;
      _targetPremium = signal.target;

      status = 'IN POSITION: ${contract.symbol} @ ₹${entryPremium.toStringAsFixed(2)}';
      _startPremiumPolling(contract.symbol);
    } catch (e) {
      status = 'Error opening trade: $e';
    } finally {
      _isSelectingContract = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _startPremiumPolling(String symbol) {
    _premiumPollTimer?.cancel();
    _premiumPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollPremium(symbol));
  }

  Future<void> _pollPremium(String symbol) async {
    if (openTrade == null) {
      _premiumPollTimer?.cancel();
      return;
    }
    try {
      final quotes = await _restService.getQuotesBatched([symbol]);
      if (quotes.isEmpty) return;
      final ltp = quotes.first.ltp;
      if (ltp <= 0) return;

      if (ltp <= _slPremium) {
        _closeTrade(ltp, TradeStatus.closedStopLoss);
      } else if (ltp >= _targetPremium) {
        _closeTrade(ltp, TradeStatus.closedTarget);
      }
    } catch (e) {
      debugPrint('Premium poll failed for $symbol: $e');
    }
  }

  void _closeTrade(double exitPrice, TradeStatus newStatus) {
    final trade = openTrade;
    if (trade == null) return;
    trade.exitPrice = exitPrice;
    trade.exitTime = DateTime.now();
    trade.status = newStatus;
    closedTrades.insert(0, trade);
    openTrade = null;
    _premiumPollTimer?.cancel();
    status = 'Trade closed (${newStatus.name}). Watching for next signal.';
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _premiumPollTimer?.cancel();
    super.dispose();
  }
}