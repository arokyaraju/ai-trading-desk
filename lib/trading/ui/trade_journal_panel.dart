import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../live/live_trading_provider.dart';
import '../models/trade.dart';

class TradeJournalPanel extends StatelessWidget {
  const TradeJournalPanel({super.key});

  double _pnl(Trade trade) {
    final exit = trade.exitPrice;
    if (exit == null) return 0;
    return (exit - trade.signal.entryPrice) * trade.quantity;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveTradingProvider>();
    final open = provider.openTrade;
    final closed = provider.closedTrades;

    final totalPnl = closed.fold<double>(0, (sum, t) => sum + _pnl(t));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trade Journal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'Total P&L: ₹${totalPnl.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: totalPnl >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 10),
          if (open != null) ...[
            const Text('Open Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${open.signal.contract.symbol}  entry ₹${open.signal.entryPrice.toStringAsFixed(2)}  qty ${open.quantity}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const Text('Closed Trades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          if (closed.isEmpty)
            const Text('No closed trades yet', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...closed.map((t) {
              final pnl = _pnl(t);
              final color = pnl >= 0 ? Colors.greenAccent : Colors.redAccent;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${t.signal.contract.symbol} (${t.status.name})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${pnl.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}