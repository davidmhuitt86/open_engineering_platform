import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-005: exercises the SimulationEngine facade -- sessions, playback,
/// timeline/bookmarks/replay, fault injection, diagnostics, compare, and
/// export/import round-tripping. Also carries the item-7 legacy regression
/// scenarios re-derived against this new engine (see the two `group`s at
/// the bottom), NOT by running any legacy code.
void main() {
  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g1',
      nodes: {
        'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
        'starterRelay': const EngineeringNode(id: 'starterRelay', category: NodeCategory.relay, displayName: 'Starter Relay'),
        'starterMotor': const EngineeringNode(id: 'starterMotor', category: NodeCategory.actuator, displayName: 'Starter Motor'),
        'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
      },
      relationships: {
        'r1': const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'battery',
          targetNode: 'starterRelay',
        ),
        'r2': const EngineeringRelationship(
          id: 'r2',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'starterRelay',
          targetNode: 'starterMotor',
        ),
        'r3': const EngineeringRelationship(
          id: 'r3',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'chassisGround',
          targetNode: 'starterMotor',
        ),
      },
    );
  }

  /// A variant of [buildGraph] where the starter motor is DIRECTLY targeted
  /// by `suppliesPower`/`grounds` relationships (rather than reached only
  /// via `connectedTo` propagation) -- required so `VerificationEngine`'s
  /// power/ground checks (which key off the relationship TYPE targeting a
  /// node, not mere reachability) actually fire findings for it. Used by
  /// the legacy regression scenarios below, which need real verification
  /// findings to appear/disappear as faults are injected/cleared.
  EngineeringGraph buildIgnitionGraph() {
    return EngineeringGraph(
      id: 'g-ignition',
      nodes: {
        'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
        'starterMotor': const EngineeringNode(id: 'starterMotor', category: NodeCategory.actuator, displayName: 'Starter Motor'),
        'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
      },
      relationships: {
        'r1': const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'battery',
          targetNode: 'starterMotor',
        ),
        'r2': const EngineeringRelationship(
          id: 'r2',
          relationshipType: RelationshipType.grounds,
          sourceNode: 'chassisGround',
          targetNode: 'starterMotor',
        ),
      },
    );
  }

  group('SimulationEngine sessions', () {
    test('createSession computes an initial baseline state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), name: 'baseline');
      expect(session.name, 'baseline');
      expect(session.state.isFunctional('starterMotor'), isTrue);
      expect(engine.getSession(session.id), isNotNull);
    });

    test('duplicateSession copies history/bookmarks but gets a new id', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      engine.addBookmark(session.id, 'faulted');

      final dup = engine.duplicateSession(session.id, name: 'dup');
      expect(dup.id, isNot(session.id));
      expect(dup.history.length, session.history.length);
      expect(dup.bookmarks.map((b) => b.label), contains('faulted'));
      expect(dup.state.isFunctional('starterMotor'), isFalse);
    });

    test('deleteSession removes it from the registry', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.deleteSession(session.id);
      expect(engine.getSession(session.id), isNull);
    });

    test('exportSession / importSession round-trips faults, history and bookmarks', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final session = engine.createSession(graph);
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      engine.addBookmark(session.id, 'after-fault');

      final json = engine.exportSession(session.id);
      final restored = engine.importSession(json, graph);

      expect(restored.id, session.id);
      expect(restored.history.length, session.history.length);
      expect(restored.bookmarks.map((b) => b.label), contains('after-fault'));
      expect(restored.state.isFunctional('starterMotor'), isFalse, reason: 'the fault event replays deterministically');
    });
  });

  group('SimulationEngine playback / timeline / bookmarks / replay', () {
    test('step/reset move the playback position deterministically', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      expect(session.state.isFunctional('starterMotor'), isFalse);

      engine.reset(session.id);
      expect(session.playbackPosition, 0);
      expect(session.state.isFunctional('starterMotor'), isTrue, reason: 'no faults are active at playback position 0');

      await engine.step(session.id);
      expect(session.playbackPosition, 1);
      expect(session.state.isFunctional('starterMotor'), isFalse, reason: 'stepping forward replays the fault-injection event');
    });

    test('run() returns the current deterministic snapshot without changing playback position', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      final before = session.playbackPosition;
      final result = await engine.run(session.id);
      expect(result.isFunctional('starterMotor'), isTrue);
      expect(session.playbackPosition, before);
    });

    test('bookmarks and jumpToBookmark restore exact playback position', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.addBookmark(session.id, 'start');
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      expect(session.state.isFunctional('starterMotor'), isFalse);

      engine.jumpToBookmark(session.id, 'start');
      expect(session.playbackPosition, 0);
      expect(session.state.isFunctional('starterMotor'), isTrue);
    });

    test('replay from start reproduces the same final state deterministically', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      final finalState = session.state;

      engine.reset(session.id);
      engine.replay(session.id);
      expect(session.state.isFunctional('starterMotor'), finalState.isFunctional('starterMotor'));
      expect(session.playbackPosition, session.history.length);
    });

    test('play() streams recomputed states for each remaining history step', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      engine.reset(session.id);

      final states = await engine.play(session.id).toList();
      expect(states, hasLength(1));
      expect(states.last.isFunctional('starterMotor'), isFalse);
      expect(session.playbackPosition, session.history.length);
    });
  });

  group('SimulationEngine fault injection', () {
    test('injectFault / clearFault / restoreNormal all recompute deterministically', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.relayFailure, targetId: 'starterRelay', injectedAt: DateTime(2026)));
      expect(session.state.isFunctional('starterMotor'), isFalse);

      engine.clearFault(session.id, 'f1');
      expect(session.activeFaults.isEmpty, isTrue);
      expect(session.state.isFunctional('starterMotor'), isTrue);

      engine.injectFault(session.id, SimulationFault(id: 'f2', type: SimulationFaultType.missingGround, targetId: 'starterMotor', injectedAt: DateTime(2026)));
      engine.restoreNormal(session.id);
      expect(session.activeFaults.isEmpty, isTrue);
      expect(session.state.isFunctional('starterMotor'), isTrue);
    });
  });

  group('SimulationEngine diagnostics', () {
    test('faultReport lists active faults and what they block', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      final report = engine.faultReport(session.id);
      expect(report.activeFaultCount, 1);
      expect(report.impacts.first.blockedNodeIds, contains('starterMotor'));
    });

    test('propagationReport finds the power path to a reachable node', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      final report = engine.propagationReport(session.id, 'starterMotor');
      expect(report.reachable, isTrue);
      expect(report.path.first, 'battery');
      expect(report.path.last, 'starterMotor');
    });

    test('powerReport / groundReport partition nodes by reachability', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      final power = engine.powerReport(session.id);
      final ground = engine.groundReport(session.id);
      expect(power.reachableNodeIds, containsAll(['starterRelay', 'starterMotor']));
      expect(ground.reachableNodeIds, contains('starterMotor'));
    });

    test('simulationReport summarizes session state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), name: 'demo');
      final report = engine.simulationReport(session.id);
      expect(report.sessionName, 'demo');
      expect(report.verificationPassed, isTrue);
      expect(report.totalNodeCount, 4);
    });

    test('verify() runs full verification against the session\'s current state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      final report = engine.verify(session.id);
      expect(report.passed, isTrue);
    });
  });

  group('SimulationEngine compareSessions', () {
    test('compares two sessions\' final snapshots and reports node-level differences', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final baseline = engine.createSession(graph, name: 'baseline');
      final faulted = engine.createSession(graph, name: 'faulted');
      engine.injectFault(faulted.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));

      final diff = engine.compareSessions(baseline.id, faulted.id);
      expect(diff.identical, isFalse);
      final motorDiff = diff.differences.firstWhere((d) => d.nodeId == 'starterMotor');
      expect(motorDiff.poweredA, isTrue);
      expect(motorDiff.poweredB, isFalse);
    });

    test('identical sessions produce an empty diff', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final a = engine.createSession(graph);
      final b = engine.createSession(graph);
      final diff = engine.compareSessions(a.id, b.id);
      expect(diff.identical, isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Legacy Regression Scenarios (AP-DS-005 item 7 / testing requirement).
  // Re-derived against SimulationEngine's own API from the scenario SHAPE
  // of the legacy reference's tests -- not by running/porting any legacy
  // code. See SIMULATION_TRACEABILITY_MATRIX.md for the two named rows.
  // ---------------------------------------------------------------------

  group('Legacy regression: simulator-test.js scenario (state transitions + diagnose + fault + re-diagnose)', () {
    test('key-off -> on -> cranking, baseline diagnose, inject open circuit, re-diagnose, clear fault restores baseline', () {
      final engine = SimulationEngine();
      final graph = buildIgnitionGraph();
      final session = engine.createSession(graph, name: 'ignition-scenario');

      // State transitions: key-off -> on -> cranking, modeled as
      // conditionChanged events on the timeline (this engine models
      // ignition state as a domain-specific condition, not a built-in
      // enum -- see `SimulationEvent.conditionKey` doc).
      session.changeCondition('ignition', 'off');
      session.changeCondition('ignition', 'on');
      session.changeCondition('ignition', 'cranking');
      expect(session.history.map((e) => e.conditionValue), containsAllInOrder(['off', 'on', 'cranking']));

      // Baseline diagnose: verification passes, starter motor functional.
      final baseline = engine.verify(session.id);
      expect(baseline.passed, isTrue);
      expect(session.state.isFunctional('starterMotor'), isTrue);

      // Inject an open-circuit fault (battery-to-motor power feed).
      engine.injectFault(session.id, SimulationFault(
        id: 'open-1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r1',
        isRelationship: true,
        injectedAt: DateTime(2026),
        label: 'battery-to-motor power feed open',
      ));

      // Re-diagnose: confirm new findings (power/continuity error on the
      // starter motor) that were not present at baseline.
      final afterFault = engine.verify(session.id);
      expect(afterFault.passed, isFalse);
      expect(afterFault.findingsFor(VerificationCheck.power).map((f) => f.nodeId), contains('starterMotor'));
      expect(session.state.isFunctional('starterMotor'), isFalse);

      // Clear the fault -- verify restored baseline.
      engine.clearFault(session.id, 'open-1');
      final restored = engine.verify(session.id);
      expect(restored.passed, isTrue);
      expect(session.state.isFunctional('starterMotor'), isTrue);
    });
  });

  group('Legacy regression: fault-reasoner-test.js scenario shape (multi-symptom vs empty-symptom diagnosis)', () {
    test('multiple simultaneous faults produce multiple verification findings (multi-symptom candidates)', () {
      final engine = SimulationEngine();
      final graph = buildIgnitionGraph();
      final session = engine.createSession(graph);

      engine.injectFault(session.id, SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r1', isRelationship: true, injectedAt: DateTime(2026)));
      engine.injectFault(session.id, SimulationFault(id: 'f2', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));

      final report = engine.verify(session.id);
      expect(report.errorCount, greaterThanOrEqualTo(1));
      final faultReport = engine.faultReport(session.id);
      expect(faultReport.activeFaultCount, 2);
    });

    test('empty-symptom baseline (no faults) yields zero verification errors', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph());
      final report = engine.verify(session.id);
      expect(report.errorCount, 0);
      expect(report.passed, isTrue);
    });
  });
}
