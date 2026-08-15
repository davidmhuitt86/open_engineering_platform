import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';
import 'package:oep_studio/shared/widgets/dockable_panel.dart';

/// User-requested dockable panels: "...as well as resize" -- covered
/// separately from `diagram_studio_key_states_panel_drag_test.dart`
/// (which covers moving between slots), matching this codebase's
/// existing "split flaky multi-bootstrap files" convention.
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

  testWidgets("a dock slot's resize handle changes a docked panel's size", (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;
    final container = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false);
    final simulation = container.read(diagramSimulationServiceProvider)!;
    const ignitionOff = OperatingStateDefinition(id: 'ignition_off', name: 'OFF');
    await simulation.createSession(
      (state.engine.editing.session.graph as EngineeringGraph),
      availableOperatingStates: const [ignitionOff],
    );
    state.setState(() {});
    await settle(tester);

    final panelFinder = find.ancestor(of: find.text('KEY STATES'), matching: find.byType(DockablePanel));
    final beforeSize = tester.getSize(panelFinder);

    // The TOP slot's own resize handle -- a private widget, matched by
    // its runtime type name (the same pattern this test suite already
    // uses elsewhere for a private-but-real widget, e.g.
    // `diagram_studio_wire_create_mode_test.dart`'s `ResizeHandles`
    // lookup).
    // Two exist (this page's TOP and BOTTOM dock slots -- MiniMap
    // always renders in BOTTOM by default) -- the TOP one (Key States'
    // own slot) is added first in the widget tree.
    final handleFinder = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_VerticalResizeHandle').first;

    final gesture = await tester.startGesture(tester.getCenter(handleFinder));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    final afterSize = tester.getSize(panelFinder);
    expect(afterSize.height, greaterThan(beforeSize.height),
        reason: 'dragging the TOP slot handle downward should grow the slot (and every panel docked in it)');
  });
}
