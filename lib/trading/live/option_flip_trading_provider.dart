import 'dart:async';
import 'package:flutter/material.dart';

import '../../fyers/rest/fyers_rest_service.dart';
import '../data/fyers_historical_service.dart';
import '../data/instrument_master_service.dart';
import '../data/option_chain_service.dart';
import '../models/candle.dart';
import '../models/option_contract.dart';
import '../strategy/option_flip_signal_engine.dart';

const String kNiftyUnderlying = 'NSE:NIFTY50-INDEX';

class OptionFlipTradingProvider extends ChangeNotifier {
  static const double totalCapital = 10000;
  static const double minSizeRatio = 0.5;
  static const double maxSizeRatio = 0.6;
  static const Duration _pollInterval = Duration(minutes: 2);

  final OptionChainService _optionChainService = OptionChainService();
  final FyersHistoricalService _historicalService = FyersHistoricalService();
  final FyersRestService _restService = FyersRestService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();
  final OptionFlipSignalEngine _engine = OptionFlipSignalEngine();

  Timer? _pollTimer;
  bool _disposed = false;
  bool _isBusy = false;

  OptionContract? ceContract;
  OptionContract? peContract;

  final Map<String, List<Candle>> _closedCandles = {};
  final Map<String, Candle?> _building = {};
  final Map<String, DateTime?> _currentBucket = {};

  int? currentQuantity;
  double? currentEntryPremium;
  OptionType? currentHeldSide;
  String status = 'Not started';

  final List<String> log = [];

  Future<void> start() async {
    if (_pollTimer != null) return;
    status = 'Selecting ATM contracts (next week expiry)...';
    notifyListeners();

    await _refreshContracts();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
    await _pollTick();
  }

  Future<void> _refreshContracts() async {
    try {
      final chain = await _optionChainService.getNextWeekOptionChain(
        underlyingSymbol: kNiftyUnderlying,
        strikeCount: 20,
      );
      if (chain.isEmpty) {
        status = 'Could not fetch option chain — retrying next cycle.';
        notifyListeners();
        return;
      }

      final spot = await _fetchNiftySpot();
      if (spot == null) {
        status = 'Could not fetch Nifty spot for ATM selection.';
        notifyListeners();
        return;
      }

      final ceCandidates = chain.where((c) => c.type == OptionType.CE).toList()
        ..sort((a, b) => (a.strike - spot).abs().compareTo((b.strike - spot).abs()));
      final peCandidates = chain.where((c) => c.type == OptionType.PE).toList()
        ..sort((a, b) => (a.strike - spot).abs().compareTo((b.strike - spot).abs()));

      if (ceCandidates.isEmpty || peCandidates.isEmpty) {
        status = 'ATM contracts not found in chain.';
        notifyListeners();
        return;
      }

      final newCe = ceCandidates.first;
      final newPe = peCandidates.first;

      if (ceContract?.symbol != newCe.symbol) {
        ceContract = newCe;
        await _bootstrapHistory(newCe.symbol);
      }
      if (peContract?.symbol != newPe.symbol) {
        peContract = newPe;
        await _bootstrapHistory(newPe.symbol);
      }
    } catch (e) {
      status = 'Error selecting contracts: $e';
      _log('Contract selection error: $e');
      notifyListeners();
    }
  }

  Future<double?> _fetchNiftySpot() async {
    try {
      final quotes = await _restService.getQuotesBatched([kNiftyUnderlying]);
      if (quotes.isEmpty || quotes.first.ltp <= 0) return null;
      return quotes.first.ltp;
    } catch (e) {
      return null;
    }
  }

  Future<void> _bootstrapHistory(String symbol) async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 10));
      final candles = await _historicalService.getHistoricalCandles(
        symbol: symbol,
        resolution: '60',
        from: from,
        to: now,
      );
      final closed = candles.where((c) => c.timestamp.isBefore(
          DateTime(now.year, now.month, now.day, now.hour))).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _closedCandles[symbol] = closed;
      _log('Bootstrapped ${closed.length} closed 1H candles for $symbol');
    } catch (e) {
      _closedCandles[symbol] = [];
      _log('Bootstrap failed for $symbol: $e');
    }
  }

  Future<void> _pollTick() async {
    if (_isBusy || _disposed) return;
    _isBusy = true;

    try {
      await _refreshContracts();

      final ce = ceContract;
      final pe = peContract;
      if (ce == null || pe == null) return;

      final quotes = await _restService.getQuotesBatched([ce.symbol, pe.symbol]);
      final ceQuote = quotes.where((q) => q.symbol == ce.symbol).toList();
      final peQuote = quotes.where((q) => q.symbol == pe.symbol).toList();

      if (ceQuote.isNotEmpty && ceQuote.first.ltp > 0) {
        _ingestPricePoint(ce.symbol, ceQuote.first.ltp, DateTime.now());
      }
      if (peQuote.isNotEmpty && peQuote.first.ltp > 0) {
        _ingestPricePoint(pe.symbol, peQuote.first.ltp, DateTime.now());
      }
    } catch (e) {
      status = 'Poll error: $e';
      _log('Poll error: $e');
    } finally {
      _isBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _ingestPricePoint(String symbol, double ltp, DateTime time) {
    final bucket = DateTime(time.year, time.month, time.day, time.hour);
    final currentBucket = _currentBucket[symbol];

    if (currentBucket == null) {
      _currentBucket[symbol] = bucket;
      _building[symbol] = Candle(timestamp: bucket, open: ltp, high: ltp, low: ltp, close: ltp);
      return;
    }

    if (bucket != currentBucket) {
      final finished = _building[symbol];
      if (finished != null) {
        (_closedCandles[symbol] ??= []).add(finished);
        _onCandleClosed(symbol, finished);
      }
      _currentBucket[symbol] = bucket;
      _building[symbol] = Candle(timestamp: bucket, open: ltp, high: ltp, low: ltp, close: ltp);
    } else {
      final c = _building[symbol]!;
      _building[symbol] = Candle(
        timestamp: c.timestamp,
        open: c.open,
        high: ltp > c.high ? ltp : c.high,
        low: ltp < c.low ? ltp : c.low,
        close: ltp,
      );
    }
  }

  void _onCandleClosed(String symbol, Candle closed) {
    final side = symbol == ceContract?.symbol
        ? OptionType.CE
        : (symbol == peContract?.symbol ? OptionType.PE : null);
    if (side == null) return;

    final history = _closedCandles[symbol];
    if (history == null || history.length < 2) return;

    final previous = history[history.length - 2];
    final result = _engine.evaluate(side: side, previous: previous, latest: closed);

    if (result.action == FlipAction.enter) {
      _enterPosition(side);
    } else if (result.action == FlipAction.exit) {
      _exitPosition(side);
    }
  }

  Future<void> _enterPosition(OptionType side) async {
    final contract = side == OptionType.CE ? ceContract : peContract;
    if (contract == null) return;
    final premium = contract.ltp;
    if (premium == null || premium <= 0) {
      _log('Entry skipped for ${contract.symbol} — no usable premium.');
      return;
    }

    final lotSize = await _instrumentMasterService.getLotSize(contract.symbol) ?? 75;
    final maxBudget = totalCapital * maxSizeRatio;
    final minBudget = totalCapital * minSizeRatio;

    final lots = (maxBudget / (premium * lotSize)).floor();
    final quantity = lots * lotSize;
    final investment = quantity * premium;

    if (quantity <= 0 || investment < minBudget) {
      _log('Entry skipped for ${contract.symbol} — cannot fit 50-60% band at this premium/lot size (need review).');
      status = 'Signal fired but position sizing failed — see log.';
      return;
    }

    currentHeldSide = side;
    currentQuantity = quantity;
    currentEntryPremium = premium;
    status = 'HOLDING ${side.name}: ${contract.symbol} @ ₹${premium.toStringAsFixed(2)} x $quantity (₹${investment.toStringAsFixed(0)})';
    _log(status);

    // TODO: real order placement goes here once compliance/registration
    // (Fyers Strategy ID etc.) is confirmed — this only tracks state so
    // far, matching where the other strategy currently stands (paper).
  }

  void _exitPosition(OptionType side) {
    final contract = side == OptionType.CE ? ceContract : peContract;
    final exitPremium = contract?.ltp;
    status = 'EXITED ${side.name}${exitPremium != null ? ' @ ₹${exitPremium.toStringAsFixed(2)}' : ''} — watching for flip.';
    _log(status);

    currentHeldSide = null;
    currentQuantity = null;
    currentEntryPremium = null;

    // TODO: real exit order placement goes here once compliance is confirmed.
  }

  void _log(String message) {
    log.insert(0, '${DateTime.now().toIso8601String()}: $message');
    if (log.length > 200) log.removeLast();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}