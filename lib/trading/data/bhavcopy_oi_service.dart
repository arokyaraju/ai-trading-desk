import 'dart:io';

/// Reads the locally-cached NSE bhavcopy CSV (written by
/// bridge/nse_bhavcopy_downloader.py) for a given date, and looks up
/// previous-day OI/volume for a strike — used as the liquidity filter
/// in strike selection, since Fyers' option chain can't go back in time.
class BhavcopyOiService {
  final String cacheDir;

  BhavcopyOiService({this.cacheDir = 'nse_data_cache'});

  /// Returns a lookup: "strike_optiontype" (e.g. "24500_CE") -> (oi, volume)
  /// for the given date. Returns an empty map if no cache file exists for
  /// that date (e.g. a holiday, or not yet downloaded) — caller should
  /// treat that as "no liquidity data available", not throw.
  Future<Map<String, ({int oi, int volume})>> loadOiForDate(DateTime date) async {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final file = File('$cacheDir/bhavcopy_$dateStr.csv');

    if (!await file.exists()) {
      return {};
    }

    final lines = await file.readAsLines();
    if (lines.length < 2) return {};

    final result = <String, ({int oi, int volume})>{};

    // header: expiry,strike,option_type,oi,volume,close
    for (final line in lines.skip(1)) {
      final parts = line.split(',');
      if (parts.length < 5) continue;

      final strike = parts[1].trim();
      final optionType = parts[2].trim();
      final oi = int.tryParse(parts[3].trim()) ?? 0;
      final volume = int.tryParse(parts[4].trim()) ?? 0;

      final key = '${strike}_$optionType';
      result[key] = (oi: oi, volume: volume);
    }

    return result;
  }

  /// Convenience: gets OI/volume for one specific strike+type on a date.
  Future<({int oi, int volume})?> lookup({
    required DateTime date,
    required double strike,
    required String optionType, // "CE" or "PE"
  }) async {
    final all = await loadOiForDate(date);
    // strike formatting must match what the Python script wrote —
    // NSE bhavcopy strikes are usually whole numbers for Nifty, no decimals
    final strikeKey = strike.toStringAsFixed(strike == strike.roundToDouble() ? 0 : 2);
    return all['${strikeKey}_$optionType'];
  }
}