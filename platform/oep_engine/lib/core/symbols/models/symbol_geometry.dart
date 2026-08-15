/// How a Symbol's shape is stored (SDD-028: "Preferred: SVG. Future: Native
/// Geometry").
enum GeometryKind { svgAsset, nativeGeometry }

/// A reference to the vector asset backing a Symbol's appearance.
///
/// The Engineering Engine never parses or renders this — SDD-025/026
/// forbid Flutter Widgets/dart:ui in engine code. A View's Flutter host
/// (e.g. the Demonstration Host's painter) resolves [assetPath] and draws
/// it. This model only carries the reference.
class SymbolGeometry {
  final GeometryKind kind;
  final String assetPath;

  /// Symbol-space bounds the geometry was authored for (used to normalize
  /// [SymbolPort] coordinates and scale for rendering).
  final double width;
  final double height;

  const SymbolGeometry({
    required this.kind,
    required this.assetPath,
    this.width = 100,
    this.height = 100,
  });

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'assetPath': assetPath,
        'width': width,
        'height': height,
      };

  factory SymbolGeometry.fromJson(Map<String, Object?> json) => SymbolGeometry(
        kind: GeometryKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => GeometryKind.svgAsset,
        ),
        assetPath: json['assetPath'] as String,
        width: (json['width'] as num?)?.toDouble() ?? 100,
        height: (json['height'] as num?)?.toDouble() ?? 100,
      );
}
