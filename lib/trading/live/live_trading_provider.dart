import 'package:flutter/material.dart';

import '../../market/providers/market_provider.dart';
import '../data/instrument_master_service.dart';
import '../data/option_chain_service.dart';
import '../models/candle.dart';
import '../models/option_contract.dart';
import '../models/signal.dart';
import '../models/trade.dart';
import '../pricing/greeks_calculator.dart';
import '../strategy/signal_engine.dart';
import '../strategy/strike_selector.dart';

const String kLiveNiftyUnderlying = 'NSE:NIFTY50-INDEX';

/// Tracks live simulated (paper) trades using the same VWAP + candle
/// pattern rule as the backtester, fed by live index ticks instead of
/// historical candles. SL/target on the OPEN trade are approximated via
/// the contract's delta at entry — see the caveat in the chat message.
class LiveTradingProvider extends ChangeNotifier {
  final OptionChainService _optionChainService = OptionChainService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();
  final GreeksCalculator _greeksCalculator = const GreeksCalculator();
  final SignalEngine _signalEngine = SignalEngine();

  final List<Candle> _indexCandles = [];
  DateTime? _currentMinuteBucket;
  Candle? _buildingCandle;
  DateTime? _lastSignalCheckedThrough;
  bool _isSelectingContract = false;

  Trade? openTrade;
  final List<Trade> closedTrades = [];
  String status = 'Waiting for market data...';

  double _entrySpotAtOpen = 0;
  double _deltaAtOpen = 0;
  double _slPremium = 0;
  double _targetPremium = 0;

  /// Call this every time MarketProvider notifies — reads the current
  /// NIFTY50-INDEX ltp and feeds the internal 1-min candle builder.
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

    if (openTrade != null) {
      _checkOpenTradeAgainstSpot(ltp);
    }

    notifyListeners();
  }

  void _onCandleClosed() {
    if (_indexCandles.length < 10) return;

    final candidates = _signalEngine.generateSignals(_indexCandles);
    if (candidates.isEmpty) return;

    final latest = candidates.last;
    if (_lastSignalCheckedThrough != null && !latest.timestamp.isAfter(_lastSignalCheckedThrough!)) {
      return;
    }
    _lastSignalCheckedThrough = latest.timestamp;

    if (openTrade != null) {
      status = 'Signal seen but already in a position — skipped.';
      notifyListeners();
      return;
    }

    _openTradeFromSignal(latest);
  }

  Future<void> _openTradeFromSignal(IndexSignalCandidate candidate) async {
    if (_isSelectingContract) return;
    _isSelectingContract = true;
    status = 'Signal detected — selecting ATM contract...';
    notifyListeners();

    try {
      final chain = await _optionChainService.getOptionChain(
        underlyingSymbol: kLiveNiftyUnderlying,
        strikeCount: 5,
      );

      final optionType =
          candidate.direction == SignalDirection.bullish ? OptionType.CE : OptionType.PE;

      final rawContract = StrikeSelector.selectAtm(
        chain: chain,
        spot: candidate.triggerPrice,
        type: optionType,
      );

      if (rawContract == null) {
        status = 'No matching ATM contract found — signal skipped.';
        notifyListeners();
        return;
      }

      final ltpGuess = rawContract.bid != null && rawContract.ask != null
          ? (rawContract.bid! + rawContract.ask!) / 2
          : rawContract.ltp;
      if (ltpGuess == null || ltpGuess <= 0) {
        status = 'Contract had no usable price — signal skipped.';
        notifyListeners();
        return;
      }

      final enriched = _greeksCalculator.enrichWithGreeks(
        contract: rawContract,
        ltp: ltpGuess,
        spot: candidate.triggerPrice,
        now: DateTime.now(),
      );

      if (enriched == null || enriched.delta == null) {
        status = 'Could not compute option delta — signal skipped.';
        notifyListeners();
        return;
      }

      final lotSize = await _instrumentMasterService.getLotSize(enriched.symbol) ?? 75;

      final signal = Signal(
        contract: enriched,
        side: TradeSide.long,
        entryPrice: ltpGuess,
        stopLoss: ltpGuess - (candidate.riskPoints * enriched.delta!.abs()),
        target: ltpGuess + (candidate.riskPoints * enriched.delta!.abs() * 3),
        timestamp: DateTime.now(),
      );

      openTrade = Trade(signal: signal, quantity: lotSize);
      _entrySpotAtOpen = candidate.triggerPrice;
      _deltaAtOpen = enriched.delta!;
      _slPremium = signal.stopLoss;
      _targetPremium = signal.target;

      status = 'IN POSITION: ${enriched.symbol} @ ₹${ltpGuess.toStringAsFixed(2)}';
    } catch (e) {
      status = 'Error opening trade: $e';
    } finally {
      _isSelectingContract = false;
      notifyListeners();
    }
  }

  void _checkOpenTradeAgainstSpot(double currentSpot) {
    final trade = openTrade;
    if (trade == null) return;

    final projectedPremium =
        trade.signal.entryPrice + (currentSpot - _entrySpotAtOpen) * _deltaAtOpen;

    if (projectedPremium <= _slPremium) {
      _closeTrade(projectedPremium, TradeStatus.closedStopLoss);
    } else if (projectedPremium >= _targetPremium) {
      _closeTrade(projectedPremium, TradeStatus.closedTarget);
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
    status = 'Trade closed (${newStatus.name}). Watching for next signal.';
    notifyListeners();
  }
}