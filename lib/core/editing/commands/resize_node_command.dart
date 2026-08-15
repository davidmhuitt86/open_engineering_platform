import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Resizes a single node (AP-DS-001A: "Editing Operations > Scale", and
/// Canvas resize-handle support). Layout-only mutation, same pattern as
/// [MoveNodesCommand]/[AlignNodesCommand] — a node's size lives in
/// `DiagramLayoutState.sizes`, never on `EngineeringNode` itself (SDD-024
/// Rule 5 / ADR-011: visual layout data never migrates onto the graph).
/// Undoable like every other editing operation.
///
/// [newPosition] is optional: dragging a top/left corner handle changes
/// both the node's size *and* its top-left position (the opposite edge
/// stays fixed), so this command can carry both as one atomic undoable
/// step rather than forcing the caller to execute a separate
/// `MoveNodesCommand` — the same "one command, one undo" reasoning
/// `MoveNodesCommand` uses for multi-node drags.
class ResizeNodeCommand implements EditingCommand {
  final String nodeId;
  final Size2D newSize;
  final Point2D? newPosition;

  Size2D? _previousSize;
  bool _hadSize = false;
  Point2D? _previousPosition;
  bool _hadPosition = false;

  ResizeNodeCommand(this.nodeId, this.newSize, {this.newPosition});

  @override
  String get description => 'Resize node';

  @override
  EditingSession apply(EditingSession session) {
    _previousSize = session.layout.sizeOf(nodeId);
    _hadSize = _previousSize != null;
    var layout = session.layout.withSize(nodeId, newSize);
    if (newPosition != null) {
      _previousPosition = session.layout.positionOf(nodeId);
      _hadPosition = _previousPosition != null;
      layout = layout.withPosition(nodeId, newPosition!);
    }
    return session.copyWith(layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    var layout = _hadSize
        ? session.layout.withSize(nodeId, _previousSize!)
        : session.layout.withoutSize(nodeId);
    if (newPosition != null) {
      layout = _hadPosition ? layout.withPosition(nodeId, _previousPosition!) : layout.withoutPosition(nodeId);
    }
    return session.copyWith(layout: layout);
  }
}
