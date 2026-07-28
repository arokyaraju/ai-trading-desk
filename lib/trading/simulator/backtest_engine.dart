import '../models/candle.dart';
import '../models/option_contract.dart';
import '../models/signal.dart';
import '../models/trade.dart';
import '../strategy/signal_engine.dart';
import '../strategy/strike_selector.dart';

class DaySessionData {
  final DateTime sessionDate;
  final double openingSpot;
  final double strikeInterval;
  final int lotSize;
  final List<Candle> indexCandles;
  final List<OptionContract> fullChainSnapshot;
  final Map<String, List<Candle>> candlesBySymbol;

  DaySessionData({
    required this.sessionDate,
    required this.openingSpot,
    required this.strikeInterval,
    required this.lotSize,
    required this.indexCandles,
    required this.fullChainSnapshot,
    required this.candlesBySymbol,
  });
}

class MonthlySummary {
  final String monthLabel;
  final double pnl;
  final int tradeCount;
  final int wins;

  MonthlySummary({
    required this.monthLabel,
    required this.pnl,
    required this.tradeCount,
    required this.wins,
  });

  double get winRate => tradeCount == 0 ? 0 : wins / tradeCount * 100;
}

class BacktestResult {
  final double totalPnl;
  final List<Trade> trades;
  final List<DateTime> skippedDays;

  BacktestResult({
    required this.totalPnl,
    required this.trades,
    required this.skippedDays,
  });

  double get winRate {
    if (trades.isEmpty) return 0;
    final wins = trades.where((t) => t.realizedPnl > 0).length;
    return wins / trades.length * 100;
  }

  double get totalInvestment => trades.fold<double>(0, (s, t) => s + t.investment);

  double get overallRoi =>
      totalInvestment == 0 ? 0 : (totalPnl / totalInvestment) * 100;

  double get averageRoiPerTrade {
    if (trades.isEmpty) return 0;
    return trades.fold<double>(0, (s, t) => s + t.roi) / trades.length;
  }

  List<MonthlySummary> get monthlyBreakdown {
    final Map<String, List<Trade>> byMonth = {};
    for (final t in trades) {
      final key =
          '${t.signal.timestamp.year}-${t.signal.timestamp.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(t);
    }
    final keys = byMonth.keys.toList()..sort();
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return keys.map((k) {
      final monthTrades = byMonth[k]!;
      final pnl = monthTrades.fold<double>(0, (s, t) => s + t.realizedPnl);
      final wins = monthTrades.where((t) => t.realizedPnl > 0).length;
      final parts = k.split('-');
      final monthNum = int.parse(parts[1]);
      return MonthlySummary(
        monthLabel: '${monthNames[monthNum]} ${parts[0]}',
        pnl: pnl,
        tradeCount: monthTrades.length,
        wins: wins,
      );
    }).toList();
  }
}

class BacktestEngine {
  final SignalEngine _signalEngine = SignalEngine();

  BacktestResult run(List<DaySessionData> sessions) {
    final List<Trade> allTrades = [];
    final List<DateTime> skipped = [];

    for (final session in sessions) {
      if (session.fullChainSnapshot.isEmpty ||
          session.candlesBySymbol.isEmpty ||
          session.indexCandles.isEmpty) {
        skipped.add(session.sessionDate);
        continue;
      }

      final candidates = _signalEngine.generateSignals(session.indexCandles);
      if (candidates.isEmpty) continue;

      DateTime? blockedUntil;

      for (final candidate in candidates) {
        if (blockedUntil != null && candidate.timestamp.isBefore(blockedUntil)) {
          continue;
        }

        final optionType =
            candidate.direction == SignalDirection.bullish ? OptionType.CE : OptionType.PE;

        final contract = StrikeSelector.selectAtm(
          chain: session.fullChainSnapshot,
          spot: candidate.triggerPrice,
          type: optionType,
        );
        if (contract == null) continue;

        final optionCandles = session.candlesBySymbol[contract.symbol];
        if (optionCandles == null || optionCandles.isEmpty) continue;

        final trade = _simulateTrade(
          candidate: candidate,
          contract: contract,
          optionCandles: optionCandles,
          lotSize: session.lotSize,
        );

        if (trade != null) {
          allTrades.add(trade);
          blockedUntil = trade.exitTime;
        }
      }
    }

    allTrades.sort((a, b) => a.signal.timestamp.compareTo(b.signal.timestamp));

    final totalPnl = allTrades.fold<double>(0, (sum, t) => sum + t.realizedPnl);
    return BacktestResult(totalPnl: totalPnl, trades: allTrades, skippedDays: skipped);
  }

  Trade? _simulateTrade({
    required IndexSignalCandidate candidate,
    required OptionContract contract,
    required List<Candle> optionCandles,
    required int lotSize,
  }) {
    final sorted = [...optionCandles]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final signalIndex = sorted.indexWhere((c) => !c.timestamp.isBefore(candidate.timestamp));
    if (signalIndex == -1 || signalIndex >= sorted.length - 1) return null;

    final entryCandle = sorted[signalIndex + 1];
    final entryPrice = entryCandle.open;
    if (entryPrice <= 0) return null;

    final delta = contract.delta?.abs() ?? 0.5;
    final slMove = candidate.riskPoints * delta;
    if (slMove <= 0) return null;
    final targetMove = slMove * 3;

    final stopLoss = entryPrice - slMove;
    final target = entryPrice + targetMove;

    final signal = Signal(
      contract: contract,
      side: TradeSide.long,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      target: target,
      timestamp: entryCandle.timestamp,
    );

    final trade = Trade(signal: signal, quantity: lotSize);

    for (int i = signalIndex + 1; i < sorted.length; i++) {
      final c = sorted[i];
      if (c.low <= stopLoss) {
        trade.exitPrice = stopLoss;
        trade.exitTime = c.timestamp;
        trade.status = TradeStatus.closedStopLoss;
        return trade;
      }
      if (c.high >= target) {
        trade.exitPrice = target;
        trade.exitTime = c.timestamp;
        trade.status = TradeStatus.closedTarget;
        return trade;
      }
    }

    trade.exitPrice = sorted.last.close;
    trade.exitTime = sorted.last.timestamp;
    trade.status = TradeStatus.closedEod;
    return trade;
  }
}