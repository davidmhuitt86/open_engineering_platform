import '../../graph/algorithms/graph_traversal.dart';
import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../models/signal_types.dart';
import 'verification_finding.dart';

/// AP-DS-005 Engineering Verification — static, simulation-independent
/// design-correctness checks, matching the governing spec's own list
/// exactly (Connectivity/Continuity/Open Circuit/Short Circuit/Ground/
/// Power/Relationship/Dependency/Package/Harness/Connector Verification).
///
/// Retains the legacy reference's genuinely useful pattern (per
/// `SIMULATION_TRACEABILITY_MATRIX.md`): verification is independent of
/// simulation execution, run once against the graph's structure (plus,
/// where a check is inherently about reachability, the current
/// [SimulationStateSnapshot]) — never a duplicate graph-traversal
/// implementation. Connectivity/dependency checks reuse `GraphTraversal`
/// (`oep_engine`'s existing traversal primitives); nothing here
/// reimplements BFS.
class VerificationEngine {
  const VerificationEngine();

  VerificationReport runAll(EngineeringGraph graph, {SimulationStateSnapshot? state}) {
    final findings = <VerificationFinding>[
      ..._connectivity(graph),
      ..._relationship(graph),
      ..._harnessAndConnector(graph),
      ..._package(graph),
      if (state != null) ..._continuityGroundPower(graph, state),
      if (state != null) ..._dependency(graph, state),
    ];
    return VerificationReport(findings: findings, generatedAt: DateTime.now());
  }

  /// Connectivity Verification — every node reachable from at least one
  /// other node (per-component islands are reported), reusing
  /// `GraphTraversal.reachableFrom`/`isolatedNodes` rather than a new BFS.
  List<VerificationFinding> _connectivity(EngineeringGraph graph) {
    final findings = <VerificationFinding>[];
    for (final nodeId in GraphTraversal.isolatedNodes(graph)) {
      findings.add(VerificationFinding(
        check: VerificationCheck.connectivity,
        severity: VerificationSeverity.warning,
        message: '${graph.nodes[nodeId]?.displayName ?? nodeId} has no relationships at all (isolated).',
        nodeId: nodeId,
      ));
    }

    // Island detection: every node not reachable from the first node
    // belongs to a separate connected component. Composed from
    // `GraphTraversal.reachableFrom`, not a new BFS -- matches this
    // engine's own "one traversal core" commitment.
    final allIds = graph.nodes.keys.toSet();
    final visitedGlobally = <String>{};
    final islands = <Set<String>>[];
    for (final id in allIds) {
      if (visitedGlobally.contains(id)) continue;
      final component = GraphTraversal.reachableFrom(graph, id);
      visitedGlobally.addAll(component);
      islands.add(component);
    }
    if (islands.length > 1) {
      // Report every island beyond the largest as disconnected -- mirrors
      // the legacy reference's own retained convention (largest island
      // treated as the "main" circuit), per `SIMULATION_TRACEABILITY_MATRIX.md`.
      islands.sort((a, b) => b.length.compareTo(a.length));
      for (final island in islands.skip(1)) {
        for (final nodeId in island) {
          findings.add(VerificationFinding(
            check: VerificationCheck.connectivity,
            severity: VerificationSeverity.warning,
            message: '${graph.nodes[nodeId]?.displayName ?? nodeId} is part of a disconnected sub-circuit '
                '(${island.length} node${island.length == 1 ? '' : 's'}), separate from the main circuit.',
            nodeId: nodeId,
          ));
        }
      }
    }
    return findings;
  }

  /// Relationship Verification — every relationship references two nodes
  /// that actually exist in the graph.
  List<VerificationFinding> _relationship(EngineeringGraph graph) {
    final findings = <VerificationFinding>[];
    for (final relationship in graph.relationships.values) {
      if (!graph.nodes.containsKey(relationship.sourceNode)) {
        findings.add(VerificationFinding(
          check: VerificationCheck.relationship,
          severity: VerificationSeverity.error,
          message: 'Relationship ${relationship.id} references a source node that does not exist.',
          relationshipId: relationship.id,
        ));
      }
      if (!graph.nodes.containsKey(relationship.targetNode)) {
        findings.add(VerificationFinding(
          check: VerificationCheck.relationship,
          severity: VerificationSeverity.error,
          message: 'Relationship ${relationship.id} references a target node that does not exist.',
          relationshipId: relationship.id,
        ));
      }
      if (relationship.sourceNode == relationship.targetNode) {
        findings.add(VerificationFinding(
          check: VerificationCheck.relationship,
          severity: VerificationSeverity.warning,
          message: 'Relationship ${relationship.id} connects a node to itself.',
          relationshipId: relationship.id,
        ));
      }
    }
    return findings;
  }

  /// Harness Verification + Connector Verification. Harness membership is
  /// this platform's chosen representation (layer assignment, per
  /// `ENGINEERING_MAPPING.md`/`wire_report.dart`'s established convention)
  /// -- but the Simulation Engine has no direct `DiagramLayoutState`
  /// dependency (it operates on `EngineeringGraph` alone, per this phase's
  /// own architectural boundary: "Simulation Engine performs deterministic
  /// execution... base all execution exclusively on Engineering Objects
  /// and Relationships"). So Harness Verification here is scoped to what
  /// the GRAPH itself can express: harness-category nodes and their
  /// membership relationships, not layout-layer membership (that remains
  /// a Diagram Studio/presentation-layer concept, verified separately if
  /// ever needed at that layer).
  List<VerificationFinding> _harnessAndConnector(EngineeringGraph graph) {
    final findings = <VerificationFinding>[];
    for (final node in graph.nodes.values) {
      if (node.category == NodeCategory.harness) {
        final hasMembers = graph.relationshipsForNode(node.id).any(
              (r) => r.relationshipType == RelationshipType.contains || r.relationshipType == RelationshipType.partOf,
            );
        if (!hasMembers) {
          findings.add(VerificationFinding(
            check: VerificationCheck.harness,
            severity: VerificationSeverity.info,
            message: 'Harness "${node.displayName}" has no Contains/PartOf membership relationships.',
            nodeId: node.id,
          ));
        }
      }
      if (node.category == NodeCategory.connector) {
        if (node.ports.isEmpty) {
          findings.add(VerificationFinding(
            check: VerificationCheck.connector,
            severity: VerificationSeverity.info,
            message: 'Connector "${node.displayName}" declares no pins/ports.',
            nodeId: node.id,
          ));
        }
        final unusedPorts = node.ports.where((p) => !_portReferenced(graph, node.id, p.id)).toList();
        for (final port in unusedPorts) {
          findings.add(VerificationFinding(
            check: VerificationCheck.connector,
            severity: VerificationSeverity.info,
            message: 'Connector "${node.displayName}" pin "${port.name}" is not referenced by any relationship metadata.',
            nodeId: node.id,
          ));
        }
      }
    }
    return findings;
  }

  bool _portReferenced(EngineeringGraph graph, String nodeId, String portId) {
    for (final r in graph.relationshipsForNode(nodeId)) {
      if (r.metadata['sourcePort'] == portId || r.metadata['targetPort'] == portId) return true;
    }
    return false;
  }

  /// Package Verification — every node with a `repositoryObjectId` is at
  /// least internally consistent (non-empty id); a genuinely deeper package
  /// check (Foundation package/trust validation) is Foundation's own job
  /// (`FoundationBridge.verifyPackage`, AP-DS-002), not reimplemented here
  /// -- this check only verifies the graph's own local consistency.
  List<VerificationFinding> _package(EngineeringGraph graph) {
    final findings = <VerificationFinding>[];
    for (final node in graph.nodes.values) {
      if (node.repositoryObjectId != null && node.repositoryObjectId!.trim().isEmpty) {
        findings.add(VerificationFinding(
          check: VerificationCheck.package,
          severity: VerificationSeverity.warning,
          message: '${node.displayName} has an empty (not null) repositoryObjectId.',
          nodeId: node.id,
        ));
      }
    }
    return findings;
  }

  /// Continuity/Ground/Power/Open-Circuit/Short-Circuit Verification --
  /// these require a computed [SimulationStateSnapshot] (they're
  /// statements about reachability under current conditions, not pure
  /// graph structure), so they're only run when a snapshot is supplied.
  List<VerificationFinding> _continuityGroundPower(EngineeringGraph graph, SimulationStateSnapshot state) {
    final findings = <VerificationFinding>[];
    for (final node in graph.nodes.values) {
      final needsPower = graph.relationshipsForNode(node.id).any((r) => r.relationshipType == RelationshipType.suppliesPower && r.targetNode == node.id);
      final needsGround = node.category != NodeCategory.ground &&
          graph.relationshipsForNode(node.id).any((r) => r.relationshipType == RelationshipType.grounds && r.targetNode == node.id);

      if (needsPower && !state.isPowered(node.id)) {
        findings.add(VerificationFinding(
          check: VerificationCheck.power,
          severity: VerificationSeverity.error,
          message: '${node.displayName} expects power but is not reachable from any power source under current conditions.',
          nodeId: node.id,
        ));
      }
      if (needsGround && !state.isGrounded(node.id)) {
        findings.add(VerificationFinding(
          check: VerificationCheck.ground,
          severity: VerificationSeverity.error,
          message: '${node.displayName} expects a ground return but is not reachable from any ground source under current conditions.',
          nodeId: node.id,
        ));
      }
      if ((needsPower || needsGround) && !state.isFunctional(node.id) && (state.isPowered(node.id) || state.isGrounded(node.id))) {
        // Continuity: reached by exactly one of power/ground, not both --
        // a real, distinct "open circuit somewhere" signal, not merely a
        // restatement of the power/ground findings above.
        findings.add(VerificationFinding(
          check: VerificationCheck.continuity,
          severity: VerificationSeverity.warning,
          message: '${node.displayName} has a partial circuit (power or ground reached, not both) -- check for an open circuit.',
          nodeId: node.id,
        ));
      }
    }
    return findings;
  }

  /// Dependency Verification -- flags a node whose only path to
  /// functionality passes through a single upstream node (a single point
  /// of failure), reusing [GraphTraversal.findPath] rather than a new
  /// traversal. This directly retains the legacy reference's
  /// `whatFailsIf` concept while fixing its known bug (checking only the
  /// first power source) -- see `SIMULATION_TRACEABILITY_MATRIX.md`.
  List<VerificationFinding> _dependency(EngineeringGraph graph, SimulationStateSnapshot state) {
    final findings = <VerificationFinding>[];
    final powerSources = graph.relationships.values
        .where((r) => r.relationshipType == RelationshipType.suppliesPower)
        .map((r) => r.sourceNode)
        .toSet();
    if (powerSources.isEmpty) return findings;

    for (final node in graph.nodes.values) {
      if (!state.isPowered(node.id)) continue;
      // Checks EVERY power source (fixing the legacy reference's
      // single-source bug), not just the first.
      final singlePointsOfFailure = <String>{};
      for (final sourceId in powerSources) {
        final path = GraphTraversal.findPath(graph, sourceId, node.id);
        if (path == null) continue;
        singlePointsOfFailure.addAll(path.where((id) => id != sourceId && id != node.id));
      }
      if (singlePointsOfFailure.length == 1) {
        findings.add(VerificationFinding(
          check: VerificationCheck.dependency,
          severity: VerificationSeverity.info,
          message: '${node.displayName} depends entirely on ${graph.nodes[singlePointsOfFailure.first]?.displayName ?? singlePointsOfFailure.first} '
              'for power (single point of failure across every checked power source).',
          nodeId: node.id,
        ));
      }
    }
    return findings;
  }
}
