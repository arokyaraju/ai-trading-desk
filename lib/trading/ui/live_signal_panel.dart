/// lib/trading/ui/live_signal_panel.dart
///
/// Displays signals from LiveSignalProvider as they're detected — entry
/// price, SL, target, strike, and how long ago it fired. Purely
/// informational: no order placement, no position tracking.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../strategy/live_signal_provider.dart';
import '../strategy/signal_engine.dart' show SignalDirection;
import '../strategy/signal_levels.dart';

class LiveSignalPanel extends StatefulWidget {
  const LiveSignalPanel({super.key});

  @override
  State<LiveSignalPanel> createState() => _LiveSignalPanelState();
}

class _LiveSignalPanelState extends State<LiveSignalPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveSignalProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveSignalProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Live Signals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (provider.isPolling)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
          ],
        ),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: provider.signals.isEmpty
              ? const Center(
                  child: Text('No signals yet today', style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              : ListView.separated(
                  itemCount: provider.signals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _SignalCard(signal: provider.signals[i]),
                ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  final SignalWithLevels signal;
  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final isBullish = signal.direction == SignalDirection.bullish;
    final accentColor = isBullish ? Colors.greenAccent : Colors.redAccent;
    final timeStr =
        '${signal.timestamp.hour.toString().padLeft(2, '0')}:${signal.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: accentColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isBullish ? Icons.trending_up : Icons.trending_down, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    isBullish ? 'BULLISH' : 'BEARISH',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
              Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          _row('Entry', signal.entryPrice.toStringAsFixed(2)),
          _row('SL', signal.stopLoss.toStringAsFixed(2)),
          _row('Target', signal.target.toStringAsFixed(2)),
          if (signal.strikeSymbol != null) _row('Strike', signal.strikeSymbol!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}