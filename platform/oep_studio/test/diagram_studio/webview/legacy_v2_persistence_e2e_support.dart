import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';

import '../../support/diagram_studio_controller_harness.dart';

/// AP-DIAGRAM-V2-BRIDGE-008/010 — shared fake channel for the real-disk
/// persistence e2e test files, kept split one `testWidgets` per file
/// (§ each file's own doc comment for why — that reasoning predates and
/// is unrelated to the AP-DIAGRAM-V2-BRIDGE-010 harness change below,
/// and is left as-is rather than re-tested under time pressure).
///
/// AP-DIAGRAM-V2-BRIDGE-010 — bootstraps via
/// [bootstrapDiagramStudioController] (the real provider-driven
/// bootstrap, no dependency on the retired native `DiagramStudioPage`)
/// rather than the former `DiagramStudioPage`-pumping harness. Returns
/// the [ProviderContainer] too, so callers can read
/// `engineeringProjectServiceProvider`/etc. directly, exactly as they
/// could reach sibling providers via `ProviderScope.containerOf` before.
Future<(DiagramStudioController, ProviderContainer)>
    legacyV2PersistenceBootstrap(WidgetTester tester) =>
        bootstrapDiagramStudioController(tester);

Future<void> legacyV2PersistenceSettle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Minimal fake [LegacyV2Channel] covering exactly what these
/// persistence tests need to observe (module/wire creation in, restore
/// calls out) — not a general-purpose test double for every bridge
/// capability (see `legacy_v2_state_adapter_test.dart`'s own richer fake
/// for that).
class LegacyV2PersistenceFakeChannel implements LegacyV2Channel {
  void Function(V2ModuleCreatedMessage message)? _onModuleCreated;
  void Function(V2WireCreatedMessage message)? _onWireCreated;
  void Function()? _onSaveRequested;

  final List<String> restoredModuleIds = [];
  final List<(String, String, String, double, double)> restoredModules = [];
  final List<String> restoredWireIds = [];
  final List<(String, String, String, String, String)> restoredWires = [];
  int clearAllSurfacesCallCount = 0;
  final List<String> saveResults = [];

  @override
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler) {}
  @override
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler) =>
      _onModuleCreated = handler;
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
  set onSaveRequested(void Function()? handler) => _onSaveRequested = handler;

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
  Future<void> reportSaveResult(bool success, String message) async {
    saveResults.add('$success:$message');
  }

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) async {}

  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '',
      List<Map<String, String>> terminals = const []}) async {
    restoredModuleIds.add(v2ModuleId);
    restoredModules.add((v2ModuleId, label, category, x, y));
  }

  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId,
      String toModuleId, String label, String color,
      {String fromTerminal = '', String toTerminal = ''}) async {
    restoredWireIds.add(v2WireId);
    restoredWires.add((v2WireId, fromModuleId, toModuleId, label, color));
  }

  @override
  Future<void> clearAllSurfaces() async {
    clearAllSurfacesCallCount++;
  }

  /// `null` — these persistence-roundtrip tests exercise `saveDocument`
  /// directly via `simulateCreate`/`simulateWireCreated` followed by
  /// `simulateSaveRequested`; `flushBeforeSave` seeing no snapshot is a
  /// no-op, so `_handleSaveRequested` behaves exactly as before this
  /// capability existed. `restoreWireRouteOffsets` for this file's own
  /// route-persistence coverage.
  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => null;

  final List<(String, Map<String, double>)> restoredWireRouteOffsets = [];

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) async {
    restoredWireRouteOffsets.add((v2WireId, offsets));
  }

  void simulateCreate(String v2ModuleId, String label, String category,
          double x, double y) =>
      _onModuleCreated?.call(V2ModuleCreatedMessage(
          v2ModuleId: v2ModuleId,
          label: label,
          category: category,
          x: x,
          y: y));

  void simulateWireCreated(
    String v2WireId,
    String from,
    String to,
    String label,
    String color, {
    String fromTerminal = '',
    String toTerminal = '',
  }) =>
      _onWireCreated?.call(V2WireCreatedMessage(
        v2WireId: v2WireId,
        fromModuleId: from,
        fromTerminal: fromTerminal,
        toModuleId: to,
        toTerminal: toTerminal,
        label: label,
        color: color,
      ));

  void simulateSaveRequested() => _onSaveRequested?.call();
}
