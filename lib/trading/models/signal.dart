import 'option_contract.dart';

enum TradeSide { long, short }

class Signal {
  final OptionContract contract;
  final TradeSide side;
  final double entryPrice;
  final double stopLoss;
  final double target;
  final DateTime timestamp;
  final double confidence;

  const Signal({
    required this.contract,
    required this.side,
    required this.entryPrice,
    required this.stopLoss,
    required this.target,
    required this.timestamp,
    this.confidence = 1.0,
  });
}