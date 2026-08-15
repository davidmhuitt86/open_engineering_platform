import '../../views/diagram/diagram_layer.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Creates a Diagram Layout layer (WORK_PACKAGE_023, ENGINE-TASK-000101).
/// Layout-only — the Engineering Graph remains layer-independent.
class CreateLayerCommand implements EditingCommand {
  final DiagramLayer layer;

  CreateLayerCommand(this.layer);

  @override
  String get description => 'Create layer';

  @override
  EditingSession apply(EditingSession session) {
    return session.copyWith(layout: session.layout.withLayer(layer));
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(layout: session.layout.withoutLayer(layer.id));
  }
}
