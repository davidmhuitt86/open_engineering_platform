import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';
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

  group('openDiagramTab (AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001)', () {
    test('1. the first call opens the primary Diagram instance', () {
      final controller = WorkspaceTabsController();
      final id = openDiagramTab(controller);

      expect(id, primaryDiagramInstanceId);
      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, primaryDiagramInstanceId);
      expect(controller.tabs.single.isDiagram, isTrue);
      expect(controller.activeId, primaryDiagramInstanceId);
    });

    test('2/3/4. a second and third call each create a new, independent, distinctly-id\'d Diagram tab', () {
      final controller = WorkspaceTabsController();
      final aId = openDiagramTab(controller);
      final bId = openDiagramTab(controller);
      final cId = openDiagramTab(controller);

      expect({aId, bId, cId}, hasLength(3), reason: 'three genuinely distinct ids, not reused/deduplicated');
      expect(aId, primaryDiagramInstanceId);
      expect(controller.tabs, hasLength(3));
      expect(controller.tabs.every((t) => t.isDiagram), isTrue);
    });

    test('no duplicate Diagram tabs are created merely by activating an existing Diagram tab', () {
      final controller = WorkspaceTabsController();
      final aId = openDiagramTab(controller);
      openDiagramTab(controller); // a genuine second instance

      controller.activate(aId);
      controller.activate(aId); // activating twice, including a no-op re-activation

      expect(controller.tabs, hasLength(2), reason: 'activation never opens or duplicates a tab');
    });

    test('switching A -> B -> A preserves both Diagram tabs (nothing is closed by switching)', () {
      final controller = WorkspaceTabsController();
      final aId = openDiagramTab(controller);
      final bId = openDiagramTab(controller);

      controller.activate(aId);
      controller.activate(bId);
      controller.activate(aId);

      expect(controller.tabs.map((t) => t.id).toSet(), {aId, bId});
      expect(controller.activeId, aId);
    });

    test('closing a secondary Diagram instance leaves the primary open and unaffected', () {
      final controller = WorkspaceTabsController();
      final primaryId = openDiagramTab(controller);
      final secondaryId = openDiagramTab(controller);

      controller.close(secondaryId);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, primaryId);
    });

    test('closing the primary Diagram tab leaves a secondary instance open and unaffected', () {
      final controller = WorkspaceTabsController();
      final primaryId = openDiagramTab(controller);
      final secondaryId = openDiagramTab(controller);

      controller.close(primaryId);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, secondaryId);
    });

    test('a Diagram instance opened after the primary was closed and re-opened still gets a fresh, distinct id', () {
      final controller = WorkspaceTabsController();
      final primaryId = openDiagramTab(controller);
      controller.close(primaryId);

      final reopenedPrimaryId = openDiagramTab(controller);
      final secondId = openDiagramTab(controller);

      expect(reopenedPrimaryId, primaryDiagramInstanceId, reason: 'the primary alias is deterministic and self-heals');
      expect(secondId, isNot(reopenedPrimaryId));
    });

    test('existing singleton Surfaces are unaffected by Diagram\'s multi-instance behavior', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      openDiagramTab(controller);
      openDiagramTab(controller);

      final firstId = controller.openSurface(surface.id);
      final secondId = controller.openSurface(surface.id);

      expect(firstId, secondId, reason: 'non-Diagram Surfaces still dedupe to one tab');
      expect(controller.tabs.where((t) => t.surfaceId == surface.id), hasLength(1));
    });
  });

  group('diagramOrdinalFor (AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001)', () {
    test('the first open Diagram tab has ordinal 1', () {
      final tabs = [WorkspaceTab(id: 'a', surfaceId: WorkspaceTab.diagramSurfaceId)];
      expect(diagramOrdinalFor(tabs, 0), 1);
    });

    test('the second and third open Diagram tabs have ordinals 2 and 3', () {
      final tabs = [
        WorkspaceTab(id: 'a', surfaceId: WorkspaceTab.diagramSurfaceId),
        WorkspaceTab(id: 'b', surfaceId: WorkspaceTab.diagramSurfaceId),
        WorkspaceTab(id: 'c', surfaceId: WorkspaceTab.diagramSurfaceId),
      ];
      expect(diagramOrdinalFor(tabs, 1), 2);
      expect(diagramOrdinalFor(tabs, 2), 3);
    });

    test('a non-Diagram tab always has ordinal 0, regardless of position', () {
      final surface = SurfaceRegistry.all.first;
      final tabs = [
        WorkspaceTab(id: 'a', surfaceId: WorkspaceTab.diagramSurfaceId),
        WorkspaceTab(id: 'b', surfaceId: surface.id),
      ];
      expect(diagramOrdinalFor(tabs, 1), 0);
    });

    test('ordinals count only Diagram tabs, ignoring interleaved non-Diagram tabs', () {
      final surface = SurfaceRegistry.all.first;
      final tabs = [
        WorkspaceTab(id: 'a', surfaceId: WorkspaceTab.diagramSurfaceId),
        WorkspaceTab(id: 'x', surfaceId: surface.id),
        WorkspaceTab(id: 'b', surfaceId: WorkspaceTab.diagramSurfaceId),
      ];
      expect(diagramOrdinalFor(tabs, 0), 1);
      expect(diagramOrdinalFor(tabs, 2), 2);
    });
  });

  group('splitWith/closeSplit (AP-OEP-WORKSPACE-SPLIT-VIEW-001)', () {
    test('no split by default', () {
      final controller = WorkspaceTabsController();
      controller.openSurface(SurfaceRegistry.all.first.id);

      expect(controller.secondTabId, isNull);
      expect(controller.second, isNull);
    });

    test('splitWith a valid open tab sets secondTabId, leaving activeId untouched', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      final bId = controller.openSurface(SurfaceRegistry.all[1].id);

      controller.splitWith(aId);

      expect(controller.secondTabId, aId);
      expect(controller.activeId, bId, reason: 'splitWith must never change which tab is primary/active');
      expect(controller.tabs.map((t) => t.id).toList(), [aId, bId], reason: 'tab order is untouched');
    });

    test('splitWith an unknown/invalid id is a no-op', () {
      final controller = WorkspaceTabsController();
      controller.openSurface(SurfaceRegistry.all.first.id);

      controller.splitWith('does-not-exist');

      expect(controller.secondTabId, isNull);
    });

    test('splitWith the already-selected secondTabId is a no-op (no extra notification)', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      controller.openSurface(SurfaceRegistry.all[1].id);
      controller.splitWith(aId);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.splitWith(aId);

      expect(notifications, 0);
    });

    test('splitWith the same tab as activeId is permitted at the state level (not rejected as invalid)', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all.first.id);

      controller.splitWith(aId);

      expect(controller.secondTabId, aId);
      expect(controller.activeId, aId);
    });

    test('closeSplit clears secondTabId and is a no-op when already unsplit', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      controller.openSurface(SurfaceRegistry.all[1].id);
      controller.splitWith(aId);

      controller.closeSplit();
      expect(controller.secondTabId, isNull);

      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.closeSplit();
      expect(notifications, 0);
    });

    test('does not modify openSurface() semantics', () {
      final controller = WorkspaceTabsController();
      final surface = SurfaceRegistry.all.first;
      final firstId = controller.openSurface(surface.id);
      controller.splitWith(firstId);

      final secondCallId = controller.openSurface(surface.id);

      expect(secondCallId, firstId, reason: 'still one tab per surfaceId, split or not');
      expect(controller.tabs, hasLength(1));
    });

    test('does not modify openNewInstance() semantics', () {
      final controller = WorkspaceTabsController();
      const surfaceId = 'test-multi-instance-surface';
      final aId = controller.openNewInstance(surfaceId);
      controller.splitWith(aId);

      final bId = controller.openNewInstance(surfaceId);

      expect(bId, isNot(aId), reason: 'still always creates a new instance, split or not');
      expect(controller.tabs, hasLength(2));
    });

    group('close() interaction', () {
      test('A | B, close A -> B remains, split collapses to single-tab mode', () {
        final controller = WorkspaceTabsController();
        final aId = controller.openSurface(SurfaceRegistry.all[0].id);
        final bId = controller.openSurface(SurfaceRegistry.all[1].id);
        controller.activate(aId);
        controller.splitWith(bId);

        controller.close(aId);

        expect(controller.tabs.map((t) => t.id).toList(), [bId]);
        expect(controller.secondTabId, isNull);
        expect(controller.activeId, bId);
      });

      test('A | B, close B -> A remains, split collapses to single-tab mode', () {
        final controller = WorkspaceTabsController();
        final aId = controller.openSurface(SurfaceRegistry.all[0].id);
        final bId = controller.openSurface(SurfaceRegistry.all[1].id);
        controller.activate(aId);
        controller.splitWith(bId);

        controller.close(bId);

        expect(controller.tabs.map((t) => t.id).toList(), [aId]);
        expect(controller.secondTabId, isNull);
        expect(controller.activeId, aId);
      });

      test('A | B, closing a different tab C leaves the split as A | B', () {
        final controller = WorkspaceTabsController();
        final aId = controller.openSurface(SurfaceRegistry.all[0].id);
        final bId = controller.openSurface(SurfaceRegistry.all[1].id);
        final cId = controller.openSurface(SurfaceRegistry.all[2].id);
        controller.activate(aId);
        controller.splitWith(bId);

        controller.close(cId);

        expect(controller.activeId, aId);
        expect(controller.secondTabId, bId);
        expect(controller.tabs.map((t) => t.id).toList(), [aId, bId]);
      });

      test('closing the active tab while split resolves cleanly rather than showing the same tab in both panes', () {
        final controller = WorkspaceTabsController();
        final aId = controller.openSurface(SurfaceRegistry.all[0].id);
        final bId = controller.openSurface(SurfaceRegistry.all[1].id);
        controller.activate(aId);
        controller.splitWith(bId);

        // Closing A: the existing neighbor-selection rule has no tab
        // before A, so it falls back to the new first tab, which is B —
        // exactly the tab already occupying the second pane.
        controller.close(aId);

        expect(controller.activeId, bId);
        expect(controller.secondTabId, isNull, reason: 'must not silently show B in both panes');
      });

      test('closing the final split participant leaves the Workspace in normal single-tab mode', () {
        final controller = WorkspaceTabsController();
        final aId = controller.openSurface(SurfaceRegistry.all[0].id);
        final bId = controller.openSurface(SurfaceRegistry.all[1].id);
        controller.splitWith(bId);
        controller.close(bId);

        expect(controller.secondTabId, isNull);
        expect(controller.tabs, hasLength(1));
        expect(controller.tabs.single.id, aId);
      });
    });

    test('activation while split: activating C replaces the primary/left pane only -> A|B becomes C|B', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      final bId = controller.openSurface(SurfaceRegistry.all[1].id);
      final cId = controller.openSurface(SurfaceRegistry.all[2].id);
      controller.activate(aId);
      controller.splitWith(bId);

      controller.activate(cId);

      expect(controller.activeId, cId);
      expect(controller.secondTabId, bId, reason: 'the second pane is untouched by activating a different tab');
    });

    test('two Diagram instances can be split together', () {
      final controller = WorkspaceTabsController();
      final primaryId = openDiagramTab(controller);
      final secondaryId = openDiagramTab(controller);

      controller.activate(primaryId);
      controller.splitWith(secondaryId);

      expect(controller.activeId, primaryId);
      expect(controller.secondTabId, secondaryId);
      expect(controller.tabs, hasLength(2));
      expect(controller.tabs.every((t) => t.isDiagram), isTrue);
    });

    test('singleton Surface behavior is unaffected by an unrelated split', () {
      final controller = WorkspaceTabsController();
      final diagramId = openDiagramTab(controller);
      final secondDiagramId = openDiagramTab(controller);
      controller.splitWith(secondDiagramId);

      final surface = SurfaceRegistry.all.first;
      final firstId = controller.openSurface(surface.id);
      final secondId = controller.openSurface(surface.id);

      expect(firstId, secondId, reason: 'still deduplicates to one tab regardless of split state');
      expect(controller.tabs.where((t) => t.surfaceId == surface.id), hasLength(1));
      expect(diagramId, isNot(secondDiagramId));
    });

    test('tab order is unaffected by splitWith/closeSplit', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      final bId = controller.openSurface(SurfaceRegistry.all[1].id);
      final cId = controller.openSurface(SurfaceRegistry.all[2].id);

      controller.splitWith(aId);
      controller.closeSplit();
      controller.splitWith(cId);

      expect(controller.tabs.map((t) => t.id).toList(), [aId, bId, cId]);
    });
  });

  group('Browser (AP-OEP-WORKSPACE-BROWSER-001)', () {
    // Controller-level only, matching the established WebView test
    // strategy (`test/web_surface/web_surface_test.dart`'s own doc
    // comment): `WorkspaceTabsController` never constructs a Browser
    // Surface's actual widget/`WebviewController` — only its
    // `WorkspaceTab.id`/`surfaceId` bookkeeping, which is all that's
    // needed to prove every requirement below.

    test('3/4/5/6. every Browser open creates a new, distinctly-id\'d Workspace tab -- never deduplicated', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      expect(controller.tabs, hasLength(1));

      final bId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      expect(controller.tabs, hasLength(2));
      expect(bId, isNot(aId));
      expect(controller.tabs.map((t) => t.surfaceId).toSet(), {SurfaceRegistry.browserSurfaceId});

      final cId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      expect(controller.tabs, hasLength(3), reason: 'a third Browser open is a third distinct tab, not a no-op');
      expect({aId, bId, cId}, hasLength(3));
    });

    test('7. activation works for a Browser tab', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      final bId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);

      controller.activate(aId);

      expect(controller.activeId, aId);
      expect(controller.tabs.map((t) => t.id).toSet(), {aId, bId});
    });

    test('8. closing a Browser tab works, leaving any other Browser tab intact', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      final bId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);

      controller.close(aId);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, bId);
    });

    test('10. Browser instances coexist with a Diagram instance', () {
      final controller = WorkspaceTabsController();
      final diagramId = openDiagramTab(controller);
      final browserId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);

      expect(controller.tabs, hasLength(2));
      expect(controller.tabs.map((t) => t.id).toSet(), {diagramId, browserId});
      expect(controller.tabs.firstWhere((t) => t.id == diagramId).isDiagram, isTrue);
      expect(controller.tabs.firstWhere((t) => t.id == browserId).surfaceId, SurfaceRegistry.browserSurfaceId);
    });

    test('11. Browser instances coexist with native Surfaces', () {
      final controller = WorkspaceTabsController();
      final nativeId = controller.openSurface(SurfaceRegistry.all.first.id);
      final browserId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);

      expect(controller.tabs, hasLength(2));
      expect(controller.tabs.map((t) => t.id).toSet(), {nativeId, browserId});
    });

    test('12. two Browser tabs can be selected as the two split panes', () {
      final controller = WorkspaceTabsController();
      final aId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      final bId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      controller.activate(aId);

      controller.splitWith(bId);

      expect(controller.activeId, aId);
      expect(controller.secondTabId, bId);
    });

    test('Browser + Diagram can be placed side-by-side in split view', () {
      final controller = WorkspaceTabsController();
      final diagramId = openDiagramTab(controller);
      final browserId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      controller.activate(diagramId);

      controller.splitWith(browserId);

      expect(controller.activeId, diagramId);
      expect(controller.secondTabId, browserId);
    });

    test('Browser + a native Surface can be placed side-by-side in split view', () {
      final controller = WorkspaceTabsController();
      final nativeId = controller.openSurface(SurfaceRegistry.all.first.id);
      final browserId = controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      controller.activate(nativeId);

      controller.splitWith(browserId);

      expect(controller.activeId, nativeId);
      expect(controller.secondTabId, browserId);
    });

    test('14. existing singleton Surfaces remain singleton once Browser tabs also exist', () {
      final controller = WorkspaceTabsController();
      controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      controller.openNewInstance(SurfaceRegistry.browserSurfaceId);
      final surface = SurfaceRegistry.all.first;

      final firstId = controller.openSurface(surface.id);
      final secondId = controller.openSurface(surface.id);

      expect(firstId, secondId);
      expect(controller.tabs.where((t) => t.surfaceId == surface.id), hasLength(1));
    });

    test('the Workspace "+" menu\'s generic Surface list never offers Browser via openSurface', () {
      expect(SurfaceRegistry.all.any((s) => s.id == SurfaceRegistry.browserSurfaceId), isFalse);
    });
  });

  test('SurfaceRegistry has no duplicate ids (a shared invariant this shell also depends on)', () {
    final ids = SurfaceRegistry.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
