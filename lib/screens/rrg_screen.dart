/// lib/screens/rrg_screen.dart
///
/// Relative Rotation Graph tab: plots RS-Ratio (x) vs RS-Momentum (y)
/// for the configured index universe against Nifty 50, with a trailing
/// "tail" of the last N days per symbol — same idea as Strike's RRG view.
///
/// Wiring required on your end:
///   1. Implement RRGDataProvider.getDailyCloses() using your existing
///      FyersRestService (lib/fyers/rest/fyers_rest_service.dart).
///      See FyersRRGDataProvider below for the shape expected — adjust
///      the method name/args to match your actual service.
///   2. Drop RRGScreen into your nav (see integration notes doc).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../fyers/rest/fyers_rest_service.dart';
import '../trading/rrg/rrg_calculator.dart';
import '../trading/rrg/rrg_models.dart';
import '../trading/rrg/rrg_symbols.dart';

/// Abstract so the screen doesn't hard-couple to your exact Fyers service.
abstract class RRGDataProvider {
  /// Daily closes for [fyersSymbol] between [from] and [to], oldest first.
  /// Call this once per symbol (including the benchmark) with the SAME
  /// date range so the series align by trading day.
  Future<List<MapEntry<DateTime, double>>> getDailyCloses({
    required String fyersSymbol,
    required DateTime from,
    required DateTime to,
  });
}

/// Adapter wired to FyersRestService.getHistoricalCandles.
class FyersRRGDataProvider implements RRGDataProvider {
  final FyersRestService _fyers;
  FyersRRGDataProvider(this._fyers);

  @override
  Future<List<MapEntry<DateTime, double>>> getDailyCloses({
    required String fyersSymbol,
    required DateTime from,
    required DateTime to,
  }) async {
    final candles = await _fyers.getHistoricalCandles(
      symbol: fyersSymbol,
      from: from,
      to: to,
    );
    return candles
        .map((c) => MapEntry(c['date'] as DateTime, c['close'] as double))
        .toList();
  }
}

class RRGScreen extends StatefulWidget {
  final RRGDataProvider dataProvider;
  final int lookbackTradingDays; // history pulled, e.g. 60
  final int rsRatioWindow;       // smoothing window, default 10
  final int momentumWindow;      // smoothing window, default 10
  final int tailLength;          // days shown as tail, e.g. 12

  const RRGScreen({
    super.key,
    required this.dataProvider,
    this.lookbackTradingDays = 60,
    this.rsRatioWindow = 10,
    this.momentumWindow = 10,
    this.tailLength = 12,
  });

  @override
  State<RRGScreen> createState() => _RRGScreenState();
}

class _RRGScreenState extends State<RRGScreen> {
  bool _loading = true;
  String? _error;
  List<RRGSeries> _series = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final to = DateTime.now();
      final from = to.subtract(Duration(days: (widget.lookbackTradingDays * 1.6).round()));

      final benchmarkData = await widget.dataProvider.getDailyCloses(
        fyersSymbol: rrgBenchmark.fyersSymbol,
        from: from,
        to: to,
      );
      final benchmarkDates = benchmarkData.map((e) => e.key).toList();
      final benchmarkCloses = benchmarkData.map((e) => e.value).toList();

      final series = <RRGSeries>[];
      for (final sym in rrgSymbolUniverse) {
        final data = await widget.dataProvider.getDailyCloses(
          fyersSymbol: sym.fyersSymbol,
          from: from,
          to: to,
        );

        // Align by date to the benchmark (simple intersection on date).
        final byDate = {for (final e in data) e.key: e.value};
        final dates = <DateTime>[];
        final symCloses = <double>[];
        final benchCloses = <double>[];
        for (int i = 0; i < benchmarkDates.length; i++) {
          final d = benchmarkDates[i];
          final v = byDate[d];
          if (v != null) {
            dates.add(d);
            symCloses.add(v);
            benchCloses.add(benchmarkCloses[i]);
          }
        }

        series.add(RRGCalculator.buildSeries(
          symbolKey: sym.key,
          displayName: sym.displayName,
          dates: dates,
          symbolCloses: symCloses,
          benchmarkCloses: benchCloses,
          rsRatioWindow: widget.rsRatioWindow,
          momentumWindow: widget.momentumWindow,
          tailLength: widget.tailLength,
        ));
      }

      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load RRG data:\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Relative Rotation Graph', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomPaint(
              painter: RRGChartPainter(series: _series),
              child: Container(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the quadrant background, axes, and each symbol's tail.
class RRGChartPainter extends CustomPainter {
  final List<RRGSeries> series;

  RRGChartPainter({required this.series});

  static const _quadrantColors = {
    RRGQuadrant.improving: Color(0xFFE6DFF5),  // lavender, top-left
    RRGQuadrant.leading: Color(0xFFD9EFDD),    // green, top-right
    RRGQuadrant.lagging: Color(0xFFF6DCDF),    // pink, bottom-left
    RRGQuadrant.weakening: Color(0xFFFBE6CE),  // orange, bottom-right
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    // Determine plot bounds from all points, padded, always including 100/100.
    double minX = 100, maxX = 100, minY = 100, maxY = 100;
    for (final s in series) {
      for (final p in s.points) {
        minX = math.min(minX, p.rsRatio);
        maxX = math.max(maxX, p.rsRatio);
        minY = math.min(minY, p.rsMomentum);
        maxY = math.max(maxY, p.rsMomentum);
      }
    }
    final padX = (maxX - minX) * 0.15 + 0.5;
    final padY = (maxY - minY) * 0.15 + 0.5;
    minX -= padX; maxX += padX; minY -= padY; maxY += padY;

    Offset toCanvas(double rsRatio, double rsMomentum) {
      final dx = (rsRatio - minX) / (maxX - minX) * size.width;
      final dy = size.height - (rsMomentum - minY) / (maxY - minY) * size.height;
      return Offset(dx, dy);
    }

    final centerPx = toCanvas(100, 100);

    // Quadrant backgrounds
    final paintQ = Paint();
    paintQ.color = _quadrantColors[RRGQuadrant.improving]!;
    canvas.drawRect(Rect.fromLTRB(0, 0, centerPx.dx, centerPx.dy), paintQ);
    paintQ.color = _quadrantColors[RRGQuadrant.leading]!;
    canvas.drawRect(Rect.fromLTRB(centerPx.dx, 0, size.width, centerPx.dy), paintQ);
    paintQ.color = _quadrantColors[RRGQuadrant.lagging]!;
    canvas.drawRect(Rect.fromLTRB(0, centerPx.dy, centerPx.dx, size.height), paintQ);
    paintQ.color = _quadrantColors[RRGQuadrant.weakening]!;
    canvas.drawRect(Rect.fromLTRB(centerPx.dx, centerPx.dy, size.width, size.height), paintQ);

    // Axis lines
    final axisPaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;
    canvas.drawLine(Offset(centerPx.dx, 0), Offset(centerPx.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, centerPx.dy), Offset(size.width, centerPx.dy), axisPaint);

    // Quadrant labels
    _drawLabel(canvas, 'IMPROVING', const Offset(6, 4));
    _drawLabel(canvas, 'LEADING', Offset(size.width - 6, 4), alignRight: true);
    _drawLabel(canvas, 'LAGGING', Offset(6, size.height - 16));
    _drawLabel(canvas, 'WEAKENING', Offset(size.width - 6, size.height - 16), alignRight: true);

    // Symbol colors (cycled)
    const palette = [
      Color(0xFF2E7D32), Color(0xFFE65100), Color(0xFF1565C0),
      Color(0xFF6A1B9A), Color(0xFFAD1457), Color(0xFF00695C),
      Color(0xFF5D4037), Color(0xFF37474F), Color(0xFF9E9D24),
      Color(0xFFC62828), Color(0xFF283593), Color(0xFF00838F),
      Color(0xFF4527A0), Color(0xFF558B2F),
    ];

    for (int si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.points.isEmpty) continue;
      final color = palette[si % palette.length];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;

      final pts = s.points.map((p) => toCanvas(p.rsRatio, p.rsMomentum)).toList();

      for (int i = 0; i < pts.length - 1; i++) {
        canvas.drawLine(pts[i], pts[i + 1], linePaint);
      }
      for (int i = 0; i < pts.length; i++) {
        final isLast = i == pts.length - 1;
        canvas.drawCircle(pts[i], isLast ? 4 : 2, Paint()..color = color);
      }

      // Label at the last (current) point
      final last = pts.last;
      final tp = TextPainter(
        text: TextSpan(
          text: s.displayName,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, last + const Offset(6, -6));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = alignRight ? pos - Offset(tp.width, 0) : pos;
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RRGChartPainter oldDelegate) => true;
}