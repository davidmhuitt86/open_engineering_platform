import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/simulation/simulation_center_dialog.dart';

import 'simulation_test_fixtures.dart';

/// Real end-to-end widget tests: a real `SimulationEngine`, a real
/// `DiagramSimulationService`, a real graph — driven through
/// `SimulationCenterDialog`'s actual UI, asserting on rendered output.
/// Matches `test/publishing/publishing_center_dialog_test.dart`'s own
/// structure/conventions.
void main() {
  late EngineeringGraph graph;
  late DiagramSimulationService simulation;

  setUp(() {
    graph = buildSimulationTestGraph();
    simulation = DiagramSimulationService(engine: SimulationEngine());
  });

  Widget harness() => MaterialApp(
        theme: StudioTheme.dark,
        home: Scaffold(
          body: SimulationCenterDialog(
            simulation: simulation,
            graph: graph,
            onSelectNode: (_) {},
            onSessionStateChanged: () {},
          ),
        ),
      );

  Future<void> enlargeSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders the five simulation tabs', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Power Distribution'), findsOneWidget);
    expect(find.text('Fault Injection'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
  });

  testWidgets('Sessions tab: Create builds a real SimulationSession and makes it current', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(simulation.hasSession, isFalse);
    await tester.tap(find.byKey(const Key('sim_create_session')));
    await tester.pumpAndSettle();

    expect(simulation.hasSession, isTrue);
    expect(find.textContaining(simulation.currentSessionId!), findsWidgets);
  });

  testWidgets('Playback tab is disabled until a session exists, then reflects real engine playback position', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Playback'));
    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No simulation session yet'), findsOneWidget);

    await tester.ensureVisible(find.text('Sessions'));
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_create_session')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Playback'));
    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Position 0 /'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sim_step')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Position 1 /'), findsOneWidget);
    expect(simulation.currentSession!.playbackPosition, 1);
  });

  testWidgets('Fault Injection tab injects a real fault and Diagnostics tab shows the real computed impact', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sim_create_session')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Fault Injection'));
    await tester.tap(find.text('Fault Injection'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fault_target_id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('battery').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fault_inject_button')));
    await tester.pumpAndSettle();

    expect(simulation.currentSession!.activeFaults.active, hasLength(1));
    expect(find.textContaining('openCircuit'), findsWidgets);

    await tester.ensureVisible(find.text('Diagnostics'));
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Simulation Report'), findsOneWidget);
  });

  testWidgets('Power Distribution tab renders a real PowerDistributionView once a session exists', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sim_create_session')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Power Distribution'));
    await tester.tap(find.text('Power Distribution'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Power Domains'), findsOneWidget);
    expect(find.textContaining('Fuse Paths'), findsOneWidget);
  });
}
