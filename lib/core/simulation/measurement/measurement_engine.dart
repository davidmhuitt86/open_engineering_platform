import '../../graph/algorithms/graph_traversal.dart';
import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../models/signal_types.dart';
import '../models/simulation_fault.dart';
import '../propagation/signal_propagator.dart';
import 'measurement_result.dart';
import 'measurement_types.dart';

/// WP-DS-005A Measurement Engine — computes [MeasurementResult]s for the
/// Digital Multimeter (and future instruments) from two probe points. This
/// is the ONLY place a measurement value is computed; Diagram Studio's
/// Instruments Framework only requests measurements and renders results
/// (per the work package's own Architectural Principles: "Diagram Studio
/// shall never compute engineering measurements").
///
/// **Disclosed scope boundary — logical, not physical, measurement.** This
/// engine performs no analog/SPICE-style computation (consistent with
/// AP-DS-005's own exclusion, reaffirmed here for instruments). For
/// continuity/resistance, a measurement is a fault-gated reachability query
/// (reusing [SignalPropagator], never a second traversal). For value-typed
/// measurements (voltage/current/power/frequency/duty cycle/ground
/// potential), the "measured value" is the graph's own AUTHORED engineering
/// intent — read from `properties['expectedValue']`/`['expectedUnit']` on
/// the probed node or port — reported as the reading when the probe point
/// is reachable under current simulation/fault conditions, and as `0`
/// (or unreachable) when it is not. This is the same honest pattern
/// [SignalPropagator] already uses for non-boolean signal types (a caller-
/// supplied/seeded value carried by reachability, never computed from
/// physics) — every [MeasurementResult] for these types carries a [notes]
/// disclosure saying so, so no caller can mistake it for a real analog
/// reading.
class MeasurementEngine {
  const MeasurementEngine({SignalPropagator propagator = const SignalPropagator()}) : _propagator = propagator;

  final SignalPropagator _propagator;

  static const _valueDisclosure = 'Reflects the graph\'s authored expected value, gated by current logical '
      'simulation state (reachable/blocked) — not a computed analog reading. This engine performs no '
      'SPICE-style circuit simulation.';

  /// [blockedRelationshipIds] (Phase 10 -- Operating/Input State Effects):
  /// the same real-input-state-resolved set [SimulationSession.recompute]
  /// gates propagation with -- passed through here so a measurement
  /// reflects the identical simulated circuit the session's own [state]
  /// snapshot reflects, never a second, independently-computed reality.
  MeasurementResult measure(
    EngineeringGraph graph,
    FaultOverlay faults, {
    required ProbePoint probeA,
    required ProbePoint probeB,
    required MeasurementType type,
    MeasurementMode mode = MeasurementMode.manual,
    Set<String> blockedRelationshipIds = const {},
  }) {
    final now = DateTime.now();
    final path = GraphTraversal.findPath(graph, probeA.nodeId, probeB.nodeId) ?? const [];
    final contributingRelationshipIds = _relationshipsAlongPath(graph, path);

    switch (type) {
      case MeasurementType.continuity:
      case MeasurementType.diode:
        return _measureContinuity(
            graph, faults, probeA, probeB, type, mode, now, path, contributingRelationshipIds, blockedRelationshipIds);
      case MeasurementType.resistance:
        return _measureResistance(
            graph, faults, probeA, probeB, mode, now, path, contributingRelationshipIds, blockedRelationshipIds);
      case MeasurementType.voltageDc:
      case MeasurementType.voltageAc:
      case MeasurementType.current:
      case MeasurementType.power:
        return _measureValue(graph, faults, probeA, probeB, type, mode, now, path, contributingRelationshipIds,
            gate: SignalType.power, blockedRelationshipIds: blockedRelationshipIds);
      case MeasurementType.groundPotential:
        return _measureValue(graph, faults, probeA, probeB, type, mode, now, path, contributingRelationshipIds,
            gate: SignalType.ground, blockedRelationshipIds: blockedRelationshipIds);
      case MeasurementType.frequency:
      case MeasurementType.dutyCycle:
        return _measureValue(graph, faults, probeA, probeB, type, mode, now, path, contributingRelationshipIds,
            gate: SignalType.power, blockedRelationshipIds: blockedRelationshipIds);
      case MeasurementType.capacitance:
      case MeasurementType.temperature:
        // Named "future placeholders" in the work package's own Digital
        // Multimeter section — not computed yet, disclosed as such rather
        // than silently returning a fabricated zero.
        return MeasurementResult(
          type: type,
          mode: mode,
          probeA: probeA,
          probeB: probeB,
          reachable: false,
          timestamp: now,
          notes: '${type.name} is a documented future placeholder; not yet supported by MeasurementEngine.',
        );
    }
  }

  /// A generic fault-gated reachability query between two points, reusing
  /// [SignalPropagator.propagateSignal] with [SignalType.discreteState] as
  /// a neutral "is there an unbroken path" seed — never a second BFS.
  bool _connected(
    EngineeringGraph graph,
    FaultOverlay faults,
    String fromNodeId,
    String toNodeId,
    Set<String> blockedRelationshipIds,
  ) {
    final reached = _propagator.propagateSignal(
      graph,
      faults,
      SignalType.discreteState,
      {fromNodeId},
      blockedRelationshipIds: blockedRelationshipIds,
    );
    return reached.nodeStates.containsKey(toNodeId);
  }

  MeasurementResult _measureContinuity(
    EngineeringGraph graph,
    FaultOverlay faults,
    ProbePoint probeA,
    ProbePoint probeB,
    MeasurementType type,
    MeasurementMode mode,
    DateTime now,
    List<String> path,
    List<String> contributingRelationshipIds,
    Set<String> blockedRelationshipIds,
  ) {
    final connected = _connected(graph, faults, probeA.nodeId, probeB.nodeId, blockedRelationshipIds);
    return MeasurementResult(
      type: type,
      mode: mode,
      probeA: probeA,
      probeB: probeB,
      reachable: connected,
      timestamp: now,
      continuous: connected,
      measuredValue: connected ? 0 : null,
      unit: connected ? 'Ω' : '',
      path: connected ? path : const [],
      contributingRelationshipIds: connected ? contributingRelationshipIds : const [],
      notes: type == MeasurementType.diode
          ? 'Logical continuity only — forward-bias direction and voltage drop are not modeled.'
          : null,
    );
  }

  MeasurementResult _measureResistance(
    EngineeringGraph graph,
    FaultOverlay faults,
    ProbePoint probeA,
    ProbePoint probeB,
    MeasurementMode mode,
    DateTime now,
    List<String> path,
    List<String> contributingRelationshipIds,
    Set<String> blockedRelationshipIds,
  ) {
    final connected = _connected(graph, faults, probeA.nodeId, probeB.nodeId, blockedRelationshipIds);
    return MeasurementResult(
      type: MeasurementType.resistance,
      mode: mode,
      probeA: probeA,
      probeB: probeB,
      reachable: connected,
      timestamp: now,
      measuredValue: connected ? 0 : null,
      unit: 'Ω',
      path: connected ? path : const [],
      contributingRelationshipIds: connected ? contributingRelationshipIds : const [],
      notes: 'No per-component resistance is modeled (no SPICE simulation) — reports 0 Ω when continuous, '
          'open (no reading) otherwise.',
    );
  }

  MeasurementResult _measureValue(
    EngineeringGraph graph,
    FaultOverlay faults,
    ProbePoint probeA,
    ProbePoint probeB,
    MeasurementType type,
    MeasurementMode mode,
    DateTime now,
    List<String> path,
    List<String> contributingRelationshipIds, {
    required SignalType gate,
    Set<String> blockedRelationshipIds = const {},
  }) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final reachable = gate == SignalType.ground ? state.isGrounded(probeA.nodeId) : state.isPowered(probeA.nodeId);

    final expected = _expectedValue(graph, probeA);
    final measured = reachable ? expected : (expected == null ? null : 0);

    String? powerSourceId;
    String? groundSourceId;
    if (reachable) {
      if (gate == SignalType.ground) {
        // Ground sources are nodes with an outgoing `grounds` relationship,
        // OR any `NodeCategory.ground` node (a chassis-ground point is a
        // source with no explicit relationship) -- matches
        // SignalPropagator.propagatePowerAndGround's own source-finding
        // convention exactly, so this never disagrees with it.
        final groundSources = <String>{
          for (final r in graph.relationships.values)
            if (r.relationshipType == RelationshipType.grounds) r.sourceNode,
          for (final n in graph.nodes.values)
            if (n.category == NodeCategory.ground) n.id,
        };
        for (final sourceId in groundSources) {
          if (GraphTraversal.findPath(graph, sourceId, probeA.nodeId) != null) groundSourceId = sourceId;
        }
      } else {
        for (final r in graph.relationships.values) {
          if (r.relationshipType == RelationshipType.suppliesPower &&
              GraphTraversal.findPath(graph, r.sourceNode, probeA.nodeId) != null) {
            powerSourceId = r.sourceNode;
          }
        }
      }
    }

    return MeasurementResult(
      type: type,
      mode: mode,
      probeA: probeA,
      probeB: probeB,
      reachable: reachable,
      timestamp: now,
      measuredValue: measured,
      expectedValue: expected,
      unit: _unitFor(type, graph, probeA) ?? '',
      path: path,
      powerSourceId: powerSourceId,
      groundSourceId: groundSourceId,
      contributingRelationshipIds: contributingRelationshipIds,
      notes: expected != null ? _valueDisclosure : 'No expectedValue authored on this node/port.',
    );
  }

  num? _expectedValue(EngineeringGraph graph, ProbePoint probe) {
    final node = graph.nodes[probe.nodeId];
    if (node == null) return null;
    if (probe.portId != null) {
      for (final port in node.ports) {
        if (port.id == probe.portId) {
          final v = port.metadata['expectedValue'];
          if (v is num) return v;
        }
      }
    }
    final v = node.properties['expectedValue'];
    return v is num ? v : null;
  }

  String? _unitFor(MeasurementType type, EngineeringGraph graph, ProbePoint probe) {
    final node = graph.nodes[probe.nodeId];
    final authored = node?.properties['expectedUnit'];
    if (authored is String && authored.isNotEmpty) return authored;
    switch (type) {
      case MeasurementType.voltageDc:
      case MeasurementType.voltageAc:
      case MeasurementType.groundPotential:
        return 'V';
      case MeasurementType.current:
        return 'A';
      case MeasurementType.power:
        return 'W';
      case MeasurementType.frequency:
        return 'Hz';
      case MeasurementType.dutyCycle:
        return '%';
      default:
        return null;
    }
  }

  List<String> _relationshipsAlongPath(EngineeringGraph graph, List<String> path) {
    if (path.length < 2) return const [];
    final ids = <String>[];
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      for (final r in graph.relationshipsForNode(a)) {
        if ((r.sourceNode == a && r.targetNode == b) || (r.sourceNode == b && r.targetNode == a)) {
          ids.add(r.id);
          break;
        }
      }
    }
    return ids;
  }
}
