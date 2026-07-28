import 'package:http/http.dart' as http;

/// Fetches Fyers' public F&O symbol master CSV.
/// No auth required — public.fyers.in is separate from the api-t1 domain
/// used for everything else.
///
/// Column mapping confirmed from a real downloaded row (2026-07-26):
///   [1]  human-readable description ("BANKNIFTY 28 Jul 26 FUT")
///   [3]  lot size
///   [4]  tick size
///   [8]  expiry epoch (seconds)
///   [9]  Fyers trading symbol ("NSE:BANKNIFTY26JULFUT")
///   [13] underlying symbol ("BANKNIFTY", "RELIANCE", etc.)
///   [15] strike price (-1.0 for futures, real strike for options)
///   [16] option type ("XX" = future, "CE"/"PE" = option)
class InstrumentMasterService {
  static const String _masterUrl = 'https://public.fyers.in/sym_details/NSE_FO.csv';

  static const int _colLotSize = 3;
  static const int _colExpiryEpoch = 8;
  static const int _colFyersSymbol = 9;
  static const int _colUnderlying = 13;
  static const int _colStrike = 15;
  static const int _colOptType = 16;

  static const Set<String> _indexUnderlyings = {
    'NIFTY', 'BANKNIFTY', 'FINNIFTY', 'MIDCPNIFTY', 'NIFTYNXT50',
    'SENSEX', 'BANKEX',
  };

  List<List<String>>? _cachedRows;

  Future<void> _ensureLoaded() async {
    if (_cachedRows != null) return;

    final response = await http.get(Uri.parse(_masterUrl));
    if (response.statusCode != 200) {
      _cachedRows = [];
      return;
    }

    final lines = response.body.split('\n');
    _cachedRows = lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split(','))
        .toList();
  }

  /// Returns every stock underlying that currently has F&O contracts —
  /// e.g. ["ADANIENT", "RELIANCE", "TCS", ...]. Indices are excluded.
  Future<List<String>> getFnoStockUnderlyings() async {
    await _ensureLoaded();
    final rows = _cachedRows;
    if (rows == null || rows.isEmpty) return [];

    final set = <String>{};
    for (final row in rows) {
      if (row.length <= _colUnderlying) continue;
      final underlying = row[_colUnderlying].trim();
      if (underlying.isEmpty || _indexUnderlyings.contains(underlying)) continue;
      set.add(underlying);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Converts an underlying stock name into its Fyers equity spot symbol,
  /// e.g. "RELIANCE" -> "NSE:RELIANCE-EQ".
  String equitySymbolFor(String underlying) => 'NSE:$underlying-EQ';

  /// Returns the futures lot size for a given underlying (stock or index),
  /// using the nearest (row-order-first) FUT contract found.
  Future<int?> getLotSizeForUnderlying(String underlying) async {
    await _ensureLoaded();
    final rows = _cachedRows;
    if (rows == null || rows.isEmpty) return null;

    for (final row in rows) {
      if (row.length <= _colOptType) continue;
      if (row[_colUnderlying].trim() == underlying && row[_colOptType].trim() == 'XX') {
        return int.tryParse(row[_colLotSize].trim());
      }
    }
    return null;
  }

  Future<int?> getLotSize(String symbol) async {
    await _ensureLoaded();
    final rows = _cachedRows;
    if (rows == null || rows.isEmpty) return null;

    for (final row in rows) {
      if (row.length <= _colFyersSymbol) continue;
      if (row[_colFyersSymbol].trim() == symbol) {
        return int.tryParse(row[_colLotSize].trim());
      }
    }
    return null;
  }

  Future<int?> getCurrentNiftyLotSize(String anyCurrentWeeklyNiftySymbol) async {
    return getLotSize(anyCurrentWeeklyNiftySymbol);
  }
}