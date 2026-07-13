/// What kind of Engineering object is currently selected (SDD-026:
/// "Current Node, Current Relationship, Current Circuit, Current Symbol,
/// Current Diagram").
enum SelectionKind {
  none,
  node,
  relationship,
  port,
  symbol,
  group,
  evidence,
}

/// Runtime-only selection snapshot (SDD-027: selection is Runtime Metadata,
/// never persisted).
class SelectionState {
  final SelectionKind kind;
  final String? id;

  /// Set only when [kind] is [SelectionKind.port] — the owning node id.
  final String? ownerId;

  const SelectionState._(this.kind, this.id, this.ownerId);

  const SelectionState.none() : this._(SelectionKind.none, null, null);

  factory SelectionState.node(String id) =>
      SelectionState._(SelectionKind.node, id, null);

  factory SelectionState.relationship(String id) =>
      SelectionState._(SelectionKind.relationship, id, null);

  factory SelectionState.port(String nodeId, String portId) =>
      SelectionState._(SelectionKind.port, portId, nodeId);

  factory SelectionState.symbol(String id) =>
      SelectionState._(SelectionKind.symbol, id, null);

  factory SelectionState.group(String id) =>
      SelectionState._(SelectionKind.group, id, null);

  factory SelectionState.evidence(String id) =>
      SelectionState._(SelectionKind.evidence, id, null);

  bool get isEmpty => kind == SelectionKind.none;

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.kind == kind &&
      other.id == id &&
      other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(kind, id, ownerId);
}
