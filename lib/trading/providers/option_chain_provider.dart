import 'dart:async';
import 'package:flutter/material.dart';

import '../data/option_chain_service.dart';
import '../models/option_contract.dart';

const String kOptionChainUnderlying = 'NSE:NIFTY50-INDEX';

class OptionChainProvider extends ChangeNotifier {
  final OptionChainService _service = OptionChainService();

  List<OptionContract> contracts = [];
  bool isLoading = false;
  String? error;

  Timer? _refreshTimer;

  Future<void> start({Duration refreshInterval = const Duration(minutes: 1)}) async {
    await refresh();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      contracts = await _service.getOptionChain(
        underlyingSymbol: kOptionChainUnderlying,
        strikeCount: 10,
      );
    } catch (e) {
      error = 'Failed to load option chain: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  double get pcr {
    final totalCeOi = contracts
        .where((c) => c.type == OptionType.CE)
        .fold<int>(0, (sum, c) => sum + (c.openInterest ?? 0));
    final totalPeOi = contracts
        .where((c) => c.type == OptionType.PE)
        .fold<int>(0, (sum, c) => sum + (c.openInterest ?? 0));

    if (totalCeOi == 0) return 0;
    return totalPeOi / totalCeOi;
  }

  List<({double strike, OptionContract? ce, OptionContract? pe})> get rowsByStrike {
    final strikes = contracts.map((c) => c.strike).toSet().toList()..sort();

    return strikes.map((strike) {
      final matchesCe = contracts.where((c) => c.strike == strike && c.type == OptionType.CE);
      final matchesPe = contracts.where((c) => c.strike == strike && c.type == OptionType.PE);

      final ce = matchesCe.isNotEmpty ? matchesCe.first : null;
      final pe = matchesPe.isNotEmpty ? matchesPe.first : null;

      return (strike: strike, ce: ce, pe: pe);
    }).toList();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
