/// lib/trading/chart/price_chart_widget.dart
///
/// Combines ChartViewport (state) + CandleChartPainter (rendering) with
/// pan/pinch-zoom gestures. Drop in any List<Candle> and it just works —
/// used for Nifty, any F&O stock, or an option contract's own candles.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/candle.dart';
import 'candle_renderer.dart';
import 'chart_viewport.dart';

class PriceChartWidget extends StatefulWidget {
  final List<Candle> candles;
  final int initialVisibleCandles;

  const PriceChartWidget({
    super.key,
    required this.candles,
    this.initialVisibleCandles = 80,
  });

  @override
  State<PriceChartWidget> createState() => _PriceChartWidgetState();
}

class _PriceChartWidgetState extends State<PriceChartWidget> {
  late ChartViewport _viewport;
  double _scaleStartCount = 0;
  double _panStartIndex = 0;
  double _lastWidth = 0;

  @override
  void initState() {
    super.initState();
    _resetViewport();
  }

  @override
  void didUpdateWidget(covariant PriceChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles.length != widget.candles.length) {
      _resetViewport();
    }
  }

  void _resetViewport() {
    final total = widget.candles.length;
    final visible = total < widget.initialVisibleCandles ? total : widget.initialVisibleCandles;
    _viewport = ChartViewport(
      startIndex: (total - visible).toDouble(),
      endIndex: total.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _scaleStartCount = _viewport.visibleCount;
            _panStartIndex = _viewport.startIndex;
          },
          onScaleUpdate: (details) {
            setState(() {
              if ((details.scale - 1.0).abs() > 0.001) {
                final focalIndex = _panStartIndex +
                    (details.localFocalPoint.dx / _lastWidth) * _scaleStartCount;
                _viewport.zoom(1 / details.scale, focalIndex);
              } else {
                final candleWidth = _lastWidth / _viewport.visibleCount;
                final deltaCandles = -details.focalPointDelta.dx / candleWidth;
                _viewport.pan(deltaCandles);
              }
              _viewport.clamp(widget.candles.length);
            });
          },
          child: MouseRegion(
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  setState(() {
                    final factor = event.scrollDelta.dy > 0 ? 1.1 : 0.9;
                    final focalIndex = _viewport.startIndex +
                        (event.localPosition.dx / _lastWidth) * _viewport.visibleCount;
                    _viewport.zoom(factor, focalIndex);
                    _viewport.clamp(widget.candles.length);
                  });
                }
              },
              child: CustomPaint(
                painter: CandleChartPainter(candles: widget.candles, viewport: _viewport),
                child: Container(),
              ),
            ),
          ),
        );
      },
    );
  }
}