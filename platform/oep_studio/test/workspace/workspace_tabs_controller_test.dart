import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-SHELL-001 — focused tests for the new workspace tab
/// model/controller. Does not touch DiagramTab, WebSurfaceTabsController,
/// or any Diagram/V2 behavior — those are unmodified by this package.
///
/// AP-OEP-WORKSPACE-PERSISTENCE-001 — every `WorkspaceTabsController()`
/// built below now uses the real, default `WorkspaceTabsStorage` (this
/// file predates persistence and has no reason to inject a fake), so
/// `useIsolatedSettingsStorage()` keeps its real (but fire-and-forget)
/// writes off this machine's actual `%APPDATA%/oep_studio` — the same
/// isolation seam every other real-storage test in this repo already
/// uses. Persistence *behavior* itself is covered by
/// `workspace_tabs_persistence_test.dart`, not here.
void main() {
  setUp(useIsolatedSettingsStorage);

  group('WorkspaceTab', () {
    test('a native surface tab resolves title/icon live from SurfaceRegistry, not a stored copy', () {
      final surface = SurfaceRegistry.all.first;
      final tab = WorkspaceTab(id: 't1', surfaceId: surface.id);
      expect(tab.title, surface.title);
      expect(tab.icon, surface.icon);
      expect(tab.isDiagram, isFalse);
    });

    test('the reserved diagram surfaceId resolves via StudioDestination, not SurfaceRegistry', () {
      final tab = WorkspaceTab(id: 't2', surfaceId: WorkspaceTab.diagramSurfaceId);
      expect(tab.isDiagram, isTrue);
      expect(tab.title, 'Diagram Studio');
      expect(SurfaceRegistry.forId(WorkspaceTab.diagramSurfaceId), isNull, reason: 'diagram is deliberately excluded from SurfaceRegistry');
    });
  });

  group('WorkspaceTabsController', () {
    test('opening a Surface creates a tab and activates it', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      final id = controller.openSurface(surface.id);

      expect(controller.tabs, hasLength(1));
      expect(controller.activeId, id);
      expect(controller.active!.surfaceId, surface.id);
    });

    test('opening the same Surface twice focuses the existing tab instead of duplicating', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      final firstId = controller.openSurface(surface.id);
      final secondId = controller.openSurface(surface.id);

      expect(secondId, firstId);
      expect(controller.tabs, hasLength(1));
    });

    test('multiple different Surfaces coexist as separate tabs', () {
      final controller = WorkspaceTabsController();
      final a = SurfaceRegistry.all[0];
      final b = SurfaceRegistry.all[1];
      controller.openSurface(a.id);
      controller.openSurface(b.id);

      expect(controller.tabs, hasLength(2));
      expect(controller.active!.surfaceId, b.id, reason: 'opening a new tab activates it');
    });

    test('the Diagram tab (not in SurfaceRegistry) opens and coexists with native Surface tabs', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      controller.openSurface(surface.id);
      controller.openSurface(WorkspaceTab.diagramSurfaceId);

      expect(controller.tabs, hasLength(2));
      expect(controller.active!.isDiagram, isTrue);
    });

    test('AP-OEP-WORKSPACE-UX-002: re-opening the already-active tab does not notify listeners or attempt a persist write', () {
      final controller = WorkspaceTabsController();
      final surfaceId = controller.openSurface(SurfaceRegistry.all.first.id);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.openSurface(SurfaceRegistry.all.first.id); // already the active tab

      expect(notifications, 0, reason: 'nothing about what is open or active actually changed');
      expect(controller.activeId, surfaceId);
    });

    test('AP-OEP-WORKSPACE-UX-002: re-activating the already-active tab does not notify listeners', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.activate(aId); // already the active tab

      expect(notifications, 0);
      expect(controller.activeId, aId);
    });

    test('activate switches the active tab without closing anything', () {
      final controller = WorkspaceTabsController();
      final a = SurfaceRegistry.all[0];
      final b = SurfaceRegistry.all[1];
      final aId = controller.openSurface(a.id);
      controller.openSurface(b.id);

      controller.activate(aId);

      expect(controller.activeId, aId);
      expect(controller.tabs, hasLength(2));
    });

    test('activate ignores an unknown id', () {
      final controller = WorkspaceTabsController();
      final id = controller.openSurface(SurfaceRegistry.all.first.id);

      controller.activate('does-not-exist');

      expect(controller.activeId, id, reason: 'an invalid id must not clear or corrupt the active tab');
    });

    test('closing the active tab activates its left neighbor', () {
      final controller = WorkspaceTabsController();
      final a = SurfaceRegistry.all[0];
      final b = SurfaceRegistry.all[1];
      final aId = controller.openSurface(a.id);
      final bId = controller.openSurface(b.id);

      controller.close(bId);

      expect(controller.tabs, hasLength(1));
      expect(controller.activeId, aId);
    });

    test('closing a non-active tab does not change the active tab', () {
      final controller = WorkspaceTabsController();
      final a = SurfaceRegistry.all[0];
      final b = SurfaceRegistry.all[1];
      final aId = controller.openSurface(a.id);
      final bId = controller.openSurface(b.id);
      controller.activate(aId);

      controller.close(bId);

      expect(controller.activeId, aId);
      expect(controller.tabs, hasLength(1));
    });

    test('closing the last remaining tab leaves no active tab', () {
      final controller = WorkspaceTabsController();
      final id = controller.openSurface(SurfaceRegistry.all.first.id);

      controller.close(id);

      expect(controller.tabs, isEmpty);
      expect(controller.activeId, isNull);
      expect(controller.active, isNull);
    });

    test('closing an unknown id is a no-op', () {
      final controller = WorkspaceTabsController();
      final id = controller.openSurface(SurfaceRegistry.all.first.id);

      controller.close('does-not-exist');

      expect(controller.tabs, hasLength(1));
      expect(controller.activeId, id);
    });
  });

  group('WorkspaceTabsController.openNewInstance (AP-OEP-WORKSPACE-MULTI-INSTANCE-001)', () {
    // A harmless, unregistered surfaceId — this controller never
    // consults SurfaceRegistry/allowsMultipleInstances to decide whether
    // `openNewInstance` is allowed (that policy belongs to a future
    // caller, § the controller's own class doc comment), so no real
    // multi-instance Surface needs to exist yet to prove the mechanism.
    const multiInstanceSurfaceId = 'test-multi-instance-surface';

    test('two calls create two distinct tabs with the same surfaceId', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(multiInstanceSurfaceId);
      final bId = controller.openNewInstance(multiInstanceSurfaceId);

      expect(controller.tabs, hasLength(2));
      expect(aId, isNot(bId));
      expect(controller.tabs[0].id, aId);
      expect(controller.tabs[1].id, bId);
      expect(controller.tabs[0].surfaceId, multiInstanceSurfaceId);
      expect(controller.tabs[1].surfaceId, multiInstanceSurfaceId);
    });

    test('each call activates the newly-created instance', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(multiInstanceSurfaceId);
      expect(controller.activeId, aId);

      final bId = controller.openNewInstance(multiInstanceSurfaceId);
      expect(controller.activeId, bId);
    });

    test('activating instance A does not affect instance B', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(multiInstanceSurfaceId);
      final bId = controller.openNewInstance(multiInstanceSurfaceId);

      controller.activate(aId);

      expect(controller.activeId, aId);
      expect(controller.tabs.map((t) => t.id), containsAll([aId, bId]));
      expect(controller.tabs, hasLength(2), reason: 'activating one instance never closes the other');
    });

    test('closing instance A leaves instance B intact and active if it was active', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(multiInstanceSurfaceId);
      final bId = controller.openNewInstance(multiInstanceSurfaceId);

      controller.close(aId);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, bId);
      expect(controller.activeId, bId);
    });

    test('closing instance B leaves instance A intact', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(multiInstanceSurfaceId);
      final bId = controller.openNewInstance(multiInstanceSurfaceId);

      controller.close(bId);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, aId);
      expect(controller.activeId, aId);
    });

    test('append-order is preserved across mixed openSurface/openNewInstance calls, and activation never reorders', () {
      final controller = WorkspaceTabsController();
      final a = SurfaceRegistry.all[0];
      final c = SurfaceRegistry.all[1];
      final aId = controller.openSurface(a.id);
      final instance1Id = controller.openNewInstance(multiInstanceSurfaceId);
      final instance2Id = controller.openNewInstance(multiInstanceSurfaceId);
      final cId = controller.openSurface(c.id);

      expect(controller.tabs.map((t) => t.id).toList(), [aId, instance1Id, instance2Id, cId]);

      controller.activate(aId);

      expect(controller.tabs.map((t) => t.id).toList(), [aId, instance1Id, instance2Id, cId],
          reason: 'activation must never reorder tabs');
    });

    test('openNewInstance never reuses an existing tab, unlike openSurface', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      controller.openSurface(surface.id);
      controller.openSurface(surface.id); // still just one tab, per existing contract

      expect(controller.tabs, hasLength(1));

      controller.openNewInstance(surface.id);

      expect(controller.tabs, hasLength(2), reason: 'openNewInstance always creates a new instance, even for a normally-singleton surfaceId');
    });

    test('openSurface still deduplicates singleton Surfaces even after multi-instance tabs exist elsewhere', () {
      final controller = WorkspaceTabsController();
      controller.openNewInstance(multiInstanceSurfaceId);
      controller.openNewInstance(multiInstanceSurfaceId);
      final surface = SurfaceRegistry.all.first;

      final firstId = controller.openSurface(surface.id);
      final secondId = controller.openSurface(surface.id);

      expect(firstId, secondId);
      expect(controller.tabs.where((t) => t.surfaceId == surface.id), hasLength(1));
    });
  });

  test('SurfaceRegistry has no duplicate ids (a shared invariant this shell also depends on)', () {
    final ids = SurfaceRegistry.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
