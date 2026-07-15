import '../graph/models/engineering_graph.dart';
import '../graph/models/engineering_node.dart';
import '../selection/focus_state.dart';
import '../selection/graph_selection.dart';
import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/diagram_layout_state.dart';
import '../views/diagram/diagram_scene.dart';
import '../views/diagram/rect2d.dart';

/// Runtime selection state (SDD-026 `SelectionEngine`), extended in
/// WORK_PACKAGE_021 (ENGINE-TASK-000080) to a full multi-select model, and
/// again in WORK_PACKAGE_023 (ENGINE-TASK-000098) with query-driven
/// selection modes. Selection state is runtime-only and never persisted
/// (SDD-027), and stays outside the undo/redo command system.
abstract class SelectionProvider {
  GraphSelection get current;
  Stream<GraphSelection> get changes;

  FocusState get focus;
  Stream<FocusState> get focusChanges;

  /// Selects a single node. [additive]: add to the current selection
  /// instead of replacing it (shift/ctrl-click).
  void selectNode(String nodeId, {bool additive = false});

  void selectRelationship(String relationshipId, {bool additive = false});

  void selectGroup(String groupId, {bool additive = false});

  void selectAnnotation(String annotationId, {bool additive = false});

  /// Replaces (or extends, if [additive]) the selection with an explicit
  /// set — used by box selection.
  void selectMany({
    Set<String> nodeIds = const {},
    Set<String> relationshipIds = const {},
    Set<String> groupIds = const {},
    Set<String> annotationIds = const {},
    bool additive = false,
  });

  void toggleNode(String nodeId);
  void toggleRelationship(String relationshipId);
  void toggleGroup(String groupId);
  void toggleAnnotation(String annotationId);

  /// Selects every node/relationship/group in [graph], plus every
  /// annotation in [layout] when it's provided (optional so existing
  /// callers that only have a graph handy keep working unchanged).
  void selectAll(EngineeringGraph graph, {DiagramLayoutState? layout});
  void deselectAll();

  /// Replaces the selection with every node/relationship/group/annotation
  /// currently *not* selected (WORK_PACKAGE_023, ENGINE-TASK-000098:
  /// "Invert Selection").
  void invertSelection(EngineeringGraph graph, DiagramLayoutState layout);

  /// Lasso Selection: nodes whose center falls inside [polygon].
  void selectByLasso(DiagramScene scene, List<Point2D> polygon, {bool additive = false});

  /// Crossing (default) or Window ([crossing] = false, full containment)
  /// rectangle selection.
  void selectByRect(DiagramScene scene, Rect2D rect,
      {bool crossing = true, bool additive = false});

  /// Connected Component Selection: every node reachable from [seedNodeId]
  /// treating relationships as undirected edges.
  void selectConnectedComponent(EngineeringGraph graph, String seedNodeId,
      {bool additive = false});

  /// Select Similar: every node sharing [node]'s category (and symbolId,
  /// when it has one).
  void selectSimilar(EngineeringGraph graph, EngineeringNode node, {bool additive = false});

  void selectByCategory(EngineeringGraph graph, NodeCategory category,
      {bool additive = false});

  /// Select by Layer: every node/annotation assigned to [layerId].
  void selectByLayer(DiagramLayoutState layout, String layerId, {bool additive = false});

  void focusPort(String nodeId, String portId);
  void focusSymbol(String symbolId);
  void focusEvidence(String evidenceId);
  void clearFocus();
}
