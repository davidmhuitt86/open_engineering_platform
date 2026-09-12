import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';
import 'package:oep_studio/diagram_studio/webview/v2_measurement_bridge.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// PRODUCT-READINESS-007 §8/§9 — proves the NEW native-Engine-backed V2
/// measurement path (`v2WireMeasurementTerminals`/`measureV2WireViaNativeEngine`),
/// additive alongside the existing LiveSim-backed
/// `legacy_v2_live_measurement_bridge_test.dart` path, which this file
/// does not touch or duplicate.
class _BridgeFakeChannel implements LegacyV2Channel {
  void Function(V2ModuleCreatedMessage message)? _onModuleCreated;
  void Function(V2WireCreatedMessage message)? _onWireCreated;
  void Function(V2OperatingStateChangedMessage message)? _onOperatingStateChanged;

  void simulateModuleCreated(V2ModuleCreatedMessage message) => _onModuleCreated?.call(message);
  void simulateWireCreated(V2WireCreatedMessage message) => _onWireCreated?.call(message);
  void simulateOperatingStateChanged(V2OperatingStateChangedMessage message) =>
      _onOperatingStateChanged?.call(message);

  @override
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler) => _onModuleCreated = handler;
  @override
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler) => _onWireCreated = handler;

  @override
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler) {}
  @override
  set onModuleDeleted(void Function(V2ModuleDeletedMessage message)? handler) {}
  @override
  set onModulePropertiesChanged(void Function(V2ModulePropertiesChangedMessage message)? handler) {}
  @override
  set onWireDeleted(void Function(V2WireDeletedMessage message)? handler) {}
  @override
  set onWireSelectionChanged(void Function(V2WireSelectionChangedMessage message)? handler) {}
  @override
  set onModuleSelectionChanged(void Function(V2ModuleSelectionChangedMessage message)? handler) {}
  @override
  set onWirePropertiesChanged(void Function(V2WirePropertiesChangedMessage message)? handler) {}
  @override
  set onMeasurementRequested(void Function(V2MeasurementRequestedMessage message)? handler) {}
  @override
  set onOperatingStateChanged(void Function(V2OperatingStateChangedMessage message)? handler) =>
      _onOperatingStateChanged = handler;
  @override
  set onSaveRequested(void Function()? handler) {}
  @override
  set onEngineeringCommand(void Function(String command)? handler) {}

  @override
  Future<V2LiveMeasurementResult?> queryLiveMeasurement(String v2WireId, String v2Mode) async => null;
  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode, String displayValue, String unit, String note) async {}
  @override
  Future<void> sendAuthoritativeModulePosition(String v2ModuleId, double x, double y) async {}
  @override
  Future<void> sendAuthoritativeModuleLabel(String v2ModuleId, String label) async {}
  @override
  Future<void> restoreModule(String v2ModuleId, String label, String category, double x, double y,
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
  Future<void> confirmWireCreated(String v2WireId, String label, String color) async {}
  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId, String toModuleId, String label, String color,
      {String fromTerminal = '', String toTerminal = '', String fromExit = '', String toExit = '', bool cable = false}) async {}
  @override
  Future<void> clearAllSurfaces() async {}
  @override
  Future<void> interceptV2Save() async {}
  @override
  Future<void> reportSaveResult(bool success, String message) async {}
  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => null;
  @override
  Future<void> restoreWireRouteOffsets(String v2WireId, Map<String, double> offsets) async {}
  @override
  Future<void> applyTraceHighlight(List<String> wireIds, List<String> sourceModuleIds,
      List<String> returnModuleIds, List<String> blockedModuleIds, Map<String, int> currentFlowByWireId) async {}
  @override
  Future<void> clearTraceHighlight() async {}

  /// PRODUCT-READINESS-010 §17 — no-op: not exercised by this test.
  @override
  Future<void> fitToTraceHighlight(List<String> nodeIds) async {}
}

void main() {
  group('v2WireEndpointProbePoint / normalizeV2PortRef (pure, no WebView)', () {
    test('normalizes real V2 _IN/_OUT connector-pin suffixes and the SPLICE sentinel', () {
      expect(normalizeV2PortRef('3_IN'), '3');
      expect(normalizeV2PortRef('3_OUT'), '3');
      expect(normalizeV2PortRef('SPLICE'), '1');
      expect(normalizeV2PortRef('5'), '5', reason: 'an already-bare reference is left unchanged');
      expect(normalizeV2PortRef(null), isNull);
    });

    test('reads a bridged relationship\'s own sourcePort/targetPort into two real ProbePoints', () {
      const relationship = EngineeringRelationship(
        id: 'r1',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'battery',
        targetNode: 'lamp',
        metadata: {'sourcePort': '1_OUT', 'targetPort': 'SPLICE'},
      );
      final positive = v2WireEndpointProbePoint(relationship, atSource: true);
      final negative = v2WireEndpointProbePoint(relationship, atSource: false);
      expect(positive, const ProbePoint(nodeId: 'battery', portId: '1'));
      expect(negative, const ProbePoint(nodeId: 'lamp', portId: '1'));
    });

    test('v2WireMeasurementTerminals returns null for an unbridged relationship id', () {
      final graph = EngineeringGraph(id: 'g', nodes: const {}, relationships: const {});
      expect(v2WireMeasurementTerminals(graph, null), isNull);
      expect(v2WireMeasurementTerminals(graph, 'not-in-graph'), isNull);
    });
  });

  testWidgets('measureV2WireViaNativeEngine solves the LIVE, adapter-synced graph via the real Engine — no electrical math in the bridge', (tester) async {
    useIsolatedSettingsStorage();
    final (controller, _) = await bootstrapDiagramStudioController(tester);
    final channel = _BridgeFakeChannel();
    final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
    await adapter.initializeFromDocument();
    expect(adapter.isReady, isTrue);

    channel.simulateModuleCreated(const V2ModuleCreatedMessage(v2ModuleId: 'v2-battery', label: 'Battery', category: 'power', x: 0, y: 0));
    channel.simulateModuleCreated(const V2ModuleCreatedMessage(v2ModuleId: 'v2-ground', label: 'Ground', category: 'ground', x: 100, y: 0));
    channel.simulateWireCreated(const V2WireCreatedMessage(
      v2WireId: 'v2-wire-1',
      fromModuleId: 'v2-battery',
      fromTerminal: '',
      toModuleId: 'v2-ground',
      toTerminal: '',
      label: '',
      color: 'R',
    ));

    final oepNodeId = adapter.oepNodeIdFor('v2-battery')!;
    // The real, live-synced battery node has no `properties['nominalVoltageV']`
    // (there is no command on `DiagramEditingHost` to author `properties`
    // at all today -- the same real, disclosed gap PRODUCT-READINESS-006B
    // found on the real diagram7.json Battery). A caller with real,
    // external knowledge of the actual source voltage supplies its own
    // resolver, exactly like every TRX300 test in this codebase already
    // does -- never fabricated inside the bridge itself.
    final solver = ElectricalSolver(
      sourceVoltage: (node, context) =>
          node.id == oepNodeId ? ElectricalReading.valid(9.0, unit: 'V') : ElectricalReading.unknown(unit: 'V'),
    );

    final result = measureV2WireViaNativeEngine(
      adapter,
      'v2-wire-1',
      MeasurementType.voltageDc,
      solver: solver,
      generationCounter: ElectricalSolutionGenerationCounter(),
    );

    expect(result, isNotNull);
    expect(result!.reading.isValid, isTrue);
    expect(result.reading.value, closeTo(9.0, 1e-6));
    expect(result.reading.unit, 'V');
  });

  testWidgets('PRODUCT-READINESS-008 §12/§14: a V2 operating-state message translates into ElectricalOperatingContext, keyed by the real OEP node id', (tester) async {
    useIsolatedSettingsStorage();
    final (controller, _) = await bootstrapDiagramStudioController(tester);
    final channel = _BridgeFakeChannel();
    final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
    await adapter.initializeFromDocument();

    channel.simulateModuleCreated(const V2ModuleCreatedMessage(v2ModuleId: 'v2-switch', label: 'Switch', category: 'switch', x: 0, y: 0));
    channel.simulateModuleCreated(const V2ModuleCreatedMessage(v2ModuleId: 'v2-ignition', label: 'Ignition', category: 'ignition', x: 50, y: 0));
    final switchOepId = adapter.oepNodeIdFor('v2-switch')!;
    final ignitionOepId = adapter.oepNodeIdFor('v2-ignition')!;

    expect(adapter.currentOperatingContext.activeInputStates, isEmpty, reason: 'no operatingStateChanged message has arrived yet');

    channel.simulateOperatingStateChanged(const V2OperatingStateChangedMessage(
      switchStates: {'v2-switch': 'closed'},
      multiSwitchStates: {
        'v2-ignition': {'power': 'on'},
        'v2-never-bridged': {'power': 'on'}, // no OEP mapping exists for this one.
      },
    ));

    final context = adapter.currentOperatingContext;
    expect(context.activeInputStates[switchOepId], isTrue, reason: "V2's own 'closed' becomes a real bool true, matching SwitchElectricalBehavior's default closedValue");
    expect(context.activeInputStates[ignitionOepId], {'power': 'on'}, reason: 'a multi-group switch\'s own real group/position data is preserved verbatim, keyed by the real OEP node id');
    expect(context.activeInputStates.length, 2, reason: 'the never-bridged V2 module id is silently omitted, never fabricated into a fake OEP node id');
  });

  testWidgets('measureV2WireViaNativeEngine returns null for an unbridged V2 wire id, never a fabricated result', (tester) async {
    useIsolatedSettingsStorage();
    final (controller, _) = await bootstrapDiagramStudioController(tester);
    final channel = _BridgeFakeChannel();
    final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
    await adapter.initializeFromDocument();

    final result = measureV2WireViaNativeEngine(
      adapter,
      'never-created',
      MeasurementType.voltageDc,
      generationCounter: ElectricalSolutionGenerationCounter(),
    );
    expect(result, isNull);
  });
}
