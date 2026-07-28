import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/models/market_quote.dart';
import '../providers/fno_movers_provider.dart';

class MoversPanel extends StatefulWidget {
  const MoversPanel({super.key});

  @override
  State<MoversPanel> createState() => _MoversPanelState();
}

class _MoversPanelState extends State<MoversPanel> {
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
    final quotes = provider.quotes;

    final gainers = [...quotes]..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final losers = [...quotes]..sort((a, b) => a.changePercent.compareTo(b.changePercent));

    final momentum = [...quotes]
      ..sort((a, b) {
        final scoreA = a.volume * a.changePercent.abs();
        final scoreB = b.volume * b.changePercent.abs();
        return scoreB.compareTo(scoreA);
      });

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('F&O Movers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (provider.isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => context.read<dynamic>().refresh(),
                  tooltip: 'Refresh F&O quotes',
                ),
            ],
          ),
          if (provider.error != null)
            Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          const SizedBox(height: 6),
          _sectionTitle('Top Gainers'),
          ..._buildList(gainers.take(5).toList()),
          const SizedBox(height: 14),
          _sectionTitle('Top Losers'),
          ..._buildList(losers.take(5).toList()),
          const SizedBox(height: 14),
          _sectionTitle('Momentum'),
          ..._buildList(momentum.take(5).toList()),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  List<Widget> _buildList(List<MarketQuote> quotes) {
    if (quotes.isEmpty) {
      return [const Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12))];
    }
    return quotes.map((q) {
      final chp = q.changePercent;
      final color = chp >= 0 ? Colors.green : Colors.red;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(q.symbol, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
            Text('₹${q.ltp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 55,
              child: Text(
                '${chp.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}