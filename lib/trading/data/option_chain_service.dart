import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/session.dart';
import '../models/option_contract.dart';

class OptionChainService {
  static const String _baseUrl = "https://api-t1.fyers.in/data/options-chain-v3";

  Future<Map<String, dynamic>?> _fetchRaw({
    required String underlyingSymbol,
    required int strikeCount,
    int? expiryTimestamp,
  }) async {
    final uri = Uri.parse(
      "$_baseUrl?symbol=$underlyingSymbol&strikecount=$strikeCount"
      "&timestamp=${expiryTimestamp ?? ''}",
    );

    final response = await http.get(
      uri,
      headers: {
        "Authorization": "${Session.appId}:${Session.accessToken}",
        "Content-Type": "application/json",
      },
    );

    print("OptionChain raw [$underlyingSymbol, ts=$expiryTimestamp] Status : ${response.statusCode}");
    print(response.body);

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json["s"] != "ok" || json["data"] == null) return null;
    return json["data"];
  }

  Future<List<OptionContract>> getOptionChain({
    required String underlyingSymbol,
    required int strikeCount,
  }) async {
    final discoveryData = await _fetchRaw(
      underlyingSymbol: underlyingSymbol,
      strikeCount: strikeCount,
    );
    if (discoveryData == null) return [];

    final List<dynamic> expiryData = discoveryData["expiryData"] ?? [];
    if (expiryData.isEmpty) return [];

    final weeklyEntry = expiryData.firstWhere(
      (e) => e["expiry_flag"] == "W",
      orElse: () => expiryData[0],
    );
    final expirySeconds = int.tryParse(weeklyEntry["expiry"].toString());
    if (expirySeconds == null) return [];
    final expiry = DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000);

    final isDefaultAlreadyWeekly = expiryData[0]["expiry_flag"] == "W";

    Map<String, dynamic> chainData = discoveryData;
    if (!isDefaultAlreadyWeekly) {
      final weeklyData = await _fetchRaw(
        underlyingSymbol: underlyingSymbol,
        strikeCount: strikeCount,
        expiryTimestamp: expirySeconds,
      );
      if (weeklyData != null) {
        chainData = weeklyData;
      }
    }

    final List<dynamic> optionsChain = chainData["optionsChain"] ?? [];
    final List<OptionContract> contracts = [];

    for (final row in optionsChain) {
      final optionType = row["option_type"];
      if (optionType != "CE" && optionType != "PE") continue;

      contracts.add(OptionContract(
        symbol: row["symbol"] ?? "",
        strike: (row["strike_price"] as num?)?.toDouble() ?? 0,
        expiry: expiry,
        type: optionType == "CE" ? OptionType.CE : OptionType.PE,
        bid: (row["bid"] as num?)?.toDouble(),
        ask: (row["ask"] as num?)?.toDouble(),
        ltp: (row["ltp"] as num?)?.toDouble(),
        openInterest: (row["oi"] as num?)?.toInt(),
      ));
    }

    return contracts;
  }

  /// Selects the expiry AFTER the nearest weekly one — i.e. "next
  /// week's" contract. UNVERIFIED ASSUMPTION: expiryData is
  /// chronologically ordered and the entry after the nearest "W"-flagged
  /// one is next week's expiry — check the printed raw response the
  /// first time this runs.
  Future<List<OptionContract>> getNextWeekOptionChain({
    required String underlyingSymbol,
    required int strikeCount,
  }) async {
    final discoveryData = await _fetchRaw(
      underlyingSymbol: underlyingSymbol,
      strikeCount: strikeCount,
    );
    if (discoveryData == null) return [];

    final List<dynamic> expiryData = discoveryData["expiryData"] ?? [];
    if (expiryData.isEmpty) return [];

    final nearestWeeklyIndex = expiryData.indexWhere((e) => e["expiry_flag"] == "W");
    final targetIndex = nearestWeeklyIndex >= 0 && nearestWeeklyIndex + 1 < expiryData.length
        ? nearestWeeklyIndex + 1
        : (expiryData.length > 1 ? 1 : 0);

    final targetEntry = expiryData[targetIndex];
    final expirySeconds = int.tryParse(targetEntry["expiry"].toString());
    if (expirySeconds == null) return [];
    final expiry = DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000);

    final chainData = await _fetchRaw(
      underlyingSymbol: underlyingSymbol,
      strikeCount: strikeCount,
      expiryTimestamp: expirySeconds,
    );
    if (chainData == null) return [];

    final List<dynamic> optionsChain = chainData["optionsChain"] ?? [];
    final List<OptionContract> contracts = [];

    for (final row in optionsChain) {
      final optionType = row["option_type"];
      if (optionType != "CE" && optionType != "PE") continue;

      contracts.add(OptionContract(
        symbol: row["symbol"] ?? "",
        strike: (row["strike_price"] as num?)?.toDouble() ?? 0,
        expiry: expiry,
        type: optionType == "CE" ? OptionType.CE : OptionType.PE,
        bid: (row["bid"] as num?)?.toDouble(),
        ask: (row["ask"] as num?)?.toDouble(),
        ltp: (row["ltp"] as num?)?.toDouble(),
        openInterest: (row["oi"] as num?)?.toInt(),
      ));
    }

    return contracts;
  }
}