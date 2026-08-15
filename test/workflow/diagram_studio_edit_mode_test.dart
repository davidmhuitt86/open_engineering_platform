import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 7: widget-layer acceptance tests
/// specific to Edit/Build mode's own MODE-SENSITIVE behavior (Part 30
/// Tests A, I, J, L, M, N). The underlying editing mechanics
/// themselves (component insertion, node movement, undo/redo depth,
/// wire/port connect, resize) are already exhaustively covered by the
/// pre-existing `diagram_studio_interaction_test.dart` -- which has
/// always run against Edit mode's own real default behavior, before
/// "mode" existed as a concept -- so this file does not re-prove them
/// (Part 13's "use the lowest appropriate testing layer" / don't
/// duplicate existing coverage).
///
/// Stays at 2 real right-clicks in this process (node in Edit mode,
/// same node in Simulate mode), well within the documented
/// `kSecondaryButton` harness ceiling.
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

  Future<void> rightClick(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(point, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('Diagram Studio Edit mode: real construction, save/dirty, fault boundary, mode transitions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;
    final container = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false);

    // --- Test A: Edit mode is the real default; construction tools visible
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Edit is the default mode for a new tab');
    expect(find.text('Unsaved changes'), findsNothing, reason: 'a freshly-bootstrapped document has no real edits yet');

    // --- Test L: a real edit marks the document dirty (existing
    // dirty-tracking, not a new system) --------------------------------
    final before = Set<String>.from(state.engine.editing.session.graph.nodes.keys as Iterable<String>);
    await tester.tap(find.byTooltip('Add node'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Battery'));
    await tester.pumpAndSettle();
    await settle(tester);
    final nodeId = (state.engine.editing.session.graph.nodes.keys as Iterable<String>).firstWhere((id) => !before.contains(id));
    expect(find.text('Unsaved changes'), findsOneWidget, reason: 'a real graph edit must mark the existing dirty-state true');

    // --- Test I/J: contextual menu in Edit mode -- Inspect/Test present,
    // Inject Fault absent (Phase 7 correction: fault is Simulate-only) --
    final nodeRect = tester.getRect(find.byKey(ValueKey('node-$nodeId')));
    await rightClick(tester, nodeRect.center);
    expect(find.text('INSPECT'), findsOneWidget, reason: 'Inspect remains available in Edit mode');
    expect(find.text('TEST'), findsOneWidget, reason: 'Place DMM Probe remains available in Edit mode');
    expect(find.text('Inject Fault'), findsNothing, reason: 'fault injection is Simulate-only as of Phase 7');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test N: Edit -> Simulate preserves the real shared runtime,
    // no duplicate instance --------------------------------------------
    final multimeter = container.read(multimeterRuntimeServiceProvider)!;
    final simulation = container.read(diagramSimulationServiceProvider)!;
    await tester.tap(find.byKey(const ValueKey('diagram-mode-simulate')));
    await settle(tester);
    expect(container.read(multimeterRuntimeServiceProvider), same(multimeter), reason: 'switching mode must not create a second DMM instance');
    expect(container.read(diagramSimulationServiceProvider), same(simulation), reason: 'switching mode must not create a second simulation instance');

    await simulation.createSession(state.engine.editing.session.graph, name: 'phase-7-edit-simulate-test');
    await rightClick(tester, nodeRect.center);
    expect(find.text('Inject Fault'), findsOneWidget, reason: 'fault injection is now available in Simulate mode with a real active session');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test M: Simulate -> View hides construction tools and Inject
    // Fault, without disturbing the real session -------------------------
    await tester.tap(find.byKey(const ValueKey('diagram-mode-view')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsNothing);
    expect(simulation.hasSession, isTrue, reason: 'switching to View must not tear down the real, active simulation session');

    // --- Back to Edit: construction tools restored, real state intact --
    await tester.tap(find.byKey(const ValueKey('diagram-mode-edit')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsOneWidget);
    expect(state.engine.editing.session.graph.nodes.containsKey(nodeId), isTrue, reason: 'the real edit made earlier must still be present');
  });
}
