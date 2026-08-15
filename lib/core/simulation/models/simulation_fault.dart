/// AP-DS-005 fault taxonomy — matches the governing spec's own "Fault
/// Injection" list and `SIMULATION_TRACEABILITY_MATRIX.md`'s decision to
/// retain the legacy reference's fault vocabulary (a reasonable,
/// real-world-grounded taxonomy) while rejecting its representation drift
/// (the legacy reference had two different, inconsistent fault data
/// shapes coexisting — this engine has exactly one).
enum SimulationFaultType {
  openCircuit,
  shortCircuit,
  disconnectedConnector,
  brokenWire,
  incorrectWire,
  missingGround,
  missingPower,
  relayFailure,
  fuseFailure,
  connectorFailure,
}

/// A single injected fault. AP-DS-005 §Concepts Retained: faults are an
/// OVERLAY consulted during propagation, never a mutation of the
/// underlying `EngineeringGraph` — the base graph stays pristine and a
/// fault scenario is trivially resettable by clearing this overlay. This
/// directly retains the one legacy pattern explicitly named as worth
/// keeping (`SIMULATION_TRACEABILITY_MATRIX.md`'s `FaultInjector` row).
class SimulationFault {
  const SimulationFault({
    required this.id,
    required this.type,
    required this.targetId,
    this.targetPortId,
    this.isRelationship = false,
    required this.injectedAt,
    this.label = '',
  });

  final String id;
  final SimulationFaultType type;

  /// The node id or relationship id this fault targets, per [isRelationship].
  final String targetId;

  /// Optional port qualifier, for faults scoped to a specific pin (e.g. a
  /// `connectorFailure` on one specific pin of a multi-pin connector).
  final String? targetPortId;

  /// True if [targetId] is a relationship id (e.g. `brokenWire`,
  /// `incorrectWire`, `openCircuit`, `shortCircuit` typically target a
  /// relationship/wire); false if it targets a node (e.g. `relayFailure`,
  /// `fuseFailure`, `missingGround`, `missingPower`, `disconnectedConnector`
  /// typically target a component node).
  final bool isRelationship;

  final DateTime injectedAt;
  final String label;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'targetId': targetId,
        if (targetPortId != null) 'targetPortId': targetPortId,
        'isRelationship': isRelationship,
        'injectedAt': injectedAt.toIso8601String(),
        'label': label,
      };

  factory SimulationFault.fromJson(Map<String, Object?> json) {
    return SimulationFault(
      id: json['id'] as String,
      type: SimulationFaultType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SimulationFaultType.openCircuit,
      ),
      targetId: json['targetId'] as String,
      targetPortId: json['targetPortId'] as String?,
      isRelationship: json['isRelationship'] as bool? ?? false,
      injectedAt: DateTime.tryParse(json['injectedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      label: json['label'] as String? ?? '',
    );
  }
}

/// The fault overlay for one simulation session — a simple, single-shape
/// collection (AP-DS-005 §Concepts Rejected: the legacy reference had a
/// second, differently-shaped fault model coexisting with its primary one;
/// this engine has exactly one).
class FaultOverlay {
  FaultOverlay({Map<String, SimulationFault>? faults}) : _faults = faults ?? {};

  final Map<String, SimulationFault> _faults;

  List<SimulationFault> get active => _faults.values.toList(growable: false);

  bool get isEmpty => _faults.isEmpty;

  void inject(SimulationFault fault) => _faults[fault.id] = fault;

  void clear(String faultId) => _faults.remove(faultId);

  void clearAll() => _faults.clear();

  /// Faults targeting [id] (a node or relationship id), regardless of type.
  List<SimulationFault> faultsFor(String id) => _faults.values.where((f) => f.targetId == id).toList(growable: false);

  bool hasOpenCircuitOn(String relationshipId) =>
      _faults.values.any((f) => f.targetId == relationshipId && (f.type == SimulationFaultType.openCircuit || f.type == SimulationFaultType.brokenWire));

  bool hasShortOn(String relationshipId) =>
      _faults.values.any((f) => f.targetId == relationshipId && f.type == SimulationFaultType.shortCircuit);
}
