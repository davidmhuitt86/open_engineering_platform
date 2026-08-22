import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-DIAGRAM-V2-BRIDGE-008 — never-saved document identity distinctness
/// and dirty-state transitions (mutation -> dirty, save -> clean, undo
/// after save -> dirty again, reopen -> clean), through real disk saves/
/// reloads. See `legacy_v2_persistence_e2e_support.dart`'s own doc
/// comment for why this is its own file.
void main() {
  late Directory documentsDir;

  setUp(() {
    documentsDir = Directory.systemTemp.createTempSync('oep_studio_bridge008_docs_');
  });

  tearDown(() {
    if (documentsDir.existsSync()) {
      try {
        documentsDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Same disposable-temp-dir tolerance as useIsolatedSettingsStorage.
      }
    }
  });

  testWidgets(
    'AP-DIAGRAM-V2-BRIDGE-008: two never-saved documents have distinct ids; dirty-state transitions are correct',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, container) = await legacyV2PersistenceBootstrap(tester);

      final firstNeverSavedId = controller.document.id;
      expect(controller.documentPath, isNull);
      expect(controller.isDirty, isFalse, reason: 'a fresh bootstrapped document starts clean');

      // --- mutation -> dirty ---------------------------------------------
      final channel = LegacyV2PersistenceFakeChannel();
      final adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();
      channel.simulateCreate('gnd-1', 'Ground', 'ground', 5, 5);
      await legacyV2PersistenceSettle(tester);
      expect(controller.isDirty, isTrue, reason: 'a bridged mutation must dirty the document like any other edit');

      // --- save -> clean ---------------------------------------------------
      final path = '${documentsDir.path}${Platform.pathSeparator}dirty.json';
      await tester.runAsync(() => controller.saveDocumentAs(path));
      expect(controller.isDirty, isFalse);

      // --- undo after save: Engine undo still works, and re-dirties -----
      // AP-DIAGRAM-V2-BRIDGE-008 finding: `controller.commands.undo()`
      // reverts the Engine command but does not call
      // `DiagramStudioController.markDirty()` -- the same gap this task
      // found (and fixed) in `LegacyV2WebViewPage._undoLastV2Move()`.
      // `controller.undo()` is the correct wrapper, matching the fix.
      controller.undo();
      await legacyV2PersistenceSettle(tester);
      expect(controller.isDirty, isTrue, reason: 'undo is itself a mutation relative to the saved state');
      expect(controller.engine.editing.session.graph.nodes.isEmpty, isTrue,
          reason: 'undo must revert the CreateNode command the bridge issued');

      // --- reopen -> clean --------------------------------------------------
      await tester.runAsync(() => controller.openDocument(path));
      await legacyV2PersistenceSettle(tester);
      expect(controller.isDirty, isFalse, reason: 'a freshly reloaded document must be clean regardless of prior dirty state');

      // --- a second never-saved document gets a distinct id from the
      //     first -------------------------------------------------------
      await tester.runAsync(() => container.read(engineeringProjectServiceProvider.notifier).newDocument());
      await legacyV2PersistenceSettle(tester);
      final secondNeverSavedId = controller.document.id;
      expect(controller.documentPath, isNull);
      expect(secondNeverSavedId, isNot(firstNeverSavedId));
    },
  );
}
