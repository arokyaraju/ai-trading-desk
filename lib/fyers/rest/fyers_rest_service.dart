import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../core/config/session.dart';
import '../../home/models/market_quote.dart';

class FyersRestService {
  static const String _baseUrl = "https://api-t1.fyers.in/data/quotes";
  static const String _historyUrl = "https://api-t1.fyers.in/data/history";

  Future<List<dynamic>> getQuotes(List<String> symbols) async {
    final response = await http.get(
      Uri.parse(
        "$_baseUrl?symbols=${symbols.join(",")}",
      ),
      headers: {
        "Authorization": "${Session.appId}:${Session.accessToken}",
        "Content-Type": "application/json",
      },
    );

    print("Status : ${response.statusCode}");
    print(response.body);

    if (response.statusCode != 200) {
      return [];
    }

    final json = jsonDecode(response.body);

    return json["d"] ?? [];
  }

  /// Fetches quotes for many symbols by chunking into Fyers' per-call
  /// limit and pacing requests to avoid the 429 rate limit.
  Future<List<MarketQuote>> getQuotesBatched(
    List<String> symbols, {
    int batchSize = 50,
  }) async {
    final result = <MarketQuote>[];

    for (var i = 0; i < symbols.length; i += batchSize) {
      final end = (i + batchSize > symbols.length) ? symbols.length : i + batchSize;
      final batch = symbols.sublist(i, end);

      final raw = await getQuotes(batch);
      for (final item in raw) {
        result.add(MarketQuote.fromJson(item as Map<String, dynamic>));
      }

      if (end < symbols.length) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return result;
  }

  /// Fetches daily OHLCV candles for a single [symbol] between [from] and
  /// [to] (inclusive), using Fyers' /data/history endpoint.
  ///
  /// Returns a list of maps: {date, open, high, low, close, volume},
  /// oldest first. Empty list on error or no data.
  ///
  /// Fyers daily-resolution history calls are capped at ~366 days per
  /// request — fine for RRG (we only need ~60-90 trading days), but if
  /// you ever need longer daily history you'll need to chunk by year.
  ///
  /// Automatically retries with exponential backoff on HTTP 429 /
  /// Cloudflare error code 1015 (rate limited), up to [maxAttempts] times.
  Future<List<Map<String, dynamic>>> getHistoricalCandles({
    required String symbol,
    required DateTime from,
    required DateTime to,
    String resolution = 'D',
    int maxAttempts = 5,
  }) async {
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(
      "$_historyUrl"
      "?symbol=$symbol"
      "&resolution=$resolution"
      "&date_format=1"
      "&range_from=${fmt(from)}"
      "&range_to=${fmt(to)}"
      "&cont_flag=1",
    );

    var attempt = 0;
    while (true) {
      final response = await http.get(
        uri,
        headers: {
          "Authorization": "${Session.appId}:${Session.accessToken}",
          "Content-Type": "application/json",
        },
      );

      print("Historical [$symbol] Status : ${response.statusCode}");

      if (response.statusCode == 429 || response.body.contains('"code":1015')) {
        if (attempt < maxAttempts) {
          attempt++;
          final waitTime = Duration(milliseconds: 500 * (1 << attempt)); // 1s,2s,4s,8s,16s
          print("Historical [$symbol]: rate limited, retry $attempt/$maxAttempts in ${waitTime.inMilliseconds}ms");
          await Future.delayed(waitTime);
          continue;
        } else {
          print("Historical [$symbol]: giving up after $maxAttempts retries");
          return [];
        }
      }

      if (response.statusCode != 200) {
        print(response.body);
        return [];
      }

      final json = jsonDecode(response.body);
      if (json["s"] != "ok" || json["candles"] == null) {
        print("History error [$symbol]: ${json["message"] ?? json["s"]}");
        return [];
      }

      // Each raw candle: [epochSeconds, open, high, low, close, volume]
      final candles = (json["candles"] as List).map<Map<String, dynamic>>((c) {
        final ts = (c[0] as num).toInt();
        final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toLocal();
        // Daily candles are truncated to date-only so cross-symbol date
        // alignment (e.g. for RRG) works reliably. Intraday candles (1,
        // 5, 15... minute resolutions) keep their full timestamp, since
        // signal engines need the exact time-of-day.
        final effectiveDate = resolution.toUpperCase() == 'D'
            ? DateTime(date.year, date.month, date.day)
            : date;
        return {
          "date": effectiveDate,
          "open": (c[1] as num).toDouble(),
          "high": (c[2] as num).toDouble(),
          "low": (c[3] as num).toDouble(),
          "close": (c[4] as num).toDouble(),
          "volume": (c[5] as num).toDouble(),
        };
      }).toList();

      return candles;
    }
  }

  /// Fetches historical candles for many symbols, chunked and paced to
  /// avoid tripping Fyers'/Cloudflare's rate limit (the flood of 429s you
  /// get calling getHistoricalCandles per-symbol in a tight loop or
  /// Future.wait). Returns a map of symbol -> candles; symbols that fail
  /// even after retries map to an empty list.
  Future<Map<String, List<Map<String, dynamic>>>> getHistoricalCandlesBatched({
    required List<String> symbols,
    required DateTime from,
    required DateTime to,
    String resolution = 'D',
    int batchSize = 4,
    Duration delayBetweenBatches = const Duration(milliseconds: 800),
  }) async {
    final result = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i < symbols.length; i += batchSize) {
      final end = (i + batchSize > symbols.length) ? symbols.length : i + batchSize;
      final batch = symbols.sublist(i, end);

      await Future.wait(batch.map((symbol) async {
        result[symbol] = await getHistoricalCandles(
          symbol: symbol,
          from: from,
          to: to,
          resolution: resolution,
        );
      }));

      if (end < symbols.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    return result;
  }

  /// Places a single order via Fyers API v3.
  ///
  /// side: 1 = Buy, -1 = Sell
  /// type: 2 = Market, 1 = Limit, 3 = Stop (SL-M), 4 = Stop Limit (SL-L)
  /// productType: e.g. "INTRADAY", "MARGIN"
  ///
  /// NOTE: As of SEBI's algo-trading framework (mandatory for all brokers
  /// from 1 Apr 2026), retail-built strategies placing automated orders
  /// generally need to route through the broker's registered algo
  /// infrastructure (e.g. a Strategy ID / order tag Fyers issues you) —
  /// confirm the current requirement directly with Fyers before this
  /// method is used to place real orders, and add whatever tag/field
  /// they require to `orderTag` below.
  Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required int qty,
    required int side, // 1 = buy, -1 = sell
    int type = 2, // market order by default
    String productType = "INTRADAY",
    double limitPrice = 0,
    double stopPrice = 0,
    String validity = "DAY",
    String orderTag = "",
  }) async {
    final body = jsonEncode({
      "symbol": symbol,
      "qty": qty,
      "type": type,
      "side": side,
      "productType": productType,
      "limitPrice": limitPrice,
      "stopPrice": stopPrice,
      "validity": validity,
      "disclosedQty": 0,
      "offlineOrder": false,
      "stopLoss": 0,
      "takeProfit": 0,
      if (orderTag.isNotEmpty) "orderTag": orderTag,
    });

    final response = await http.post(
      Uri.parse("https://api-t1.fyers.in/api/v3/orders"),
      headers: {
        "Authorization": "${Session.appId}:${Session.accessToken}",
        "Content-Type": "application/json",
      },
      body: body,
    );

    print("Order status: ${response.statusCode}");
    print(response.body);

    final json = jsonDecode(response.body);
    return json is Map<String, dynamic> ? json : {"s": "error", "raw": json};
  }
}