import '../../graph/models/engineering_node.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Creates a node at an optional initial layout position (ENGINE-TASK-000079).
class CreateNodeCommand implements EditingCommand {
  final EngineeringNode node;
  final Point2D? position;

  CreateNodeCommand(this.node, {this.position});

  @override
  String get description => 'Create ${node.displayName}';

  @override
  EditingSession apply(EditingSession session) {
    final graph = session.graph.withNode(node);
    final layout =
        position == null ? session.layout : session.layout.withPosition(node.id, position!);
    return session.copyWith(graph: graph, layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(
      graph: session.graph.withoutNode(node.id),
      layout: session.layout.withoutPosition(node.id),
    );
  }
}
