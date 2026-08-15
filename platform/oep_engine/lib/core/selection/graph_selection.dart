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
///
/// [annotationIds] (WORK_PACKAGE_023, ENGINE-TASK-000100) extends this to
/// Diagram Layout's annotations, so they can be selected, copied, and
/// pasted through the same selection/clipboard machinery as nodes —
/// still runtime-only, still outside undo/redo.
class GraphSelection {
  final Set<String> nodeIds;
  final Set<String> relationshipIds;
  final Set<String> groupIds;
  final Set<String> annotationIds;

  const GraphSelection({
    this.nodeIds = const {},
    this.relationshipIds = const {},
    this.groupIds = const {},
    this.annotationIds = const {},
  });

  static const GraphSelection empty = GraphSelection();

  bool get isEmpty =>
      nodeIds.isEmpty && relationshipIds.isEmpty && groupIds.isEmpty && annotationIds.isEmpty;

  int get length =>
      nodeIds.length + relationshipIds.length + groupIds.length + annotationIds.length;

  bool containsNode(String id) => nodeIds.contains(id);
  bool containsRelationship(String id) => relationshipIds.contains(id);
  bool containsGroup(String id) => groupIds.contains(id);
  bool containsAnnotation(String id) => annotationIds.contains(id);

  @override
  bool operator ==(Object other) {
    return other is GraphSelection &&
        _setEquals(other.nodeIds, nodeIds) &&
        _setEquals(other.relationshipIds, relationshipIds) &&
        _setEquals(other.groupIds, groupIds) &&
        _setEquals(other.annotationIds, annotationIds);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(nodeIds),
        Object.hashAllUnordered(relationshipIds),
        Object.hashAllUnordered(groupIds),
        Object.hashAllUnordered(annotationIds),
      );

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
