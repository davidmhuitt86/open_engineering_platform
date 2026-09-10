import '../measurement/measurement_types.dart';
import 'electrical_branch_state.dart';
import 'electrical_reading.dart';
import 'electrical_resistive_network.dart';
import 'electrical_solution_generation.dart';
import 'electrical_terminal_state.dart';

/// PRODUCT-READINESS-004 Phase A, §5 — the canonical, immutable solved
/// electrical state: the ONE authoritative answer for "what is the current
/// electrical condition of this engineering graph," keyed by terminal
/// ([ElectricalTerminalState], via [ProbePoint]) and by branch
/// ([ElectricalBranchState], via a branch id).
///
/// **Immutability**: every field is `final`, every collection is wrapped
/// unmodifiable at construction (see constructor body), and every nested
/// value type ([ElectricalReading], [ElectricalTerminalState],
/// [ElectricalBranchState]) is itself immutable. A new solve produces a
/// brand-new [SolvedElectricalState] with a new, strictly greater
/// [generation] (§12/§13) — this type is never mutated after publication
/// (§5's "Do NOT fake values... immutable or treated as immutable after
/// publication," success criterion 4).
///
/// **This is deliberately NOT the same type as** `SimulationStateSnapshot`
/// (`core/simulation/models/signal_types.dart`) — that type is the
/// existing, disclosed-as-logical-not-electrical reachability model for
/// the generic (non-electrical-domain) Simulation Engine (`SignalState`'s
/// own doc comment: "No SPICE/analog/physics simulation... a logical/
/// discrete-state model, never a resistive-network solve"). Reusing it
/// here would merge two responsibilities this task's own §1 explicitly
/// keeps separate ("There must be ONE authoritative live electrical
/// solution" — the ELECTRICAL one, not the generic logical one). This
/// type's own SHAPE deliberately mirrors `SimulationStateSnapshot`'s
/// already-proven "keyed by node, optionally refined by port" design
/// lineage (same convention, different, genuinely electrical payload).
class SolvedElectricalState {
  SolvedElectricalState({
    required this.generation,
    required Map<ProbePoint, ElectricalTerminalState> terminalStates,
    required Map<String, ElectricalBranchState> branchStates,
    this.network,
  })  : terminalStates = Map.unmodifiable(terminalStates),
        branchStates = Map.unmodifiable(branchStates);

  final ElectricalSolutionGeneration generation;

  /// PRODUCT-READINESS-006B, §24/§42/§43 — the general resistive-network
  /// solution (series/parallel/mixed, arbitrary-terminal resistance,
  /// genuinely network-solved branch current) this phase adds, ADDITIVE to
  /// [terminalStates]/[branchStates] (both of which remain exactly the
  /// PRODUCT-READINESS-006 ideal-propagation values, unchanged, to preserve
  /// every regression that phase established — see
  /// `ELECTRICAL_SOLUTION_ENGINE.md`'s own "Two solved answers, one
  /// authority" section for why both coexist here rather than one
  /// replacing the other). `null` only for a [SolvedElectricalState] built
  /// by an older call site that never attached one (e.g. a hand-built test
  /// fixture) — [ElectricalMeasurementQuery] degrades gracefully to
  /// UNSUPPORTED for the modes that genuinely need it (resistance,
  /// continuity, diode, current, power) rather than crashing.
  final ElectricalResistiveNetwork? network;

  /// Every terminal this solve produced a state for, keyed by its own
  /// [ProbePoint] address (§4: "componentId + terminalId", not merely
  /// "componentId" — see [ElectricalTerminalState]'s own doc comment for
  /// why this is what makes the model terminal-centric).
  final Map<ProbePoint, ElectricalTerminalState> terminalStates;

  /// Every branch this solve produced a state for, keyed by [ElectricalBranchState.branchId].
  final Map<String, ElectricalBranchState> branchStates;

  ElectricalTerminalState? terminalState(String componentId, String terminalId) =>
      terminalStates[ProbePoint(nodeId: componentId, portId: terminalId)];

  ElectricalBranchState? branchState(String branchId) => branchStates[branchId];

  /// §2 COMPONENT STATE — deliberately DERIVED from [terminalStates] on
  /// every call rather than stored as a third, separately-populated map:
  /// a component's state is nothing more than the aggregate of its own
  /// terminals' states, and storing it redundantly would risk the two
  /// silently disagreeing after a future partial update. Returns `null`
  /// if [componentId] has no terminal states recorded in this generation
  /// at all (never a fabricated all-[ElectricalReadingState.unknown]
  /// component state for a component this solve never touched).
  ElectricalComponentState? componentState(String componentId) {
    final terminals = terminalStates.values.where((t) => t.terminal.nodeId == componentId).toList(growable: false);
    if (terminals.isEmpty) return null;
    return ElectricalComponentState(componentId: componentId, terminals: terminals);
  }

  Map<String, Object?> toJson() => {
        'generation': generation.toJson(),
        'terminalStates': terminalStates.entries
            .map((e) => {'terminal': e.key.toJson(), 'state': e.value.toJson()})
            .toList(),
        'branchStates': branchStates.map((id, state) => MapEntry(id, state.toJson())),
      };

  factory SolvedElectricalState.fromJson(Map<String, Object?> json) {
    final terminalStates = <ProbePoint, ElectricalTerminalState>{};
    for (final entry in (json['terminalStates'] as List? ?? const [])) {
      final map = Map<String, Object?>.from(entry as Map);
      final terminal = ProbePoint.fromJson(Map<String, Object?>.from(map['terminal'] as Map));
      terminalStates[terminal] = ElectricalTerminalState.fromJson(Map<String, Object?>.from(map['state'] as Map));
    }
    final branchStatesJson = Map<String, Object?>.from(json['branchStates'] as Map? ?? const {});
    return SolvedElectricalState(
      generation: ElectricalSolutionGeneration.fromJson(Map<String, Object?>.from(json['generation'] as Map)),
      terminalStates: terminalStates,
      branchStates: branchStatesJson.map(
        (id, state) => MapEntry(id, ElectricalBranchState.fromJson(Map<String, Object?>.from(state as Map))),
      ),
    );
  }
}

/// §2 COMPONENT STATE — a read-only aggregate view over one component's
/// own [ElectricalTerminalState]s, produced only via
/// [SolvedElectricalState.componentState] (see that method's own doc
/// comment for why this is never independently stored).
class ElectricalComponentState {
  const ElectricalComponentState({required this.componentId, required this.terminals});

  final String componentId;
  final List<ElectricalTerminalState> terminals;

  /// True if ANY of this component's known terminals is energized (§2's
  /// "energized" node-state concept, lifted to component scope). A
  /// component with zero recorded terminals never reaches this getter —
  /// [SolvedElectricalState.componentState] returns `null` first.
  bool get isEnergized => terminals.any((t) => t.isEnergized);

  bool get hasSourceTerminal => terminals.any((t) => t.isSourceTerminal);

  bool get hasReferenceTerminal => terminals.any((t) => t.isReferenceTerminal);

  ElectricalTerminalState? terminal(String terminalId) {
    for (final t in terminals) {
      if (t.terminal.portId == terminalId) return t;
    }
    return null;
  }
}
