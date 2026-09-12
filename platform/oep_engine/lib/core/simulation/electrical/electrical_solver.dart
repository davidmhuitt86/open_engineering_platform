import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../../graph/models/port.dart';
import '../measurement/measurement_types.dart';
import 'electrical_branch_state.dart';
import 'electrical_component_behavior.dart';
import 'electrical_conducting_state.dart';
import 'electrical_node_roles.dart';
import 'electrical_operating_context.dart';
import 'electrical_reading.dart';
import 'electrical_resistive_network.dart';
import 'electrical_solution_generation.dart';
import 'electrical_terminal_state.dart';
import 'solved_electrical_state.dart';

/// PRODUCT-READINESS-006 — decides whether a terminal is a modeled power
/// source. Defaults to: the node's own [ElectricalComponentBehavior]
/// reports [ElectricalComponentBehavior.generatesPower], AND the terminal
/// is not itself ground/reference-shaped (see [defaultIsReferenceTerminal]).
/// A caller with real, richer component data (e.g. "this Port's name is
/// literally the diagram's own `+`") may supply a more precise resolver —
/// never hardcoded to a component id (§16/§33).
typedef ElectricalSourceRoleResolver = bool Function(EngineeringNode node, String? portId, ElectricalComponentBehavior? behavior);

typedef ElectricalReferenceRoleResolver = bool Function(EngineeringNode node, String? portId);

/// §9/§14/§15/§18 — a source's declared voltage under the current
/// operating state (a real battery's terminal voltage genuinely varies by
/// key position — key-off/on/cranking/running — matching the Legacy V2
/// solver's own `BatteryBehavior.VOLTAGE` table). Defaults to
/// [ElectricalSolver]'s own `properties['nominalVoltageV']` lookup (a
/// single, state-independent value); a caller with real, richer,
/// operating-state-aware voltage data (or a real diagram whose source
/// component simply never had a `nominalVoltageV` property authored at
/// all — confirmed true of the real, production `diagram7.json` Battery
/// node, which has no such property) may supply this instead. Honestly
/// [ElectricalReading.unknown] wherever neither has a real answer — never
/// fabricated.
typedef ElectricalSourceVoltageResolver = ElectricalReading Function(EngineeringNode node, ElectricalOperatingContext context);

/// The plain, name-based-fallback default — see [preciseIsReferenceTerminal]
/// (`electrical_node_roles.dart`) for the PRODUCTION-recommended resolver
/// PRODUCT-READINESS-006B/008 established, which narrows the name-based
/// fallback to a recognized source component's own return pin (avoiding
/// the real, disclosed over-firing this plain default has at real,
/// full-harness scale). This default remains unchanged/available for a
/// caller working with a small/synthetic diagram, where the distinction
/// never matters.
bool defaultIsReferenceTerminal(EngineeringNode node, String? portId) {
  if (isGroundNode(node)) return true;
  return nameMatchesReferenceTerminal(node, portId);
}

/// A node is treated as a modeled power source when EITHER its own
/// [ElectricalComponentBehavior.generatesPower] says so, OR — the more
/// common real-world case, since no behavior is ported for most real
/// component types yet (PRODUCT-READINESS-005's own disclosed gap) — its
/// `metadata['v2Category'] == 'power'` (the real, already-established V2
/// bridge signal: confirmed directly on the real
/// `platform/oep_studio/samples/diagram7.json` Battery node, `"v2Category":
/// "power"`) or `metadata['v2Kind'] == 'battery'`. All three are generic
/// signals (category/kind/behavior), never a hardcoded component id
/// (§16/§33). Its own negative/ground-shaped terminal is excluded (a
/// source's `-` terminal is a reference role, not a source role — see
/// [defaultIsReferenceTerminal]).
bool defaultIsSourceTerminal(EngineeringNode node, String? portId, ElectricalComponentBehavior? behavior) {
  final isSourceComponent =
      behavior?.generatesPower == true || node.metadata['v2Category'] == 'power' || node.metadata['v2Kind'] == 'battery';
  if (!isSourceComponent) return false;
  return !defaultIsReferenceTerminal(node, portId);
}

/// PRODUCT-READINESS-006 — the production Electrical Solution Engine.
///
/// **Architecture decision (documented per §5/§44 — see
/// `ELECTRICAL_SOLUTION_ENGINE.md` for the full rationale): NATIVE.** A
/// thin adapter over the Legacy V2 JS solver was considered and rejected
/// for this phase: `oep_engine` is a plain Dart package with no WebView/JS
/// runtime dependency today (confirmed by inspection — `webview_flutter*`
/// only appears in `oep_studio`), and §35 requires any native-or-adapter
/// solution to work identically on Windows/Linux/Android/iOS without
/// platform-specific logic — embedding a JS engine inside `oep_engine`
/// purely to reuse the JS solver's math would itself be exactly that kind
/// of platform-specific complexity, not less of it. This class instead
/// re-implements the SAME proven invariants (PRODUCT-READINESS-002's own
/// regression suite) natively, against the terminal-centric model, and is
/// validated by an equivalent Dart-side regression suite
/// (`test/simulation/electrical/electrical_solver_*_test.dart`) rather
/// than by calling into the JS implementation. The JS solver remains
/// untouched and continues to drive the WebView's own live bulb-glow
/// display — a presentation-layer concern this phase does not touch (§40).
/// This is realistically a HYBRID migration (§5 option C): one new
/// authority for `SolvedElectricalState` going forward, one existing,
/// unmodified, still-correct system for the existing WebView UI, kept
/// behaviorally consistent by mirrored invariants, not by one calling the
/// other.
///
/// **Algorithm**: BFS voltage/ground propagation over TERMINALS (not
/// nodes — the direct fix for PRODUCT-READINESS-004's own audited "one
/// node, not one terminal" limitation), gated by
/// [ElectricalComponentBehavior.conductingTerminalPairs] for internal
/// (same-component) bridging and by [ElectricalBranchState] fault/wire
/// gating for external (relationship) bridging — the exact same terminal-
/// graph shape [TraceEngine] already builds (this solver is what actually
/// computes the state [TraceEngine] only ever reads). Current/power are
/// computed ONLY where a real resistance is known for a component AND
/// both its own terminal voltages are resolved (§19/§49's own scope
/// limit: real Ohm's law for a simple series load, not a general
/// resistive-network/Kirchhoff solve).
class ElectricalSolver {
  const ElectricalSolver({
    this.behaviorResolver,
    this.isSourceTerminal = defaultIsSourceTerminal,
    this.isReferenceTerminal = defaultIsReferenceTerminal,
    this.sourceVoltage = _defaultSourceVoltage,
    this.wireResistanceOhms = _defaultWireResistanceOhmsForSolver,
  });

  final ElectricalBehaviorResolver? behaviorResolver;
  final ElectricalSourceRoleResolver isSourceTerminal;
  final ElectricalReferenceRoleResolver isReferenceTerminal;
  final ElectricalSourceVoltageResolver sourceVoltage;

  /// PRODUCT-READINESS-006B — feeds [ElectricalResistiveNetwork.build]'s own
  /// [ElectricalWireResistanceResolver] (see that typedef's doc comment for
  /// the real, disclosed `0.1Ω` default this mirrors).
  final ElectricalWireResistanceResolver wireResistanceOhms;

  static num _defaultWireResistanceOhmsForSolver(String relationshipId) => 0.1;

  SolvedElectricalState solve(
    EngineeringGraph graph,
    ElectricalOperatingContext operatingContext, {
    required ElectricalSolutionGenerationCounter generationCounter,
  }) {
    final terminalsByNode = <String, List<ProbePoint>>{};
    for (final node in graph.nodes.values) {
      terminalsByNode[node.id] =
          node.ports.isEmpty ? [ProbePoint(nodeId: node.id)] : node.ports.map((p) => ProbePoint(nodeId: node.id, portId: p.id)).toList();
    }

    ElectricalComponentBehavior? behaviorFor(EngineeringNode node) =>
        behaviorResolver?.call(node) ?? defaultElectricalBehaviorFor(node);

    // Voltage propagation dead-ends at a ground node (AP-VOLTAGE-GROUND-
    // RACE-001, PRODUCT-READINESS-002): reaching ground is a sink for
    // VOLTAGE, never a conductor onward to whatever else shares that
    // ground bus.
    final voltage = _propagate(
      graph,
      terminalsByNode,
      operatingContext,
      behaviorFor,
      seedPredicate: (node, portId, behavior) => isSourceTerminal(node, portId, behavior),
      seedValue: (node, portId) => sourceVoltage(node, operatingContext),
      isSink: isGroundNode,
    );

    // Ground propagation is seeded FROM ground nodes, so they must NOT be
    // treated as a dead end for this pass (only for the voltage pass
    // above) — a ground node's own onward wires are exactly how "has
    // ground" reaches everything else connected to that ground bus.
    final ground = _propagate(
      graph,
      terminalsByNode,
      operatingContext,
      behaviorFor,
      seedPredicate: (node, portId, behavior) => isReferenceTerminal(node, portId),
      seedValue: (node, portId) => ElectricalReading.valid(0, unit: 'V'),
      isSink: (node) => false,
    );

    // A STRUCTURALLY reference/ground terminal (a real Ground-category
    // node, or a terminal whose own name matches a reference-shaped
    // pattern — see [isReferenceTerminal]'s own doc) reads a real,
    // definitional 0V, whether or not the voltage-source BFS above
    // happened to reach it. Deliberately NOT based on general ground-BFS
    // REACHABILITY here (an earlier version of this method used
    // `ground[terminal]?.isValid` for this — found, on the real TRX300
    // fixture, to over-fire: a chassis ground bus reaches nearly every
    // terminal transitively through splices/connectors several hops away,
    // which would mark plainly non-ground terminals like a headlight's own
    // power-feed pin as "0V" merely because SOMETHING on its shared splice
    // chain eventually has a ground path — electrically wrong. See
    // `_effectiveGroundVoltage` below for the narrower, one-hop-only use
    // ground-BFS reachability is still legitimately used for.
    final isReferenceByTerminal = <ProbePoint, bool>{};
    final resolvedVoltageByTerminal = <ProbePoint, ElectricalReading>{};
    for (final entry in terminalsByNode.entries) {
      final node = graph.nodes[entry.key]!;
      for (final terminal in entry.value) {
        final isReference = isReferenceTerminal(node, terminal.portId);
        isReferenceByTerminal[terminal] = isReference;
        resolvedVoltageByTerminal[terminal] =
            isReference ? ElectricalReading.valid(0, unit: 'V') : (voltage[terminal] ?? ElectricalReading.unreached(unit: 'V'));
      }
    }

    final terminalStates = <ProbePoint, ElectricalTerminalState>{};
    for (final entry in terminalsByNode.entries) {
      final node = graph.nodes[entry.key]!;
      for (final terminal in entry.value) {
        final behavior = behaviorFor(node);
        terminalStates[terminal] = ElectricalTerminalState(
          terminal: terminal,
          voltage: resolvedVoltageByTerminal[terminal]!,
          current: ElectricalReading.unsupported(unit: 'A', note: 'No branch-level current computed for this terminal.'),
          isSourceTerminal: isSourceTerminal(node, terminal.portId, behavior),
          isReferenceTerminal: isReferenceByTerminal[terminal]!,
        );
      }
    }

    // PRODUCT-READINESS-006B — built BEFORE the branch-state loop below
    // (unlike its previous position after that loop) so `_resistiveCurrentFor`
    // can consult it as a real, non-heuristic fallback when the ideal-
    // propagation voltage can't resolve a resistive load's own return
    // terminal (§9/PRODUCT-READINESS-009 — see that method's own doc
    // comment for why this fallback is safe where an earlier, REJECTED
    // multi-hop ground-BFS heuristic was not).
    final network = ElectricalResistiveNetwork.build(
      graph: graph,
      context: operatingContext,
      behaviorFor: behaviorFor,
      isSourceTerminal: isSourceTerminal,
      isReferenceTerminal: isReferenceTerminal,
      sourceVoltage: sourceVoltage,
      wireResistanceOhms: wireResistanceOhms,
    );

    final branchStates = <String, ElectricalBranchState>{};
    for (final relationship in graph.relationships.values) {
      final source = _endpointTerminal(relationship, atSource: true);
      final destination = _endpointTerminal(relationship, atSource: false);
      final sourceVoltage = resolvedVoltageByTerminal[source] ?? ElectricalReading.unreached(unit: 'V');
      final destinationVoltage = resolvedVoltageByTerminal[destination] ?? ElectricalReading.unreached(unit: 'V');

      // Conducting state (continuity) is a weaker, boolean claim than a
      // specific voltage value — safe to base on the pin-gated GROUND
      // reachability pass too (unlike the voltage/reference resolution
      // above, which deliberately stopped doing that): a multi-hop
      // ground-return path (e.g. a taillight's own return wire crossing
      // a splice before reaching a real ground point) is genuinely
      // conducting even though no single wire along it resolves a
      // specific 0V value on its own.
      final sourceGrounded = ground[source]?.isValid ?? false;
      final destinationGrounded = ground[destination]?.isValid ?? false;
      final conducting = sourceVoltage.isValid || destinationVoltage.isValid || sourceGrounded || destinationGrounded
          ? ElectricalConductingState.conducting
          : ElectricalConductingState.unknown;

      final resistiveCurrent =
          _resistiveCurrentFor(graph, source, destination, resolvedVoltageByTerminal, operatingContext, behaviorFor, network);

      branchStates[relationship.id] = ElectricalBranchState(
        branchId: relationship.id,
        sourceTerminal: source,
        destinationTerminal: destination,
        voltage: sourceVoltage.isValid ? sourceVoltage : destinationVoltage,
        voltageDrop: ElectricalReading.unsupported(unit: 'V', note: 'No per-branch drop model beyond the resistive-load case.'),
        current: resistiveCurrent.current,
        resistance: resistiveCurrent.resistance,
        power: resistiveCurrent.power,
        conductingState: conducting,
        currentDirection: resistiveCurrent.direction,
        relationshipId: relationship.id,
      );
    }

    return SolvedElectricalState(
      generation: generationCounter.next(),
      terminalStates: terminalStates,
      branchStates: branchStates,
      network: network,
    );
  }

  // ---- Voltage/ground BFS (mirrors the proven Legacy V2 pin-gating shape) ----

  Map<ProbePoint, ElectricalReading> _propagate(
    EngineeringGraph graph,
    Map<String, List<ProbePoint>> terminalsByNode,
    ElectricalOperatingContext context,
    ElectricalComponentBehavior? Function(EngineeringNode) behaviorFor, {
    required bool Function(EngineeringNode node, String? portId, ElectricalComponentBehavior? behavior) seedPredicate,
    required ElectricalReading Function(EngineeringNode node, String? portId) seedValue,
    required bool Function(EngineeringNode node) isSink,
  }) {
    final result = <ProbePoint, ElectricalReading>{};
    final queue = <ProbePoint>[];
    for (final node in graph.nodes.values) {
      final behavior = behaviorFor(node);
      for (final terminal in terminalsByNode[node.id]!) {
        if (seedPredicate(node, terminal.portId, behavior)) {
          result[terminal] = seedValue(node, terminal.portId);
          queue.add(terminal);
        }
      }
    }

    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      final node = graph.nodes[current.nodeId];
      if (node == null) continue;
      // A sink (e.g. a ground node, for the VOLTAGE pass specifically —
      // see the two call sites' own doc comments) receives its seed value
      // but never forwards it onward through any of its own terminals,
      // internal or external (AP-VOLTAGE-GROUND-RACE-001). A dead-end/
      // resistive-load component reaches the same effective outcome
      // generically, via an empty `conductingTerminalPairs` below (no
      // pair ever matches, so nothing propagates past it) — no separate
      // special-case is needed for that (AP-LAMP-TUNNEL-001).
      if (isSink(node)) continue;

      // Internal (same-component) propagation to another terminal of the
      // SAME node.
      final behavior = behaviorFor(node);
      if (behavior != null && current.portId != null) {
        for (final terminal in terminalsByNode[node.id]!) {
          if (terminal.portId == current.portId) continue;
          if (terminal.portId == null) continue;
          if (!behavior.conductsFrom(node, current.portId!, terminal.portId!, context)) continue;
          if (result.containsKey(terminal)) continue;
          result[terminal] = result[current]!;
          queue.add(terminal);
        }
      }

      // External (wire) propagation.
      for (final relationship in graph.relationshipsForNode(current.nodeId)) {
        final atSource = relationship.sourceNode == current.nodeId;
        final ownPort = atSource
            ? relationship.metadata['sourcePort'] as String?
            : relationship.metadata['targetPort'] as String?;
        if (ownPort != null && ownPort != current.portId) continue;
        final other = _endpointTerminal(relationship, atSource: !atSource);
        if (result.containsKey(other)) continue;
        result[other] = result[current]!;
        queue.add(other);
      }
    }
    return result;
  }

  ProbePoint _endpointTerminal(EngineeringRelationship relationship, {required bool atSource}) {
    final nodeId = atSource ? relationship.sourceNode : relationship.targetNode;
    final portId = atSource
        ? relationship.metadata['sourcePort'] as String?
        : relationship.metadata['targetPort'] as String?;
    return ProbePoint(nodeId: nodeId, portId: portId);
  }

  /// A node's own declared nominal source voltage (§9: real component
  /// metadata, never a hardcoded value) — read from
  /// `EngineeringNode.properties['nominalVoltageV']`, the generic
  /// "real engineering property" bag (distinct from the more V2-bridge/UI-
  /// ish `metadata`). Honestly [ElectricalReading.unknown] when no value
  /// was ever authored — never fabricated (§14/§15). The DEFAULT
  /// [ElectricalSourceVoltageResolver] — see that typedef's own doc
  /// comment for why a caller may supply a different one (e.g. the real,
  /// production `diagram7.json` Battery has no `nominalVoltageV` property
  /// at all today, honestly yielding [ElectricalReading.unknown] here
  /// unless a caller with real, external knowledge of the actual TRX300
  /// battery voltage supplies its own resolver).
  static ElectricalReading _defaultSourceVoltage(EngineeringNode node, ElectricalOperatingContext context) {
    final declared = node.properties['nominalVoltageV'];
    if (declared is num) return ElectricalReading.valid(declared, unit: 'V');
    return ElectricalReading.unknown(unit: 'V', note: 'No nominalVoltageV declared on this source component.');
  }

  /// A narrow, ONE-HOP-ONLY fallback for "is this terminal effectively at
  /// 0V for Ohm's-law purposes" — used ONLY inside [_resistiveCurrentFor],
  /// never for the general [ElectricalTerminalState.voltage] a caller
  /// like [TraceEngine] reads (see that field's own construction above
  /// for why: a multi-hop ground-BFS-reachability rule was tried and
  /// found, on the real TRX300 fixture, to falsely mark non-ground
  /// terminals several splice-hops away from an actual ground point as
  /// "0V"). This checks only a DIRECT wire from [terminal] to a real
  /// Ground-category node — the exact, unambiguous shape a load's own
  /// return terminal has in every fixture this phase's own tests use
  /// (§32.A/K: `lamp.out -> wire -> ground`) — never a transitive chain.
  ///
  /// PRODUCT-READINESS-009 — a THIRD fallback, tried only after both of
  /// the above: [network]'s own [ElectricalResistiveNetwork.operatingVoltage]
  /// (PRODUCT-READINESS-006B's real, resistance-aware circuit solve). This
  /// is deliberately NOT the same kind of heuristic the two rejected
  /// ground-BFS-reachability attempts documented above were — it computes
  /// an actual voltage-divider answer from the real, disclosed component/
  /// wire resistances (§8-§14 of that class), never "is this terminal
  /// merely near a ground node." On the real `diagram7.json` TRX300
  /// fixture, a load's own return terminal (e.g. a headlight's GND) is
  /// typically several splice-hops from chassis-ground — a shape neither
  /// of the two narrower fallbacks above resolves, which otherwise left
  /// `TraceMode.currentFlow` (PRODUCT-READINESS-009 §12/§13) unable to
  /// report ANY valid current for that entirely real, correctly-wired
  /// circuit. Consulted last, and only when both narrower checks already
  /// failed, so no existing (already-valid) answer changes.
  ElectricalReading _effectiveVoltageForCurrent(
    EngineeringGraph graph,
    ProbePoint terminal,
    Map<ProbePoint, ElectricalReading> resolvedVoltageByTerminal,
    ElectricalResistiveNetwork network,
  ) {
    final direct = resolvedVoltageByTerminal[terminal];
    if (direct != null && direct.isValid) return direct;
    for (final relationship in graph.relationshipsForNode(terminal.nodeId)) {
      final atSource = relationship.sourceNode == terminal.nodeId;
      final ownPort = atSource
          ? relationship.metadata['sourcePort'] as String?
          : relationship.metadata['targetPort'] as String?;
      if (ownPort != null && ownPort != terminal.portId) continue;
      final otherNodeId = atSource ? relationship.targetNode : relationship.sourceNode;
      final otherNode = graph.nodes[otherNodeId];
      if (otherNode != null && isGroundNode(otherNode)) return ElectricalReading.valid(0, unit: 'V');
    }
    final fromNetwork = network.operatingVoltage(terminal);
    if (fromNetwork != null && fromNetwork.isValid) return fromNetwork;
    return direct ?? ElectricalReading.unreached(unit: 'V');
  }

  // ---- Ohm's law current/power for a resistive load (§19/§20/§49) -------

  /// §19/§20/§49 — a resistive component (e.g. a lamp) has its own real
  /// resistance between ITS OWN two terminals, which are generally NOT
  /// the same two points as a given wire's own two endpoints: for
  /// `battery -> wire -> lamp.in` / `lamp.out -> wire -> ground`, the
  /// resistance/voltage-drop genuinely belongs between `lamp.in` and
  /// `lamp.out` (the component itself), not between `battery` and
  /// `lamp.in` (a plain 0Ω wire, whose own two ends are electrically the
  /// SAME point). This method finds, for a given wire's own endpoint,
  /// whether that endpoint's OWN component has a real resistance value —
  /// and if so, computes current/power using THAT component's own two
  /// terminal voltages (via [resolvedVoltageByTerminal], not the wire's
  /// own endpoints) — then reports the result on the WIRE anyway, since a
  /// simple series circuit conserves current: the wire immediately
  /// feeding a resistive component carries the exact same current the
  /// component itself does. This is the deliberately minimal, honest
  /// scope this phase supports (§49) — a general multi-branch/parallel
  /// Kirchhoff solve is explicitly NOT attempted.
  ({ElectricalReading current, ElectricalReading resistance, ElectricalReading power, ElectricalCurrentDirection direction})
      _resistiveCurrentFor(
    EngineeringGraph graph,
    ProbePoint wireSource,
    ProbePoint wireDestination,
    Map<ProbePoint, ElectricalReading> resolvedVoltageByTerminal,
    ElectricalOperatingContext context,
    ElectricalComponentBehavior? Function(EngineeringNode) behaviorFor,
    ElectricalResistiveNetwork network,
  ) {
    ({ElectricalReading resistance, ProbePoint ownTerminal, ProbePoint otherTerminal})? resistiveComponentAt(ProbePoint terminal) {
      final node = graph.nodes[terminal.nodeId];
      if (node == null || terminal.portId == null) return null;
      final behavior = behaviorFor(node);
      if (behavior == null) return null;
      final otherPort = node.ports.firstWhere((p) => p.id != terminal.portId, orElse: () => Port(id: terminal.portId!, name: ''));
      // A component that BRIDGES this exact pair (a fuse, a closed
      // switch, a connector's same pin, a splice) always solves to a
      // real-but-uninformative zero-drop reading between its own two
      // terminals, since the voltage BFS gives both the identical
      // propagated value by construction — that is not a genuine Ohm's-
      // law answer, so this only treats a pair as resistive-current-
      // eligible when the component does NOT already bridge it (a true
      // dead-end/load, e.g. a lamp, whose `conductingTerminalPairs` is
      // empty for this pair specifically).
      if (behavior.conductsFrom(node, terminal.portId!, otherPort.id, context) ||
          behavior.conductsFrom(node, otherPort.id, terminal.portId!, context)) {
        return null;
      }
      final reading = behavior.resistanceBetween(node, terminal.portId!, otherPort.id, context);
      if (!reading.isValid) return null;
      return (resistance: reading, ownTerminal: terminal, otherTerminal: ProbePoint(nodeId: node.id, portId: otherPort.id));
    }

    final unsupported = (
      current: ElectricalReading.unsupported(unit: 'A', note: 'No resistance model resolved for either endpoint.'),
      resistance: ElectricalReading.unsupported(unit: 'Ω'),
      power: ElectricalReading.unsupported(unit: 'W'),
      direction: ElectricalCurrentDirection.unknown,
    );

    final found = resistiveComponentAt(wireSource) ?? resistiveComponentAt(wireDestination);
    if (found == null) return unsupported;

    final ownVoltage = _effectiveVoltageForCurrent(graph, found.ownTerminal, resolvedVoltageByTerminal, network);
    final otherVoltage = _effectiveVoltageForCurrent(graph, found.otherTerminal, resolvedVoltageByTerminal, network);
    if (!ownVoltage.isValid || !otherVoltage.isValid) {
      return (
        current: ElectricalReading.unsupported(unit: 'A', note: 'Both of the component\'s own terminal voltages must be resolved first.'),
        resistance: found.resistance,
        power: ElectricalReading.unsupported(unit: 'W'),
        direction: ElectricalCurrentDirection.unknown,
      );
    }
    final ohms = found.resistance.value!;
    if (ohms == 0) return unsupported;
    final deltaV = ownVoltage.value! - otherVoltage.value!;
    final amps = deltaV / ohms;

    // Orient direction relative to the WIRE's own source->destination
    // (not the resistive component's own/other terminal order, which is
    // frequently NOT the same pair as the wire's — see this method's own
    // doc comment). By series current conservation: if the component's
    // OWN terminal is the wire's DESTINATION, current entering `own` from
    // outside (rawDirection own->other) is exactly current flowing
    // wireSource->wireDestination on this wire — no flip. If the
    // component's OWN terminal is instead the wire's SOURCE, current
    // must be flowing other->own at the internal junction (rawDirection
    // destinationToSource, i.e. INTO own) for it to then continue OUT via
    // this wire toward wireDestination — so the wire's own direction is
    // the OPPOSITE label from rawDirection in that case.
    final flip = found.ownTerminal == wireSource;
    final rawDirection = amps == 0
        ? ElectricalCurrentDirection.none
        : (amps > 0 ? ElectricalCurrentDirection.sourceToDestination : ElectricalCurrentDirection.destinationToSource);
    final direction = !flip
        ? rawDirection
        : switch (rawDirection) {
            ElectricalCurrentDirection.sourceToDestination => ElectricalCurrentDirection.destinationToSource,
            ElectricalCurrentDirection.destinationToSource => ElectricalCurrentDirection.sourceToDestination,
            ElectricalCurrentDirection.none => ElectricalCurrentDirection.none,
            ElectricalCurrentDirection.unknown => ElectricalCurrentDirection.unknown,
          };

    return (
      current: ElectricalReading.valid(amps.abs(), unit: 'A'),
      resistance: found.resistance,
      power: ElectricalReading.valid(amps.abs() * deltaV.abs(), unit: 'W'),
      direction: direction,
    );
  }
}
