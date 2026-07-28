/// lib/trading/chart/chart_viewport.dart
///
/// Tracks which slice of the candle series is currently visible, in
/// fractional candle-index units so panning/zooming feels smooth rather
/// than snapping candle-by-candle.

class ChartViewport {
  double startIndex;
  double endIndex;

  ChartViewport({required this.startIndex, required this.endIndex});

  double get visibleCount => endIndex - startIndex;

  /// Shifts the visible window left/right by [deltaCandles] (can be
  /// fractional).
  void pan(double deltaCandles) {
    startIndex += deltaCandles;
    endIndex += deltaCandles;
  }

  /// Zooms in/out around [focalIndex] (the candle index under the
  /// finger/cursor). [factor] > 1 zooms out, < 1 zooms in.
  void zoom(double factor, double focalIndex) {
    final newCount = (visibleCount * factor).clamp(10.0, 1000.0);
    final ratio = visibleCount == 0 ? 0.5 : (focalIndex - startIndex) / visibleCount;
    startIndex = focalIndex - newCount * ratio;
    endIndex = startIndex + newCount;
  }

  /// Keeps the window within [0, totalCandles], preserving the visible
  /// count where possible instead of clamping it away.
  void clamp(int totalCandles) {
    if (totalCandles <= 0) return;
    if (endIndex > totalCandles) {
      final shift = endIndex - totalCandles;
      startIndex -= shift;
      endIndex -= shift;
    }
    if (startIndex < 0) {
      final shift = -startIndex;
      startIndex += shift;
      endIndex += shift;
    }
    if (startIndex < 0) startIndex = 0;
    if (endIndex > totalCandles) endIndex = totalCandles.toDouble();
  }
}