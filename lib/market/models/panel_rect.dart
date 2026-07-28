class PanelRect {
  final double x, y, w, h;

  const PanelRect({required this.x, required this.y, required this.w, required this.h});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory PanelRect.fromJson(Map<String, dynamic> j) => PanelRect(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
      );

  PanelRect copyWith({double? x, double? y, double? w, double? h}) => PanelRect(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
      );
}