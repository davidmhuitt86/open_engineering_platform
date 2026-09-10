import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

EngineeringRelationship _wire(String id, String fromNode, String fromPort, String toNode, String toPort) {
  return EngineeringRelationship(
    id: id,
    relationshipType: RelationshipType.connectedTo,
    sourceNode: fromNode,
    targetNode: toNode,
    metadata: {'sourcePort': fromPort, 'targetPort': toPort},
  );
}

EngineeringGraph _diamondGraph() {
  // source -> splice -> {A, B} -> sink -- a genuine diamond: two branches
  // reconverging on the same downstream node, the classic case naive
  // traversal could double-count as two "different" paths to sink.
  final source = EngineeringNode(id: 'source', category: NodeCategory.component, displayName: 'Source', ports: const [Port(id: 'out', name: 'out')]);
  final splice = EngineeringNode(
    id: 'splice', category: NodeCategory.component, displayName: 'Splice',
    metadata: const {'v2Category': 'splice'},
    ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b'), Port(id: 'c', name: 'c')],
  );
  final branchA = EngineeringNode(id: 'branchA', category: NodeCategory.component, displayName: 'Branch A', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
  final branchB = EngineeringNode(id: 'branchB', category: NodeCategory.component, displayName: 'Branch B', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
  final sink = EngineeringNode(id: 'sink', category: NodeCategory.ground, displayName: 'Sink', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);

  return EngineeringGraph(id: 'g', nodes: {
    'source': source, 'splice': splice, 'branchA': branchA, 'branchB': branchB, 'sink': sink,
  }, relationships: {
    'w1': _wire('w1', 'source', 'out', 'splice', 'a'),
    'w2': _wire('w2', 'splice', 'b', 'branchA', 'in'),
    'w3': _wire('w3', 'splice', 'c', 'branchB', 'in'),
    'w4': _wire('w4', 'branchA', 'out', 'sink', 'a'),
    'w5': _wire('w5', 'branchB', 'out', 'sink', 'b'),
  });
}

void main() {
  group('O/P/Q: trace target kinds resolve through the same canonical engine', () {
    test('O: component-centric trace expands to the component\'s own terminals', () {
      const engine = TraceEngine();
      final graph = _diamondGraph();
      final result = engine.trace(graph: graph, target: TraceTarget.component('splice'), mode: TraceMode.physical);
      expect(result.paths.map((p) => p.startTerminal.nodeId).toSet(), {'splice'});
      expect(result.paths.map((p) => p.startTerminal.portId).toSet(), {'a', 'b', 'c'});
    });

    test('P: terminal-centric trace starts from exactly the one supplied terminal', () {
      const engine = TraceEngine();
      final graph = _diamondGraph();
      final terminal = ProbePoint(nodeId: 'splice', portId: 'b');
      final result = engine.trace(graph: graph, target: TraceTarget.terminal(terminal), mode: TraceMode.physical);
      expect(result.paths, isNotEmpty);
      expect(result.paths.every((p) => p.startTerminal == terminal), isTrue);
    });

    test('Q: wire-centric trace resolves through the same architecture (its two endpoint terminals)', () {
      const engine = TraceEngine();
      final graph = _diamondGraph();
      final byRelationship = engine.trace(graph: graph, target: TraceTarget.relationship('w2'), mode: TraceMode.physical);
      final expectedTerminals = {ProbePoint(nodeId: 'splice', portId: 'b'), ProbePoint(nodeId: 'branchA', portId: 'in')};
      expect(byRelationship.paths.map((p) => p.startTerminal).toSet(), expectedTerminals);

      // Same result set (by component/relationship membership) as tracing
      // the endpoint terminal directly -- proving there is no separate
      // "wire tracing" code path, just the same engine given a different
      // starting terminal.
      final byTerminal = engine.trace(
        graph: graph, target: TraceTarget.terminal(ProbePoint(nodeId: 'splice', portId: 'b')), mode: TraceMode.physical,
      );
      expect(byRelationship.componentIds.intersection(byTerminal.componentIds), byTerminal.componentIds);
    });

    test('unknown component id produces a targetNotFound diagnostic, not a crash or empty silent success', () {
      const engine = TraceEngine();
      final graph = _diamondGraph();
      final result = engine.trace(graph: graph, target: TraceTarget.component('does-not-exist'), mode: TraceMode.physical);
      expect(result.paths, isEmpty);
      expect(result.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.targetNotFound));
    });
  });

  group('R/S: deterministic ordering and path deduplication', () {
    test('R: repeated traces of the identical graph produce identically-ordered paths', () {
      const engine = TraceEngine();
      final graphA = _diamondGraph();
      // A second graph, semantically identical but built with map entries
      // inserted in a DIFFERENT order, to prove ordering never depends on
      // Map/Set iteration order.
      final graphB = EngineeringGraph(
        id: 'g',
        nodes: Map.fromEntries(graphA.nodes.entries.toList().reversed),
        relationships: Map.fromEntries(graphA.relationships.entries.toList().reversed),
      );

      final resultA = engine.trace(graph: graphA, target: TraceTarget.component('splice'), mode: TraceMode.physical);
      final resultB = engine.trace(graph: graphB, target: TraceTarget.component('splice'), mode: TraceMode.physical);

      expect(resultA.paths.map((p) => p.pathId).toList(), resultB.paths.map((p) => p.pathId).toList());
    });

    test('S: no duplicate equivalent paths in a diamond topology', () {
      const engine = TraceEngine();
      final graph = _diamondGraph();
      final result = engine.trace(graph: graph, target: TraceTarget.component('source'), mode: TraceMode.physical);
      final ids = result.paths.map((p) => p.pathId).toList();
      expect(ids.toSet().length, ids.length, reason: 'every path id must be unique -- no duplicate equivalent paths');
    });
  });
}
