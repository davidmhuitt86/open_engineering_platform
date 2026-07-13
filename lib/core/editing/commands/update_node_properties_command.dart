import '../editing_command.dart';
import '../editing_session.dart';

/// Merges a property patch into a node's `properties` map
/// (ENGINE-TASK-000079/000085). `null` values in [patch] remove the key.
class UpdateNodePropertiesCommand implements EditingCommand {
  final String nodeId;
  final Map<String, Object?> patch;

  Map<String, Object?>? _previousProperties;

  UpdateNodePropertiesCommand(this.nodeId, this.patch);

  @override
  String get description => 'Update properties';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _previousProperties = node.properties;
    final merged = Map<String, Object?>.from(node.properties);
    patch.forEach((key, value) {
      if (value == null) {
        merged.remove(key);
      } else {
        merged[key] = value;
      }
    });
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(properties: merged)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousProperties;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(properties: previous)),
    );
  }
}
