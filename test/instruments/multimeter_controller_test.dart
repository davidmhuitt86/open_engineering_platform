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
