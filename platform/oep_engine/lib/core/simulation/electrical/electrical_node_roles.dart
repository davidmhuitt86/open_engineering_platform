import '../../graph/models/engineering_node.dart';
import '../../graph/models/port.dart';
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

/// Common ground/negative-terminal name spellings this engine has directly
/// observed in real diagrams (`platform/oep_studio/samples/diagram7.json`'s
/// own real Battery: terminal names `+`/`−`, confirmed by direct
/// inspection) — shared by [electrical_solver.dart]'s own
/// `defaultIsReferenceTerminal` and [preciseIsReferenceTerminal] below.
const referenceTerminalNamePatterns = {'-', '−', 'gnd', 'ground', 'neg', 'negative'};

bool nameMatchesReferenceTerminal(EngineeringNode node, String? portId) {
  if (portId == null) return false;
  final port = node.ports.where((p) => p.id == portId).cast<Port?>().firstWhere((_) => true, orElse: () => null);
  final name = port?.name.trim().toLowerCase();
  return name != null && referenceTerminalNamePatterns.contains(name);
}

/// A node this engine can recognize, from real, already-established
/// signals, as a modeled power SOURCE component — the same three signals
/// `defaultIsSourceTerminal` (`electrical_solver.dart`) already checks
/// (`behavior.generatesPower`, `metadata['v2Category'] == 'power'`,
/// `metadata['v2Kind'] == 'battery'`), factored out here so
/// [preciseIsReferenceTerminal] can reuse the exact same recognition
/// without duplicating it.
bool isRecognizedSourceComponent(EngineeringNode node, ElectricalComponentBehavior? behavior) =>
    behavior?.generatesPower == true || node.metadata['v2Category'] == 'power' || node.metadata['v2Kind'] == 'battery';

/// PRODUCT-READINESS-006B/PRODUCT-READINESS-008 §16 — the PRECISE
/// reference-terminal resolver PRODUCT-READINESS-006B validated against
/// the real, full-harness `diagram7.json` (previously only wired into
/// that phase's own TRX300 test, per its own disclosed "the DEFAULT
/// name-based resolver over-fires at full-harness scale" finding — see
/// `ELECTRICAL_SOLUTION_ENGINE.md`'s "A real finding from the real
/// diagram7.json validation"). PRODUCT-READINESS-008 §16 requires this
/// now be available on the PRODUCTION path, not test-only.
///
/// Unconditionally true for a genuine [isGroundNode] (a real
/// Ground-category node, or `metadata['v2Category'] == 'ground'` — the
/// real TRX300 `chassis-ground` node is exactly this). Otherwise, a
/// name-matched terminal (`referenceTerminalNamePatterns`) is treated as
/// a reference ONLY when it belongs to a [isRecognizedSourceComponent] —
/// i.e. "a modeled SOURCE's own declared return/negative pin is a
/// reference" (needed for battery isolation — a battery's own `-` post
/// must read 0V even with no separate chassis-ground node in scope),
/// while an unrelated real component that merely happens to have a pin
/// NAMED something like `-`/`neg` (PRODUCT-READINESS-006B's own real
/// finding: a voltage regulator/rectifier, an ignition coil, a DC
/// accessory jack, ... in the real, full `diagram7.json`) is no longer
/// incorrectly promoted to a global 0V boundary merely by its pin's name.
/// This is strictly narrower than the plain name-based default
/// (`defaultIsReferenceTerminal`) in exactly the one case that was found
/// to be wrong, and identical to it everywhere else — a real regression
/// risk was checked by running every existing PRODUCT-READINESS-004/005/
/// 006/006B fixture against this resolver (they all already model their
/// own source components via `v2Category: 'power'`, so no existing test
/// value changes).
bool preciseIsReferenceTerminal(EngineeringNode node, String? portId, {ElectricalComponentBehavior? behavior}) {
  if (isGroundNode(node)) return true;
  return nameMatchesReferenceTerminal(node, portId) && isRecognizedSourceComponent(node, behavior);
}
