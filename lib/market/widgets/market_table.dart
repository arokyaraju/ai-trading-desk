import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';

class MarketTable extends StatelessWidget {
  const MarketTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [

            // Header
            Container(
              height: 38,
              color: Colors.blueGrey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Row(
                children: [

                  Expanded(
                    flex: 2,
                    child: Text(
                      "SYMBOL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      "LTP",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      "CHG",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      "%",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      "VOL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: provider.quotes.length,
                itemBuilder: (context, index) {

                  final q = provider.quotes[index];

                  final color =
                      q.change >= 0 ? Colors.greenAccent : Colors.redAccent;

                  return Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [

                        Expanded(
                          flex: 2,
                          child: Text(
                            q.symbol,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            q.ltp.toStringAsFixed(2),
                            style: TextStyle(color: color),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            q.change.toStringAsFixed(2),
                            style: TextStyle(color: color),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "${q.changePercent.toStringAsFixed(2)}%",
                            style: TextStyle(color: color),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            q.volume.toString(),
                            style: const TextStyle(color: Colors.white),
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
      },
    );
  }
}