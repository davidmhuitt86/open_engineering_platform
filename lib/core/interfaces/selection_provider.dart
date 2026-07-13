import '../selection/selection_state.dart';

/// Runtime selection state (SDD-026 `SelectionEngine`). Selection state is
/// runtime-only and never persisted (SDD-027).
abstract class SelectionProvider {
  SelectionState get current;

  Stream<SelectionState> get changes;

  void selectNode(String nodeId);

  void selectRelationship(String relationshipId);

  void selectPort(String nodeId, String portId);

  void selectSymbol(String symbolId);

  void selectGroup(String groupId);

  void selectEvidence(String evidenceId);

  void clear();
}
