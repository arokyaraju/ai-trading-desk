import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../home/models/market_quote.dart';
import '../providers/market_provider.dart';

class IndicesPanel extends StatefulWidget {
  const IndicesPanel({super.key});

  @override
  State<IndicesPanel> createState() => _IndicesPanelState();
}

class _IndicesPanelState extends State<IndicesPanel> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;

  static const double _pixelsPerSecond = 30.0;
  static const double _cardWidth = 140.0;
  static const double _cardSpacing = 8.0;

  final List<({String name, String symbol})> _indices = const [
    (name: "NIFTY", symbol: "NSE:NIFTY50-INDEX"),
    (name: "BANKNIFTY", symbol: "NSE:NIFTYBANK-INDEX"),
    (name: "FINNIFTY", symbol: "NSE:FINNIFTY-INDEX"),
    (name: "MIDCPNIFTY", symbol: "NSE:MIDCPNIFTY-INDEX"),
    (name: "SENSEX", symbol: "BSE:SENSEX-INDEX"),
    (name: "BANKEX", symbol: "BSE:BANKEX-INDEX"),
    (name: "INDIA VIX", symbol: "NSE:INDIAVIX-INDEX"),
  ];

  double get _oneSetWidth => _indices.length * (_cardWidth + _cardSpacing);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    double next = _scrollController.offset + (_pixelsPerSecond / 60);

    // Once we've scrolled past one full set of cards, snap back by exactly
    // that width — since the list is duplicated, this is visually seamless.
    if (next >= _oneSetWidth) {
      next -= _oneSetWidth;
    }

    _scrollController.jumpTo(next);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _card(String name, String symbol, List<MarketQuote> quotes) {
    final match = quotes.where((q) => q.symbol == symbol);
    final quote = match.isNotEmpty ? match.first : null;

    final ltp = quote?.ltp ?? 0.0;
    final changePercent = quote?.changePercent ?? 0.0;
    final color = changePercent >= 0 ? Colors.greenAccent : Colors.redAccent;

    return SizedBox(
      width: _cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(ltp.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
              Text("${changePercent.toStringAsFixed(2)}%", style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, provider, child) {
        // Duplicated so the loop-back (jumpTo) is invisible — as soon as
        // the first set scrolls fully out, an identical second set is
        // already in view underneath it.
        final doubledIndices = [..._indices, ..._indices];

        return SizedBox(
          height: 110,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: doubledIndices.length,
            itemBuilder: (context, i) {
              final entry = doubledIndices[i];
              return Padding(
                padding: const EdgeInsets.only(right: _cardSpacing),
                child: _card(entry.name, entry.symbol, provider.quotes),
              );
            },
          ),
        );
      },
    );
  }
}