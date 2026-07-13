import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Moves a single node — layout-only (ENGINE-TASK-000081): "Movement
/// updates Engineering Graph coordinates only" is satisfied by routing
/// position through the same command/undo-redo system as graph edits,
/// via [EditingSession.layout], never by adding coordinate fields to
/// `EngineeringNode` (see docs/ARCHITECTURE_DECISIONS.md ADR-011).
class MoveNodeCommand implements EditingCommand {
  final String nodeId;
  final Point2D newPosition;

  Point2D? _previousPosition;
  bool _hadPosition = false;

  MoveNodeCommand(this.nodeId, this.newPosition);

  @override
  String get description => 'Move node';

  @override
  EditingSession apply(EditingSession session) {
    _previousPosition = session.layout.positionOf(nodeId);
    _hadPosition = _previousPosition != null;
    return session.copyWith(layout: session.layout.withPosition(nodeId, newPosition));
  }

  @override
  EditingSession revert(EditingSession session) {
    final layout = _hadPosition
        ? session.layout.withPosition(nodeId, _previousPosition!)
        : session.layout.withoutPosition(nodeId);
    return session.copyWith(layout: layout);
  }
}
