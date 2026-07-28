import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/models/market_quote.dart';
import '../providers/fno_movers_provider.dart';

class FnoHeatmapTab extends StatefulWidget {
  const FnoHeatmapTab({super.key});

  @override
  State<FnoHeatmapTab> createState() => _FnoHeatmapTabState();
}

class _FnoHeatmapTabState extends State<FnoHeatmapTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FnoMoversProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FnoMoversProvider>();
    final quotes = [...provider.quotes]
      ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'F&O Heatmap${quotes.isNotEmpty ? ' (${quotes.length})' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (provider.isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => context.read<FnoMoversProvider>().refresh(),
                  tooltip: 'Refresh heatmap',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: quotes.isEmpty
              ? Center(
                  child: provider.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('No F&O data', style: TextStyle(color: Colors.grey)),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return _FittedHeatGrid(
                      quotes: quotes,
                      availableWidth: constraints.maxWidth,
                      availableHeight: constraints.maxHeight,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FittedHeatGrid extends StatelessWidget {
  final List<MarketQuote> quotes;
  final double availableWidth;
  final double availableHeight;

  const _FittedHeatGrid({
    required this.quotes,
    required this.availableWidth,
    required this.availableHeight,
  });

  @override
  Widget build(BuildContext context) {
    final count = quotes.length;
    if (count == 0 || availableWidth <= 0 || availableHeight <= 0) {
      return const SizedBox.shrink();
    }

    const spacing = 3.0;

    int bestColumns = 1;
    double bestScore = double.infinity;

    for (int columns = 1; columns <= count; columns++) {
      final rows = (count / columns).ceil();
      final tileWidth = (availableWidth - spacing * (columns - 1)) / columns;
      final tileHeight = (availableHeight - spacing * (rows - 1)) / rows;
      if (tileWidth <= 0 || tileHeight <= 0) continue;

      final aspectPenalty = (tileWidth / tileHeight - 1).abs();
      final emptyCells = columns * rows - count;
      final score = aspectPenalty + emptyCells * 0.01;

      if (score < bestScore) {
        bestScore = score;
        bestColumns = columns;
      }
    }

    final columns = bestColumns;
    final rows = (count / columns).ceil();
    final tileWidth = (availableWidth - spacing * (columns - 1)) / columns;
    final tileHeight = (availableHeight - spacing * (rows - 1)) / rows;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final q in quotes)
          SizedBox(
            width: tileWidth,
            height: tileHeight,
            child: _HeatTile(quote: q, compact: tileHeight < 40),
          ),
      ],
    );
  }
}

class _HeatTile extends StatelessWidget {
  final MarketQuote quote;
  final bool compact;

  const _HeatTile({required this.quote, this.compact = false});

  static const double _maxAbsChange = 5.0;

  Color _colorFor(double changePercent) {
    final clamped = changePercent.clamp(-_maxAbsChange, _maxAbsChange);
    final intensity = (clamped.abs() / _maxAbsChange).clamp(0.15, 1.0);
    final base = changePercent >= 0 ? Colors.green : Colors.red;
    return Color.lerp(base.shade900, base.shade400, intensity)!;
  }

  @override
  Widget build(BuildContext context) {
    final chp = quote.changePercent;
    final label = quote.symbol.replaceFirst('NSE:', '').replaceFirst('-EQ', '');

    return Container(
      decoration: BoxDecoration(
        color: _colorFor(chp),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: compact ? 8 : 10, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (!compact) const SizedBox(height: 1),
            Text(
              '${chp >= 0 ? '+' : ''}${chp.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.white, fontSize: compact ? 7 : 9),
            ),
          ],
        ),
      ),
    );
  }
}