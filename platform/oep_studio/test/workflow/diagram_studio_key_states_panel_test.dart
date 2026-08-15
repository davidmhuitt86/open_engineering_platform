import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// User-requested Key States panel: "add this and wire it in to work in
/// all 3 modes" -- verifies the panel shows and actually drives the
/// real `SimulationSession` while the page sits in its DEFAULT mode
/// (Edit, per `DiagramTab.mode`'s own default), not just Simulate mode,
/// proving the removal of the old Simulate-only gate really works end
/// to end rather than just in isolation. (The drag-to-reposition half of
/// this feature is covered separately, in
/// `diagram_studio_key_states_panel_drag_test.dart` -- a full app
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

  testWidgets('Key States panel shows and works in the default (non-Simulate) mode', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);

    // No profile loaded yet -- the panel must not show a fabricated
    // empty frame.
    expect(find.text('KEY STATES'), findsNothing);

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;
    final container = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false);
    final simulation = container.read(diagramSimulationServiceProvider)!;

    const headlightSwitch = InputStateDefinition(id: 'headlight_switch', label: 'Headlights');
    const ignitionOff = OperatingStateDefinition(id: 'ignition_off', name: 'OFF');
    const ignitionOn = OperatingStateDefinition(id: 'ignition_on', name: 'ON');

    // Mirrors what `_loadDomainProfile` does after reading a real
    // profile file -- exercised directly here rather than through the
    // file picker, matching this codebase's existing pattern
    // (`simulation_controls_toolbar_operating_state_test.dart`).
    await simulation.createSession(
      (state.engine.editing.session.graph as EngineeringGraph),
      availableOperatingStates: const [ignitionOff, ignitionOn],
      availableInputStates: const [headlightSwitch],
    );
    state.setState(() {});
    await settle(tester);

    expect(find.text('KEY STATES'), findsOneWidget, reason: 'visible without switching to Simulate mode');
    expect(find.text('IGNITION'), findsOneWidget);
    expect(find.text('HEADLIGHTS'), findsOneWidget);

    // Each group's own ON button, found relative to its label rather
    // than by list position (both IGNITION and HEADLIGHTS render an ON
    // button, so `find.text('ON').first`/`.last` would be order-fragile).
    Finder onButtonFor(String groupLabel) => find.descendant(
          of: find.ancestor(of: find.text(groupLabel), matching: find.byType(Column)).first,
          matching: find.text('ON'),
        );

    expect(simulation.currentSession!.activeInputStates['headlight_switch'], isNot(true));
    await tester.tap(onButtonFor('HEADLIGHTS'));
    await settle(tester);
    expect(simulation.currentSession!.activeInputStates['headlight_switch'], isTrue,
        reason: 'tapping ON in the default mode must actually drive the real session');

    expect(simulation.currentSession!.activeOperatingStateId, isNull);
    await tester.tap(onButtonFor('IGNITION'));
    await settle(tester);
    expect(simulation.currentSession!.activeOperatingStateId, 'ignition_on');
  });
}
