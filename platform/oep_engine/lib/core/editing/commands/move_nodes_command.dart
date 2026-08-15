import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Moves one or more nodes as a single undoable step (ENGINE-TASK-000081:
/// "Move Node(s)"). Used for both single- and multi-node drags — a
/// dedicated single-node `MoveNodeCommand` existed early in
/// WORK_PACKAGE_021 but was removed during AP-DS-001A: it had no
/// production call sites (`MoveNodesCommand` with a one-entry map is
/// exactly equivalent and is what every caller — the Diagram Studio
/// canvas drag handler included — already used), so keeping both was
/// pure duplication. One command, not N single-node commands, so a
/// single undo reverts the whole drag regardless of selection size.
class MoveNodesCommand implements EditingCommand {
  final Map<String, Point2D> newPositions;

  Map<String, Point2D?> _previousPositions = const {};

  MoveNodesCommand(this.newPositions);

  @override
  String get description => 'Move ${newPositions.length} nodes';

  @override
  EditingSession apply(EditingSession session) {
    _previousPositions = {
      for (final id in newPositions.keys) id: session.layout.positionOf(id),
    };
    return session.copyWith(layout: session.layout.withPositions(newPositions));
  }

  @override
  EditingSession revert(EditingSession session) {
    var layout = session.layout;
    for (final entry in _previousPositions.entries) {
      layout = entry.value == null
          ? layout.withoutPosition(entry.key)
          : layout.withPosition(entry.key, entry.value!);
    }
    return session.copyWith(layout: layout);
  }
}
