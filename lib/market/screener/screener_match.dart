enum ScreenerPattern { falseBreakoutHigh, falseBreakdownLow, pivotRejection }

extension ScreenerPatternLabel on ScreenerPattern {
  String get label {
    switch (this) {
      case ScreenerPattern.falseBreakoutHigh:
        return 'False Breakout (Prev-Day High)';
      case ScreenerPattern.falseBreakdownLow:
        return 'False Breakdown (Prev-Day Low)';
      case ScreenerPattern.pivotRejection:
        return 'Rejection (Prev-Close + Pivot)';
    }
  }
}

class ScreenerMatch {
  final String symbol;
  final ScreenerPattern pattern;
  final DateTime firstCandleTime;
  final DateTime secondCandleTime;
  final double firstClose;
  final double secondClose;
  final Map<String, double> referenceLevels; // e.g. {'Prev Day High': 24500}

  ScreenerMatch({
    required this.symbol,
    required this.pattern,
    required this.firstCandleTime,
    required this.secondCandleTime,
    required this.firstClose,
    required this.secondClose,
    required this.referenceLevels,
  });
}