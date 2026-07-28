import 'signal.dart';

enum TradeStatus { open, closedTarget, closedStopLoss, closedEod }

class Trade {
  final Signal signal;
  final int quantity;
  double? exitPrice;
  DateTime? exitTime;
  TradeStatus status;

  Trade({
    required this.signal,
    required this.quantity,
    this.exitPrice,
    this.exitTime,
    this.status = TradeStatus.open,
  });

  double get realizedPnl {
    if (exitPrice == null) return 0;
    final diff = signal.side == TradeSide.long
        ? exitPrice! - signal.entryPrice
        : signal.entryPrice - exitPrice!;
    return diff * quantity;
  }

  /// Capital deployed to enter this trade (premium paid × quantity).
  double get investment => signal.entryPrice * quantity;

  /// Return on investment for this trade, as a percentage.
  double get roi => investment == 0 ? 0 : (realizedPnl / investment) * 100;
}