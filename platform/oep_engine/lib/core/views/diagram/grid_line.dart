/// Which direction a [GridLine] runs.
enum GridAxis { horizontal, vertical }

/// One grid line, positioned in scene coordinates (WORK_PACKAGE_022,
/// ENGINE-TASK-000090). Pure data — the Demonstration Host paints it; the
/// engine only decides where lines go ("The Engine computes grid
/// geometry. The Demonstration Host renders it.").
class GridLine {
  final GridAxis axis;
  final double position;
  final bool isMajor;

  const GridLine({required this.axis, required this.position, required this.isMajor});
}
