import '../editing/editing_session.dart';
import '../selection/graph_selection.dart';
import 'clipboard_entry.dart';

/// Builds a [ClipboardEntry] from the current selection (Copy/Cut/
/// Duplicate — ENGINE-TASK-000083). "Preserve relationships where
/// possible": a relationship is included only when both its endpoints are
/// in the selected node set, so pasting never produces a dangling
/// reference.
class ClipboardExtraction {
  ClipboardExtraction._();

  static ClipboardEntry extract(EditingSession session, GraphSelection selection) {
    final selectedNodes = [
      for (final id in selection.nodeIds)
        if (session.graph.nodes[id] != null) session.graph.nodes[id]!,
    ];
    final relationships = [
      for (final relationship in session.graph.relationships.values)
        if (selection.nodeIds.contains(relationship.sourceNode) &&
            selection.nodeIds.contains(relationship.targetNode))
          relationship,
    ];
    final groups = [
      for (final id in selection.groupIds)
        if (session.graph.groups[id] != null) session.graph.groups[id]!,
    ];
    final positions = {
      for (final node in selectedNodes)
        if (session.layout.positionOf(node.id) != null)
          node.id: session.layout.positionOf(node.id)!,
    };
    return ClipboardEntry(
      nodes: selectedNodes,
      relationships: relationships,
      groups: groups,
      positions: positions,
    );
  }
}
