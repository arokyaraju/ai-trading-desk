import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/price_alert.dart';
import '../providers/price_alerts_provider.dart';

class PriceAlertsPanel extends StatelessWidget {
  const PriceAlertsPanel({super.key});

  void _showAddDialog(BuildContext context) {
    final symbolController = TextEditingController();
    final priceController = TextEditingController();
    AlertDirection direction = AlertDirection.above;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('New Price Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol (e.g. NSE:RELIANCE-EQ)',
                ),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target Price'),
              ),
              const SizedBox(height: 8),
              DropdownButton<AlertDirection>(
                value: direction,
                items: const [
                  DropdownMenuItem(value: AlertDirection.above, child: Text('Above')),
                  DropdownMenuItem(value: AlertDirection.below, child: Text('Below')),
                ],
                onChanged: (v) => setState(() => direction = v ?? AlertDirection.above),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final symbol = symbolController.text.trim();
                final price = double.tryParse(priceController.text.trim());
                if (symbol.isEmpty || price == null) return;

                dialogContext.read<PriceAlertsProvider>().addAlert(symbol, price, direction);
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PriceAlertsProvider>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Price Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.add_alert, size: 18),
                onPressed: () => _showAddDialog(context),
                tooltip: 'Add alert',
              ),
            ],
          ),
          if (provider.alerts.isEmpty)
            const Text('No alerts set', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...provider.alerts.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${a.symbol} ${a.direction == AlertDirection.above ? "≥" : "≤"} ₹${a.targetPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: a.triggered ? Colors.orangeAccent : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => context.read<PriceAlertsProvider>().removeAlert(a),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}