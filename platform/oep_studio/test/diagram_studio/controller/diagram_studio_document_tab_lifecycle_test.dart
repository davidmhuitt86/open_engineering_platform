import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';
import 'package:oep_studio/diagram_studio/tabs/diagram_tabs_controller.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// Regression coverage for AP-DIAGRAM-W2-C (Wave 2 Stage C — Document /
/// Tab Lifecycle Extraction). The document/tab lifecycle operations
/// (`newDocument`/`openDocument`/`saveDocument`/`saveDocumentAs`/
/// `closeDocument`/`closeTab`/`activateTab`/`reopenRecentlyClosed`) have
/// lived on `DiagramStudioController` since Wave 2's original landing
/// (composition boundary §7–§8), and that Controller has been
/// provider-hosted with app-session lifetime since Stage A. What Stage C
/// verifies — and what was genuinely still open before it — is that this
/// combination actually delivers the invariant the whole Wave exists to
/// establish:
///
///   widget rebuild/remount  ≠  document recreation
///   widget rebuild/remount  ≠  tab recreation
///   widget rebuild/remount  ≠  Engine session recreation
///
/// None of `_newDocument`/`_openDocument`/`_closeTab`/etc. are ever
/// called automatically from `initState`/`build`/`_bootstrap` — every
/// one is wired only to an explicit user action (menu item, tab click,
/// keyboard shortcut). The only place document/tab creation happens
/// without a direct user action is inside
/// `DiagramStudioController.bootstrap`'s own seed-tab fallback, and that
/// method itself only runs once per app session (Stage A). This test
/// exercises that combination directly against the real engine/tabs
/// providers, rather than re-asserting it as a code-reading claim.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'document/tab lifecycle is independent of widget mounting: seed-tab cannot race a restored document, switching works, and a revisit neither duplicates tabs nor discards the live document',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // AP-DIAGRAM-W2-D1: isolates this test's tabs/workspace/document
      // persistence from the real machine — this test creates and closes
      // real tabs (below), which previously required careful try/finally
      // real-disk restoration; with isolation, that entire concern is
      // gone, since nothing this test does can reach the real
      // %APPDATA%/oep_studio at all.
      useIsolatedSettingsStorage();

      final (firstController, container) = await bootstrapDiagramStudioController(tester);
      final EngineeringEngine engine = firstController.engine;

      // --- 4/7: tab restoration ran before / instead of the seed-tab -----
      // fallback. `DiagramStudioController.bootstrap` only ever seeds a
      // tab when `diagramTabsProvider` is empty *after* awaiting
      // restoration; on a fresh isolated root there is nothing to
      // restore, so the fallback fires deterministically, seeding
      // exactly one tab — proven by the tab list being non-empty (and,
      // per the seed-tab logic, exactly length 1) immediately after
      // bootstrap.
      final tabsAfterBootstrap = container.read(diagramTabsProvider);
      expect(tabsAfterBootstrap.tabs, hasLength(1), reason: 'a fresh isolated root has nothing to restore, so bootstrap\'s seed-tab fallback must have created exactly one tab');
      final tabCountAfterBootstrap = tabsAfterBootstrap.tabs.length;

      // --- 1: a live, in-memory-only document edit ------------------------
      final nodesBefore = Set<String>.from(engine.editing.session.graph.nodes.keys);
      firstController.addNode('battery', const Point2D(40, 40));
      await settle(tester);
      final liveNodeIds = engine.editing.session.graph.nodes.keys.toSet();
      expect(liveNodeIds.length, nodesBefore.length + 1);
      expect(firstController.isDirty, isTrue, reason: 'setup: the live edit must actually mark the document dirty before testing that dirty state survives lifecycle operations');

      // --- 6/7/12: tab switching (new tab, then back) preserves expected --
      // active-document / active-tab state, and does so through the
      // existing openDocument/newDocument pipeline (never a second
      // document model). IMPORTANT, discovered by running this test
      // against the real controller rather than assuming: switching
      // *away* from a dirty tab through `activateTab` directly (bypassing
      // `DiagramStudioPage._activateTab`'s own dirty-check +
      // `_confirmDiscardChanges()` dialog) does NOT preserve the unsaved
      // edit — the single shared Engine holds one document at a time, and
      // `activateTab`'s target-tab branch reopens the target's real file
      // from disk (`EngineeringProjectNotifier.openDocument`). That is
      // correct, existing, intentional behavior (composition boundary
      // entry 80): the *page* is what protects the user from losing
      // unsaved work, by asking before ever calling this method — the
      // Controller method itself has no reason to know or care. This
      // test therefore does not assert the (false) claim that switching
      // away and back preserves an unsaved edit; it asserts the true
      // thing: the reload is real (reflects the last-saved/persisted
      // content, not the discarded in-memory edit) and dirty state is
      // correctly clean afterward.
      final activeTabBefore = tabsAfterBootstrap.activeTabId;
      // `newDocument()`/`activateTab()` perform real (non-fake) async
      // work internally (`EngineeringProjectNotifier`'s document I/O),
      // so — like `bootstrap()` above — they must run inside
      // `tester.runAsync`; awaiting them directly in the fake-async test
      // zone leaves their real `Future`s permanently unresolved (this
      // was verified: it hangs to the suite's 10-minute timeout).
      await tester.runAsync(() => firstController.newDocument());
      await settle(tester);
      final tabsAfterNew = container.read(diagramTabsProvider);
      expect(tabsAfterNew.tabs.length, tabCountAfterBootstrap + 1, reason: 'newDocument must create exactly one new tab, not replace or duplicate existing ones');
      expect(tabsAfterNew.activeTabId, isNot(activeTabBefore), reason: 'the new tab must become active');
      // AP-DIAGRAM-W2-D1: with `useIsolatedSettingsStorage()` above,
      // every `DiagramTabsNotifier` mutation this test makes (including
      // the new tab just created) auto-persists only to this test's own
      // disposable temp directory — no real-disk cleanup is needed here
      // (Stage C's own version of this test required an elaborate
      // try/finally real-tab-list restoration; that entire concern is
      // gone).
      expect(engine.editing.session.graph.nodes, isEmpty, reason: 'newDocument must give the shared engine a genuinely blank session (Engine resetSession/beginEditingSession boundary), independent of the previous tab');

      // Switch back to the original tab.
      expect(activeTabBefore, isNotNull);
      final modeOnActivate = await tester.runAsync(() => firstController.activateTab(activeTabBefore!));
      await settle(tester);
      expect(modeOnActivate, isNotNull, reason: 'activateTab must recognize a real existing tab id');
      expect(container.read(diagramTabsProvider).activeTabId, activeTabBefore, reason: 'activating the original tab must make it active again');
      expect(engine.editing.session.graph.nodes.keys.toSet(), nodesBefore, reason: 'switching back must reload the original tab\'s real (persisted) document — the unsaved in-memory edit from before the switch is correctly gone, exactly as it would be if the page had asked to discard and the user agreed');
      expect(firstController.isDirty, isFalse, reason: 'a freshly (re)opened document must not be dirty');

      // --- 1/2/3/5/9: a *fresh* live edit, then a widget remount ---------
      // without any tab switch in between — this is the actual "widget
      // rebuild/remount ≠ document/tab recreation" invariant Stage C
      // exists to prove, isolated from the (unrelated, already-correct)
      // tab-switch reload behavior demonstrated above.
      final nodesBeforeSecondEdit = Set<String>.from(engine.editing.session.graph.nodes.keys);
      firstController.addNode('battery', const Point2D(60, 60));
      await settle(tester);
      final liveNodeIdsAfterRemountSetup = engine.editing.session.graph.nodes.keys.toSet();
      expect(liveNodeIdsAfterRemountSetup.length, nodesBeforeSecondEdit.length + 1);
      expect(firstController.isDirty, isTrue);
      final tabCountBeforeRemount = container.read(diagramTabsProvider).tabs.length;

      // AP-DIAGRAM-V2-BRIDGE-010 — the original version of this section
      // unmounted/remounted `DiagramStudioPage` (now retired) to prove a
      // widget remount doesn't reconstruct the controller or re-run
      // bootstrap. As with the sibling provider-lifetime test, that
      // invariant is actually about the provider's container-scoped
      // lifetime, not about any particular widget's mount state — a
      // second read from the same container exercises exactly the same
      // question, more directly.
      final secondController = (await tester.runAsync(() => container.read(diagramStudioControllerProvider.future)))!;

      expect(identical(secondController, firstController), isTrue, reason: 'the app-session-scoped Controller must not be reconstructed by a second provider read (Stage A)');
      expect(container.read(diagramTabsProvider).tabs.length, tabCountBeforeRemount, reason: 'a second read must not re-run the seed-tab fallback and must not create/lose any tab — tab count must be exactly what user-driven operations produced, no more and no less');
      expect(engine.editing.session.graph.nodes.keys.toSet(), liveNodeIdsAfterRemountSetup, reason: 'a second read must not re-run document bootstrap/restoration over the live, still-active document — unlike an explicit tab switch, a mere re-read is not a document operation and must not reload anything from disk');
      expect(secondController.isDirty, isTrue, reason: 'dirty state must survive a second provider read unchanged — re-reading is not a document/tab operation and must not touch it');
    },
  );
}
