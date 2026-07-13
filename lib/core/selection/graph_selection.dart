/// Multi-select graph selection (WORK_PACKAGE_021, ENGINE-TASK-000080):
/// the set of nodes/relationships/groups currently selected for editing.
///
/// Deliberately separate from [FocusState] (port/symbol/evidence
/// inspection) — those are single-item, editing-irrelevant "what is the
/// Property Inspector showing" concerns; `GraphSelection` is "what would
/// Delete/Move/Clipboard operate on." Runtime-only (SDD-027: selection is
/// Runtime Metadata, never persisted) and outside the undo/redo command
/// system (ENGINE-TASK-000084's history list never includes selection
/// changes).
class GraphSelection {
  final Set<String> nodeIds;
  final Set<String> relationshipIds;
  final Set<String> groupIds;

  const GraphSelection({
    this.nodeIds = const {},
    this.relationshipIds = const {},
    this.groupIds = const {},
  });

  static const GraphSelection empty = GraphSelection();

  bool get isEmpty =>
      nodeIds.isEmpty && relationshipIds.isEmpty && groupIds.isEmpty;

  int get length => nodeIds.length + relationshipIds.length + groupIds.length;

  bool containsNode(String id) => nodeIds.contains(id);
  bool containsRelationship(String id) => relationshipIds.contains(id);
  bool containsGroup(String id) => groupIds.contains(id);

  @override
  bool operator ==(Object other) {
    return other is GraphSelection &&
        _setEquals(other.nodeIds, nodeIds) &&
        _setEquals(other.relationshipIds, relationshipIds) &&
        _setEquals(other.groupIds, groupIds);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(nodeIds),
        Object.hashAllUnordered(relationshipIds),
        Object.hashAllUnordered(groupIds),
      );

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
