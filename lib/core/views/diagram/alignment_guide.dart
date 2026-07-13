import 'grid_line.dart';

/// One smart alignment guide — a line to render, hinting "this edge/center
/// lines up with another element" (WORK_PACKAGE_022, ENGINE-TASK-000091).
/// Runtime only: computed while dragging, shown, then discarded. Never a
/// command, never persisted.
class AlignmentGuide {
  final GridAxis axis;
  final double position;

  const AlignmentGuide({required this.axis, required this.position});
}
