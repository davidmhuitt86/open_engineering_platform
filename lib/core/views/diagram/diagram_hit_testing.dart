import 'diagram_scene.dart';
import 'rect2d.dart';

/// Box-selection hit-testing (WORK_PACKAGE_021, ENGINE-TASK-000080).
///
/// Lives in the View layer, not `SelectionService` — selection never
/// needs to know about screen coordinates; only the thing that already
/// has them ([DiagramScene]) does.
class DiagramHitTesting {
  DiagramHitTesting._();

  /// Node ids whose bounds intersect [rect]. "Selection Priority"
  /// (ENGINE-TASK-000080) is resolved by the caller choosing which of
  /// nodes/relationships/groups to act on when several are returned —
  /// this helper only reports geometric membership.
  static Set<String> nodesInRect(DiagramScene scene, Rect2D rect) {
    final result = <String>{};
    for (final node in scene.nodes) {
      final nodeRect = Rect2D(
        left: node.position.dx,
        top: node.position.dy,
        right: node.position.dx + node.width,
        bottom: node.position.dy + node.height,
      );
      if (rect.intersects(nodeRect)) {
        result.add(node.nodeId);
      }
    }
    return result;
  }
}
