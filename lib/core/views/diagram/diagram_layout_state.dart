import 'diagram_geometry.dart';

/// Per-node visual position, tracked as a sibling of the Engineering Graph
/// — never as fields on it.
///
/// SDD-024 Architecture Rule 5: "Layout is not Engineering Knowledge... The
/// graph contains no visual layout information." WORK_PACKAGE_021's Move
/// System is satisfied by routing position through the same
/// command/undo-redo system as graph edits (bundled into
/// `EditingSession { graph, layout }`), not by adding coordinate fields to
/// `EngineeringNode`. See docs/ARCHITECTURE_DECISIONS.md ADR-011.
class DiagramLayoutState {
  final Map<String, Point2D> positions;

  const DiagramLayoutState({this.positions = const {}});

  static const DiagramLayoutState empty = DiagramLayoutState();

  Point2D? positionOf(String nodeId) => positions[nodeId];

  DiagramLayoutState withPosition(String nodeId, Point2D position) {
    return DiagramLayoutState(positions: {...positions, nodeId: position});
  }

  DiagramLayoutState withPositions(Map<String, Point2D> updates) {
    return DiagramLayoutState(positions: {...positions, ...updates});
  }

  DiagramLayoutState withoutPosition(String nodeId) {
    final next = {...positions}..remove(nodeId);
    return DiagramLayoutState(positions: next);
  }
}
