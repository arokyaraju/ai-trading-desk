import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../trading/data/fyers_historical_service.dart';
import '../providers/fno_movers_provider.dart';

class BreakoutPanel extends StatefulWidget {
  const BreakoutPanel({super.key});

  @override
  State<BreakoutPanel> createState() => _BreakoutPanelState();
}

class _BreakoutPanelState extends State<BreakoutPanel> {
  final _historicalService = FyersHistoricalService();

  final Map<String, double> _prevHigh = {};
  final Map<String, double> _prevLow = {};
  bool _isLoading = false;
  String? _error;

  List<String> _lastLoadedSymbols = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FnoMoversProvider>().start();
      _loadPrevDayLevels();
    });
  }

  Future<void> _loadPrevDayLevels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final symbols = context.read<FnoMoversProvider>().quotes.map((q) => q.symbol).toList();

      if (symbols.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));

      const batchSize = 10;
      for (var i = 0; i < symbols.length; i += batchSize) {
        final batch = symbols.skip(i).take(batchSize);
        await Future.wait(batch.map((symbol) async {
          try {
            final candles = await _historicalService.getHistoricalCandles(
              symbol: symbol,
              resolution: 'D',
              from: from,
              to: now,
            );

            final priorDayCandles = candles.where((c) => !(c.timestamp.year == now.year &&
                c.timestamp.month == now.month &&
                c.timestamp.day == now.day)).toList();

            if (priorDayCandles.isNotEmpty) {
              priorDayCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              final prevDay = priorDayCandles.last;
              _prevHigh[symbol] = prevDay.high;
              _prevLow[symbol] = prevDay.low;
            }
          } catch (e) {
            debugPrint('Breakout: failed to load $symbol: $e');
          }
        }));

        if (i + batchSize < symbols.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      _lastLoadedSymbols = symbols;
    } catch (e) {
      _error = 'Failed to load previous-day levels: $e';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<FnoMoversProvider>().quotes;

    if (quotes.isNotEmpty &&
        !_isLoading &&
        _lastLoadedSymbols.length != quotes.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrevDayLevels());
    }

    final breakouts = <String>[];
    final breakdowns = <String>[];

    for (final q in quotes) {
      final ltp = q.ltp;
      final prevHigh = _prevHigh[q.symbol];
      final prevLow = _prevLow[q.symbol];
      if (prevHigh != null && ltp > prevHigh) {
        breakouts.add(q.symbol);
      } else if (prevLow != null && ltp < prevLow) {
        breakdowns.add(q.symbol);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prev-Day High/Low Breaks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (_isLoading)
                const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _loadPrevDayLevels,
                  tooltip: 'Refresh previous-day levels',
                ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          const SizedBox(height: 8),
          const Text('Breakout (above prev-day high)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
          if (breakouts.isEmpty)
            const Text('None right now', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...breakouts.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                )),
          const SizedBox(height: 14),
          const Text('Breakdown (below prev-day low)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
          if (breakdowns.isEmpty)
            const Text('None right now', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...breakdowns.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                )),
        ],
      ),
    );
  }
}