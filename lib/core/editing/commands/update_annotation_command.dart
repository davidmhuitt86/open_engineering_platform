import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Moves, rotates, and/or edits the text of an annotation in one patch
/// (WORK_PACKAGE_023, ENGINE-TASK-000100: "Move", "Rotate", "Edit") — the
/// same patch-style shape `UpdateNodePropertiesCommand` already uses.
/// Unset fields leave that property untouched.
class UpdateAnnotationCommand implements EditingCommand {
  final String annotationId;
  final Point2D? position;
  final double? rotation;
  final String? text;

  Point2D? _previousPosition;
  double? _previousRotation;
  String? _previousText;

  UpdateAnnotationCommand(this.annotationId, {this.position, this.rotation, this.text});

  @override
  String get description => 'Update annotation';

  @override
  EditingSession apply(EditingSession session) {
    final annotation = session.layout.annotationOf(annotationId);
    if (annotation == null) return session;
    _previousPosition = annotation.position;
    _previousRotation = annotation.rotation;
    _previousText = annotation.text;
    final updated = annotation.copyWith(
      position: position,
      rotation: rotation,
      text: text,
    );
    return session.copyWith(layout: session.layout.withAnnotation(updated));
  }

  @override
  EditingSession revert(EditingSession session) {
    final annotation = session.layout.annotationOf(annotationId);
    if (annotation == null || _previousPosition == null) return session;
    final restored = annotation.copyWith(
      position: _previousPosition,
      rotation: _previousRotation,
      text: _previousText,
    );
    return session.copyWith(layout: session.layout.withAnnotation(restored));
  }
}
