import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Moves multiple nodes as one undoable step (ENGINE-TASK-000081: "Move
/// Multiple Nodes"). One command, not N individual [MoveNodeCommand]s, so
/// a single undo reverts the whole drag.
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
