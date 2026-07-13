/// Rendering hints attached to a Symbol (SDD-028). Appearance only —
/// "Symbols contain no Engineering Knowledge."
class SymbolRenderingMetadata {
  final String defaultColor;
  final double strokeWidth;
  final bool fill;
  final int layer;
  final List<List<double>> snapPoints;

  const SymbolRenderingMetadata({
    this.defaultColor = '#000000',
    this.strokeWidth = 1.5,
    this.fill = false,
    this.layer = 0,
    this.snapPoints = const [],
  });

  Map<String, Object?> toJson() => {
        'defaultColor': defaultColor,
        'strokeWidth': strokeWidth,
        'fill': fill,
        'layer': layer,
        'snapPoints': snapPoints,
      };

  factory SymbolRenderingMetadata.fromJson(Map<String, Object?> json) {
    return SymbolRenderingMetadata(
      defaultColor: json['defaultColor'] as String? ?? '#000000',
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.5,
      fill: json['fill'] as bool? ?? false,
      layer: (json['layer'] as num?)?.toInt() ?? 0,
      snapPoints: (json['snapPoints'] as List? ?? const [])
          .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
    );
  }
}
