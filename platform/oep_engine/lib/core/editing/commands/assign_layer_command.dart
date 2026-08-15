import '../editing_command.dart';
import '../editing_session.dart';

/// Assigns (or unassigns, when [layerId] is `null`) a node or annotation
/// to a layer (WORK_PACKAGE_023, ENGINE-TASK-000101: "Layer Assignment").
class AssignLayerCommand implements EditingCommand {
  final String entityId;
  final String? layerId;

  String? _previousLayerId;

  AssignLayerCommand(this.entityId, this.layerId);

  @override
  String get description => layerId == null ? 'Unassign layer' : 'Assign layer';

  @override
  EditingSession apply(EditingSession session) {
    _previousLayerId = session.layout.layerOf(entityId);
    return session.copyWith(
      layout: session.layout.withLayerAssignment(entityId, layerId),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(
      layout: session.layout.withLayerAssignment(entityId, _previousLayerId),
    );
  }
}
