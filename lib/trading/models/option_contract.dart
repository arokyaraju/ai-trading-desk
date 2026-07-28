enum OptionType { CE, PE }

class OptionContract {
  final String symbol;
  final double strike;
  final DateTime expiry;
  final OptionType type;
  final double? bid;
  final double? ask;
  final double? ltp;
  final double? iv;
  final double? delta;
  final int? openInterest;

  const OptionContract({
    required this.symbol,
    required this.strike,
    required this.expiry,
    required this.type,
    this.bid,
    this.ask,
    this.ltp,
    this.iv,
    this.delta,
    this.openInterest,
  });

  OptionContract copyWith({
    double? ltp,
    double? iv,
    double? delta,
  }) {
    return OptionContract(
      symbol: symbol,
      strike: strike,
      expiry: expiry,
      type: type,
      bid: bid,
      ask: ask,
      ltp: ltp ?? this.ltp,
      iv: iv ?? this.iv,
      delta: delta ?? this.delta,
      openInterest: openInterest,
    );
  }
}