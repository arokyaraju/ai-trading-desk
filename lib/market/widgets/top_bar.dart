import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<MarketProvider>().isSocketConnected;

    return Container(
      height: 45,
      color: const Color(0xff1B1D24),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          const Icon(Icons.show_chart, color: Colors.green),
          const SizedBox(width: 10),
          const Text(
            "FYERS LIVE MARKET WATCH",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.circle,
            color: connected ? Colors.green : Colors.red,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(connected ? "Connected" : "Disconnected"),
        ],
      ),
    );
  }
}