import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-MODULE-KIND-002 — root-cause regression for the user-reported bug:
/// a Diode/Battery/Starter Motor/Starter Solenoid/grounded-Switch/
/// Thermistor module renders correctly live, survives an in-memory
/// metadata check (§ `legacy_v2_module_kind_persistence_test.dart`), but
/// STILL reverts to a plain card after actually pressing V2's own Save
/// button and restarting.
///
/// Root cause: `LegacyV2StateAdapter.flushBeforeSave` (run BEFORE every
/// `saveDocument()` triggered via V2's own in-page Save button —
/// `_handleSaveRequested`) reconciles an ALREADY-bridged module by
/// synthesizing a `V2ModulePropertiesChangedMessage` from the save
/// snapshot carrying only `label`/`category`/`notes` — every other field
/// (including `kind`, and pre-existing `sub`/`labelJustify`/`labelPos`/
/// `pinLabelPos`/`subLabelPos`) defaults to `''`. `_handleModulePropertiesChanged`
/// treats an empty string for those fields as "explicitly cleared" (the
/// same convention that lets the properties panel reset an override back
/// to Auto), so this synthesized message ERASES a module's already-correct
/// `v2Kind` metadata on every single Save through V2's own button —
/// *before* the (now kind-less) session is ever written to disk. This is
/// why the bug reproduced even immediately after the `kind`-threading fix
/// (§ `legacy_v2_module_kind_persistence_test.dart`, which never
/// exercises `_handleSaveRequested`/`flushBeforeSave` at all, so it
/// couldn't catch this).
class _SaveFlushFakeChannel extends LegacyV2PersistenceFakeChannel {
  V2SaveSnapshot? nextSnapshot;

  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => nextSnapshot;
}

Future<void> _triggerSaveAndWait(
    WidgetTester tester, _SaveFlushFakeChannel channel) async {
  final before = channel.saveResults.length;
  await tester.runAsync(() async {
    channel.simulateSaveRequested();
    for (var i = 0; i < 100; i++) {
      if (channel.saveResults.length > before) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
}

void main() {
  late Directory documentsDir;

  setUp(() {
    documentsDir =
        Directory.systemTemp.createTempSync('oep_studio_v2_kind_flush_');
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
    'AP-MODULE-KIND-002: kind survives pressing V2\'s own Save button on an already-bridged module',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, _) = await legacyV2PersistenceBootstrap(tester);
      final channel = _SaveFlushFakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      // Module created live -- immediately bridged (this is what makes it
      // "already-bridged" by the time Save runs below, exactly like a
      // module that's been sitting on the canvas for more than one
      // 400ms poll tick before the user hits Save).
      channel.simulateCreate('diode-1', 'Diode', 'diode', 10, 20,
          kind: 'diode');
      await legacyV2PersistenceSettle(tester);
      final nodeId = adapter.oepNodeIdFor('diode-1')!;
      expect(
          controller.engine.editing.session.graph.nodes[nodeId]
              ?.metadata['v2Kind'],
          'diode',
          reason: 'sanity check -- kind is correctly set right after creation');

      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}kind_flush.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));

      // The Save-button flush: captureSaveSnapshot reports the module's
      // CURRENT true state (kind included, same as V2's own live MODULES
      // array would) -- this is what the real bridge script's
      // `__oepBridgeCaptureSaveSnapshot` sends.
      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'diode-1': const V2SnapshotModule(
            label: 'Diode',
            category: 'diode',
            notes: '',
            x: 10,
            y: 20,
            kind: 'diode',
          ),
        },
        wires: const {},
        wireRoutes: const {},
      );
      await _triggerSaveAndWait(tester, channel);
      await legacyV2PersistenceSettle(tester);

      expect(
          controller.engine.editing.session.graph.nodes[nodeId]
              ?.metadata['v2Kind'],
          'diode',
          reason:
              'pressing V2\'s own Save button must not erase kind metadata for a module whose kind never changed -- '
              'flushBeforeSave\'s modulePropertiesChanged reconciliation for an already-bridged module must carry '
              'kind (and every other module field the snapshot has), not just label/category/notes');

      // saveDocumentAs already wrote to disk once above (before this
      // flush); write again now that the flush has run, and confirm what
      // actually lands on disk still carries the kind metadata.
      await tester.runAsync(() => controller.saveDocument());
      final onDiskAfterFlush = File(filePath).readAsStringSync();
      expect(onDiskAfterFlush, contains('"v2Kind"'),
          reason:
              'the file actually written to disk after Save must still carry the kind metadata key');
      expect(onDiskAfterFlush, contains('diode'),
          reason: 'and its value must still be "diode", not cleared');
    },
  );
}
