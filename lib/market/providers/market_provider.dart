import 'package:flutter/material.dart';

import '../../core/config/session.dart';
import '../../core/constants/symbols.dart';
import '../../home/models/market_quote.dart';
import '../repository/live_market_repository.dart';
import '../repository/market_repository.dart';

class MarketProvider extends ChangeNotifier {
  final MarketRepository repository = MarketRepository();
  final LiveMarketRepository liveRepository = LiveMarketRepository();

  List<MarketQuote> quotes = [];

  bool isLoading = false;
  bool isSocketConnected = false;

  Future<void> loadQuotes() async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await repository.api.getQuotes(
        Symbols.marketWatch,
      );

      quotes = response
          .map<MarketQuote>(
            (e) => MarketQuote.fromJson(e),
          )
          .toList();
    } catch (e) {
      debugPrint("Load Quotes Error: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  void connect(String accessToken) {
    liveRepository.onMessage = (data) {
      _handleTick(data);
    };

    liveRepository.onConnected = () {
      isSocketConnected = true;
      notifyListeners();
    };

    liveRepository.onDisconnected = () {
      isSocketConnected = false;
      notifyListeners();
    };

    liveRepository.onError = (error) {
      isSocketConnected = false;
      notifyListeners();
    };

    liveRepository.connect(
      appId: Session.appId,
      accessToken: accessToken,
      symbols: Symbols.marketWatch,
    );
  }

  void _handleTick(Map<String, dynamic> data) {
    final symbol = data['symbol'];
    if (symbol == null) return;

    final index = quotes.indexWhere((q) => q.symbol == symbol);
    if (index == -1) return;

    final quote = quotes[index];

    if (data['ltp'] != null) {
      quote.ltp = (data['ltp'] as num).toDouble();
    }
    if (data['ch'] != null) {
      quote.change = (data['ch'] as num).toDouble();
    }
    if (data['chp'] != null) {
      quote.changePercent = (data['chp'] as num).toDouble();
    }
    if (data['vol_traded_today'] != null) {
      quote.volume = (data['vol_traded_today'] as num).toInt();
    }
    if (data['high_price'] != null) {
      quote.high = (data['high_price'] as num).toDouble();
    }
    if (data['low_price'] != null) {
      quote.low = (data['low_price'] as num).toDouble();
    }
    if (data['open_price'] != null) {
      quote.open = (data['open_price'] as num).toDouble();
    }
    if (data['bid_price'] != null) {
      quote.bid = (data['bid_price'] as num).toDouble();
    }
    if (data['ask_price'] != null) {
      quote.ask = (data['ask_price'] as num).toDouble();
    }

    notifyListeners();
  }

  void disconnect() {
    liveRepository.disconnect();
    isSocketConnected = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadQuotes();
  }
}