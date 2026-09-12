import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/instruments/history/measurement_history_store.dart';
import 'package:oep_studio/diagram_studio/instruments/bookmarks/measurement_bookmark_store.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

import '../simulation/simulation_test_fixtures.dart';

/// Integration-style tests against a REAL `SimulationEngine`/
/// `DiagramSimulationService`, no mocks — same convention
/// `diagram_simulation_service_test.dart` already established. Every
/// history/bookmark test cleans up the real on-disk file it touches
/// (`MeasurementHistoryStore`/`MeasurementBookmarkStore` have no
/// directory-override, matching `WorkspaceStateStorage`'s own precedent).
///
/// PRODUCT-READINESS-002 Phase 11.14 — `MultimeterController` here is
/// deliberately still exercised against `DiagramSimulationService`/
/// `MeasurementEngine`, unchanged: this controller has no V2/WebView
/// awareness at all (by design — see its own class doc comment) and is
/// not part of the `measurementRequested` bridge path that was moved
/// onto the live V2 solver (`legacy_v2_live_measurement_bridge_test.dart`).
/// `MeasurementEngine` remains genuinely correct — just reachability-only,
/// not a circuit solver — for whatever this controller is pointed at;
/// wiring it to receive live V2-solver-backed results is deliberately
/// deferred (see PRODUCT-READINESS-002's own final report, "Remaining
/// Gaps") rather than done here by fabricating a `MeasurementResult` this
/// engine didn't actually compute.
void main() {
  late SimulationEngine engine;
  late DiagramSimulationService service;
  late MultimeterController controller;

  setUp(() async {
    engine = SimulationEngine();
    service = DiagramSimulationService(engine: engine);
    await service.createSession(buildSimulationTestGraph(), name: 'multimeter-test');
    controller = MultimeterController(simulationService: service);
  });

  tearDown(() => controller.dispose());

  group('PRODUCT-READINESS-007 §6 -- native Engine electrical measurement path (additive)', () {
    EngineeringGraph electricalFixtureGraph() => EngineeringGraph(
          id: 'elec-g1',
          nodes: {
            'battery': const EngineeringNode(
              id: 'battery',
              category: NodeCategory.component,
              displayName: 'Battery',
              metadata: {'v2Category': 'power'},
              properties: {'nominalVoltageV': 12.0},
            ),
            'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
          },
          relationships: {
            'w1': const EngineeringRelationship(id: 'w1', relationshipType: RelationshipType.connectedTo, sourceNode: 'battery', targetNode: 'ground'),
          },
        );

    test('measureElectrical() takes a real reading through ElectricalSolver + ElectricalMeasurementQuery -- never SimulationEngine', () async {
      controller
        ..setProbeA(const ProbePoint(nodeId: 'battery'))
        ..setProbeB(const ProbePoint(nodeId: 'ground'))
        ..setType(MeasurementType.voltageDc);
      expect(controller.electricalResult, isNull, reason: 'a mode/probe change clears any prior electrical result');

      await controller.measureElectrical(
        graph: electricalFixtureGraph(),
        solver: const ElectricalSolver(),
        generationCounter: ElectricalSolutionGenerationCounter(),
      );

      expect(controller.electricalResult, isNotNull);
      expect(controller.electricalResult!.reading.isValid, isTrue);
      expect(controller.electricalResult!.reading.value, 12.0);
      // The OLD, reachability-based path is untouched by this call.
      expect(controller.latestResult, isNull);
    });

    test('measureElectrical() against a genuinely floating pair (no wire path to any source or reference) honestly reports UNREACHED', () async {
      // Two isolated nodes, no relationships at all -- neither reaches a
      // source nor a reference by any path, so this is unambiguously
      // UNREACHED (distinct from `buildSimulationTestGraph()`'s own
      // battery/lamp/fuse/chassis, which -- though it declares no real
      // source either -- ARE wire-connected to the real chassis-ground
      // reference node, and per the Engine's own "single boundary, zero
      // current" rule correctly settle at a real, valid 0V, not
      // UNREACHED; see `ELECTRICAL_SOLUTION_ENGINE.md`'s own PRODUCT-
      // READINESS-006B section for the same principle applied to TRX300).
      final floatingGraph = EngineeringGraph(id: 'floating', nodes: {
        'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
        'b': const EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B'),
      }, relationships: const {});

      controller
        ..setProbeA(const ProbePoint(nodeId: 'a'))
        ..setProbeB(const ProbePoint(nodeId: 'b'))
        ..setType(MeasurementType.voltageDc);

      await controller.measureElectrical(
        graph: floatingGraph,
        solver: const ElectricalSolver(),
        generationCounter: ElectricalSolutionGenerationCounter(),
      );

      expect(controller.electricalResult!.reading.state, ElectricalReadingState.unreached);
      expect(controller.electricalResult!.reading.value, isNull);
    });

    test('§6.9 changing a probe or the mode clears the current electrical result', () async {
      controller
        ..setProbeA(const ProbePoint(nodeId: 'battery'))
        ..setProbeB(const ProbePoint(nodeId: 'ground'))
        ..setType(MeasurementType.voltageDc);
      await controller.measureElectrical(
        graph: electricalFixtureGraph(),
        solver: const ElectricalSolver(),
        generationCounter: ElectricalSolutionGenerationCounter(),
      );
      expect(controller.electricalResult, isNotNull);

      controller.setProbeA(const ProbePoint(nodeId: 'ground'));
      expect(controller.electricalResult, isNull);
    });

    // PRODUCT-READINESS-008 §9/§30 -- the worked stale-result example (an
    // older request 101 must never overwrite a newer request 102), proven
    // against the REAL `MultimeterController.measureElectrical`
    // correlation guard (`_electricalRequestSeq`), not a reimplementation.
    // `ElectricalSolver.solve` itself is synchronous (no `await` inside
    // `measureElectrical`), so a genuine out-of-order completion can only
    // be produced the same way any synchronous API can race: reentrantly
    // -- a solver whose own `solve()` call reaches back into the
    // controller (here, `setProbeB`, exactly as a live V2 state change
    // arriving mid-solve would) before the outer, now-superseded
    // "request 101" call reaches its own correlation check. This exercises
    // the real `if (requestSeq != _electricalRequestSeq) return;` guard,
    // not a mock of it.
    test('§9/§30 an older, now-superseded electrical request never overwrites a newer one', () async {
      controller
        ..setProbeA(const ProbePoint(nodeId: 'battery'))
        ..setProbeB(const ProbePoint(nodeId: 'ground'))
        ..setType(MeasurementType.voltageDc);

      final reentrantSolver = _ReentrantOnceElectricalSolver(
        onFirstSolve: () {
          // Simulates request 102: a mode change (the same observable
          // effect a live V2 state change forcing a re-measure would have)
          // followed by a reentrant `measureElectrical` call that reaches
          // its own correlation check -- and completes -- before request
          // 101's own check runs. (`measureElectrical` has no internal
          // `await`, so calling it here, unawaited, still runs it
          // synchronously to completion.) Deliberately a DIFFERENT mode
          // than request 101's `voltageDc` so the final displayed result
          // can be attributed to 102, not just asserted non-null.
          controller.setType(MeasurementType.resistance);
          controller.measureElectrical(
            graph: electricalFixtureGraph(),
            solver: const ElectricalSolver(),
            generationCounter: ElectricalSolutionGenerationCounter(),
          );
        },
      );

      // Request 101 -- its own correlation check runs only AFTER the
      // reentrant request 102 above has already completed and bumped
      // `_electricalRequestSeq`, so 101 must discard its own answer.
      await controller.measureElectrical(
        graph: electricalFixtureGraph(),
        solver: reentrantSolver,
        generationCounter: ElectricalSolutionGenerationCounter(),
      );

      expect(controller.electricalResult, isNotNull, reason: 'request 102\'s own valid result must still be displayed');
      expect(controller.electricalResult!.request.mode, MeasurementType.resistance, reason: 'the displayed result is request 102\'s (resistance), never overwritten by the late-checking request 101 (voltageDc)');
      expect(reentrantSolver.solveCallCount, 1, reason: 'request 101\'s own (outer) solve really ran, and only once');
    });
  });

  test('canMeasure requires both probes and a supported type', () {
    expect(controller.canMeasure, isFalse);
    controller.setProbeA(const ProbePoint(nodeId: 'battery'));
    expect(controller.canMeasure, isFalse);
    controller.setProbeB(const ProbePoint(nodeId: 'lamp'));
    expect(controller.canMeasure, isTrue);

    controller.setType(MeasurementType.capacitance);
    expect(controller.canMeasure, isFalse, reason: 'capacitance is an unsupported placeholder type');
  });

  test('measure() calls the real engine and populates latestResult with no local computation', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.voltageDc);

    await controller.measure();

    expect(controller.latestResult, isNotNull);
    expect(controller.latestResult!.reachable, isTrue);
    expect(controller.busy, isFalse);
    expect(controller.lastError, isNull);
  });

  test('measure() on an unsupported type sets lastError and does not call the engine', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.temperature);

    await controller.measure();

    expect(controller.latestResult, isNull);
    expect(controller.lastError, contains('not yet supported'));
  });

  test('continuity measurement populates highlightedPathNodeIds for path highlighting', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.continuity);

    await controller.measure();

    expect(controller.latestResult!.continuous, isTrue);
    expect(controller.highlightedPathNodeIds, isNotEmpty);
    expect(controller.highlightedPathNodeIds, containsAll(controller.latestResult!.path));
  });

  test('comparison mode result exposes difference via MeasurementResult.difference', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.voltageDc)
      ..setMode(MeasurementMode.comparison);

    await controller.measure();

    expect(controller.latestResult!.mode, MeasurementMode.comparison);
    // difference is purely derived on MeasurementResult -- this asserts
    // the controller does not recompute it independently.
    expect(controller.latestResult!.difference,
        controller.latestResult!.measuredValue == null || controller.latestResult!.expectedValue == null
            ? isNull
            : controller.latestResult!.measuredValue! - controller.latestResult!.expectedValue!);
  });

  test('setMode away from liveSimulation stops any running live timer', () {
    controller.setMode(MeasurementMode.liveSimulation);
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'));
    controller.startLive(interval: const Duration(milliseconds: 10));
    expect(controller.liveActive, isTrue);

    controller.setMode(MeasurementMode.manual);
    expect(controller.liveActive, isFalse);
  });

  test('history: measuring records an entry, replay restores state without a new engine call, clear empties it',
      () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.voltageDc);

    try {
      await controller.measure();
      expect(controller.history, isNotEmpty);
      final entry = controller.history.first;

      controller.setProbeA(null);
      controller.replay(entry);
      expect(controller.probeA?.nodeId, 'battery');
      expect(controller.latestResult, entry.result);

      final exported = controller.exportHistoryJson();
      expect(exported, contains('voltageDc'));

      await controller.clearHistory();
      expect(controller.history, isEmpty);
    } finally {
      await MeasurementHistoryStore.save(const []);
    }
  });

  test('bookmarks: add, quick recall, remove round-trip through real disk persistence', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.resistance);

    try {
      await controller.addBookmark('Battery-Lamp check', group: 'Power');
      expect(controller.bookmarks, hasLength(1));
      final bookmark = controller.bookmarks.single;
      expect(bookmark.name, 'Battery-Lamp check');
      expect(bookmark.group, 'Power');

      controller.setProbeA(null);
      controller.setProbeB(null);
      controller.recallBookmark(bookmark);
      expect(controller.probeA?.nodeId, 'battery');
      expect(controller.probeB?.nodeId, 'lamp');
      expect(controller.selectedType, MeasurementType.resistance);

      await controller.removeBookmark(bookmark.id);
      expect(controller.bookmarks, isEmpty);
    } finally {
      await MeasurementBookmarkStore.save(const []);
    }
  });

  test('relatedFindings filters a VerificationReport to findings on the measured path', () async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.voltageDc);
    await controller.measure();

    final report = VerificationReport(generatedAt: DateTime(2026), findings: const [
      VerificationFinding(
        check: VerificationCheck.power,
        severity: VerificationSeverity.warning,
        message: 'on path',
        nodeId: 'lamp',
      ),
      VerificationFinding(
        check: VerificationCheck.ground,
        severity: VerificationSeverity.info,
        message: 'off path',
        nodeId: 'chassis-unrelated',
      ),
    ]);

    final related = controller.relatedFindings(report);
    expect(related, hasLength(1));
    expect(related.single.message, 'on path');
  });

  test('relatedFindings returns empty with no result or no report', () {
    expect(controller.relatedFindings(null), isEmpty);
  });
}

/// PRODUCT-READINESS-008 §9/§30 test helper: a real [ElectricalSolver]
/// (delegates to `super.solve` for the actual computation -- never
/// fabricates a result) that runs [onFirstSolve] the first time [solve] is
/// called, before returning, to reproduce a genuine reentrant
/// "newer-request-completes-while-an-older-one-is-still-solving" race
/// against [MultimeterController]'s real correlation guard.
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
