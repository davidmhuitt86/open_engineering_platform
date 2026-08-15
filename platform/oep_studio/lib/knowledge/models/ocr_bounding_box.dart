/// A word's location on a page (Work Package 013 STUDIO-TASK-000034:
/// "Each page produces: ... Bounding Boxes").
///
/// [x]/[y]/[width]/[height] are fractions (`0.0`–`1.0`) of the page
/// image's own width/height, **top-left origin** — the same
/// resolution-/zoom-independent convention `EvidenceRegion` already
/// established (`docs/EVIDENCE_MODEL.md` § Coordinate System), reused
/// here rather than inventing a second coordinate convention for
/// bounding boxes that live on the same rendered pages.
class OcrBoundingBox {
  const OcrBoundingBox({required this.x, required this.y, required this.width, required this.height});

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'width': width, 'height': height};

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) {
    return OcrBoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}
