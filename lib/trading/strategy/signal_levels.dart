/// lib/trading/strategy/signal_levels.dart
///
/// A raw IndexSignalCandidate (from HourlyReversalSignalEngine) enriched
/// with a computed target and, optionally, a resolved option strike —
/// this is what actually gets shown on the live signal panel.

import 'signal_engine.dart' show SignalDirection;

class SignalWithLevels {
  final DateTime timestamp;
  final SignalDirection direction;
  final double entryPrice;   // index-level trigger price
  final double stopLoss;     // index-level SL
  final double target;       // index-level target (entry +/- rrMultiple * risk)
  final String? strikeSymbol; // e.g. "NSE:NIFTY24AUG24500CE", null if not yet resolved

  const SignalWithLevels({
    required this.timestamp,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.target,
    this.strikeSymbol,
  });

  double get riskPoints => (entryPrice - stopLoss).abs();
  double get rewardPoints => (target - entryPrice).abs();
}

/// Abstraction over strike selection so LiveSignalProvider doesn't need
/// to know your OptionChainService's exact interface directly — wire a
/// concrete implementation once option_chain_service.dart is available.
abstract class StrikeSelector {
  /// Returns a suggested option contract symbol for the given signal
  /// direction and underlying trigger price, or null if none could be
  /// resolved (e.g. option chain fetch failed).
  Future<String?> selectStrike({
    required SignalDirection direction,
    required double underlyingPrice,
  });
}