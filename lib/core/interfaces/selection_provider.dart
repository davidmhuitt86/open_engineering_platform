import '../graph/models/engineering_graph.dart';
import '../selection/focus_state.dart';
import '../selection/graph_selection.dart';

/// Runtime selection state (SDD-026 `SelectionEngine`), extended in
/// WORK_PACKAGE_021 (ENGINE-TASK-000080) to a full multi-select model.
/// Selection state is runtime-only and never persisted (SDD-027), and
/// stays outside the undo/redo command system.
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

  /// Replaces (or extends, if [additive]) the selection with an explicit
  /// set — used by box selection.
  void selectMany({
    Set<String> nodeIds = const {},
    Set<String> relationshipIds = const {},
    Set<String> groupIds = const {},
    bool additive = false,
  });

  void toggleNode(String nodeId);
  void toggleRelationship(String relationshipId);
  void toggleGroup(String groupId);

  void selectAll(EngineeringGraph graph);
  void deselectAll();

  void focusPort(String nodeId, String portId);
  void focusSymbol(String symbolId);
  void focusEvidence(String evidenceId);
  void clearFocus();
}
