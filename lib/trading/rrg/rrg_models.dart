/// lib/trading/rrg/rrg_models.dart
///
/// Core data types for the Relative Rotation Graph (RRG) feature.

class RRGPoint {
  final DateTime date;
  final double rsRatio;   // x-axis: JdK-style RS-Ratio (centered on 100)
  final double rsMomentum; // y-axis: JdK-style RS-Momentum (centered on 100)

  const RRGPoint({
    required this.date,
    required this.rsRatio,
    required this.rsMomentum,
  });
}

/// One symbol's full RRG tail (chronological list of points).
class RRGSeries {
  final String symbolKey;   // internal key, e.g. "niftyMidcap50"
  final String displayName; // e.g. "Nifty Midcap 50"
  final List<RRGPoint> points; // chronological order, oldest -> newest

  const RRGSeries({
    required this.symbolKey,
    required this.displayName,
    required this.points,
  });

  RRGPoint? get latest => points.isEmpty ? null : points.last;

  /// Returns the quadrant of the latest point, or null if no data.
  RRGQuadrant? get currentQuadrant {
    final p = latest;
    if (p == null) return null;
    return RRGQuadrant.fromPoint(p);
  }
}

enum RRGQuadrant {
  leading,   // rsRatio >= 100, rsMomentum >= 100
  weakening, // rsRatio >= 100, rsMomentum < 100
  lagging,   // rsRatio < 100,  rsMomentum < 100
  improving; // rsRatio < 100,  rsMomentum >= 100

  static RRGQuadrant fromPoint(RRGPoint p) {
    if (p.rsRatio >= 100 && p.rsMomentum >= 100) return RRGQuadrant.leading;
    if (p.rsRatio >= 100 && p.rsMomentum < 100) return RRGQuadrant.weakening;
    if (p.rsRatio < 100 && p.rsMomentum < 100) return RRGQuadrant.lagging;
    return RRGQuadrant.improving;
  }
}