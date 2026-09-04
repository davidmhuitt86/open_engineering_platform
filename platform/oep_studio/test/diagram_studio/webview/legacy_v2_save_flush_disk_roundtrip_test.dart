import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the exact acceptance scenarios this
/// task requires, run end-to-end through the REAL `_handleSaveRequested`
/// path (`channel.simulateSaveRequested()`, not a direct
/// `flushBeforeSave()` call) and REAL disk save/reopen — not just the
/// in-memory Engine session `legacy_v2_state_adapter_test.dart` already
/// covers. Every scenario here deliberately mirrors "drag module, release
/// mouse, immediately click Save" / "route edit, immediately click Save"
/// by setting the snapshot the flush will read and firing `saveRequested`
/// in the same synchronous stretch — no `simulateMove`/settle gap of the
/// kind that used to hide this bug.
class _SaveFlushFakeChannel extends LegacyV2PersistenceFakeChannel {
  V2SaveSnapshot? nextSnapshot;

  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async => nextSnapshot;
}

/// `LegacyV2Channel.onSaveRequested` is `void Function()?` (matching
/// production's fire-and-forget "V2's Save button was clicked" trigger),
/// so `simulateSaveRequested()` cannot itself be awaited — this drains
/// the real async save chain (flush -> real disk write -> reportSaveResult)
/// before returning, the same "poll inside `tester.runAsync`" pattern
/// `legacy_v2_state_adapter_test.dart` already uses for the async
/// measurement round trip.
Future<void> _triggerSaveAndWait(
    WidgetTester tester, _SaveFlushFakeChannel channel) async {
  final before = channel.saveResults.length;
  // Both the trigger AND the poll must run inside `runAsync` — the real
  // `dart:io` file write `saveDocument()` performs never resolves if
  // kicked off from the plain FakeAsync-ish widget-test zone (the same
  // hazard class already established elsewhere in this suite for real
  // file I/O started outside `runAsync`).
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
        Directory.systemTemp.createTempSync('oep_studio_v2_save_flush_');
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
    'module move -> IMMEDIATE Save (no settle) -> reopen -> exact released position persists',
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

      channel.simulateCreate('gnd-1', 'Chassis Ground', 'ground', 10, 20);
      await legacyV2PersistenceSettle(tester);
      final nodeId = adapter.oepNodeIdFor('gnd-1')!;

      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}move_race.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));

      // The "drag module, release mouse, immediately click Save" moment:
      // V2's own globals now show the new position (this is what the
      // snapshot represents), but NO `moduleMoved` event has been -- or
      // ever will be -- simulated. The old, poller-dependent behavior
      // would silently save the stale (10, 20) position here.
      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'gnd-1': const V2SnapshotModule(
              label: 'Chassis Ground',
              category: 'ground',
              notes: '',
              x: 321,
              y: 654)
        },
        wires: const {},
        wireRoutes: const {},
      );
      await _triggerSaveAndWait(tester, channel);
      await legacyV2PersistenceSettle(tester);

      expect(controller.engine.editing.session.layout.positionOf(nodeId),
          const Point2D(321, 654),
          reason:
              'the in-memory session must reflect the released position immediately after Save, with no settle gap');
      expect(channel.saveResults, isNotEmpty);
      expect(channel.saveResults.last, startsWith('true:'),
          reason: 'save must report success');

      final onDiskRaw = File(filePath).readAsStringSync();
      expect(onDiskRaw, contains('"dx": 321.0'));
      expect(onDiskRaw, contains('"dy": 654.0'));
      expect(onDiskRaw, isNot(contains('"dx": 10.0')),
          reason: 'the stale pre-move position must never reach disk');
    },
  );

  testWidgets(
    'wire route edit -> IMMEDIATE Save (no settle) -> reopen -> manual route persists; Reset Route -> Save -> reopen -> automatic routing restored',
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

      channel.simulateCreate('gnd-1', 'A', 'ground', 0, 0);
      await legacyV2PersistenceSettle(tester);
      channel.simulateCreate('gnd-2', 'B', 'ground', 200, 200);
      await legacyV2PersistenceSettle(tester);
      channel.simulateWireCreated(
          'wire-1', 'gnd-1', 'gnd-2', 'Routed Wire', 'W',
          fromTerminal: 'A', toTerminal: 'B');
      await legacyV2PersistenceSettle(tester);
      final relId = adapter.oepRelationshipIdFor('wire-1')!;

      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}route_persist.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));

      V2SaveSnapshot snapshotWithModulesAndWire(
          Map<String, Map<int, double>> wireRoutes) {
        return V2SaveSnapshot(
          modules: {
            'gnd-1': const V2SnapshotModule(
                label: 'A', category: 'ground', notes: '', x: 0, y: 0),
            'gnd-2': const V2SnapshotModule(
                label: 'B', category: 'ground', notes: '', x: 200, y: 200),
          },
          wires: {
            'wire-1': const V2SnapshotWire(
              fromModuleId: 'gnd-1',
              fromTerminal: 'A',
              toModuleId: 'gnd-2',
              toTerminal: 'B',
              label: 'Routed Wire',
              color: 'W',
            ),
          },
          wireRoutes: wireRoutes,
        );
      }

      // --- Route edit: multiple segment nudges (V2's own accumulated
      //     scalar-offset model), immediate Save, no settle gap ---------
      channel.nextSnapshot = snapshotWithModulesAndWire({
        'wire-1': {0: 15.0, 1: -8.5},
      });
      await _triggerSaveAndWait(tester, channel);
      await legacyV2PersistenceSettle(tester);
      expect(
          controller.engine.editing.session.layout.wireSegmentOffsetsOf(relId),
          {0: 15.0, 1: -8.5});

      final onDiskAfterRouteEdit = File(filePath).readAsStringSync();
      expect(onDiskAfterRouteEdit, contains('"wireSegmentOffsets"'));

      // --- Real close/reopen: route survives on disk, independent of the
      //     in-memory session ---------------------------------------------
      await tester.runAsync(() => controller.openDocument(filePath));
      await legacyV2PersistenceSettle(tester);
      final reloadedRel = controller
          .engine.editing.session.graph.relationships.values
          .singleWhere((r) => r.metadata['v2WireId'] == 'wire-1');
      expect(
          controller.engine.editing.session.layout
              .wireSegmentOffsetsOf(reloadedRel.id),
          {0: 15.0, 1: -8.5},
          reason:
              'route offsets must survive a real disk save -> close -> reopen cycle');

      // --- Reset Route: next flush's snapshot omits the wire from
      //     wireRoutes entirely; save immediately, reopen ------------------
      final freshChannel = _SaveFlushFakeChannel();
      final freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();
      freshChannel.nextSnapshot = snapshotWithModulesAndWire(const {});
      await _triggerSaveAndWait(tester, freshChannel);
      await legacyV2PersistenceSettle(tester);
      expect(
          controller.engine.editing.session.layout
              .wireSegmentOffsetsOf(reloadedRel.id),
          isNull,
          reason:
              'a route missing from the flush snapshot must reset to automatic routing');

      await tester.runAsync(() => controller.openDocument(filePath));
      await legacyV2PersistenceSettle(tester);
      final reloadedAfterReset = controller
          .engine.editing.session.graph.relationships.values
          .singleWhere((r) => r.metadata['v2WireId'] == 'wire-1');
      expect(
          controller.engine.editing.session.layout
              .wireSegmentOffsetsOf(reloadedAfterReset.id),
          isNull,
          reason:
              'automatic routing must remain restored after a real disk reopen');
    },
  );

  testWidgets(
    'module move -> Save triggered via EngineeringProjectNotifier.saveDocument() directly '
    '(Ctrl+S / Command Palette diagram.saveDocument, NOT V2\'s own in-page Save button) '
    '-> reopen -> exact released position persists',
    (tester) async {
      // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — `command_registry.dart`'s
      // `diagram.saveDocument` command (reachable via Ctrl+S and the
      // Command Palette) calls `EngineeringProjectNotifier.saveDocument()`
      // directly and has no idea a V2 bridge is even involved -- it never
      // goes through `LegacyV2StateAdapter._handleSaveRequested`/
      // `channel.simulateSaveRequested()` at all. This test proves the
      // `beforeSaveFlush` hook (registered by the webview host in
      // `_ensureAdapter`) closes that gap: the flush must still run even
      // when nothing ever touches the V2-button save path.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, container) =
          await legacyV2PersistenceBootstrap(tester);
      final channel = _SaveFlushFakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      // Simulates exactly what `_ensureAdapter` does in production --
      // registers the adapter's flush as the notifier's pre-save hook.
      final notifier =
          container.read(engineeringProjectServiceProvider.notifier);
      notifier.beforeSaveFlush = adapter.flushBeforeSave;

      channel.simulateCreate('gnd-1', 'Chassis Ground', 'ground', 10, 20);
      await legacyV2PersistenceSettle(tester);
      final nodeId = adapter.oepNodeIdFor('gnd-1')!;

      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}command_palette_save.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));

      // V2's globals show the released position; no moduleMoved event was
      // ever simulated, and -- critically -- `channel.simulateSaveRequested`
      // is never called either. Only the notifier's own `saveDocument()`
      // is invoked, exactly as the Command Palette/Ctrl+S path does.
      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'gnd-1': const V2SnapshotModule(
              label: 'Chassis Ground',
              category: 'ground',
              notes: '',
              x: 777,
              y: 888)
        },
        wires: const {},
        wireRoutes: const {},
      );
      await tester.runAsync(() => notifier.saveDocument());
      await legacyV2PersistenceSettle(tester);

      expect(controller.engine.editing.session.layout.positionOf(nodeId),
          const Point2D(777, 888),
          reason:
              'a save triggered outside V2\'s own in-page button must still flush V2\'s current state first');

      final onDiskRaw = File(filePath).readAsStringSync();
      expect(onDiskRaw, contains('"dx": 777.0'));
      expect(onDiskRaw, contains('"dy": 888.0'));
      expect(onDiskRaw, isNot(contains('"dx": 10.0')));
    },
  );
}
