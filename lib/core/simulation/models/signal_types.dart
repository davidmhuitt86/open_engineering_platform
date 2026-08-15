/// AP-DS-005: signal types the Simulation Engine propagates deterministically.
/// Matches the governing spec's own "Signal Propagation" list exactly. No
/// SPICE/analog/physics simulation — every one of these is a logical/
/// discrete-state model, never a resistive-network solve (see
/// `SIMULATION_REFERENCE_REVIEW.md` for why: the legacy reference's own
/// "voltage propagation" was flood-fill, not Kirchhoff's laws, and this
/// engine deliberately does not attempt more than that).
enum SignalType {
  power,
  ground,
  digitalHigh,
  digitalLow,
  analogState,
  pwmState,
  can,
  lin,
  discreteState,
}

/// The propagated state at one point in the graph for one [SignalType].
///
/// [reachable] is the Power/Ground-style boolean reachability result
/// (AP-DS-005 §Concepts Retained: "power and ground as two independent
/// reachability passes," reused here as the base primitive every signal
/// type shares). [value] carries a signal-specific payload for types where
/// a single boolean isn't sufficient (analog/PWM numeric value, CAN/LIN bus
/// state, discrete state label) — `null` when [reachable] alone is the
/// complete answer (Power/Ground/DigitalHigh/DigitalLow).
class SignalState {
  const SignalState({
    required this.type,
    required this.reachable,
    this.value,
  });

  final SignalType type;
  final bool reachable;

  /// Present only for analogState (a `double`), pwmState (a `double` duty
  /// cycle 0.0-1.0), can/lin (a `String` bus-state label), discreteState
  /// (a `String` state label). `null` for power/ground/digitalHigh/
  /// digitalLow, where [reachable] alone is the complete signal.
  final Object? value;

  static const SignalState unreachable = SignalState(type: SignalType.power, reachable: false);

  Map<String, Object?> toJson() => {
        'type': type.name,
        'reachable': reachable,
        if (value != null) 'value': value,
      };

  factory SignalState.fromJson(Map<String, Object?> json) {
    return SignalState(
      type: SignalType.values.firstWhere((t) => t.name == json['type'], orElse: () => SignalType.power),
      reachable: json['reachable'] as bool? ?? false,
      value: json['value'],
    );
  }

  @override
  String toString() => 'SignalState(${type.name}, reachable=$reachable${value != null ? ', value=$value' : ''})';
}

/// The full computed signal state for one simulation pass: every
/// [SignalType] that was actually seeded/propagated, keyed by node id, then
/// by [SignalType]. A node with no entry for a given type was never
/// evaluated for that type (distinct from "evaluated and unreachable").
///
/// AP-DS-005's own "Concepts Improved" decision (per
/// `SIMULATION_TRACEABILITY_MATRIX.md`): the legacy reference collapsed an
/// entire multi-pin component to one voltage value, self-flagged in its own
/// code as a known weakness. This model keys state per NODE by default
/// (matching what the reference actually shipped and proved workable at
/// harness scale) but ALSO supports an optional per-PORT override
/// ([portStates]) for components whose ports must be distinguished (e.g. a
/// relay's coil pins vs. contact pins) — populated only where a
/// relationship's metadata names a specific port, not for every node. This
/// is a real, honest partial improvement over the legacy one-state-per-node
/// model, not a full per-terminal resistive solve.
class SimulationStateSnapshot {
  const SimulationStateSnapshot({
    required this.nodeStates,
    this.portStates = const {},
  });

  /// nodeId -> SignalType -> SignalState
  final Map<String, Map<SignalType, SignalState>> nodeStates;

  /// nodeId -> portId -> SignalType -> SignalState (populated only for
  /// nodes/ports where a relationship explicitly named a port).
  final Map<String, Map<String, Map<SignalType, SignalState>>> portStates;

  SignalState? stateOf(String nodeId, SignalType type) => nodeStates[nodeId]?[type];

  SignalState? portStateOf(String nodeId, String portId, SignalType type) => portStates[nodeId]?[portId]?[type];

  bool isPowered(String nodeId) => stateOf(nodeId, SignalType.power)?.reachable ?? false;

  bool isGrounded(String nodeId) => stateOf(nodeId, SignalType.ground)?.reachable ?? false;

  /// "Functional" per the legacy reference's own retained pattern
  /// (`SIMULATION_REFERENCE_REVIEW.md`): powered AND grounded, two
  /// independent reachability passes combined, never merged into one net.
  bool isFunctional(String nodeId) => isPowered(nodeId) && isGrounded(nodeId);

  Map<String, Object?> toJson() => {
        'nodeStates': nodeStates.map(
          (nodeId, byType) => MapEntry(nodeId, byType.map((type, state) => MapEntry(type.name, state.toJson()))),
        ),
        'portStates': portStates.map(
          (nodeId, byPort) => MapEntry(
            nodeId,
            byPort.map(
              (portId, byType) => MapEntry(portId, byType.map((type, state) => MapEntry(type.name, state.toJson()))),
            ),
          ),
        ),
      };
}
