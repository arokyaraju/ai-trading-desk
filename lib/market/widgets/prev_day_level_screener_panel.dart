import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prev_day_level_screener_provider.dart';
import '../screener/screener_match.dart';

class PrevDayLevelScreenerPanel extends StatefulWidget {
  const PrevDayLevelScreenerPanel({super.key});

  @override
  State<PrevDayLevelScreenerPanel> createState() => _PrevDayLevelScreenerPanelState();
}

class _PrevDayLevelScreenerPanelState extends State<PrevDayLevelScreenerPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrevDayLevelScreenerProvider>().start();
    });
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Color _colorFor(ScreenerPattern p) {
    switch (p) {
      case ScreenerPattern.falseBreakoutHigh:
        return Colors.redAccent; // failed bullish break -> bearish signal
      case ScreenerPattern.falseBreakdownLow:
        return Colors.greenAccent; // failed bearish break -> bullish signal
      case ScreenerPattern.pivotRejection:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrevDayLevelScreenerProvider>();
    final grouped = <ScreenerPattern, List<ScreenerMatch>>{
      for (final p in ScreenerPattern.values)
        p: provider.matches.where((m) => m.pattern == p).toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prev-Day Level Screener${provider.matches.isNotEmpty ? ' (${provider.matches.length})' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (provider.isLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: () => context.read<PrevDayLevelScreenerProvider>().refresh(),
                tooltip: 'Refresh screener',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        if (provider.error != null)
          Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
        const SizedBox(height: 6),
        Expanded(
          child: provider.matches.isEmpty
              ? Center(
                  child: provider.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('No matches right now', style: TextStyle(color: Colors.grey)),
                )
              : ListView(
                  children: [
                    for (final pattern in ScreenerPattern.values)
                      if (grouped[pattern]!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            pattern.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _colorFor(pattern),
                            ),
                          ),
                        ),
                        ...grouped[pattern]!.map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${m.symbol}  '
                                '(${_fmtTime(m.firstCandleTime)}→${_fmtTime(m.secondCandleTime)}: '
                                '${m.firstClose.toStringAsFixed(1)} → ${m.secondClose.toStringAsFixed(1)})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            )),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}