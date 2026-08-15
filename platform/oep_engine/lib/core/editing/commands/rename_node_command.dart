import '../editing_command.dart';
import '../editing_session.dart';

/// Renames a node's `displayName` (ENGINE-TASK-000079).
class RenameNodeCommand implements EditingCommand {
  final String nodeId;
  final String newDisplayName;

  String? _previousDisplayName;

  RenameNodeCommand(this.nodeId, this.newDisplayName);

  @override
  String get description => 'Rename node';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _previousDisplayName = node.displayName;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(displayName: newDisplayName)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousDisplayName;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(displayName: previous)),
    );
  }
}
