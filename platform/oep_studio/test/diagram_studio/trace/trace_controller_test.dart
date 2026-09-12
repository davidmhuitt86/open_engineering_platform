import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/trace/trace_controller.dart';

/// PRODUCT-READINESS-009 §34 — [TraceController] unit tests: target/mode
/// changes, clearing, running a real trace through [TraceEngine] (never a
/// reimplementation), and the stale-result correlation guard.
void main() {
  late TraceController controller;

  setUp(() => controller = TraceController());

  EngineeringGraph seriesGraph() => EngineeringGraph(id: 'g', nodes: {
        'battery': const EngineeringNode(
          id: 'battery',
          category: NodeCategory.component,
          displayName: 'Battery',
          metadata: {'v2Category': 'power'},
          properties: {'nominalVoltageV': 12.0},
        ),
        'load': const EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load'),
        'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
      }, relationships: {
        'w1': const EngineeringRelationship(id: 'w1', relationshipType: RelationshipType.connectedTo, sourceNode: 'battery', targetNode: 'load'),
        'w2': const EngineeringRelationship(id: 'w2', relationshipType: RelationshipType.connectedTo, sourceNode: 'load', targetNode: 'ground'),
      });

  test('starts with no target, physical mode, no result', () {
    expect(controller.target, isNull);
    expect(controller.mode, TraceMode.physical);
    expect(controller.result, isNull);
  });

  test('setTarget/setMode invalidate any prior result', () {
    controller.setTarget(TraceTarget.component('load'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());
    expect(controller.result, isNotNull);

    controller.setMode(TraceMode.conducting);
    expect(controller.result, isNull, reason: 'a mode change must clear the now-stale physical-mode result');
  });

  test('runTrace with no target is a no-op', () {
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());
    expect(controller.result, isNull);
  });

  test('§1/§41 runTrace against a real graph produces a real TraceEngine result, never a fabricated one', () {
    controller.setTarget(TraceTarget.component('battery'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());

    expect(controller.result, isNotNull);
    expect(controller.result!.mode, TraceMode.physical);
    expect(controller.result!.isEmpty, isFalse);
    expect(controller.result!.componentIds, containsAll(<String>{'battery', 'load', 'ground'}));
  });

  test('§29 a relationship (wire) target remains fully supported, resolved through the same TraceEngine normalization', () {
    controller.setTarget(TraceTarget.relationship('w1'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());

    expect(controller.result, isNotNull);
    expect(controller.result!.relationshipIds, contains('w1'));
    expect(controller.result!.componentIds, containsAll(<String>{'battery', 'load'}));
  });

  test('§6 a terminal target (a specific ProbePoint, not a whole component) is honored, never widened back to the whole component', () {
    controller.setTarget(TraceTarget.terminal(const ProbePoint(nodeId: 'battery', portId: 'p1')));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());

    expect(controller.result, isNotNull);
    expect(controller.result!.target.kind, TraceTargetKind.terminal);
    expect(controller.result!.target.terminal, const ProbePoint(nodeId: 'battery', portId: 'p1'));
  });

  test('§6 conducting mode solves first, then traces the solved state -- never a UI-side reimplementation', () {
    controller.setTarget(TraceTarget.component('battery'));
    controller.setMode(TraceMode.conducting);
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());

    expect(controller.result, isNotNull);
    expect(controller.result!.mode, TraceMode.conducting);
  });

  test('clear() resets target and result', () {
    controller.setTarget(TraceTarget.component('battery'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());
    expect(controller.result, isNotNull);

    controller.clear();
    expect(controller.target, isNull);
    expect(controller.result, isNull);
  });

  test('§9-equivalent: an older, now-superseded trace request never overwrites a newer one', () {
    // Conducting mode (not the default physical mode) so the outer
    // `runTrace` call really does invoke `solver.solve(...)` -- physical
    // mode never solves at all, so the reentrancy below would never fire.
    controller.setTarget(TraceTarget.component('battery'));
    controller.setMode(TraceMode.conducting);

    final reentrantSolver = _ReentrantOnceElectricalSolver(onFirstSolve: () {
      // Simulates a newer trace request (e.g. a target change, or a live
      // operating-context update) landing while the outer trace's own
      // solve is still "in flight."
      controller.setTarget(TraceTarget.component('load'));
      controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());
    });

    controller.runTrace(graph: seriesGraph(), solver: reentrantSolver);

    expect(controller.result, isNotNull, reason: 'the newer, reentrant trace\'s own result must still be displayed');
    expect(controller.result!.target.componentId, 'load', reason: 'never overwritten by the stale outer (battery/conducting) request');
    expect(reentrantSolver.solveCallCount, 1, reason: 'the outer solve ran once; its own result was correctly discarded, not that it never ran');
  });
}

/// Real [ElectricalSolver] subclass (delegates to `super.solve` for the
/// actual computation) that reaches back into the controller before
/// returning, the same reentrancy technique
/// `multimeter_controller_test.dart`'s own §9/§30 stale-result test uses
/// to reproduce a genuine out-of-order completion against a solver that is
/// otherwise fully synchronous.
class _ReentrantOnceElectricalSolver extends ElectricalSolver {
  _ReentrantOnceElectricalSolver({required this.onFirstSolve});

  final void Function() onFirstSolve;
  int solveCallCount = 0;

  @override
  SolvedElectricalState solve(
    EngineeringGraph graph,
    ElectricalOperatingContext operatingContext, {
    required ElectricalSolutionGenerationCounter generationCounter,
  }) {
    solveCallCount++;
    if (solveCallCount == 1) onFirstSolve();
    return super.solve(graph, operatingContext, generationCounter: generationCounter);
  }
}
