import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

import 'simulation_test_fixtures.dart';

/// Integration-style tests against a REAL `SimulationEngine` (pure Dart,
/// no FFI — confirmed by `oep_engine/lib/core/simulation/simulation_engine.dart`'s
/// own imports, which are all relative `oep_engine` sources, no
/// `dart:ffi`). No mocks/fakes: this exercises the exact same engine
/// `EngineeringEngine.create()` registers, through the exact same
/// `DiagramSimulationService` facade Diagram Studio's UI uses.
void main() {
  late SimulationEngine engine;
  late DiagramSimulationService service;
  late EngineeringGraph graph;

  setUp(() {
    engine = SimulationEngine();
    service = DiagramSimulationService(engine: engine);
    graph = buildSimulationTestGraph();
  });

  test('createSession computes real power/ground propagation with no engineering logic in Studio', () async {
    final session = await service.createSession(graph, name: 'baseline');
    expect(service.currentSessionId, session.id);
    expect(service.hasSession, isTrue);

    // battery -[suppliesPower]-> fuse1 -[connectedTo]-> lamp: lamp is powered.
    expect(session.state.isPowered('lamp'), isTrue);
    // chassis (NodeCategory.ground) -[connectedTo]-> lamp: lamp is grounded.
    expect(session.state.isGrounded('lamp'), isTrue);
    expect(session.state.isFunctional('lamp'), isTrue);
  });

  test('injectFault(openCircuit) on the fuse->lamp wire blocks power propagation, verified via real engine recompute', () async {
    await service.createSession(graph, name: 'fault-scenario');
    await service.injectFault(SimulationFault(
      id: 'f1',
      type: SimulationFaultType.openCircuit,
      targetId: 'r_fuse_lamp',
      isRelationship: true,
      injectedAt: DateTime(2026),
    ));

    final snapshot = await service.run();
    expect(snapshot.isPowered('lamp'), isFalse, reason: 'open circuit on the supplying wire must block propagation');
    expect(snapshot.isGrounded('lamp'), isTrue, reason: 'ground path is unaffected by a fault on the power wire');

    final faultReport = await service.faultReport();
    expect(faultReport.activeFaultCount, 1);
    expect(faultReport.impacts.single.blockedNodeIds, contains('lamp'));

    await service.restoreNormal();
    final restored = await service.run();
    expect(restored.isPowered('lamp'), isTrue, reason: 'restoreNormal must clear the fault overlay');
  });

  test('playback: step/reset/timeline reflect real SimulationSession state, never independently-tracked local state', () async {
    await service.createSession(graph, name: 'playback');
    await service.injectFault(SimulationFault(
      id: 'f2',
      type: SimulationFaultType.missingGround,
      targetId: 'lamp',
      injectedAt: DateTime(2026),
    ));
    final timelineAfterFault = await service.timeline();
    expect(timelineAfterFault, hasLength(1));
    expect(service.currentSession!.playbackPosition, 1);

    await service.reset();
    expect(service.currentSession!.playbackPosition, 0);
    expect(service.currentSession!.activeFaults.isEmpty, isTrue, reason: 'reset returns to position 0 == no faults applied yet');

    await service.step();
    expect(service.currentSession!.playbackPosition, 1);
    expect(service.currentSession!.activeFaults.isEmpty, isFalse, reason: 'stepping forward re-applies the recorded fault event');
  });

  test('bookmarks + replay round-trip through the real engine', () async {
    await service.createSession(graph);
    await service.addBookmark('start');
    await service.injectFault(SimulationFault(
      id: 'f3',
      type: SimulationFaultType.openCircuit,
      targetId: 'r_fuse_lamp',
      isRelationship: true,
      injectedAt: DateTime(2026),
    ));
    expect(service.currentSession!.state.isPowered('lamp'), isFalse);

    await service.jumpToBookmark('start');
    expect(service.currentSession!.state.isPowered('lamp'), isTrue, reason: 'bookmark predates the fault injection event');

    await service.replay();
    expect(service.currentSession!.state.isPowered('lamp'), isFalse, reason: 'replay with no bookmark returns to the end of history');
  });

  test('verification/diagnostics reports are all genuinely computed by the engine, not fabricated in Studio', () async {
    await service.createSession(graph);
    final verification = await service.verify();
    expect(verification, isA<VerificationReport>());

    final powerReport = await service.powerReport();
    expect(powerReport.reachableNodeIds, containsAll(['battery', 'fuse1', 'lamp']));

    final groundReport = await service.groundReport();
    expect(groundReport.reachableNodeIds, containsAll(['chassis', 'lamp']));

    final simReport = await service.simulationReport();
    expect(simReport.totalNodeCount, graph.nodes.length);
    expect(simReport.functionalNodeCount, greaterThan(0));

    final propagation = await service.propagationReport('lamp');
    expect(propagation.reachable, isTrue);
    expect(propagation.path, isNotEmpty);
  });

  test('power distribution view is sourced directly from PowerDistributionCalculator', () async {
    await service.createSession(graph);
    final view = await service.powerDistribution();
    expect(view.poweredDeviceIds, contains('lamp'));
    expect(view.fusePaths, isNotEmpty);
  });

  test('session management: duplicate/compare/export/import/delete all operate on real sessions', () async {
    final original = await service.createSession(graph, name: 'original');
    final duplicate = await service.duplicateSession(name: 'clone');
    expect(duplicate.id, isNot(original.id));
    expect(service.currentSessionId, duplicate.id);

    await service.injectFault(SimulationFault(
      id: 'f4',
      type: SimulationFaultType.openCircuit,
      targetId: 'r_fuse_lamp',
      isRelationship: true,
      injectedAt: DateTime(2026),
    ));

    final compare = await service.compareSessions(original.id, duplicate.id);
    expect(compare.identical, isFalse);
    expect(compare.differences.map((d) => d.nodeId), contains('lamp'));

    final exported = await service.exportSession();
    await service.resumeSession(original.id);
    expect(service.currentSessionId, original.id);

    final reimported = await service.importSession(exported, graph);
    expect(reimported.id, duplicate.id);

    await service.deleteSession(original.id);
    expect(engine.getSession(original.id), isNull);
  });
}
