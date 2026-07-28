enum AlertDirection { above, below }

class PriceAlert {
  final String symbol;
  final double targetPrice;
  final AlertDirection direction;
  bool triggered;

  PriceAlert({
    required this.symbol,
    required this.targetPrice,
    required this.direction,
    this.triggered = false,
  });
}