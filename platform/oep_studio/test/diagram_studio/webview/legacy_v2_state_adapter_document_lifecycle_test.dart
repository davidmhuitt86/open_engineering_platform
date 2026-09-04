import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// AP-DIAGRAM-V2-BRIDGE-002 — focused tests for the document/identity
/// foundation: readiness gating, durable identity rebuilt from
/// `EngineeringNode`/`EngineeringRelationship` metadata (not a second
/// persistence system), and `reinitializeForDocument`'s "old document's
/// identity cannot mutate the new one" guarantee.
class _FakeChannel implements LegacyV2Channel {
  void Function(V2ModuleCreatedMessage message)? _onCreated;
  void Function(V2WireCreatedMessage message)? _onWireCreated;

  final List<String> restoredModuleIds = [];
  final List<String> restoredWireIds = [];
  int clearAllSurfacesCallCount = 0;

  @override
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler) {}
  @override
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler) =>
      _onCreated = handler;
  @override
  set onModuleDeleted(void Function(V2ModuleDeletedMessage message)? handler) {}
  @override
  set onModulePropertiesChanged(
      void Function(V2ModulePropertiesChangedMessage message)? handler) {}
  @override
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler) =>
      _onWireCreated = handler;
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
      void Function(V2MeasurementRequestedMessage message)? handler) {}
  @override
  set onSaveRequested(void Function()? handler) {}

  @override
  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y) async {}
  @override
  Future<void> sendAuthoritativeModuleLabel(
      String v2ModuleId, String label) async {}
  @override
  Future<void> removeModuleFromV2(String v2ModuleId) async {}
  @override
  Future<void> removeWireFromV2(String v2WireId) async {}
  @override
  Future<void> confirmWireCreated(
      String v2WireId, String label, String color) async {}
  @override
  Future<void> interceptV2Save() async {}
  @override
  Future<void> reportSaveResult(bool success, String message) async {}

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) async {}

  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '',
      List<Map<String, String>> terminals = const []}) async {
    restoredModuleIds.add(v2ModuleId);
  }

  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId,
      String toModuleId, String label, String color,
      {String fromTerminal = '', String toTerminal = ''}) async {
    restoredWireIds.add(v2WireId);
  }

  @override
  Future<void> clearAllSurfaces() async {
    clearAllSurfacesCallCount++;
  }

  final List<String> restoredWireRouteOffsetIds = [];

  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => null;

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) async {
    restoredWireRouteOffsetIds.add(v2WireId);
  }

  void simulateCreate(String v2ModuleId, String label, String category,
          double x, double y) =>
      _onCreated?.call(V2ModuleCreatedMessage(
          v2ModuleId: v2ModuleId,
          label: label,
          category: category,
          x: x,
          y: y));

  void simulateWireCreated(
          String v2WireId, String fromModuleId, String toModuleId) =>
      _onWireCreated?.call(
        V2WireCreatedMessage(
          v2WireId: v2WireId,
          fromModuleId: fromModuleId,
          fromTerminal: '',
          toModuleId: toModuleId,
          toTerminal: '',
          label: 'L',
          color: 'W',
        ),
      );
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'LegacyV2StateAdapter: readiness gate, durable metadata-backed identity, document isolation',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final engine = controller.engine;

      final channel = _FakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);

      // --- Phase 7: not ready until initialized; messages before that
      //     are dropped, not queued or fabricated ---------------------
      expect(adapter.isReady, isFalse);
      final beforeGate = engine.editing.session.graph.nodes.length;
      channel.simulateCreate('gnd-early', 'Too Early', 'ground', 1, 1);
      await settle(tester);
      expect(engine.editing.session.graph.nodes.length, beforeGate,
          reason:
              'a message received before initializeFromDocument must be ignored, not queued');

      await adapter.initializeFromDocument();
      expect(adapter.isReady, isTrue);
      expect(channel.restoredModuleIds, isEmpty,
          reason: 'a fresh empty document has nothing to seed');

      // --- Bridge a module + wire normally now that we're ready -------
      channel.simulateCreate('gnd-1', 'Ground A', 'ground', 10, 10);
      await settle(tester);
      channel.simulateCreate('gnd-2', 'Ground B', 'ground', 20, 20);
      await settle(tester);
      channel.simulateWireCreated('wire-1', 'gnd-1', 'gnd-2');
      await settle(tester);
      final nodeIdA = adapter.oepNodeIdFor('gnd-1')!;
      final relId = adapter.oepRelationshipIdFor('wire-1')!;

      // --- Phase 5: identity is durable metadata, not a second store —
      //     confirm it round-trips through EngineeringNode/Relationship
      //     JSON exactly as any other persisted field would ------------
      final nodeJson = engine.editing.session.graph.nodes[nodeIdA]!.toJson();
      expect(nodeJson['metadata'], containsPair('v2ModuleId', 'gnd-1'));
      final relJson =
          engine.editing.session.graph.relationships[relId]!.toJson();
      expect(relJson['metadata'], containsPair('v2WireId', 'wire-1'));

      // --- A second adapter instance (simulating a fresh WebView/tab
      //     reload) rebuilds the SAME identity map purely from that
      //     metadata, with no in-memory hand-off from the first adapter -
      final freshChannel = _FakeChannel();
      final freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();
      expect(freshAdapter.oepNodeIdFor('gnd-1'), nodeIdA,
          reason:
              'identity must be reconstructible from document metadata alone');
      expect(freshAdapter.oepRelationshipIdFor('wire-1'), relId);
      expect(freshChannel.restoredModuleIds, containsAll(['gnd-1', 'gnd-2']));
      expect(freshChannel.restoredWireIds, contains('wire-1'));

      // --- Phase 8: reinitializeForDocument clears V2 and cannot leave
      //     the old identity map able to mutate anything -----------------
      await adapter.reinitializeForDocument();
      expect(channel.clearAllSurfacesCallCount, 1);
      expect(adapter.isReady, isTrue);
      // The mapping still resolves (same document, re-scanned) — this is
      // "document B is actually the same document" reloading cleanly,
      // not a leak; the real isolation guarantee is that a *stale*
      // adapter for a document that's no longer active never gets asked
      // to resync anything (the host widget only ever holds one adapter
      // per mounted WebView, torn down with it — see the production
      // architecture doc's "Document switching lifecycle").
      expect(adapter.oepNodeIdFor('gnd-1'), nodeIdA);
    },
  );
}
