import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// PRODUCT-READINESS-002 Phase 11 — proves [LegacyV2StateAdapter]'s
/// `measurementRequested` handling is now backed by the LIVE V2
/// electrical solver (`LiveSim.readWireMeasurement`, reached via
/// [LegacyV2Channel.queryLiveMeasurement]), not the old
/// reachability-only `MeasurementEngine`/`DiagramSimulationService` path
/// it used before.
///
/// This fake channel never runs real JS — it stands in for
/// `LiveSim.readWireMeasurement`'s answer with a canned
/// [V2LiveMeasurementResult], exactly the shape the real bridge script
/// (`legacy_v2_bridge_script.dart`'s `__oepBridgeQueryLiveMeasurement`)
/// would hand back. The solver's OWN correctness (battery isolation,
/// connector/splice pin gating, switch continuity, lamp dead-ends) is
/// covered separately by the JS-side regression suite
/// (`reference/legacy_wiring_sim_v2/eke-wiring-sim/tests/`) and the
/// TRX300 fixture test — this file's job is the BRIDGE's own
/// translation/plumbing correctness, given a solver answer.
class _MeasurementFakeChannel implements LegacyV2Channel {
  void Function(V2MeasurementRequestedMessage message)? _onMeasurementRequested;

  /// The canned answer [queryLiveMeasurement] returns; `null` (the
  /// default) simulates the bridge/WebView being unreachable.
  V2LiveMeasurementResult? nextResult;

  final List<(String, String)> queriedWireIdsAndModes = [];
  final List<(String, String, String, String, String)> appliedMeasurements = [];

  void simulateMeasurementRequested(String v2WireId, String mode) =>
      _onMeasurementRequested
          ?.call(V2MeasurementRequestedMessage(v2WireId: v2WireId, mode: mode));

  @override
  Future<V2LiveMeasurementResult?> queryLiveMeasurement(
      String v2WireId, String v2Mode) async {
    queriedWireIdsAndModes.add((v2WireId, v2Mode));
    return nextResult;
  }

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) async {
    appliedMeasurements.add((v2WireId, mode, displayValue, unit, note));
  }

  // ---- Everything else this adapter needs but this suite never
  // exercises: no-ops. ------------------------------------------------
  @override
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler) {}
  @override
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler) {}
  @override
  set onModuleDeleted(void Function(V2ModuleDeletedMessage message)? handler) {}
  @override
  set onModulePropertiesChanged(
      void Function(V2ModulePropertiesChangedMessage message)? handler) {}
  @override
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler) {}
  @override
  set onWireDeleted(void Function(V2WireDeletedMessage message)? handler) {}
  @override
  set onWireSelectionChanged(
      void Function(V2WireSelectionChangedMessage message)? handler) {}
  @override
  set onModuleSelectionChanged(
      void Function(V2ModuleSelectionChangedMessage message)? handler) {}
  @override
  set onWirePropertiesChanged(
      void Function(V2WirePropertiesChangedMessage message)? handler) {}
  @override
  set onMeasurementRequested(
          void Function(V2MeasurementRequestedMessage message)? handler) =>
      _onMeasurementRequested = handler;
  @override
  set onSaveRequested(void Function()? handler) {}

  @override
  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y) async {}
  @override
  Future<void> sendAuthoritativeModuleLabel(
      String v2ModuleId, String label) async {}
  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '',
      List<Map<String, String>> terminals = const [],
      String exit = '',
      bool? connector,
      bool? vertical,
      String? labelPos,
      String? pinLabelPos,
      String? subLabelPos,
      String? sub,
      String? labelJustify,
      String? kind,
      String? bulbStyle,
      String? bulbColor,
      bool? flipped}) async {}
  @override
  Future<void> removeModuleFromV2(String v2ModuleId) async {}
  @override
  Future<void> removeWireFromV2(String v2WireId) async {}
  @override
  Future<void> confirmWireCreated(
      String v2WireId, String label, String color) async {}
  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId,
      String toModuleId, String label, String color,
      {String fromTerminal = '',
      String toTerminal = '',
      String fromExit = '',
      String toExit = '',
      bool cable = false}) async {}
  @override
  Future<void> clearAllSurfaces() async {}
  @override
  Future<void> interceptV2Save() async {}
  @override
  Future<void> reportSaveResult(bool success, String message) async {}
  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => null;
  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) async {}
}

void main() {
  /// Builds a ready [LegacyV2StateAdapter] wired to a fresh
  /// [_MeasurementFakeChannel] — no OEP module/wire creation needed at
  /// all, since (unlike the pre-PRODUCT-READINESS-002 design) this
  /// handler no longer looks up an OEP relationship id for the V2 wire;
  /// it queries the live solver by V2's own wire id directly.
  Future<(LegacyV2StateAdapter, _MeasurementFakeChannel)> readyAdapter(
      WidgetTester tester) async {
    useIsolatedSettingsStorage();
    final (controller, _) = await bootstrapDiagramStudioController(tester);
    final channel = _MeasurementFakeChannel();
    final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
    await adapter.initializeFromDocument();
    expect(adapter.isReady, isTrue);
    return (adapter, channel);
  }

  group('V2LiveMeasurementResult.fromJson', () {
    test('round-trips every field, including nested source/reference', () {
      final result = V2LiveMeasurementResult.fromJson({
        'status': 'ok',
        'readingType': 'voltage',
        'value': 12.4,
        'unit': 'V',
        'open': false,
        'overload': false,
        'fault': false,
        'note': 'Circuit complete',
        'source': {'moduleId': 'battery-1', 'terminalId': '1'},
        'reference': {'moduleId': 'ignition-switch', 'terminalId': 'BAT1'},
        'solvedAt': 123456,
      });
      expect(result.status, 'ok');
      expect(result.readingType, 'voltage');
      expect(result.value, 12.4);
      expect(result.unit, 'V');
      expect(result.open, isFalse);
      expect(result.note, 'Circuit complete');
      expect(result.source?.moduleId, 'battery-1');
      expect(result.source?.terminalId, '1');
      expect(result.reference?.moduleId, 'ignition-switch');
      expect(result.reference?.terminalId, 'BAT1');
      expect(result.solvedAt, 123456);
    });

    test('missing source/reference decode to null, not a crash', () {
      final result = V2LiveMeasurementResult.fromJson({
        'status': 'error',
        'readingType': 'voltage',
        'value': null,
        'unit': '',
        'open': true,
        'overload': false,
        'fault': false,
        'note': 'Wire not found',
      });
      expect(result.status, 'error');
      expect(result.source, isNull);
      expect(result.reference, isNull);
      expect(result.value, isNull);
    });
  });

  testWidgets(
    'closed switch / grounded endpoint: a real numeric reading displays faithfully, not fabricated',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: 12.6, unit: 'V',
        open: false, overload: false, fault: false,
        note: 'Circuit complete',
        source: V2MeasurementEndpoint(moduleId: 'battery-1', terminalId: '1'),
        reference: V2MeasurementEndpoint(moduleId: 'left-handlebar-switch', terminalId: 'BAT2'),
        solvedAt: 1000,
      );
      channel.simulateMeasurementRequested('wire-closed-switch', 'VDC');
      await tester.pump();
      final applied = channel.appliedMeasurements.single;
      expect(applied.$1, 'wire-closed-switch');
      expect(applied.$3, '12.60');
      expect(applied.$4, 'V');
    },
  );

  testWidgets(
    'open switch measurement: OL, never fabricated as 0.00',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: null, unit: 'V',
        open: true, overload: false, fault: false,
        note: 'Open circuit — no continuity.',
        source: null, reference: null, solvedAt: 1000,
      );
      channel.simulateMeasurementRequested('wire-open-switch', 'VDC');
      await tester.pump();
      final applied = channel.appliedMeasurements.single;
      expect(applied.$3, 'OL', reason: 'an open reading must never display as a number');
      expect(applied.$3, isNot('0.00'));
    },
  );

  testWidgets(
    'open/OL is distinguishable from a genuine measured 0.00V — the hard requirement',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);

      // Genuinely reachable and measured at exactly 0V (e.g. a grounded
      // node, or a de-energized-but-connected point) -- NOT open.
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: 0.0, unit: 'V',
        open: false, overload: false, fault: false, note: 'Ground path OK — no supply voltage',
        source: null, reference: null, solvedAt: 1,
      );
      channel.simulateMeasurementRequested('wire-a', 'VDC');
      await tester.pump();
      expect(channel.appliedMeasurements.last.$3, '0.00');

      // Genuinely unreachable/open -- must NOT collapse to the same '0.00'.
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: null, unit: 'V',
        open: true, overload: false, fault: false, note: '',
        source: null, reference: null, solvedAt: 2,
      );
      channel.simulateMeasurementRequested('wire-b', 'VDC');
      await tester.pump();
      expect(channel.appliedMeasurements.last.$3, 'OL');
      expect(channel.appliedMeasurements.last.$3, isNot(channel.appliedMeasurements.first.$3),
          reason: 'a true 0.00V reading and an open/OL reading must render as visibly different values');
    },
  );

  testWidgets(
    'continuity mode: conductive -> 000, open -> OPN, never a fabricated number',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'continuity', value: 0, unit: '',
        open: false, overload: false, fault: false, note: '',
        source: null, reference: null, solvedAt: 1,
      );
      channel.simulateMeasurementRequested('wire-cont-closed', 'CONT');
      await tester.pump();
      expect(channel.appliedMeasurements.last.$3, '000');

      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'continuity', value: null, unit: '',
        open: true, overload: false, fault: false, note: '',
        source: null, reference: null, solvedAt: 2,
      );
      channel.simulateMeasurementRequested('wire-cont-open', 'CONT');
      await tester.pump();
      expect(channel.appliedMeasurements.last.$3, 'OPN');
    },
  );

  testWidgets(
    'terminal-level precision: source/reference module+terminal ids reach the caller intact',
    (tester) async {
      useIsolatedSettingsStorage();
      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final channel = _MeasurementFakeChannel();
      final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      V2LiveMeasurementResult? captured;
      String? capturedWireId;
      adapter.onLiveMeasurement = (v2WireId, v2Mode, result) {
        capturedWireId = v2WireId;
        captured = result;
      };

      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: 12.0, unit: 'V',
        open: false, overload: false, fault: false, note: '',
        source: V2MeasurementEndpoint(moduleId: 'mod-battery-1', terminalId: '1'),
        reference: V2MeasurementEndpoint(moduleId: 'ignition-switch', terminalId: '2'),
        solvedAt: 1,
      );
      channel.simulateMeasurementRequested('wire-terminal-precise', 'VDC');
      await tester.pump();

      expect(capturedWireId, 'wire-terminal-precise');
      expect(captured?.source?.moduleId, 'mod-battery-1');
      expect(captured?.source?.terminalId, '1');
      expect(captured?.reference?.moduleId, 'ignition-switch');
      expect(captured?.reference?.terminalId, '2');
    },
  );

  testWidgets(
    'bridge/WebView unreachable: "-", never a fabricated reading, and the note says so',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);
      channel.nextResult = null; // default, but explicit for clarity
      channel.simulateMeasurementRequested('wire-x', 'VDC');
      await tester.pump();
      final applied = channel.appliedMeasurements.single;
      expect(applied.$3, '—');
      expect(applied.$5, contains('unreachable'));
    },
  );

  testWidgets(
    'solver-reported error (unsupported mode / unknown wire): "-" with the solver\'s own note, not OL',
    (tester) async {
      final (_, channel) = await readyAdapter(tester);
      channel.nextResult = const V2LiveMeasurementResult(
        status: 'error', readingType: 'voltage', value: null, unit: '',
        open: true, overload: false, fault: false,
        note: 'Wire not found: wire-ghost',
        source: null, reference: null, solvedAt: null,
      );
      channel.simulateMeasurementRequested('wire-ghost', 'VDC');
      await tester.pump();
      final applied = channel.appliedMeasurements.single;
      expect(applied.$3, '—', reason: 'a solver-level error is not the same as a real open-circuit reading');
      expect(applied.$5, 'Wire not found: wire-ghost');
    },
  );

  testWidgets(
    'PRODUCT-READINESS-002 Phase 11.13: the bridge queries the live V2 solver exclusively -- '
    'no DiagramSimulationService/MeasurementEngine dependency is reachable or required for this path',
    (tester) async {
      // Deliberately constructed with NO simulationServiceResolver at all
      // (the field the old reachability-engine path depended on) -- if
      // this path still silently needed it, this test would produce the
      // OLD "No active OEP simulation session" message instead of a real
      // solver-backed answer.
      useIsolatedSettingsStorage();
      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final channel = _MeasurementFakeChannel();
      final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      channel.nextResult = const V2LiveMeasurementResult(
        status: 'ok', readingType: 'voltage', value: 5.0, unit: 'V',
        open: false, overload: false, fault: false, note: '',
        source: null, reference: null, solvedAt: 1,
      );
      channel.simulateMeasurementRequested('wire-no-resolver', 'VDC');
      await tester.pump();

      expect(channel.queriedWireIdsAndModes.single, ('wire-no-resolver', 'VDC'),
          reason: 'the bridge must reach LiveSim.readWireMeasurement (queryLiveMeasurement), not a reachability engine');
      expect(channel.appliedMeasurements.single.$3, '5.00',
          reason: 'the live-solver answer must be used even with no simulationServiceResolver configured at all');
      expect(channel.appliedMeasurements.single.$5, isNot(contains('No active OEP simulation session')),
          reason: 'this message belonged to the retired MeasurementEngine path and must never appear again on this path');
    },
  );

  testWidgets(
    'not ready: measurementRequested before initializeFromDocument is a no-op, no crash',
    (tester) async {
      useIsolatedSettingsStorage();
      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final channel = _MeasurementFakeChannel();
      // ignore: unused_local_variable
      final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
      channel.simulateMeasurementRequested('wire-too-early', 'VDC');
      await tester.pump();
      expect(channel.queriedWireIdsAndModes, isEmpty);
      expect(channel.appliedMeasurements, isEmpty);
    },
  );
}
