import '../../graph/models/engineering_node.dart';
import 'electrical_component_behavior.dart';

/// PRODUCT-READINESS-006 — component classification shared by [TraceEngine]
/// and [ElectricalSolver] (previously duplicated privately inside
/// `TraceEngine`; consolidated here so both consumers can never silently
/// diverge on what counts as a connector/splice/ground). Every check here
/// reads real, already-existing signals — [NodeCategory] (the canonical
/// Engine model) or the real V2 bridge's own already-established
/// `metadata['v2Category']`/`metadata['v2Connector']` convention
/// (`legacy_v2_state_adapter.dart`'s `_handleModuleCreated`) — never a
/// hardcoded component id (§33).
bool isConnectorNode(EngineeringNode node) =>
    node.category == NodeCategory.connector || node.metadata['v2Category'] == 'connector' || node.metadata['v2Connector'] == true;

/// The real Engine graph model has no first-class `NodeCategory.splice`
/// (a genuine representational gap between the generic Engine model and
/// the V2-specific concept — see `ELECTRICAL_TRACE_ENGINE.md`'s own
/// disclosure) — `metadata['v2Category'] == 'splice'` is the only real
/// signal that exists today.
bool isSpliceNode(EngineeringNode node) => node.metadata['v2Category'] == 'splice';

bool isGroundNode(EngineeringNode node) =>
    node.category == NodeCategory.ground || node.metadata['v2Category'] == 'ground';

/// The engine's own conservative built-in classification, consulted only
/// when a caller-supplied [ElectricalBehaviorResolver] has nothing to say
/// about a node — connector/splice get their proven reference behaviors;
/// everything else (including a ground node, handled separately by the
/// caller as a sink/reference rather than a behavior) gets `null`, meaning
/// "never fabricate internal bridging" (PRODUCT-READINESS-002's own
/// `AP-DEADEND-GENERALIZE-001` default, carried forward unchanged).
ElectricalComponentBehavior? defaultElectricalBehaviorFor(EngineeringNode node) {
  if (isConnectorNode(node)) return const PassThroughElectricalComponentBehavior();
  if (isSpliceNode(node)) return const AlwaysBridgeElectricalComponentBehavior();
  return null;
}
