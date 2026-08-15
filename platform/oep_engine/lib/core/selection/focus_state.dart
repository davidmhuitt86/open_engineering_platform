/// A single inspection target that isn't part of the multi-select
/// [GraphSelection] — ports, symbols, and evidence are things the
/// Property Inspector can show, but never things Delete/Move/Clipboard
/// operate on, so they never need multi-select semantics.
enum FocusKind { none, port, symbol, evidence }

/// Runtime-only (SDD-027), outside the undo/redo command system, exactly
/// like [GraphSelection].
class FocusState {
  final FocusKind kind;
  final String? id;

  /// Set only when [kind] is [FocusKind.port] — the owning node id.
  final String? ownerId;

  const FocusState._(this.kind, this.id, this.ownerId);

  const FocusState.none() : this._(FocusKind.none, null, null);

  factory FocusState.port(String nodeId, String portId) =>
      FocusState._(FocusKind.port, portId, nodeId);

  factory FocusState.symbol(String id) => FocusState._(FocusKind.symbol, id, null);

  factory FocusState.evidence(String id) => FocusState._(FocusKind.evidence, id, null);

  bool get isEmpty => kind == FocusKind.none;

  @override
  bool operator ==(Object other) =>
      other is FocusState &&
      other.kind == kind &&
      other.id == id &&
      other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(kind, id, ownerId);
}
