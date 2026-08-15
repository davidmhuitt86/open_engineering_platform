import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';
import 'package:oep_studio/shared/widgets/dockable_panel.dart';

/// User-requested dockable panels: "they just need a permanent place to
/// sit in the window with the ability to move that panel to another
/// place as well as resize" -- panels are no longer freely draggable
/// (see `dockable_panel.dart`'s own doc comment); "move" is a title-bar
/// menu that reassigns a panel's [PanelDockSlot]. Covers the Key States
/// panel specifically. (Resize is covered separately, in
/// `diagram_studio_key_states_panel_resize_test.dart` -- a full app
/// bootstrap per `testWidgets` proved unreliable sharing one process
/// with a second full bootstrap in this same file, matching this
/// codebase's existing "split flaky multi-bootstrap files" convention.)
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

  testWidgets('Key States panel can be moved to another dock slot via its own menu', (tester) async {
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

    final titleBarFinder = find.text('KEY STATES');
    expect(titleBarFinder, findsOneWidget);
    final panelFinder = find.ancestor(of: titleBarFinder, matching: find.byType(DockablePanel));
    expect(panelFinder, findsOneWidget);
    // Key States defaults to the TOP slot -- near the top of the window.
    final before = tester.getTopLeft(panelFinder);

    await tester.tap(find.descendant(of: panelFinder, matching: find.byIcon(Icons.dock_outlined)));
    await settle(tester);
    await tester.tap(find.text('Move to Right'));
    await settle(tester);

    final after = tester.getTopLeft(panelFinder);
    expect(after.dx, greaterThan(before.dx),
        reason: 'moving to the Right slot should place the panel toward the right edge of the window, not where it started');
  });
}
