import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/trace/circuit_search.dart';

/// PRODUCT-READINESS-010 §4/§5/§6/§38/§39/§40 — [searchCircuitEntities]
/// unit tests.
void main() {
  EngineeringGraph graph() => EngineeringGraph(id: 'g', nodes: {
        'headlight': const EngineeringNode(
          id: 'headlight',
          category: NodeCategory.component,
          displayName: 'Headlight',
          ports: [Port(id: 'lo', name: 'LO'), Port(id: 'hi', name: 'HI')],
        ),
        'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
      }, relationships: {
        'w1': const EngineeringRelationship(id: 'w1', relationshipType: RelationshipType.connectedTo, sourceNode: 'battery', targetNode: 'headlight'),
      });

  List<CircuitSearchEntry> search(String query) => searchCircuitEntities(
        graph: graph(),
        layout: DiagramLayoutState.empty,
        symbols: SymbolLibrary(),
        query: query,
      );

  test('§7 a component search returns the real node result, retaining its engineering identity', () {
    final results = search('Headlight');
    expect(results.any((e) => e.isNode && e.targetId == 'headlight'), isTrue);
  });

  test('§8 a "component terminal" search resolves the real (component, terminal) pair', () {
    final results = search('Headlight LO');
    final terminalEntry = results.firstWhere((e) => e.isTerminal);
    expect(terminalEntry.terminalMatch!.terminal.nodeId, 'headlight');
    expect(terminalEntry.terminalMatch!.terminal.portId, 'lo');
    expect(terminalEntry.label, 'Headlight · LO');
  });

  test('§9 a relationship search by id returns the real wire result', () {
    final results = search('w1');
    expect(results.any((e) => e.isRelationship && e.targetId == 'w1'), isTrue);
  });

  test('§6 result types are preserved, never flattened into a plain string', () {
    final results = search('Headlight');
    expect(results.every((e) => e.isNode || e.isRelationship || e.isTerminal), isTrue);
  });

  test('§40 a nonexistent term returns no results, never throws', () {
    expect(search('nonexistent-term-xyz'), isEmpty);
  });

  test('empty query returns no results', () {
    expect(search(''), isEmpty);
  });

  test('§5 terminal and component results for the same component both appear, adjacent in scope', () {
    final results = search('Headlight');
    final hasComponent = results.any((e) => e.isNode && e.targetId == 'headlight');
    final hasTerminal = results.any((e) => e.isTerminal && e.terminalMatch!.terminal.nodeId == 'headlight');
    expect(hasComponent, isTrue);
    expect(hasTerminal, isTrue, reason: 'searching just "Headlight" should also surface its own real terminals');
  });
}
