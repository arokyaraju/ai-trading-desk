import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/option_chain_provider.dart';

class OptionChainPanel extends StatefulWidget {
  const OptionChainPanel({super.key});

  @override
  State<OptionChainPanel> createState() => _OptionChainPanelState();
}

class _OptionChainPanelState extends State<OptionChainPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OptionChainProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OptionChainProvider>();
    final rows = provider.rowsByStrike;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PCR: ${provider.pcr.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (provider.isLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: () => context.read<OptionChainProvider>().refresh(),
                tooltip: 'Refresh option chain',
              ),
          ],
        ),
        if (provider.error != null)
          Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
        const SizedBox(height: 6),
        Row(
          children: const [
            Expanded(child: Text('CE OI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(
              width: 70,
              child: Text('Strike', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text('PE OI', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const Divider(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${row.ce?.openInterest ?? '-'}',
                              style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              row.strike.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${row.pe?.openInterest ?? '-'}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}