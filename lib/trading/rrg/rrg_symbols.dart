/// lib/trading/rrg/rrg_symbols.dart
///
/// The index universe tracked on the RRG tab, relative to Nifty 50
/// as the benchmark.
///
/// IMPORTANT: `fyersSymbol` values below are best-guess NSE index codes
/// in Fyers' "NSE:<SYMBOL>-INDEX" format. Fyers' index symbol master
/// is not always 1:1 with NSE's official index names — verify each one
/// against your Fyers symbol master file (or the Fyers symbol search
/// endpoint) before wiring up live calls, and correct any that don't
/// resolve.

class RRGSymbolInfo {
  final String key;          // internal identifier
  final String displayName;  // shown in UI
  final String fyersSymbol;  // TODO: verify against Fyers symbol master

  const RRGSymbolInfo({
    required this.key,
    required this.displayName,
    required this.fyersSymbol,
  });
}

/// Benchmark for all RS-Ratio / RS-Momentum calculations.
const RRGSymbolInfo rrgBenchmark = RRGSymbolInfo(
  key: 'nifty50',
  displayName: 'Nifty 50',
  fyersSymbol: 'NSE:NIFTY50-INDEX',
);

/// The tracked universe, in the order you specified.
const List<RRGSymbolInfo> rrgSymbolUniverse = [
  RRGSymbolInfo(key: 'niftyMidcap50', displayName: 'Nifty Midcap 50', fyersSymbol: 'NSE:NIFTYMID50-INDEX'),
  RRGSymbolInfo(key: 'niftyMidcap150', displayName: 'Nifty Midcap 150', fyersSymbol: 'NSE:NIFTYMIDCAP150-INDEX'),
  RRGSymbolInfo(key: 'niftyMidcap100', displayName: 'Nifty Midcap 100', fyersSymbol: 'NSE:NIFTYMIDCAP100-INDEX'),
  RRGSymbolInfo(key: 'niftyIndiaFPI150', displayName: 'Nifty India FPI 150', fyersSymbol: 'NSE:NIFTYINDIAFPI150-INDEX'),
  RRGSymbolInfo(key: 'niftyLargeMidcap250', displayName: 'Nifty LargeMidcap 250', fyersSymbol: 'NSE:NIFTYLARGEMID250-INDEX'),
  RRGSymbolInfo(key: 'niftyNext50', displayName: 'Nifty Next 50', fyersSymbol: 'NSE:NIFTYNEXT50-INDEX'),
  RRGSymbolInfo(key: 'niftyTotalMarket', displayName: 'Nifty Total Market', fyersSymbol: 'NSE:NIFTYTOTALMKT-INDEX'),
  RRGSymbolInfo(key: 'nifty500', displayName: 'Nifty 500', fyersSymbol: 'NSE:NIFTY500-INDEX'),
  RRGSymbolInfo(key: 'nifty200', displayName: 'Nifty 200', fyersSymbol: 'NSE:NIFTY200-INDEX'),
  RRGSymbolInfo(key: 'nifty100', displayName: 'Nifty 100', fyersSymbol: 'NSE:NIFTY100-INDEX'),
  RRGSymbolInfo(key: 'niftySmallcap50', displayName: 'Nifty Smallcap 50', fyersSymbol: 'NSE:NIFTYSMLCAP50-INDEX'),
  RRGSymbolInfo(key: 'niftySmallcap100', displayName: 'Nifty Smallcap 100', fyersSymbol: 'NSE:NIFTYSMLCAP100-INDEX'),
  RRGSymbolInfo(key: 'niftySmallcap250', displayName: 'Nifty Smallcap 250', fyersSymbol: 'NSE:NIFTYSMLCAP250-INDEX'),
  RRGSymbolInfo(key: 'niftyMicrocap250', displayName: 'Nifty Microcap 250', fyersSymbol: 'NSE:NIFTYMICROCAP250-INDEX'),
];