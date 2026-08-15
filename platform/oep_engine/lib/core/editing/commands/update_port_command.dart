import '../../graph/models/port.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Replaces one port on a node, matched by [Port.id] (ENGINE-TASK-000085:
/// Port property editing).
class UpdatePortCommand implements EditingCommand {
  final String nodeId;
  final Port updatedPort;

  Port? _previousPort;

  UpdatePortCommand(this.nodeId, this.updatedPort);

  @override
  String get description => 'Update port';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    final index = node.ports.indexWhere((p) => p.id == updatedPort.id);
    if (index == -1) return session;
    _previousPort = node.ports[index];
    final ports = [...node.ports];
    ports[index] = updatedPort;
    return session.copyWith(graph: session.graph.withNode(node.copyWith(ports: ports)));
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousPort;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    final index = node.ports.indexWhere((p) => p.id == updatedPort.id);
    if (index == -1) return session;
    final ports = [...node.ports];
    ports[index] = previous;
    return session.copyWith(graph: session.graph.withNode(node.copyWith(ports: ports)));
  }
}
