/// lib/trading/chart/candle_renderer.dart
///
/// Paints candlesticks + horizontal grid lines + price axis labels for
/// whatever slice of the candle series the ChartViewport currently
/// shows. Pure rendering — no gesture handling (that lives in
/// PriceChartWidget).

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/candle.dart';
import 'chart_viewport.dart';

class CandleChartPainter extends CustomPainter {
  final List<Candle> candles;
  final ChartViewport viewport;

  CandleChartPainter({required this.candles, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final start = viewport.startIndex.floor().clamp(0, candles.length - 1);
    final end = viewport.endIndex.ceil().clamp(0, candles.length);
    if (end <= start) return;
    final visible = candles.sublist(start, end);
    if (visible.isEmpty) return;

    double minPrice = visible.map((c) => c.low).reduce(math.min);
    double maxPrice = visible.map((c) => c.high).reduce(math.max);
    final pad = (maxPrice - minPrice) * 0.08 + 0.01;
    minPrice -= pad;
    maxPrice += pad;

    final chartWidth = size.width;
    final chartHeight = size.height;
    final visibleCount = viewport.visibleCount == 0 ? 1 : viewport.visibleCount;
    final candleSlotWidth = chartWidth / visibleCount;
    final bodyWidth = (candleSlotWidth * 0.6).clamp(1.0, 20.0);

    double yFor(double price) =>
        chartHeight - (price - minPrice) / (maxPrice - minPrice) * chartHeight;

    // Grid lines + price axis labels
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      final price = maxPrice - (maxPrice - minPrice) * i / 4;
      _drawText(canvas, price.toStringAsFixed(2), Offset(4, y + 2));
    }

    // Candles
    for (int i = start; i < end; i++) {
      final c = candles[i];
      final xCenter = (i - viewport.startIndex) * candleSlotWidth + candleSlotWidth / 2;
      final isUp = c.close >= c.open;
      final color = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(xCenter, yFor(c.high)), Offset(xCenter, yFor(c.low)), wickPaint);

      final bodyTop = yFor(math.max(c.open, c.close));
      final bodyBottomRaw = yFor(math.min(c.open, c.close));
      final bodyBottom = math.max(bodyBottomRaw, bodyTop + 1); // ensure visible even on doji
      final bodyRect = Rect.fromLTRB(
        xCenter - bodyWidth / 2,
        bodyTop,
        xCenter + bodyWidth / 2,
        bodyBottom,
      );
      canvas.drawRect(bodyRect, Paint()..color = color);
    }
  }

  void _drawText(Canvas canvas, String text, Offset position) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.grey, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter oldDelegate) => true;
}