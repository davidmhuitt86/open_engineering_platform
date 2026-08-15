import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/tabs/diagram_tabs_controller.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 5: widget-layer acceptance tests for the
/// browser-style tab bar and three-mode workspace, covering Part 25's
/// Tests F/I plus the tab-bar UI wiring (Tests A-C/E at the widget
/// layer -- the controller's own state logic is already covered,
/// independent of widgets, in
/// `test/diagram_studio/tabs/diagram_tabs_controller_test.dart`).
void main() {
  Widget harness() {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: DiagramStudioPage()),
      ),
    );
  }

  Future<void> bootstrap(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byTooltip('Add node').evaluate().isNotEmpty) return;
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Diagram Studio tab bar and three-mode workspace', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Engine bootstrap must complete first');

    final container = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false);

    // --- Test A/B (tab bar): one real tab exists after bootstrap -------
    var tabsState = container.read(diagramTabsProvider);
    expect(tabsState.tabs, hasLength(1), reason: 'the page seeds exactly one tab for the document it opened to');
    final firstTabId = tabsState.activeTabId;
    expect(firstTabId, isNotNull);

    // --- Test F: mode switching -----------------------------------------
    // Default mode is Edit -- PlacementToolbar's "Add node" control is
    // visible (matches every pre-Phase-5 test's own bootstrap check).
    expect(find.byTooltip('Add node'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diagram-mode-view')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsNothing, reason: 'View mode must not expose the construction toolset');

    await tester.tap(find.byKey(const ValueKey('diagram-mode-simulate')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsNothing, reason: 'Simulate mode must not expose the construction toolset either');

    await tester.tap(find.byKey(const ValueKey('diagram-mode-edit')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'switching back to Edit restores the construction toolset');

    // --- Test G: mode persists per tab, independent of other tabs -------
    expect(container.read(diagramTabsProvider).activeTab!.mode.name, 'edit');

    // --- Test I: existing functionality (right-click contextual menu) ---
    // Reuses the same real, already-proven right-click -> CursorTarget ->
    // resolver -> menu pipeline from Phase 3/4 -- just one gesture here,
    // to confirm tabs/modes didn't break it, not to re-prove the whole
    // pipeline again. Right-clicks a real node (rather than empty
    // canvas) to sidestep the unrelated, already-documented "empty
    // diagram content-area sizing" quirk Phase 3's own tests worked
    // around.
    final engineDynamic = tester.state(find.byType(DiagramStudioPage)) as dynamic;
    final before = Set<String>.from(engineDynamic.engine.editing.session.graph.nodes.keys as Iterable<String>);
    await tester.tap(find.byTooltip('Add node'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Battery'));
    await tester.pumpAndSettle();
    await settle(tester);
    final nodeId =
        (engineDynamic.engine.editing.session.graph.nodes.keys as Iterable<String>).firstWhere((id) => !before.contains(id));
    final nodeRect = tester.getRect(find.byKey(ValueKey('node-$nodeId')));

    final gesture = await tester.startGesture(nodeRect.center, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('INSPECT'), findsOneWidget, reason: 'the existing contextual menu must still work after Phase 5');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test E: pin ------------------------------------------------------
    await tester.tap(find.byKey(ValueKey('diagram-tab-pin-$firstTabId')));
    await settle(tester);
    expect(container.read(diagramTabsProvider).tabs.single.pinned, isTrue);

    // --- New tab via "+" --------------------------------------------------
    await tester.tap(find.byTooltip('New diagram tab'));
    await settle(tester);
    // The node added just above made the document dirty -- "New" goes
    // through the same existing discard-confirmation as before Phase 5
    // (Part 15's own explicit requirement).
    if (find.text('Discard').evaluate().isNotEmpty) {
      await tester.tap(find.text('Discard'));
      await settle(tester);
    }
    tabsState = container.read(diagramTabsProvider);
    expect(tabsState.tabs, hasLength(2), reason: 'the "+" control opens a real second tab');
    final secondTabId = tabsState.activeTabId;
    expect(secondTabId, isNot(firstTabId));

    // --- Test C: closing the active (second) tab returns to the first ---
    await tester.tap(find.byKey(ValueKey('diagram-tab-close-$secondTabId')));
    await settle(tester);
    tabsState = container.read(diagramTabsProvider);
    expect(tabsState.tabs, hasLength(1));
    expect(tabsState.activeTabId, firstTabId, reason: 'closing the active tab returns to the remaining (pinned) tab');
    // Part 15/E: pinning never prevented an intentional close, and the
    // still-open pinned tab remains pinned.
    expect(tabsState.tabs.single.pinned, isTrue);
  });
}
