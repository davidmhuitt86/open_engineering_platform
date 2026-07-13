/// The kind of Source Material an [EvidenceLink] traces back to (SDD-024/027).
enum EvidenceKind { ocr, text, diagramRegion, image, procedure, other }

/// An immutable reference from an Engineering Node or Relationship back to
/// its Source Material.
///
/// Evidence is never edited. A node/relationship may lose confidence, be
/// corrected, or be reclassified — its evidence links stay pointed at the
/// original material so the change remains auditable (SDD-024 Architecture
/// Rule 7).
class EvidenceLink {
  final String id;
  final EvidenceKind kind;

  /// Identifier of the Source Material this evidence traces to (e.g. a
  /// document id, image id, or page/session reference). Opaque to the
  /// Engineering Engine — interpreted by whatever produced the evidence.
  final String sourceReference;

  /// Free-form locator within the source (e.g. a bounding box, page number,
  /// OCR span). Shape is producer-defined; the engine treats it as data.
  final Map<String, Object?> locator;

  final double? confidence;

  const EvidenceLink({
    required this.id,
    required this.kind,
    required this.sourceReference,
    this.locator = const {},
    this.confidence,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'sourceReference': sourceReference,
        'locator': locator,
        'confidence': confidence,
      };

  factory EvidenceLink.fromJson(Map<String, Object?> json) => EvidenceLink(
        id: json['id'] as String,
        kind: EvidenceKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => EvidenceKind.other,
        ),
        sourceReference: json['sourceReference'] as String,
        locator: Map<String, Object?>.from(json['locator'] as Map? ?? const {}),
        confidence: (json['confidence'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) => other is EvidenceLink && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
