import '../../views/diagram/diagram_annotation.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Creates a Diagram Layout annotation (WORK_PACKAGE_023,
/// ENGINE-TASK-000100) — a text label, leader note, callout, wire/
/// component label, free text, or revision note. Layout-only: this never
/// touches the Engineering Graph.
class CreateAnnotationCommand implements EditingCommand {
  final DiagramAnnotation annotation;

  CreateAnnotationCommand(this.annotation);

  @override
  String get description => 'Create annotation';

  @override
  EditingSession apply(EditingSession session) {
    return session.copyWith(layout: session.layout.withAnnotation(annotation));
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(layout: session.layout.withoutAnnotation(annotation.id));
  }
}
