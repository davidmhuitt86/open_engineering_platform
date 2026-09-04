import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-DIAGRAM-V2-BRIDGE-008 — cross-document isolation via REAL
/// save/reload (Document A -> Document B -> Document A), not merely
/// `newDocument()` switches. See
/// `legacy_v2_persistence_e2e_support.dart`'s own doc comment for why
/// this is its own file.
void main() {
  late Directory documentsDir;

  setUp(() {
    documentsDir =
        Directory.systemTemp.createTempSync('oep_studio_bridge008_docs_');
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
    'AP-DIAGRAM-V2-BRIDGE-008: cross-document isolation -- A -> B -> A via real save/reload, no leakage either direction',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, container) =
          await legacyV2PersistenceBootstrap(tester);

      final pathA = '${documentsDir.path}${Platform.pathSeparator}doc-a.json';
      final pathB = '${documentsDir.path}${Platform.pathSeparator}doc-b.json';

      // --- Build and save Document A: module A1 ------------------------
      var channel = LegacyV2PersistenceFakeChannel();
      var adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();
      channel.simulateCreate('a1', 'Module A1', 'ground', 1, 1);
      await legacyV2PersistenceSettle(tester);
      await tester.runAsync(() => controller.saveDocumentAs(pathA));
      final docAId = controller.document.id;

      // --- Build and save Document B: module B1, as a genuinely
      //     different in-memory document (newDocument, not overwrite) --
      await tester.runAsync(() => container
          .read(engineeringProjectServiceProvider.notifier)
          .newDocument());
      await legacyV2PersistenceSettle(tester);
      channel = LegacyV2PersistenceFakeChannel();
      adapter = LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();
      channel.simulateCreate('b1', 'Module B1', 'ground', 2, 2);
      await legacyV2PersistenceSettle(tester);
      await tester.runAsync(() => controller.saveDocumentAs(pathB));
      final docBId = controller.document.id;
      expect(docBId, isNot(docAId));

      // --- Switch: A -> B -> A, each time via a REAL reload + FRESH
      //     adapter, asserting the other document's entities never
      //     appear -------------------------------------------------------
      await tester.runAsync(() => controller.openDocument(pathA));
      await legacyV2PersistenceSettle(tester);
      expect(controller.document.id, docAId);
      var freshChannel = LegacyV2PersistenceFakeChannel();
      var freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();
      expect(freshAdapter.oepNodeIdFor('a1'), isNotNull);
      expect(freshAdapter.oepNodeIdFor('b1'), isNull,
          reason: 'Document A must never resolve Document B\'s module id');
      expect(controller.engine.editing.session.graph.nodes.length, 1);
      expect(
          controller.engine.editing.session.graph.nodes.values.single
              .metadata['v2ModuleId'],
          'a1');

      await tester.runAsync(() => controller.openDocument(pathB));
      await legacyV2PersistenceSettle(tester);
      expect(controller.document.id, docBId);
      freshChannel = LegacyV2PersistenceFakeChannel();
      freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();
      expect(freshAdapter.oepNodeIdFor('b1'), isNotNull);
      expect(freshAdapter.oepNodeIdFor('a1'), isNull,
          reason: 'Document B must never resolve Document A\'s module id');
      expect(controller.engine.editing.session.graph.nodes.length, 1);
      expect(
          controller.engine.editing.session.graph.nodes.values.single
              .metadata['v2ModuleId'],
          'b1');

      await tester.runAsync(() => controller.openDocument(pathA));
      await legacyV2PersistenceSettle(tester);
      expect(controller.document.id, docAId);
      freshChannel = LegacyV2PersistenceFakeChannel();
      freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();
      expect(freshAdapter.oepNodeIdFor('a1'), isNotNull,
          reason: 'switching back to A must still resolve A\'s module');
      expect(freshAdapter.oepNodeIdFor('b1'), isNull);
      expect(controller.engine.editing.session.graph.nodes.length, 1);
    },
  );
}
