/// lib/trading/ui/chart_screen.dart
///
/// Symbol picker (Nifty + every F&O stock, same source as FnoMoversProvider)
/// + resolution picker, feeding candles into PriceChartWidget.

import 'package:flutter/material.dart';

import '../../fyers/rest/fyers_rest_service.dart';
import '../chart/price_chart_widget.dart';
import '../data/instrument_master_service.dart';
import '../models/candle.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final FyersRestService _rest = FyersRestService();
  final InstrumentMasterService _instrumentMasterService = InstrumentMasterService();

  static const _niftySymbol = 'NSE:NIFTY50-INDEX';
  static const Map<String, String> _resolutionLabels = {
    '1': '1m',
    '5': '5m',
    '15': '15m',
    '60': '1h',
    'D': '1D',
  };

  List<String> _symbols = [_niftySymbol];
  String _selectedSymbol = _niftySymbol;
  String _resolution = '5';
  List<Candle> _candles = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSymbols();
  }

  Future<void> _loadSymbols() async {
    try {
      final underlyings = await _instrumentMasterService.getFnoStockUnderlyings();
      final fnoSymbols = underlyings.map(_instrumentMasterService.equitySymbolFor).toList();
      if (mounted) {
        setState(() => _symbols = [_niftySymbol, ...fnoSymbols]);
      }
    } catch (_) {
      // Nifty is still usable even if the F&O list fails to load.
    }
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final to = DateTime.now();
      final lookbackDays = _resolution == 'D' ? 200 : 5;
      final from = to.subtract(Duration(days: lookbackDays));

      final raw = await _rest.getHistoricalCandles(
        symbol: _selectedSymbol,
        from: from,
        to: to,
        resolution: _resolution,
      );

      final candles = raw
          .map((c) => Candle(
                timestamp: c['date'] as DateTime,
                open: c['open'] as double,
                high: c['high'] as double,
                low: c['low'] as double,
                close: c['close'] as double,
                volume: (c['volume'] as double).toInt(),
              ))
          .toList();

      if (mounted) {
        setState(() {
          _candles = candles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load chart: $e';
          _loading = false;
        });
      }
    }
  }

  String _shortName(String fyersSymbol) {
    var s = fyersSymbol;
    if (s.startsWith('NSE:')) s = s.substring(4);
    if (s.endsWith('-EQ')) s = s.substring(0, s.length - 3);
    if (s.endsWith('-INDEX')) s = s.substring(0, s.length - 6);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: _selectedSymbol,
                isExpanded: true,
                dropdownColor: const Color(0xff1a1b1e),
                items: _symbols
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_shortName(s), style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedSymbol = v);
                  _loadChart();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _resolution,
              dropdownColor: const Color(0xff1a1b1e),
              items: _resolutionLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _resolution = v);
                _loadChart();
              },
            ),
            IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadChart),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : PriceChartWidget(candles: _candles),
        ),
      ],
    );
  }
}