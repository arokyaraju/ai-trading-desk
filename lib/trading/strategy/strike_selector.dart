import '../models/option_contract.dart';

class StrikeSelector {
  static OptionContract? selectAtm({
    required List<OptionContract> chain,
    required double spot,
    required OptionType type,
  }) {
    final candidates = chain.where((c) => c.type == type).toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => (a.strike - spot).abs().compareTo((b.strike - spot).abs()));
    return candidates.first;
  }

  static OptionContract? selectUnderPremium({
    required List<OptionContract> chain,
    required OptionType type,
    double maxPremium = 70,
  }) {
    double? premiumOf(OptionContract c) {
      if (c.ltp != null && c.ltp! > 0) return c.ltp;
      if (c.bid != null && c.ask != null) return (c.bid! + c.ask!) / 2;
      return null;
    }

    final candidates = chain
        .where((c) => c.type == type)
        .map((c) => MapEntry(c, premiumOf(c)))
        .where((e) => e.value != null && e.value! > 0 && e.value! < maxPremium)
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.value!.compareTo(a.value!));
    return candidates.first.key;
  }
}