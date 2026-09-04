import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// AP-DIAGRAM-V2-BRIDGE-003 — never-saved document identity, the
/// bridge's own document token, and the Save-interception path.
class _FakeChannel implements LegacyV2Channel {
  void Function()? _onSaveRequested;

  final List<String> saveResults = [];
  int interceptCallCount = 0;
  int clearAllSurfacesCallCount = 0;
  int restoreModuleCallCount = 0;

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
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '',
      List<Map<String, String>> terminals = const []}) async {
    restoreModuleCallCount++;
  }

  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId,
      String toModuleId, String label, String color,
      {String fromTerminal = '', String toTerminal = ''}) async {}
  @override
  Future<void> clearAllSurfaces() async {
    clearAllSurfacesCallCount++;
  }

  @override
  Future<void> interceptV2Save() async {
    interceptCallCount++;
  }

  @override
  Future<void> reportSaveResult(bool success, String message) async {
    saveResults.add('$success:$message');
  }

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) async {}

  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => null;

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) async {}

  void simulateSaveRequested() => _onSaveRequested?.call();
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'LegacyV2StateAdapter: never-saved document identity, document token, save interception',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, container) =
          await bootstrapDiagramStudioController(tester);

      // --- Phase 2: two different never-saved documents get distinct
      //     ids, even though `path` is null for both -------------------
      final firstId = controller.document.id;
      expect(controller.documentPath, isNull,
          reason: 'a fresh bootstrapped document is never-saved');
      await container
          .read(engineeringProjectServiceProvider.notifier)
          .newDocument();
      await settle(tester);
      final secondId = controller.document.id;
      expect(controller.documentPath, isNull,
          reason: 'the new document is also never-saved');
      expect(secondId, isNot(firstId),
          reason:
              'newDocument() resets the internal id (via close()), so a fresh one is generated on next access — '
              'distinguishing two never-saved documents without relying on path');

      // --- Phase 3: the adapter records which document it initialized
      //     against, as its own bridge-level token -----------------------
      final channel = _FakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      expect(adapter.currentDocumentToken, isNull,
          reason: 'no token until initializeFromDocument runs');
      await adapter.initializeFromDocument();
      expect(adapter.currentDocumentToken, secondId,
          reason:
              'the token must match the document actually initialized against');

      // Switching documents and reinitializing updates the token to
      // match the newly active document, not the old one.
      await container
          .read(engineeringProjectServiceProvider.notifier)
          .newDocument();
      await settle(tester);
      final thirdId = controller.document.id;
      expect(thirdId, isNot(secondId));
      await adapter.reinitializeForDocument();
      expect(adapter.currentDocumentToken, thirdId);

      // --- Phase 4/5: V2's "Save" is intercepted (not left as a second,
      //     un-reconciled file-download path) and routed through the
      //     existing DiagramStudioController.saveDocument() -------------
      // No path yet -> cannot silently fall back to a duplicate save
      // path; reports why instead.
      channel.simulateSaveRequested();
      await settle(tester);
      expect(channel.saveResults.last, startsWith('false:'),
          reason:
              'a never-saved document cannot be saved from V2 without a Save As path picker, which this task does not build');
    },
  );

  testWidgets(
    'AP-DIAGRAM-V2-BRIDGE-SAVE-006: acknowledgeSaveAs updates the token '
    'without touching V2\'s display (unlike reinitializeForDocument)',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final channel = _FakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();
      channel.clearAllSurfacesCallCount = 0;
      channel.restoreModuleCallCount = 0;

      // The exact scenario that used to delete most of a V2-bootstrap-
      // heavy diagram: Save As assigns the SAME document its first path
      // (no document switch — `document.id` is unchanged). This must be
      // a no-op for V2's own display: no clear, no reseed.
      adapter.acknowledgeSaveAs();

      expect(channel.clearAllSurfacesCallCount, 0,
          reason:
              'Save As must never clear V2\'s surfaces -- its content did not change');
      expect(channel.restoreModuleCallCount, 0,
          reason:
              'Save As must never reseed V2 -- nothing was cleared to reseed');
      expect(adapter.currentDocumentToken, controller.document.id,
          reason:
              'the token bookkeeping still needs to reflect the (now-saved) document');

      // Contrast: a genuine document switch DOES clear+reseed -- this is
      // `reinitializeForDocument()`'s correct, intentional job, not a
      // bug this fix should also remove.
      await adapter.reinitializeForDocument();
      expect(channel.clearAllSurfacesCallCount, 1,
          reason: 'a real document switch must still clear V2\'s surfaces');
    },
  );
}
