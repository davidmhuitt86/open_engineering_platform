import '../../graph/models/engineering_node.dart';
import '../../shared/ids.dart';
import '../../views/diagram/diagram_layout.dart';
import '../editing_command.dart';
import '../editing_session.dart';
import '../placement_math.dart';

/// Duplicates [nodeIds] into a `countX` x `countY` grid as one undoable
/// step (WORK_PACKAGE_023, ENGINE-TASK-000102: "Array Placement").
///
/// One grid-offset copy of every selected node is created per cell of
/// `PlacementMath.arrayOffsets` (which already excludes the `(0, 0)`
/// cell — the originals stay where they are). Node duplication follows
/// the same shape `DuplicateNodeCommand` uses; relationships between
/// duplicated nodes are intentionally not replicated (array placement is
/// a component-repetition tool, not a subgraph-clone tool — see
/// `DuplicateSelectionCommand`/`PasteCommand` for the latter).
class ArrayPlaceCommand implements EditingCommand {
  final Set<String> nodeIds;
  final int countX;
  final int countY;
  final double spacingX;
  final double spacingY;

  List<String> _createdNodeIds = const [];

  ArrayPlaceCommand(
    this.nodeIds, {
    this.countX = 1,
    this.countY = 1,
    this.spacingX = 150,
    this.spacingY = 150,
  });

  @override
  String get description => 'Array place';

  @override
  EditingSession apply(EditingSession session) {
    final offsets = PlacementMath.arrayOffsets(
      countX: countX,
      countY: countY,
      spacingX: spacingX,
      spacingY: spacingY,
    );
    if (offsets.isEmpty) return session;

    var graph = session.graph;
    var layout = session.layout;
    final createdIds = <String>[];

    for (final sourceId in nodeIds) {
      final source = graph.nodes[sourceId];
      if (source == null) continue;
      // Resolves the effective position (tracked, or the same
      // auto-layout fallback DiagramView renders with) so array-placing
      // a never-moved node still works.
      final sourcePosition = DiagramLayout.resolvePosition(session.graph, session.layout, sourceId);
      for (final offset in offsets) {
        final newId = EngineIds.generate('node');
        graph = graph.withNode(EngineeringNode(
          id: newId,
          category: source.category,
          displayName: source.displayName,
          symbolId: source.symbolId,
          metadata: source.metadata,
          properties: source.properties,
          ports: source.ports,
        ));
        layout = layout.withPosition(newId, sourcePosition.translate(offset.dx, offset.dy));
        createdIds.add(newId);
      }
    }

    _createdNodeIds = createdIds;
    return session.copyWith(graph: graph, layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    var graph = session.graph;
    var layout = session.layout;
    for (final id in _createdNodeIds) {
      graph = graph.withoutNode(id);
      layout = layout.withoutPosition(id);
    }
    return session.copyWith(graph: graph, layout: layout);
  }
}
