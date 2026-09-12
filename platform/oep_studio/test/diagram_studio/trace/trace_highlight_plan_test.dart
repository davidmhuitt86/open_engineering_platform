import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/trace/trace_highlight_plan.dart';

/// PRODUCT-READINESS-009 §34 — pure unit tests for
/// [buildTraceHighlightPlan] against hand-built [TraceResult]/[TracePath]
/// fixtures (no live graph/solver/WebView needed -- this is a translation
/// layer, tested in isolation from the things it translates between).
void main() {
  EngineeringGraph twoWireGraph() => EngineeringGraph(id: 'g', nodes: {
        'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
        'b': const EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B'),
        'c': const EngineeringNode(id: 'c', category: NodeCategory.component, displayName: 'C'),
      }, relationships: {
        'w1': const EngineeringRelationship(id: 'w1', relationshipType: RelationshipType.connectedTo, sourceNode: 'a', targetNode: 'b'),
        'w2': const EngineeringRelationship(id: 'w2', relationshipType: RelationshipType.connectedTo, sourceNode: 'b', targetNode: 'c'),
      });

  TracePath seriesPath({
    ElectricalCurrentDirection direction = ElectricalCurrentDirection.unknown,
    ElectricalReading? current,
    TracePathStep? blockingStep,
  }) =>
      TracePath(
        pathId: 'p1',
        steps: const [
          TracePathStep(terminal: ProbePoint(nodeId: 'a'), viaRelationshipId: null),
          TracePathStep(terminal: ProbePoint(nodeId: 'b'), viaRelationshipId: 'w1'),
          TracePathStep(terminal: ProbePoint(nodeId: 'c'), viaRelationshipId: 'w2'),
        ],
        conductingState: ElectricalConductingState.conducting,
        currentDirection: direction,
        current: current,
        blockingStep: blockingStep,
      );

  test('relationshipIds collects every wire on every path, and only real wires -- never fabricated', () {
    final result = TraceResult(
      target: TraceTarget.component('a'),
      mode: TraceMode.physical,
      generation: null,
      paths: [seriesPath()],
      sourceTerminals: const {},
      returnTerminals: const {},
      componentIds: const {'a', 'b', 'c'},
      relationshipIds: const {'w1', 'w2'},
      terminalsVisited: const {},
      spliceComponentIds: const {},
      connectorComponentIds: const {},
      diagnostics: const [],
    );

    final plan = buildTraceHighlightPlan(twoWireGraph(), result);
    expect(plan.relationshipIds, {'w1', 'w2'});
  });

  test('PRODUCT-READINESS-010 §17 allNodeIds mirrors TraceResult.componentIds verbatim, for Fit Circuit\'s own bounding box', () {
    final result = TraceResult(
      target: TraceTarget.component('a'),
      mode: TraceMode.physical,
      generation: null,
      paths: [seriesPath()],
      sourceTerminals: const {},
      returnTerminals: const {},
      componentIds: const {'a', 'b', 'c'},
      relationshipIds: const {'w1', 'w2'},
      terminalsVisited: const {},
      spliceComponentIds: const {},
      connectorComponentIds: const {},
      diagnostics: const [],
    );

    final plan = buildTraceHighlightPlan(twoWireGraph(), result);
    expect(plan.allNodeIds, {'a', 'b', 'c'});
  });

  test('source/return node ids come straight from TraceResult.sourceTerminals/returnTerminals', () {
    final result = TraceResult(
      target: TraceTarget.component('a'),
      mode: TraceMode.conducting,
      generation: null,
      paths: [seriesPath()],
      sourceTerminals: {const ProbePoint(nodeId: 'a')},
      returnTerminals: {const ProbePoint(nodeId: 'c')},
      componentIds: const {'a', 'b', 'c'},
      relationshipIds: const {'w1', 'w2'},
      terminalsVisited: const {},
      spliceComponentIds: const {},
      connectorComponentIds: const {},
      diagnostics: const [],
    );

    final plan = buildTraceHighlightPlan(twoWireGraph(), result);
    expect(plan.sourceNodeIds, {'a'});
    expect(plan.returnNodeIds, {'c'});
  });

  test('§16 a blocked path reports the blocking component id, not merely "no path"', () {
    const blockingStep = TracePathStep(terminal: ProbePoint(nodeId: 'b'), viaRelationshipId: 'w1');
    final result = TraceResult(
      target: TraceTarget.component('a'),
      mode: TraceMode.conducting,
      generation: null,
      paths: [seriesPath(blockingStep: blockingStep)],
      sourceTerminals: const {},
      returnTerminals: const {},
      componentIds: const {'a', 'b'},
      relationshipIds: const {'w1'},
      terminalsVisited: const {},
      spliceComponentIds: const {},
      connectorComponentIds: const {},
      diagnostics: const [],
    );

    final plan = buildTraceHighlightPlan(twoWireGraph(), result);
    expect(plan.blockedNodeIds, {'b'});
  });

  group('§12/§13 current-flow direction -- derived exclusively from TracePath.currentDirection/current', () {
    test('sourceToDestination (forward along the path) maps to +1 on both wires, since both wires already run a->b, b->c (forward)', () {
      final result = TraceResult(
        target: TraceTarget.component('a'),
        mode: TraceMode.currentFlow,
        generation: null,
        paths: [
          seriesPath(direction: ElectricalCurrentDirection.sourceToDestination, current: ElectricalReading.valid(1.5, unit: 'A')),
        ],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      expect(plan.currentFlowByRelationshipId, {'w1': 1, 'w2': 1});
    });

    test('destinationToSource reverses both wires to -1 -- direction must flip when solved current reverses, never assumed left-to-right', () {
      final result = TraceResult(
        target: TraceTarget.component('a'),
        mode: TraceMode.currentFlow,
        generation: null,
        paths: [
          seriesPath(direction: ElectricalCurrentDirection.destinationToSource, current: ElectricalReading.valid(1.5, unit: 'A')),
        ],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      expect(plan.currentFlowByRelationshipId, {'w1': -1, 'w2': -1});
    });

    test('a wire traversed BACKWARD relative to its own declared sourceNode->targetNode flips sign independently of the other wire', () {
      // Path traverses c -> b -> a, but w1 is still declared a->b and w2
      // still declared b->c -- so this path walks BOTH wires backward
      // relative to their own declared source/target.
      final path = TracePath(
        pathId: 'p2',
        steps: const [
          TracePathStep(terminal: ProbePoint(nodeId: 'c')),
          TracePathStep(terminal: ProbePoint(nodeId: 'b'), viaRelationshipId: 'w2'),
          TracePathStep(terminal: ProbePoint(nodeId: 'a'), viaRelationshipId: 'w1'),
        ],
        conductingState: ElectricalConductingState.conducting,
        currentDirection: ElectricalCurrentDirection.sourceToDestination,
        current: ElectricalReading.valid(0.8, unit: 'A'),
      );
      final result = TraceResult(
        target: TraceTarget.component('c'),
        mode: TraceMode.currentFlow,
        generation: null,
        paths: [path],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      // Traversal c->b uses w2 (declared b->c) backward -> -1.
      // Traversal b->a uses w1 (declared a->b) backward -> -1.
      expect(plan.currentFlowByRelationshipId, {'w1': -1, 'w2': -1});
    });

    test('§12 "none" direction (conducting, zero current) is never animated -- nothing meaningful to show', () {
      final result = TraceResult(
        target: TraceTarget.component('a'),
        mode: TraceMode.currentFlow,
        generation: null,
        paths: [seriesPath(direction: ElectricalCurrentDirection.none, current: ElectricalReading.valid(0, unit: 'A'))],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      expect(plan.currentFlowByRelationshipId, isEmpty);
    });

    test('§12 unknown current is never animated', () {
      final result = TraceResult(
        target: TraceTarget.component('a'),
        mode: TraceMode.currentFlow,
        generation: null,
        paths: [seriesPath(direction: ElectricalCurrentDirection.sourceToDestination, current: ElectricalReading.unknown())],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      expect(plan.currentFlowByRelationshipId, isEmpty);
    });

    test('§12 a conducting (non-currentFlow) trace never populates current-flow direction, even with a stray current value', () {
      final result = TraceResult(
        target: TraceTarget.component('a'),
        mode: TraceMode.conducting,
        generation: null,
        paths: [seriesPath(direction: ElectricalCurrentDirection.sourceToDestination, current: ElectricalReading.valid(1.5, unit: 'A'))],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {'a', 'b', 'c'},
        relationshipIds: const {'w1', 'w2'},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

      final plan = buildTraceHighlightPlan(twoWireGraph(), result);
      expect(plan.currentFlowByRelationshipId, isEmpty);
    });
  });

  test('§24 parallel branches (two separate TracePaths) both contribute their own wires -- never collapsed into one series path', () {
    final parallelGraph = EngineeringGraph(id: 'g', nodes: {
      'source': const EngineeringNode(id: 'source', category: NodeCategory.component, displayName: 'Source'),
      'splice': const EngineeringNode(id: 'splice', category: NodeCategory.component, displayName: 'Splice'),
      'lh': const EngineeringNode(id: 'lh', category: NodeCategory.component, displayName: 'LH'),
      'rh': const EngineeringNode(id: 'rh', category: NodeCategory.component, displayName: 'RH'),
      'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
    }, relationships: {
      'wSplice': const EngineeringRelationship(id: 'wSplice', relationshipType: RelationshipType.connectedTo, sourceNode: 'source', targetNode: 'splice'),
      'wLh': const EngineeringRelationship(id: 'wLh', relationshipType: RelationshipType.connectedTo, sourceNode: 'splice', targetNode: 'lh'),
      'wRh': const EngineeringRelationship(id: 'wRh', relationshipType: RelationshipType.connectedTo, sourceNode: 'splice', targetNode: 'rh'),
      'wLhGnd': const EngineeringRelationship(id: 'wLhGnd', relationshipType: RelationshipType.connectedTo, sourceNode: 'lh', targetNode: 'ground'),
      'wRhGnd': const EngineeringRelationship(id: 'wRhGnd', relationshipType: RelationshipType.connectedTo, sourceNode: 'rh', targetNode: 'ground'),
    });

    TracePath branch(String throughNode, String wireIn, String wireOut) => TracePath(
          pathId: 'p-$throughNode',
          steps: [
            const TracePathStep(terminal: ProbePoint(nodeId: 'source')),
            TracePathStep(terminal: ProbePoint(nodeId: 'splice'), viaRelationshipId: 'wSplice'),
            TracePathStep(terminal: ProbePoint(nodeId: throughNode), viaRelationshipId: wireIn),
            TracePathStep(terminal: const ProbePoint(nodeId: 'ground'), viaRelationshipId: wireOut),
          ],
          conductingState: ElectricalConductingState.conducting,
        );

    final result = TraceResult(
      target: TraceTarget.component('splice'),
      mode: TraceMode.physical,
      generation: null,
      paths: [branch('lh', 'wLh', 'wLhGnd'), branch('rh', 'wRh', 'wRhGnd')],
      sourceTerminals: const {},
      returnTerminals: const {},
      componentIds: const {'source', 'splice', 'lh', 'rh', 'ground'},
      relationshipIds: const {'wSplice', 'wLh', 'wRh', 'wLhGnd', 'wRhGnd'},
      terminalsVisited: const {},
      spliceComponentIds: const {'splice'},
      connectorComponentIds: const {},
      diagnostics: const [],
    );

    final plan = buildTraceHighlightPlan(parallelGraph, result);
    expect(plan.relationshipIds, {'wSplice', 'wLh', 'wRh', 'wLhGnd', 'wRhGnd'});
  });

  test('empty result produces an empty plan', () {
    final result = TraceResult(
      target: TraceTarget.component('a'),
      mode: TraceMode.physical,
      generation: null,
      paths: const [],
      sourceTerminals: const {},
      returnTerminals: const {},
      componentIds: const {},
      relationshipIds: const {},
      terminalsVisited: const {},
      spliceComponentIds: const {},
      connectorComponentIds: const {},
      diagnostics: const [],
    );
    expect(buildTraceHighlightPlan(twoWireGraph(), result).isEmpty, isTrue);
  });
}
