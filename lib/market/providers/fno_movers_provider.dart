import 'dart:async';
import 'package:flutter/material.dart';

import '../../fyers/rest/fyers_rest_service.dart';
import '../../trading/data/instrument_master_service.dart';
import '../../home/models/market_quote.dart';

class FnoMoversProvider extends ChangeNotifier {
  final FyersRestService _restService = FyersRestService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();

  List<MarketQuote> quotes = [];
  bool isLoading = false;
  String? error;

  Timer? _refreshTimer;
  bool _disposed = false;

  Future<void> start({Duration refreshInterval = const Duration(minutes: 2)}) async {
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
      final result = await _restService.getQuotesBatched(symbols);
      if (_disposed) return;
      quotes = result;
    } catch (e) {
      if (_disposed) return;
      error = 'Failed to load F&O quotes: $e';
    }

    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}