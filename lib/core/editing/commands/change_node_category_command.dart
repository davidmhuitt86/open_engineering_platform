import '../../graph/models/engineering_node.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Changes a node's [NodeCategory] (ENGINE-TASK-000079).
class ChangeNodeCategoryCommand implements EditingCommand {
  final String nodeId;
  final NodeCategory newCategory;

  NodeCategory? _previousCategory;

  ChangeNodeCategoryCommand(this.nodeId, this.newCategory);

  @override
  String get description => 'Change category';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _previousCategory = node.category;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(category: newCategory)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousCategory;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(category: previous)),
    );
  }
}
