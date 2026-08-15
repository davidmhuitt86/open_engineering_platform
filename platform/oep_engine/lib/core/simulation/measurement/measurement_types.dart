/// WP-DS-005A Engineering Instruments — measurement type vocabulary.
///
/// Matches the governing work package's Digital Multimeter list exactly.
/// `capacitance`/`temperature` are the spec's own named "future
/// placeholders" — present in the enum so instrument UI can list them as
/// not-yet-supported, but [MeasurementEngine] does not compute them yet.
enum MeasurementType {
  voltageDc,
  voltageAc,
  resistance,
  continuity,
  current,
  diode,
  frequency,
  dutyCycle,
  power,
  groundPotential,
  capacitance,
  temperature,
}

/// How a measurement was produced/should be interpreted.
enum MeasurementMode {
  manual,
  liveSimulation,
  expected,
  comparison,
  historical,
}

/// One probe's placement — a node, optionally a specific port on it, or a
/// point along a relationship (wire segment). Matches the spec's Probe
/// System snap targets (Engineering Objects, Pins, Connectors, Wire
/// segments, Terminals, Measurement points) by allowing either a node or a
/// relationship as the anchor.
class ProbePoint {
  const ProbePoint({required this.nodeId, this.portId, this.relationshipId});

  final String nodeId;
  final String? portId;

  /// Set when the probe is snapped to a wire segment rather than a node —
  /// [nodeId] is then the nearer endpoint, used for path/reachability
  /// queries, while [relationshipId] records the actual wire probed.
  final String? relationshipId;

  Map<String, Object?> toJson() => {
        'nodeId': nodeId,
        if (portId != null) 'portId': portId,
        if (relationshipId != null) 'relationshipId': relationshipId,
      };

  factory ProbePoint.fromJson(Map<String, Object?> json) => ProbePoint(
        nodeId: json['nodeId'] as String,
        portId: json['portId'] as String?,
        relationshipId: json['relationshipId'] as String?,
      );
}
