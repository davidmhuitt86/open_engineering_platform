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

  test('SurfaceRegistry has no duplicate ids (a shared invariant this shell also depends on)', () {
    final ids = SurfaceRegistry.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
