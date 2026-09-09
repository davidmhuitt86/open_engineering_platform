import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-MODULE-KIND-001 — direct regression test for the user-reported bug:
/// a Diode/Battery/Starter Motor/Starter Solenoid/grounded-Switch/
/// Thermistor module (any module whose special glyph is driven by V2's
/// own `m.bulb`/`m.diode`/`m.battery`/`m.starterMotor`/`m.solenoid`/
/// `m.groundedSwitch`/`m.thermistor` flag, collapsed into the bridge's
/// `kind` field) renders correctly live, but reverts to a plain generic
/// card after a real Save + app restart. Exercises the exact real-disk
/// round trip (`legacy_v2_persistence_disk_roundtrip_test.dart`'s own
/// pattern) with a non-empty `kind`, so a regression here is caught
/// without needing the actual WebView2/JS bridge.
void main() {
  late Directory documentsDir;

  setUp(() {
    documentsDir =
        Directory.systemTemp.createTempSync('oep_studio_v2_kind_');
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
    'AP-MODULE-KIND-001: a module\'s special-render kind survives a real disk save + fresh-adapter reopen',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, container) =
          await legacyV2PersistenceBootstrap(tester);

      final channel = LegacyV2PersistenceFakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      channel.simulateCreate(
          'diode-1', 'Diode', 'diode', 10, 20,
          kind: 'diode');
      await legacyV2PersistenceSettle(tester);

      final nodeId = adapter.oepNodeIdFor('diode-1')!;
      final node = controller.engine.editing.session.graph.nodes[nodeId]!;
      expect(node.metadata['v2Kind'], 'diode',
          reason:
              'moduleCreated must stash the kind into node metadata immediately, live');

      // --- Save to a REAL file on disk ---------------------------------
      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}kind_roundtrip.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));
      expect(File(filePath).existsSync(), isTrue);
      expect(File(filePath).readAsStringSync(), contains('"v2Kind"'),
          reason: 'kind metadata must actually be written to the saved JSON');

      // --- Discard in-memory state (new document), then reopen the real
      //     file from disk, exactly like an app restart -----------------
      await tester.runAsync(() => container
          .read(engineeringProjectServiceProvider.notifier)
          .newDocument());
      await legacyV2PersistenceSettle(tester);
      await tester.runAsync(() => controller.openDocument(filePath));
      await legacyV2PersistenceSettle(tester);

      // --- A FRESH adapter (simulating a fresh app launch) reconstructs
      //     V2's modules purely from the reloaded document -------------
      final freshChannel = LegacyV2PersistenceFakeChannel();
      final freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();

      expect(freshChannel.restoredModuleIds, contains('diode-1'));
      expect(freshChannel.restoredModuleKinds['diode-1'], 'diode',
          reason:
              'restoreModule must be called with the real kind after a genuine disk round trip -- '
              'this is exactly what the bridge script uses to pick buildDiodeCard/buildBatteryCard/etc '
              'over the plain buildStdCard fallback');
    },
  );
}
