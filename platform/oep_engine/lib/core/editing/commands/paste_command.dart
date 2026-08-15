import '../../clipboard/clipboard_entry.dart';
import '../../graph/models/engineering_group.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../../shared/ids.dart';
import '../../views/diagram/diagram_annotation.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Pastes a [ClipboardEntry], generating fresh ids for every object and
/// remapping relationship/group-membership references accordingly
/// (ENGINE-TASK-000083: "Generate new identifiers. Preserve relationships
/// where possible."). Extended in WORK_PACKAGE_023, ENGINE-TASK-000100 to
/// also paste copied annotations, offset the same way nodes are.
class PasteCommand implements EditingCommand {
  final ClipboardEntry entry;
  final Point2D offset;

  List<String> _pastedNodeIds = const [];
  List<String> _pastedRelationshipIds = const [];
  List<String> _pastedGroupIds = const [];
  List<String> _pastedAnnotationIds = const [];

  PasteCommand(this.entry, {this.offset = const Point2D(24, 24)});

  /// Ids of the objects this command actually created — set after
  /// [apply], read by the caller to select the pasted copies (selection
  /// itself stays outside the command system).
  List<String> get pastedNodeIds => _pastedNodeIds;

  List<String> get pastedAnnotationIds => _pastedAnnotationIds;

  @override
  String get description => 'Paste';

  @override
  EditingSession apply(EditingSession session) {
    final nodeIdMap = {for (final node in entry.nodes) node.id: EngineIds.generate('node')};
    final groupIdMap = {for (final group in entry.groups) group.id: EngineIds.generate('group')};

    var graph = session.graph;
    var layout = session.layout;

    for (final node in entry.nodes) {
      final newId = nodeIdMap[node.id]!;
      graph = graph.withNode(EngineeringNode(
        id: newId,
        category: node.category,
        displayName: node.displayName,
        symbolId: node.symbolId,
        metadata: node.metadata,
        properties: node.properties,
        ports: node.ports,
      ));
      final originalPosition = entry.positions[node.id];
      if (originalPosition != null) {
        layout = layout.withPosition(newId, originalPosition.translate(offset.dx, offset.dy));
      }
    }

    final pastedRelationshipIds = <String>[];
    for (final relationship in entry.relationships) {
      final newId = EngineIds.generate('rel');
      graph = graph.withRelationship(EngineeringRelationship(
        id: newId,
        relationshipType: relationship.relationshipType,
        sourceNode: nodeIdMap[relationship.sourceNode] ?? relationship.sourceNode,
        targetNode: nodeIdMap[relationship.targetNode] ?? relationship.targetNode,
        metadata: relationship.metadata,
      ));
      pastedRelationshipIds.add(newId);
    }

    for (final group in entry.groups) {
      final newId = groupIdMap[group.id]!;
      graph = graph.withGroup(EngineeringGroup(
        id: newId,
        kind: group.kind,
        displayName: group.displayName,
        memberNodeIds: group.memberNodeIds.map((id) => nodeIdMap[id] ?? id).toList(),
        parentGroupId: group.parentGroupId == null ? null : groupIdMap[group.parentGroupId],
        locked: group.locked,
        metadata: group.metadata,
      ));
    }

    final pastedAnnotationIds = <String>[];
    for (final annotation in entry.annotations) {
      final newId = EngineIds.generate('annotation');
      layout = layout.withAnnotation(DiagramAnnotation(
        id: newId,
        type: annotation.type,
        text: annotation.text,
        position: annotation.position.translate(offset.dx, offset.dy),
        rotation: annotation.rotation,
        // Only remap the anchor when the anchored node/relationship was
        // itself part of this same copy — otherwise the anchor is
        // dropped rather than silently pointing at an unrelated original
        // object outside the pasted selection.
        anchorNodeId: annotation.anchorNodeId == null
            ? null
            : nodeIdMap[annotation.anchorNodeId],
        metadata: annotation.metadata,
      ));
      pastedAnnotationIds.add(newId);
    }

    _pastedNodeIds = nodeIdMap.values.toList();
    _pastedRelationshipIds = pastedRelationshipIds;
    _pastedGroupIds = groupIdMap.values.toList();
    _pastedAnnotationIds = pastedAnnotationIds;

    return session.copyWith(graph: graph, layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    var graph = session.graph;
    var layout = session.layout;
    for (final id in _pastedRelationshipIds) {
      graph = graph.withoutRelationship(id);
    }
    for (final id in _pastedGroupIds) {
      graph = graph.withoutGroup(id);
    }
    for (final id in _pastedNodeIds) {
      graph = graph.withoutNode(id);
      layout = layout.withoutPosition(id);
    }
    for (final id in _pastedAnnotationIds) {
      layout = layout.withoutAnnotation(id);
    }
    return session.copyWith(graph: graph, layout: layout);
  }
}
