/// PRODUCT-READINESS-007 §8/§9 — the V2 WebView measurement bridge,
/// upgraded from "an adapter around the Legacy V2 JS solver" to "an
/// adapter around the native Engine, given the live V2-synced graph."
///
/// The Legacy V2 JS solver (`LiveSim.readWireMeasurement`, reached via
/// `LegacyV2StateAdapter.channel.queryLiveMeasurement`) remains completely
/// UNTOUCHED and remains the WebView's own real-time visual/rendering
/// authority (§8: "Do not remove the existing Legacy V2 solver where it
/// is required to maintain the WebView's live simulation behavior";
/// `legacy_v2_live_measurement_bridge_test.dart` continues to prove that
/// path works exactly as before). This file adds a SEPARATE, additive
/// capability: resolving a V2-selected wire's own two electrically
/// meaningful endpoints into the Engine's terminal model
/// ([ProbePoint]/[ElectricalTerminalPair]) and answering the SAME
/// question through the authoritative native
/// [ElectricalSolver]/[ElectricalMeasurementQuery] chain instead — never
/// implementing electrical equations itself (§8's own explicit
/// prohibition): every number below comes from the Engine.
///
/// **Disclosed limitation (§8's own "STOP and report" spirit, applied
/// narrowly rather than blocking the whole phase)**: V2's own live
/// switch/key state (`selK`) is not bridged into Dart at all — confirmed
/// by [LegacyV2StateAdapter]'s own doc comment on `_handleMeasurementRequested`
/// ("there is nothing to additionally bridge" for the EXISTING
/// LiveSim-backed path, which reads V2's switch state directly inside
/// the WebView). This NEW, native-Engine-backed path has no equivalent
/// access — it solves against [ElectricalOperatingContext.none] unless a
/// caller supplies a real one, meaning a switch-gated circuit's OFF state
/// cannot yet be distinguished from ON through this specific path. This
/// is a genuine, disclosed gap (not silently worked around) — the
/// EXISTING LiveSim-backed `queryLiveMeasurement`/`onLiveMeasurement`
/// path remains the one that correctly reflects live V2 switch state
/// today.
library;

import 'package:engineering_engine/engineering_engine.dart';

import 'legacy_v2_state_adapter.dart';

/// Normalizes a real V2 pin reference to the bare pin-index string the
/// Engine's terminal model uses — the SAME, already-established
/// convention `electrical_solver_trx300_test.dart` uses against the real
/// `diagram7.json` (§8: real V2-authored relationship metadata writes a
/// connector pin as `"<pin>_IN"`/`"<pin>_OUT"`, and a splice endpoint as
/// the literal sentinel `"SPLICE"`, neither of which is the bare terminal
/// id `backfillV2TerminalPorts`/`Port.id` actually uses). Idempotent: a
/// reference that is already bare passes through unchanged.
String? normalizeV2PortRef(String? port) {
  if (port == null || port.isEmpty) return null;
  if (port == 'SPLICE') return '1';
  return port.replaceFirst(RegExp(r'_(IN|OUT)$'), '');
}

/// One endpoint of [relationship] (the `EngineeringRelationship` a
/// bridged V2 wire is stored as — see `LegacyV2StateAdapter._handleWireCreated`,
/// which already stashes `sourcePort`/`targetPort` in exactly this
/// shape), as the Engine's own [ProbePoint].
ProbePoint v2WireEndpointProbePoint(EngineeringRelationship relationship, {required bool atSource}) {
  final nodeId = atSource ? relationship.sourceNode : relationship.targetNode;
  final rawPort = atSource ? relationship.metadata['sourcePort'] as String? : relationship.metadata['targetPort'] as String?;
  return ProbePoint(nodeId: nodeId, portId: normalizeV2PortRef(rawPort));
}

/// §9's own conversion chain: `v2WireId -> V2 wire endpoints -> ProbePoint
/// -> ElectricalTerminalPair` (the pair is represented here as the two
/// [ProbePoint]s an [ElectricalMeasurementRequest] needs directly, rather
/// than introducing a redundant intermediate value type). `null` when
/// [v2WireId] has no bridged [EngineeringRelationship] at all (an
/// unbridged wire, `LegacyV2StateAdapter.unbridgedV2WireIds`) — never a
/// fabricated pair.
({ProbePoint positive, ProbePoint negative})? v2WireMeasurementTerminals(
  EngineeringGraph graph,
  String? relationshipId,
) {
  if (relationshipId == null) return null;
  final relationship = graph.relationships[relationshipId];
  if (relationship == null) return null;
  return (
    positive: v2WireEndpointProbePoint(relationship, atSource: true),
    negative: v2WireEndpointProbePoint(relationship, atSource: false),
  );
}

/// The full §8 chain for a V2-selected wire, using the LIVE, currently-
/// synced graph [LegacyV2StateAdapter.controller] already maintains (no
/// separate "get current graph" call needed — `controller.engine.editing
/// .session.graph` IS the live state, kept in sync by the adapter's own
/// existing V2 event handlers). Returns `null` when [v2WireId] has no
/// bridged relationship (mirrors [v2WireMeasurementTerminals]) — the
/// caller (e.g. a future DMM UI action) should fall back to the existing
/// LiveSim-backed `queryLiveMeasurement` in that case, exactly as it
/// would for any other unbridged wire.
ElectricalMeasurementResult? measureV2WireViaNativeEngine(
  LegacyV2StateAdapter adapter,
  String v2WireId,
  MeasurementType mode, {
  ElectricalSolver solver = const ElectricalSolver(),
  required ElectricalSolutionGenerationCounter generationCounter,
  ElectricalOperatingContext operatingContext = ElectricalOperatingContext.none,
}) {
  final graph = adapter.controller.engine.editing.session.graph;
  final terminals = v2WireMeasurementTerminals(graph, adapter.oepRelationshipIdFor(v2WireId));
  if (terminals == null) return null;
  final solved = solver.solve(graph, operatingContext, generationCounter: generationCounter);
  return const ElectricalMeasurementQuery().measure(
    solved,
    ElectricalMeasurementRequest(positiveTerminal: terminals.positive, negativeTerminal: terminals.negative, mode: mode),
  );
}
