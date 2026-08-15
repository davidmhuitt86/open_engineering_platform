import '../../views/diagram/diagram_layer.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Deletes a Diagram Layout layer (WORK_PACKAGE_023, ENGINE-TASK-000101),
/// capturing both the layer definition and every entity assignment it
/// carried so revert restores the layer *and* which nodes/annotations
/// were on it — `DiagramLayoutState.withoutLayer` unassigns members as a
/// side effect, so both must be captured together to undo cleanly.
class DeleteLayerCommand implements EditingCommand {
  final String layerId;

  DiagramLayer? _removedLayer;
  Map<String, String> _removedAssignments = const {};

  DeleteLayerCommand(this.layerId);

  @override
  String get description => 'Delete layer';

  @override
  EditingSession apply(EditingSession session) {
    _removedLayer = session.layout.layerById(layerId);
    if (_removedLayer == null) return session;
    _removedAssignments = {
      for (final entityId in session.layout.entitiesOnLayer(layerId)) entityId: layerId,
    };
    return session.copyWith(layout: session.layout.withoutLayer(layerId));
  }

  @override
  EditingSession revert(EditingSession session) {
    final removed = _removedLayer;
    if (removed == null) return session;
    var layout = session.layout.withLayer(removed);
    for (final entry in _removedAssignments.entries) {
      layout = layout.withLayerAssignment(entry.key, entry.value);
    }
    return session.copyWith(layout: layout);
  }
}
