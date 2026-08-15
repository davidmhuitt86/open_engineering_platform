import '../../views/diagram/diagram_annotation.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Deletes a Diagram Layout annotation (WORK_PACKAGE_023,
/// ENGINE-TASK-000100), capturing it for revert.
class DeleteAnnotationCommand implements EditingCommand {
  final String annotationId;

  DiagramAnnotation? _removed;

  DeleteAnnotationCommand(this.annotationId);

  @override
  String get description => 'Delete annotation';

  @override
  EditingSession apply(EditingSession session) {
    _removed = session.layout.annotationOf(annotationId);
    if (_removed == null) return session;
    return session.copyWith(layout: session.layout.withoutAnnotation(annotationId));
  }

  @override
  EditingSession revert(EditingSession session) {
    final removed = _removed;
    if (removed == null) return session;
    return session.copyWith(layout: session.layout.withAnnotation(removed));
  }
}
