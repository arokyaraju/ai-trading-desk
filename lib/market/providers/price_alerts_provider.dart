import 'package:flutter/material.dart';

import '../../home/models/market_quote.dart';
import '../models/price_alert.dart';
import 'market_provider.dart';

/// Holds user-defined price alerts and checks them against live quotes
/// every time MarketProvider notifies (same proxy pattern as LiveTradingProvider).
class PriceAlertsProvider extends ChangeNotifier {
  final List<PriceAlert> alerts = [];
  final List<PriceAlert> _newlyTriggered = [];

  void addAlert(String symbol, double targetPrice, AlertDirection direction) {
    alerts.add(PriceAlert(symbol: symbol, targetPrice: targetPrice, direction: direction));
    notifyListeners();
  }

  void removeAlert(PriceAlert alert) {
    alerts.remove(alert);
    notifyListeners();
  }

  /// Returns and clears any alerts that triggered since the last check —
  /// call this from the UI to show a one-time SnackBar/banner.
  List<PriceAlert> consumeNewlyTriggered() {
    final result = List<PriceAlert>.from(_newlyTriggered);
    _newlyTriggered.clear();
    return result;
  }

  void onMarketUpdate(MarketProvider marketProvider) {
    _checkAlerts(marketProvider.quotes);
  }

  void _checkAlerts(List<MarketQuote> quotes) {
    var changed = false;

    for (final alert in alerts) {
      if (alert.triggered) continue;

      final match = quotes.where((q) => q.symbol == alert.symbol);
      if (match.isEmpty) continue;
      final ltp = match.first.ltp;

      final hit = alert.direction == AlertDirection.above
          ? ltp >= alert.targetPrice
          : ltp <= alert.targetPrice;

      if (hit) {
        alert.triggered = true;
        _newlyTriggered.add(alert);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }
}