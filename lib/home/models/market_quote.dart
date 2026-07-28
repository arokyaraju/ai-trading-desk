class MarketQuote {
  final String symbol;
  final String status;

  double ltp;
  double change;
  double changePercent;

  int volume;

  double high;
  double low;
  double open;
  double previousClose;

  double bid;
  double ask;

  MarketQuote({
    required this.symbol,
    required this.status,
    required this.ltp,
    required this.change,
    required this.changePercent,
    required this.volume,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.bid,
    required this.ask,
  });

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    final v = json["v"] as Map<String, dynamic>? ?? {};

    return MarketQuote(
      symbol: json["n"] ?? "",
      status: json["s"] ?? "error",

      ltp: ((v["lp"] ?? 0) as num).toDouble(),
      change: ((v["ch"] ?? 0) as num).toDouble(),
      changePercent: ((v["chp"] ?? 0) as num).toDouble(),
      volume: ((v["volume"] ?? 0) as num).toInt(),
      high: ((v["high_price"] ?? 0) as num).toDouble(),
      low: ((v["low_price"] ?? 0) as num).toDouble(),
      open: ((v["open_price"] ?? 0) as num).toDouble(),
      previousClose: ((v["prev_close_price"] ?? 0) as num).toDouble(),
      bid: ((v["bid"] ?? 0) as num).toDouble(),
      ask: ((v["ask"] ?? 0) as num).toDouble(),
    );
  }
}