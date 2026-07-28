import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/sector_provider.dart';

class SectorOverviewPanel extends StatefulWidget {
  const SectorOverviewPanel({super.key});

  @override
  State<SectorOverviewPanel> createState() => _SectorOverviewPanelState();
}

class _SectorOverviewPanelState extends State<SectorOverviewPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SectorProvider>().loadSectors();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectorProvider>(
      builder: (context, provider, child) {
        final sectors = provider.sectors;

        final maxAbsChange = sectors.isEmpty
            ? 1.0
            : sectors
                .map((e) => e.value.changePercent.abs())
                .reduce((a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff1B1D24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sector Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              if (provider.isLoading && sectors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                ...sectors.map((entry) {
                  final name = entry.key.name;
                  final chp = entry.value.changePercent;
                  final isGain = chp >= 0;
                  final barWidthFraction =
                      maxAbsChange == 0 ? 0.0 : (chp.abs() / maxAbsChange);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: barWidthFraction.clamp(0.02, 1.0),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isGain
                                      ? Colors.greenAccent.shade400
                                      : Colors.redAccent.shade200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 55,
                          child: Text(
                            "${chp.toStringAsFixed(2)}%",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: isGain
                                  ? Colors.greenAccent.shade400
                                  : Colors.redAccent.shade200,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}