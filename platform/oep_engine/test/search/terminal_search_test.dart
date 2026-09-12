import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// PRODUCT-READINESS-010 §8/§27/§38/§39 — [searchTerminals] unit tests.
void main() {
  EngineeringGraph graph() => EngineeringGraph(id: 'g', nodes: {
        'headlight': const EngineeringNode(
          id: 'headlight',
          category: NodeCategory.component,
          displayName: 'Headlight',
          ports: [Port(id: 'gnd', name: 'GND'), Port(id: 'lo', name: 'LO'), Port(id: 'hi', name: 'HI')],
        ),
        'headlight2': const EngineeringNode(
          id: 'headlight2',
          category: NodeCategory.component,
          displayName: 'Headlight',
          ports: [Port(id: 'gnd', name: 'GND'), Port(id: 'lo', name: 'LO'), Port(id: 'hi', name: 'HI')],
        ),
        'battery': const EngineeringNode(
          id: 'battery',
          category: NodeCategory.component,
          displayName: 'Battery',
          ports: [Port(id: 'p', name: '+'), Port(id: 'n', name: '-')],
        ),
      }, relationships: const {});

  test('§8 "Headlight LO" resolves the real (component, terminal) pair as a ProbePoint', () {
    final results = searchTerminals(graph(), 'Headlight LO');
    expect(results, isNotEmpty);
    expect(results.first.terminal, isA<ProbePoint>());
    expect(results.first.terminalName, 'LO');
    expect(results.first.componentName, 'Headlight');
  });

  test('an exact terminal-only query ("LO") matches every component with that terminal name', () {
    final results = searchTerminals(graph(), 'LO');
    expect(results.map((r) => r.componentName).toSet(), {'Headlight'});
    expect(results, hasLength(2), reason: 'both Headlight nodes have an LO terminal');
  });

  test('§27 deterministic ranking: exact combined match ranks above a mere substring match', () {
    final results = searchTerminals(graph(), 'headlight lo');
    expect(results.first.rank, 0);
    expect(results.first.matchedField, 'combined');
  });

  test('§39 duplicate component display names each produce their own distinguishable ProbePoint', () {
    final results = searchTerminals(graph(), 'Headlight LO');
    final nodeIds = results.map((r) => r.terminal.nodeId).toSet();
    expect(nodeIds, {'headlight', 'headlight2'}, reason: 'both real, distinct nodes must be represented, never collapsed to one');
  });

  test('§40 no match returns an empty list, never throws', () {
    expect(searchTerminals(graph(), 'nonexistent-term-xyz'), isEmpty);
  });

  test('empty query returns no results', () {
    expect(searchTerminals(graph(), ''), isEmpty);
    expect(searchTerminals(graph(), '   '), isEmpty);
  });

  test('results are sorted deterministically -- repeated calls produce identical order', () {
    final first = searchTerminals(graph(), 'headlight');
    final second = searchTerminals(graph(), 'headlight');
    expect(first.map((r) => r.terminal).toList(), second.map((r) => r.terminal).toList());
  });
}
