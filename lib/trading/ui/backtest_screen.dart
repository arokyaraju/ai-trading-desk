// lib/trading/ui/backtest_screen.dart

import 'package:flutter/material.dart';
import '../data/fyers_historical_service.dart';
import '../data/option_chain_service.dart';
import '../data/instrument_master_service.dart';
import '../models/candle.dart';
import '../models/option_contract.dart';
import '../models/trade.dart';
import '../pricing/greeks_calculator.dart';
import '../simulator/backtest_engine.dart';
import 'equity_curve_chart.dart';

const String kNiftyUnderlying = 'NSE:NIFTY50-INDEX';
const double kNiftyStrikeInterval = 50;

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _isRunning = false;
  String? _errorMessage;
  BacktestResult? _result;

  final _historicalService = FyersHistoricalService();
  final _optionChainService = OptionChainService();
  final _instrumentMasterService = InstrumentMasterService();
  final _greeksCalculator = const GreeksCalculator();
  final _backtestEngine = BacktestEngine();

  Future<void> _runBacktest() async {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final indexCandles = await _historicalService.getHistoricalCandles(
        symbol: kNiftyUnderlying,
        resolution: '1',
        from: _fromDate,
        to: _toDate,
      );

      if (indexCandles.isEmpty) {
        setState(() {
          _errorMessage =
              'No Nifty index data returned for this date range. Check date range and market holidays.';
          _isRunning = false;
        });
        return;
      }

      final Map<String, List<Candle>> candlesByDay = {};
      for (final c in indexCandles) {
        final key = '${c.timestamp.year}-${c.timestamp.month}-${c.timestamp.day}';
        candlesByDay.putIfAbsent(key, () => []).add(c);
      }

      final sessions = <DaySessionData>[];
      int? resolvedLotSize;

      for (final entry in candlesByDay.entries) {
        final dayCandles = entry.value;
        dayCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final sessionDate = dayCandles.first.timestamp;
        final openingSpot = dayCandles.first.open;

        final rawChain = await _optionChainService.getOptionChain(
          underlyingSymbol: kNiftyUnderlying,
          strikeCount: 5,
        );
        await Future.delayed(const Duration(milliseconds: 300));

        final enrichedChain = <OptionContract>[];
        for (final contract in rawChain) {
          final ltp = contract.bid != null && contract.ask != null
              ? (contract.bid! + contract.ask!) / 2
              : null;
          if (ltp == null) continue;
          final enriched = _greeksCalculator.enrichWithGreeks(
            contract: contract,
            ltp: ltp,
            spot: openingSpot,
            now: sessionDate,
          );
          if (enriched != null) enrichedChain.add(enriched);
        }

        if (enrichedChain.isEmpty) {
          continue;
        }

        if (resolvedLotSize == null) {
          resolvedLotSize = await _instrumentMasterService.getLotSize(enrichedChain.first.symbol);
          await Future.delayed(const Duration(milliseconds: 300));
          if (resolvedLotSize == null) {
            setState(() {
              _errorMessage =
                  'Could not resolve Nifty lot size from the instrument master for symbol '
                  '"${enrichedChain.first.symbol}" — aborting rather than guessing a value.';
              _isRunning = false;
            });
            return;
          }
        }

        final candlesBySymbol = <String, List<Candle>>{};
        for (final contract in enrichedChain) {
          final candles = await _historicalService.getHistoricalCandles(
            symbol: contract.symbol,
            resolution: '1',
            from: sessionDate,
            to: sessionDate,
          );
          if (candles.isNotEmpty) {
            candlesBySymbol[contract.symbol] = candles;
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }

        sessions.add(DaySessionData(
          sessionDate: sessionDate,
          openingSpot: openingSpot,
          strikeInterval: kNiftyStrikeInterval,
          lotSize: resolvedLotSize,
          indexCandles: dayCandles,
          fullChainSnapshot: enrichedChain,
          candlesBySymbol: candlesBySymbol,
        ));
      }

      if (sessions.isEmpty) {
        setState(() {
          _errorMessage = 'No valid sessions could be built for this date range.';
          _isRunning = false;
        });
        return;
      }

      final result = _backtestEngine.run(sessions);

      setState(() {
        _result = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Backtest failed: $e';
        _isRunning = false;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  String _fmtDateTime(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]}, $hh:$mm';
  }

  String _statusLabel(TradeStatus status) {
    switch (status) {
      case TradeStatus.closedTarget:
        return 'TARGET HIT';
      case TradeStatus.closedStopLoss:
        return 'SL HIT';
      case TradeStatus.closedEod:
        return 'EOD EXIT';
      case TradeStatus.open:
        return 'OPEN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nifty Options Backtest')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: _isRunning ? null : _pickFromDate,
                  child: Text('From: ${_fromDate.toLocal().toString().split(' ')[0]}'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _isRunning ? null : _pickToDate,
                  child: Text('To: ${_toDate.toLocal().toString().split(' ')[0]}'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isRunning ? null : _runBacktest,
                  child: Text(_isRunning ? 'Running...' : 'Run Backtest'),
                ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            if (_result != null) Expanded(child: _buildQuadrants(_result!)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrants(BacktestResult result) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _quadrantCard('Equity Curve', _buildChartContent(result))),
              const SizedBox(width: 8),
              Expanded(child: _quadrantCard('Trades Taken', _buildTradesContent(result))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _quadrantCard('P&L Report', _buildPnlContent(result))),
              const SizedBox(width: 8),
              Expanded(child: _quadrantCard('Return on Investment', _buildRoiContent(result))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quadrantCard(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Divider(),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildChartContent(BacktestResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total P&L: ₹${result.totalPnl.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: result.totalPnl >= 0 ? Colors.green : Colors.red,
          ),
        ),
        Text('${result.trades.length} trades  |  ${result.winRate.toStringAsFixed(1)}% win'),
        const SizedBox(height: 8),
        Expanded(child: EquityCurveChart(trades: result.trades)),
      ],
    );
  }

  Widget _buildTradesContent(BacktestResult result) {
    return ListView.builder(
      itemCount: result.trades.length,
      itemBuilder: (context, i) {
        final Trade t = result.trades[i];
        final pnlColor = t.realizedPnl >= 0 ? Colors.green : Colors.red;

        // "Points captured" = how much the option premium itself moved,
        // exit minus entry (not Nifty index points — the premium's own move).
        final pointsCaptured = (t.exitPrice ?? t.signal.entryPrice) - t.signal.entryPrice;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${t.signal.contract.symbol} — ${t.signal.side.name.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Text(
                    _statusLabel(t.status),
                    style: TextStyle(fontSize: 10, color: pnlColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'In: ${_fmtDateTime(t.signal.timestamp)}   '
                'Out: ${t.exitTime != null ? _fmtDateTime(t.exitTime!) : '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Entry ₹${t.signal.entryPrice.toStringAsFixed(2)}   '
                'SL ₹${t.signal.stopLoss.toStringAsFixed(2)}   '
                'Target ₹${t.signal.target.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                'Exit price: ₹${(t.exitPrice ?? 0).toStringAsFixed(2)}   '
                'Points captured: ${pointsCaptured.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                'Investment ₹${t.investment.toStringAsFixed(0)}   '
                'Profit: ₹${t.realizedPnl.toStringAsFixed(2)}   '
                'ROI: ${t.roi.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: pnlColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPnlContent(BacktestResult result) {
    return ListView(
      children: [
        Text(
          'Total P&L: ₹${result.totalPnl.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: result.totalPnl >= 0 ? Colors.green : Colors.red,
          ),
        ),
        Text('Win rate: ${result.winRate.toStringAsFixed(1)}%'),
        Text('Skipped days: ${result.skippedDays.length}'),
        const SizedBox(height: 8),
        const Text('Month by Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const Divider(),
        ...result.monthlyBreakdown.map((m) {
          final color = m.pnl >= 0 ? Colors.green : Colors.red;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m.monthLabel, style: const TextStyle(fontSize: 12)),
                Text('${m.tradeCount} trades', style: const TextStyle(fontSize: 12)),
                Text(
                  '₹${m.pnl.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRoiContent(BacktestResult result) {
    return ListView(
      children: [
        Text(
          'Overall ROI: ${result.overallRoi.toStringAsFixed(2)}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: result.overallRoi >= 0 ? Colors.green : Colors.red,
          ),
        ),
        Text('Total investment: ₹${result.totalInvestment.toStringAsFixed(2)}'),
        Text('Average ROI per trade: ${result.averageRoiPerTrade.toStringAsFixed(2)}%'),
        const SizedBox(height: 8),
        const Text('Per Trade ROI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const Divider(),
        ...result.trades.map((t) {
          final color = t.roi >= 0 ? Colors.green : Colors.red;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.signal.contract.symbol,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${t.roi.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}