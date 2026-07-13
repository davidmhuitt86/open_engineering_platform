import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Which axis to evenly space along (WORK_PACKAGE_022, ENGINE-TASK-000091).
enum DistributionAxis { horizontal, vertical }

/// Evenly spaces three or more nodes along one axis, keeping the first
/// and last (by current position along that axis) fixed and interpolating
/// the rest between them. Layout-only, undoable.
class DistributeNodesCommand implements EditingCommand {
  final Set<String> nodeIds;
  final DistributionAxis axis;

  Map<String, Point2D> _previousPositions = const {};

  DistributeNodesCommand(this.nodeIds, this.axis);

  @override
  String get description => 'Distribute ${axis.name}';

  @override
  EditingSession apply(EditingSession session) {
    final positions = <String, Point2D>{
      for (final id in nodeIds)
        if (session.layout.positionOf(id) != null) id: session.layout.positionOf(id)!,
    };
    if (positions.length < 3) return session;

    final sortedIds = positions.keys.toList()
      ..sort((a, b) {
        final pa = positions[a]!;
        final pb = positions[b]!;
        return axis == DistributionAxis.horizontal
            ? pa.dx.compareTo(pb.dx)
            : pa.dy.compareTo(pb.dy);
      });

    _previousPositions = Map.of(positions);

    final first = positions[sortedIds.first]!;
    final last = positions[sortedIds.last]!;
    final count = sortedIds.length;
    final newPositions = <String, Point2D>{};
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final id = sortedIds[i];
      final original = positions[id]!;
      newPositions[id] = axis == DistributionAxis.horizontal
          ? Point2D(first.dx + (last.dx - first.dx) * t, original.dy)
          : Point2D(original.dx, first.dy + (last.dy - first.dy) * t);
    }
    return session.copyWith(layout: session.layout.withPositions(newPositions));
  }

  @override
  EditingSession revert(EditingSession session) {
    if (_previousPositions.isEmpty) return session;
    return session.copyWith(layout: session.layout.withPositions(_previousPositions));
  }
}
