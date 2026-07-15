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
}
