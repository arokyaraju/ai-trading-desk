import 'package:flutter/material.dart';

import '../../core/constants/sector_symbols.dart';
import '../../home/models/market_quote.dart';
import '../repository/market_repository.dart';

class SectorProvider extends ChangeNotifier {
  final MarketRepository repository = MarketRepository();

  List<MapEntry<SectorSymbol, MarketQuote>> sectors = [];
  bool isLoading = false;

  Future<void> loadSectors() async {
    isLoading = true;
    notifyListeners();

    try {
      final symbols = SectorSymbols.candidates.map((s) => s.symbol).toList();
      final response = await repository.api.getQuotes(symbols);

      final quotes = response
          .map<MarketQuote>((e) => MarketQuote.fromJson(e))
          .toList();

      final result = <MapEntry<SectorSymbol, MarketQuote>>[];

      for (final candidate in SectorSymbols.candidates) {
        final match = quotes.where(
          (q) => q.symbol == candidate.symbol && q.status == "ok",
        );

        if (match.isNotEmpty) {
          result.add(MapEntry(candidate, match.first));
        } else {
          debugPrint(
            "Sector symbol invalid or no data: ${candidate.symbol}",
          );
        }
      }

      result.sort(
        (a, b) => b.value.changePercent.compareTo(a.value.changePercent),
      );

      sectors = result;
    } catch (e) {
      debugPrint("Load Sectors Error: $e");
    }

    isLoading = false;
    notifyListeners();
  }
}