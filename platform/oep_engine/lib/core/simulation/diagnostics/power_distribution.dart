import '../../graph/algorithms/graph_traversal.dart';
import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../models/signal_types.dart';
import '../models/simulation_fault.dart';
import '../propagation/signal_propagator.dart';

/// AP-DS-005 "Power Distribution" — a presentation-ready VIEW over what
/// [SignalPropagator]/`VerificationEngine` already compute. No new
/// propagation logic lives here (per the spec's own scoping): Power/Ground
/// Domains are connected components of the reachable subgraph, Fuse/Relay
/// Paths are paths that pass through fuse/relay-category nodes,
/// Powered/Unpowered Devices are a straightforward partition by
/// [SimulationStateSnapshot.isPowered]. Diagram Studio's visualization
/// layer consumes this shape directly.
class PowerDistributionView {
  const PowerDistributionView({
    required this.powerDomains,
    required this.groundDomains,
    required this.fusePaths,
    required this.relayPaths,
    required this.poweredDeviceIds,
    required this.unpoweredDeviceIds,
    required this.inactivePathRelationshipIds,
  });

  /// Each entry is one connected component (as node ids) of the
  /// power-reachable subgraph.
  final List<List<String>> powerDomains;

  /// Each entry is one connected component of the ground-reachable subgraph.
  final List<List<String>> groundDomains;

  /// Node-id paths from a power source through each fuse-category node.
  final List<List<String>> fusePaths;

  /// Node-id paths from a power source through each relay-category node.
  final List<List<String>> relayPaths;

  final List<String> poweredDeviceIds;
  final List<String> unpoweredDeviceIds;

  /// Relationship ids that carry no active signal under current
  /// conditions (both endpoints unpowered) — "Inactive Paths".
  final List<String> inactivePathRelationshipIds;

  Map<String, Object?> toJson() => {
        'powerDomains': powerDomains,
        'groundDomains': groundDomains,
        'fusePaths': fusePaths,
        'relayPaths': relayPaths,
        'poweredDeviceIds': poweredDeviceIds,
        'unpoweredDeviceIds': unpoweredDeviceIds,
        'inactivePathRelationshipIds': inactivePathRelationshipIds,
      };
}

class PowerDistributionCalculator {
  const PowerDistributionCalculator({SignalPropagator propagator = const SignalPropagator()}) : _propagator = propagator;

  final SignalPropagator _propagator;

  /// [blockedRelationshipIds] (Phase 11 -- Simulation Analysis
  /// Consistency): the same real-input-state-resolved set
  /// [SignalPropagator]/[MeasurementEngine] already consume, so power
  /// domains/paths/powered-device lists never disagree with the DMM
  /// about which relationships currently conduct.
  PowerDistributionView compute(EngineeringGraph graph, FaultOverlay faults, {Set<String> blockedRelationshipIds = const {}}) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);

    final powerDomains = _domains(graph, state.isPowered);
    final groundDomains = _domains(graph, state.isGrounded);

    final powerSources = <String>{};
    for (final domain in powerDomains) {
      if (domain.isNotEmpty) powerSources.add(domain.first);
    }

    final fusePaths = <List<String>>[];
    final relayPaths = <List<String>>[];
    for (final node in graph.nodes.values) {
      if (node.category != NodeCategory.fuse && node.category != NodeCategory.relay) continue;
      if (!state.isPowered(node.id)) continue;
      List<String>? shortest;
      for (final sourceId in powerSources) {
        final path = GraphTraversal.findPath(graph, sourceId, node.id);
        if (path != null && (shortest == null || path.length < shortest.length)) shortest = path;
      }
      if (shortest == null) continue;
      if (node.category == NodeCategory.fuse) {
        fusePaths.add(shortest);
      } else {
        relayPaths.add(shortest);
      }
    }

    final poweredDevices = <String>[];
    final unpoweredDevices = <String>[];
    for (final node in graph.nodes.values) {
      if (state.isPowered(node.id)) {
        poweredDevices.add(node.id);
      } else {
        unpoweredDevices.add(node.id);
      }
    }
    poweredDevices.sort();
    unpoweredDevices.sort();

    final inactive = <String>[];
    for (final r in graph.relationships.values) {
      if (!state.isPowered(r.sourceNode) && !state.isPowered(r.targetNode)) {
        inactive.add(r.id);
      }
    }
    inactive.sort();

    return PowerDistributionView(
      powerDomains: powerDomains,
      groundDomains: groundDomains,
      fusePaths: fusePaths,
      relayPaths: relayPaths,
      poweredDeviceIds: poweredDevices,
      unpoweredDeviceIds: unpoweredDevices,
      inactivePathRelationshipIds: inactive,
    );
  }

  /// Connected components (via `GraphTraversal.reachableFrom`) restricted
  /// to nodes for which [include] is true — an O(n) single pass over all
  /// nodes, not O(n^2).
  List<List<String>> _domains(EngineeringGraph graph, bool Function(String) include) {
    final eligible = graph.nodes.keys.where(include).toSet();
    final visited = <String>{};
    final domains = <List<String>>[];
    for (final id in eligible) {
      if (visited.contains(id)) continue;
      final component = GraphTraversal.reachableFrom(graph, id).intersection(eligible);
      visited.addAll(component);
      final sorted = component.toList()..sort();
      domains.add(sorted);
    }
    return domains;
  }
}
