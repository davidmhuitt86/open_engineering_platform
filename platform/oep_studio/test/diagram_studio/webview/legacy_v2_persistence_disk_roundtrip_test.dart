import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/isolated_settings_storage.dart';
import 'legacy_v2_persistence_e2e_support.dart';

/// AP-DIAGRAM-V2-BRIDGE-008 — real disk save -> discard in-memory state
/// -> fresh adapter reconstructs identity purely from what was reloaded.
/// See `legacy_v2_persistence_e2e_support.dart`'s own doc comment for
/// why this is its own file rather than one of three `testWidgets` in a
/// shared file.
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
    'AP-DIAGRAM-V2-BRIDGE-008: real disk save -> discard in-memory adapter -> fresh adapter reconstructs identity',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final (controller, container) =
          await legacyV2PersistenceBootstrap(tester);

      // --- Build a real document: two modules, one wire, with label +
      //     wireColor metadata -- through the actual bridge path -------
      final channel = LegacyV2PersistenceFakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);
      await adapter.initializeFromDocument();

      channel.simulateCreate('gnd-1', 'Chassis Ground', 'ground', 10, 20);
      await legacyV2PersistenceSettle(tester);
      channel.simulateCreate('gnd-2', 'Second Ground', 'ground', 100, 120);
      await legacyV2PersistenceSettle(tester);
      channel.simulateWireCreated(
          'wire-1', 'gnd-1', 'gnd-2', 'Bridging Wire', 'G',
          fromTerminal: 'A', toTerminal: 'B');
      await legacyV2PersistenceSettle(tester);

      final originalNodeIdA = adapter.oepNodeIdFor('gnd-1')!;
      expect(adapter.oepNodeIdFor('gnd-2'), isNotNull);
      expect(adapter.oepRelationshipIdFor('wire-1'), isNotNull);
      final documentIdBeforeSave = controller.document.id;

      // --- Save to a REAL file on disk (not just toJson) --------------
      final filePath =
          '${documentsDir.path}${Platform.pathSeparator}bridge008.json';
      await tester.runAsync(() => controller.saveDocumentAs(filePath));
      expect(controller.documentPath, filePath);
      expect(controller.isDirty, isFalse,
          reason: 'a successful save must clear dirty state');
      expect(File(filePath).existsSync(), isTrue,
          reason: 'saveDocumentAs must actually write the file');

      final onDiskRaw = File(filePath).readAsStringSync();
      expect(onDiskRaw, contains('"v2ModuleId"'),
          reason: 'bridge identity metadata must be present in the saved JSON');
      expect(onDiskRaw, contains('"v2WireId"'));
      expect(onDiskRaw, contains('"wireColor"'));
      expect(onDiskRaw, contains('"documentId"'),
          reason: 'DiagramDocument.id must be persisted in the envelope');

      // --- Discard in-memory state: open a different (never-saved)
      //     document, so the graph/session actually changes underneath
      //     the old adapter -- its maps are now stale by construction --
      await tester.runAsync(() => container
          .read(engineeringProjectServiceProvider.notifier)
          .newDocument());
      await legacyV2PersistenceSettle(tester);
      expect(controller.document.id, isNot(documentIdBeforeSave),
          reason:
              'newDocument() must generate a distinct id, not reuse the saved document\'s');
      expect(adapter.oepNodeIdFor('gnd-1'), originalNodeIdA,
          reason:
              'the OLD adapter\'s in-memory map is untouched by a document switch -- demonstrating it is now '
              'stale relative to the actual current graph, which is exactly why identity must be rebuilt fresh, '
              'not trusted from a lingering adapter');
      expect(
          controller.engine.editing.session.graph.nodes
              .containsKey(originalNodeIdA),
          isFalse,
          reason:
              'the node from the saved document must not exist in the new empty document\'s graph');

      // --- Reload the saved file for real, through the real
      //     openDocument path -------------------------------------------
      await tester.runAsync(() => controller.openDocument(filePath));
      await legacyV2PersistenceSettle(tester);
      expect(controller.documentPath, filePath);
      expect(controller.isDirty, isFalse,
          reason: 'a freshly opened document must be clean');
      expect(controller.document.id, documentIdBeforeSave,
          reason:
              'DiagramDocument.id must round-trip through save/reload unchanged');

      // The reloaded graph has NEW Dart node/relationship ids in general
      // (Engine ids are not guaranteed stable across a JSON round trip in
      // this schema) -- what must survive is the bridge metadata that
      // lets identity be *reconstructed*, not the literal id strings.
      final reloadedNodes =
          controller.engine.editing.session.graph.nodes.values.toList();
      expect(reloadedNodes.length, 2);
      expect(reloadedNodes.map((n) => n.metadata['v2ModuleId']).toSet(),
          {'gnd-1', 'gnd-2'});
      final reloadedRelationships =
          controller.engine.editing.session.graph.relationships.values.toList();
      expect(reloadedRelationships.length, 1);
      expect(reloadedRelationships.single.metadata['v2WireId'], 'wire-1');
      expect(reloadedRelationships.single.metadata['label'], 'Bridging Wire');
      expect(reloadedRelationships.single.metadata['wireColor'], 'G');
      // AP-DIAGRAM-V2-BRIDGE-011 — terminal identity survives the real
      // disk round trip too (existing sourcePort/targetPort metadata,
      // already covered by EngineeringRelationship.toJson/fromJson).
      expect(reloadedRelationships.single.metadata['sourcePort'], 'A');
      expect(reloadedRelationships.single.metadata['targetPort'], 'B');

      // --- A FRESH adapter (new instance, no shared memory with the
      //     original one) reconstructs the identity map purely from the
      //     just-reloaded document's own metadata -----------------------
      final freshChannel = LegacyV2PersistenceFakeChannel();
      final freshAdapter =
          LegacyV2StateAdapter(controller: controller, channel: freshChannel);
      await freshAdapter.initializeFromDocument();

      final rebuiltNodeIdA = freshAdapter.oepNodeIdFor('gnd-1');
      final rebuiltNodeIdB = freshAdapter.oepNodeIdFor('gnd-2');
      final rebuiltRelId = freshAdapter.oepRelationshipIdFor('wire-1');
      expect(rebuiltNodeIdA, isNotNull);
      expect(rebuiltNodeIdB, isNotNull);
      expect(rebuiltRelId, isNotNull);
      expect(freshChannel.restoredModuleIds, containsAll(['gnd-1', 'gnd-2']),
          reason:
              'V2 must be reseeded with both modules from the reloaded document');
      expect(freshChannel.restoredWireIds, contains('wire-1'));
      final restoredWireCall =
          freshChannel.restoredWires.singleWhere((w) => w.$1 == 'wire-1');
      expect(restoredWireCall.$4, 'Bridging Wire',
          reason: 'label must survive the real disk round trip');
      expect(restoredWireCall.$5, 'G',
          reason: 'wireColor must survive the real disk round trip');
      final restoredModuleA =
          freshChannel.restoredModules.singleWhere((m) => m.$1 == 'gnd-1');
      expect(restoredModuleA.$4, 10.0,
          reason: 'x position must survive the real disk round trip');
      expect(restoredModuleA.$5, 20.0,
          reason: 'y position must survive the real disk round trip');

      // The reconstructed OEP-side ids need not equal the pre-save ones
      // (a fresh JSON round trip is not guaranteed to preserve Dart-side
      // ids) -- the reconstructed *V2-facing* identity is what must be
      // stable, and it is: the same v2ModuleId/v2WireId strings resolve
      // to *some* real, currently-existing OEP entity in the reloaded
      // graph, every time, from any adapter instance.
      expect(
          controller.engine.editing.session.graph.nodes
              .containsKey(rebuiltNodeIdA),
          isTrue);
      expect(
          controller.engine.editing.session.graph.relationships
              .containsKey(rebuiltRelId),
          isTrue);
    },
  );
}
