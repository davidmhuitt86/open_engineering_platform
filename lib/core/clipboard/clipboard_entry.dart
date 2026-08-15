import '../graph/models/engineering_group.dart';
import '../graph/models/engineering_node.dart';
import '../graph/models/engineering_relationship.dart';
import '../views/diagram/diagram_annotation.dart';
import '../views/diagram/diagram_geometry.dart';

/// A copied subgraph snapshot (WORK_PACKAGE_021, ENGINE-TASK-000083;
/// extended WORK_PACKAGE_023, ENGINE-TASK-000100 to also carry copied
/// annotations).
///
/// Carries positions alongside the graph objects — the clipboard has to
/// remember layout too, or a paste would have nowhere sensible to place
/// the copies (layout lives outside the graph, see ADR-011, so it must be
/// captured explicitly here rather than assumed).
class ClipboardEntry {
  final List<EngineeringNode> nodes;
  final List<EngineeringRelationship> relationships;
  final List<EngineeringGroup> groups;
  final Map<String, Point2D> positions;
  final List<DiagramAnnotation> annotations;

  const ClipboardEntry({
    this.nodes = const [],
    this.relationships = const [],
    this.groups = const [],
    this.positions = const {},
    this.annotations = const [],
  });

  bool get isEmpty => nodes.isEmpty && annotations.isEmpty;

  // --- Serialization (AP-DS-001A: OS clipboard round-trip) --------------

  Map<String, Object?> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'relationships': relationships.map((r) => r.toJson()).toList(),
        'groups': groups.map((g) => g.toJson()).toList(),
        'positions': positions.map((id, p) => MapEntry(id, {'dx': p.dx, 'dy': p.dy})),
        'annotations': annotations.map((a) => a.toJson()).toList(),
      };

  factory ClipboardEntry.fromJson(Map<String, Object?> json) {
    Point2D pointFrom(Object? value) {
      final point = value as Map;
      return Point2D((point['dx'] as num).toDouble(), (point['dy'] as num).toDouble());
    }

    final rawPositions = json['positions'] as Map? ?? const {};
    return ClipboardEntry(
      nodes: (json['nodes'] as List? ?? const [])
          .map((n) => EngineeringNode.fromJson(Map<String, Object?>.from(n as Map)))
          .toList(),
      relationships: (json['relationships'] as List? ?? const [])
          .map((r) => EngineeringRelationship.fromJson(Map<String, Object?>.from(r as Map)))
          .toList(),
      groups: (json['groups'] as List? ?? const [])
          .map((g) => EngineeringGroup.fromJson(Map<String, Object?>.from(g as Map)))
          .toList(),
      positions: rawPositions.map((id, value) => MapEntry(id as String, pointFrom(value))),
      annotations: (json['annotations'] as List? ?? const [])
          .map((a) => DiagramAnnotation.fromJson(Map<String, Object?>.from(a as Map)))
          .toList(),
    );
  }
}
