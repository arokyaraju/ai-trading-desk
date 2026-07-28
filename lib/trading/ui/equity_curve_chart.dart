import 'package:flutter/material.dart';
import '../models/trade.dart';

/// Draws a simple cumulative P&L line — going up means profitable,
/// going down means losing, flat means no movement in that stretch.
class EquityCurveChart extends StatelessWidget {
  final List<Trade> trades; // must be chronologically sorted

  const EquityCurveChart({super.key, required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const Center(
        child: Text('No trades to chart', style: TextStyle(color: Colors.grey)),
      );
    }

    final cumulative = <double>[0];
    double running = 0;
    for (final t in trades) {
      running += t.realizedPnl;
      cumulative.add(running);
    }

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        size: Size.infinite,
        painter: _EquityCurvePainter(cumulative: cumulative),
      ),
    );
  }
}

class _EquityCurvePainter extends CustomPainter {
  final List<double> cumulative;

  _EquityCurvePainter({required this.cumulative});

  @override
  void paint(Canvas canvas, Size size) {
    final minVal = cumulative.reduce((a, b) => a < b ? a : b);
    final maxVal = cumulative.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs() < 1 ? 1.0 : (maxVal - minVal);

    double xFor(int i) =>
        cumulative.length > 1 ? (i / (cumulative.length - 1)) * size.width : 0;
    double yFor(double v) => size.height - ((v - minVal) / range) * size.height;

    final zeroY = yFor(0);
    final zeroPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    final isProfitable = cumulative.last >= 0;
    final lineColor = isProfitable ? Colors.green : Colors.red;

    final path = Path();
    for (int i = 0; i < cumulative.length; i++) {
      final x = xFor(i);
      final y = yFor(cumulative[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(xFor(cumulative.length - 1), zeroY)
      ..lineTo(xFor(0), zeroY)
      ..close();
    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _EquityCurvePainter oldDelegate) => true;
}