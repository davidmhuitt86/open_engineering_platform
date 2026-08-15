/// A reference to a specific port on a specific node — View-layer only
/// (WORK_PACKAGE_022, ENGINE-TASK-000092).
///
/// Deliberately **not** a field on `EngineeringRelationship` — SDD-027
/// stays as-is; relationships still reference nodes, not named ports (see
/// docs/PORT_INTERACTION.md and the routing engine's existing
/// nearest-port scoping note, docs/ROUTING_ENGINE.md). `PortReference` is
/// only ever held transiently — by `ViewState.hoveredPort` (hover) or
/// `FocusState.port` (selection, unchanged from WP021) — never persisted.
class PortReference {
  final String nodeId;
  final String portId;

  const PortReference({required this.nodeId, required this.portId});

  @override
  bool operator ==(Object other) =>
      other is PortReference && other.nodeId == nodeId && other.portId == portId;

  @override
  int get hashCode => Object.hash(nodeId, portId);

  @override
  String toString() => 'PortReference($nodeId.$portId)';
}
