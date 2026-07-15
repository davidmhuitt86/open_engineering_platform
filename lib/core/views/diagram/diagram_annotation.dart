import 'diagram_geometry.dart';

/// The kind of annotation a [DiagramAnnotation] represents
/// (WORK_PACKAGE_023, ENGINE-TASK-000100).
enum AnnotationType {
  textLabel,
  leaderNote,
  callout,
  wireLabel,
  componentLabel,
  freeText,
  revisionNote,
}

/// A drafting annotation — text label, leader note, callout, wire/
/// component label, free text, or revision note.
///
/// Annotations belong to Diagram Layout, never the Engineering Graph
/// (SDD-024 Rule 5: layout is not engineering knowledge) — an annotation
/// is a drafting/documentation mark on a diagram, not an engineering
/// object, relationship, or piece of evidence. [anchorNodeId]/
/// [anchorRelationshipId] are optional soft references (for Component/
/// Wire Labels that track a specific node or relationship) — they are
/// plain ids, not graph edges, and a dangling reference (anchor deleted)
/// simply means the annotation renders unanchored, exactly like an
/// [EngineeringRelationship] never being able to corrupt the annotation
/// system.
class DiagramAnnotation {
  final String id;
  final AnnotationType type;
  final String text;
  final Point2D position;

  /// Degrees, clockwise, `0` = unrotated.
  final double rotation;

  final String? anchorNodeId;
  final String? anchorRelationshipId;
  final Map<String, Object?> metadata;

  const DiagramAnnotation({
    required this.id,
    required this.type,
    required this.text,
    required this.position,
    this.rotation = 0,
    this.anchorNodeId,
    this.anchorRelationshipId,
    this.metadata = const {},
  });

  DiagramAnnotation copyWith({
    AnnotationType? type,
    String? text,
    Point2D? position,
    double? rotation,
    String? anchorNodeId,
    bool clearAnchorNodeId = false,
    String? anchorRelationshipId,
    bool clearAnchorRelationshipId = false,
    Map<String, Object?>? metadata,
  }) {
    return DiagramAnnotation(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      anchorNodeId: clearAnchorNodeId ? null : (anchorNodeId ?? this.anchorNodeId),
      anchorRelationshipId: clearAnchorRelationshipId
          ? null
          : (anchorRelationshipId ?? this.anchorRelationshipId),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        'position': {'dx': position.dx, 'dy': position.dy},
        'rotation': rotation,
        'anchorNodeId': anchorNodeId,
        'anchorRelationshipId': anchorRelationshipId,
        'metadata': metadata,
      };

  @override
  bool operator ==(Object other) {
    return other is DiagramAnnotation &&
        other.id == id &&
        other.type == type &&
        other.text == text &&
        other.position == position &&
        other.rotation == rotation &&
        other.anchorNodeId == anchorNodeId &&
        other.anchorRelationshipId == anchorRelationshipId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        text,
        position,
        rotation,
        anchorNodeId,
        anchorRelationshipId,
      );

  factory DiagramAnnotation.fromJson(Map<String, Object?> json) {
    final positionJson = json['position'] as Map;
    return DiagramAnnotation(
      id: json['id'] as String,
      type: AnnotationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AnnotationType.freeText,
      ),
      text: json['text'] as String,
      position: Point2D(
        (positionJson['dx'] as num).toDouble(),
        (positionJson['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      anchorNodeId: json['anchorNodeId'] as String?,
      anchorRelationshipId: json['anchorRelationshipId'] as String?,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}
