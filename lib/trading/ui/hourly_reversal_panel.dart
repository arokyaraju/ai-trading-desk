import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../live/hourly_reversal_trading_provider.dart';
import '../models/trade.dart';

class HourlyReversalPanel extends StatelessWidget {
  const HourlyReversalPanel({super.key});

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Consumer<HourlyReversalTradingProvider>(
      builder: (context, live, _) {
        final allTrades = <Trade>[
          if (live.openTrade != null) live.openTrade!,
          ...live.closedTrades,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: live.openTrade != null ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
              child: Text(
                live.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: live.openTrade != null ? Colors.greenAccent : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: allTrades.isEmpty
                  ? const Center(child: Text('No trades yet today', style: TextStyle(color: Colors.grey)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 32,
                        dataRowMinHeight: 28,
                        dataRowMaxHeight: 32,
                        columns: const [
                          DataColumn(label: Text('Date', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Time', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Symbol', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Entry', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('SL Pts', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('P/L Pts', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Investment', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('ROI %', style: TextStyle(fontSize: 11))),
                        ],
                        rows: allTrades.map((t) {
                          final isOpen = t.status == TradeStatus.open;
                          final slPoints = (t.signal.entryPrice - t.signal.stopLoss).abs();
                          final plPoints = isOpen ? 0.0 : (t.exitPrice! - t.signal.entryPrice);
                          final color = isOpen
                              ? Colors.orangeAccent
                              : (t.realizedPnl >= 0 ? Colors.green : Colors.red);

                          return DataRow(cells: [
                            DataCell(Text(_fmtDate(t.signal.timestamp), style: const TextStyle(fontSize: 11))),
                            DataCell(Text(_fmtTime(t.signal.timestamp), style: const TextStyle(fontSize: 11))),
                            DataCell(Text(t.signal.contract.symbol, style: const TextStyle(fontSize: 11))),
                            DataCell(Text('₹${t.signal.entryPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                            DataCell(Text(slPoints.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                            DataCell(Text(isOpen ? '—' : plPoints.toStringAsFixed(2), style: TextStyle(fontSize: 11, color: color))),
                            DataCell(Text(isOpen ? '—' : '₹${t.realizedPnl.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))),
                            DataCell(Text('₹${t.investment.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11))),
                            DataCell(Text(isOpen ? '—' : '${t.roi.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}