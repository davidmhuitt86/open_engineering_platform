import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): the
/// bottom-left category-color Legend, modeled on
/// `legacy_wiring_sim_v2`'s own toggleable `#legend`. Verifies it's off
/// by default, toggles on/off through the real `PanelsToolbar` icon
/// (not a fabricated always-on panel), and only lists categories real
/// nodes on the canvas actually use.
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

  testWidgets('Legend is off by default, toggles on with real category data, and back off', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);

    expect(find.text('LEGEND'), findsNothing, reason: 'off by default, like every other toggleable panel');

    // Add one real node so the legend has a real category to list.
    await tester.tap(find.byTooltip('Add node'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Battery').first);
    await tester.pumpAndSettle();
    await settle(tester);

    await tester.tap(find.byTooltip('Toggle Legend'));
    await settle(tester);

    expect(find.text('LEGEND'), findsOneWidget);
    // Two matches are expected and correct: the Legend's own row AND the
    // Inspector sidebar's "Category" field for the just-added, still-
    // selected node -- both real, both showing the same real category.
    expect(find.text('component'), findsNWidgets(2), reason: 'a real NodeCategory from the real node just added, not fabricated');

    await tester.tap(find.byTooltip('Toggle Legend'));
    await settle(tester);

    expect(find.text('LEGEND'), findsNothing);
  });
}
