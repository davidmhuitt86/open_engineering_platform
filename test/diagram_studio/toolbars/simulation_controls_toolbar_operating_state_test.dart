import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/toolbars/diagram_toolbars.dart';

/// OEP Engineering Runtime -- Phase 9 (Operating State & Input-State
/// Architecture), Test K: "Operating-state controls are available only
/// in Simulate mode." `SimulationControlsToolbar` is already only ever
/// mounted by `DiagramStudioPage` when `activeMode == DiagramStudioMode.simulate`
/// (Phase 8) -- this widget-level test verifies the operating-state
/// dropdown itself is additionally, independently gated on real data:
/// present only once a real session with real, caller-supplied
/// operating states exists, absent otherwise (never a fabricated
/// default control with nothing real behind it).
void main() {
  EngineeringGraph buildGraph() => EngineeringGraph(
        id: 'g-toolbar-state',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
        },
      );

  Widget harness(DiagramSimulationService simulation, EngineeringGraph graph) => MaterialApp(
        home: Scaffold(
          body: SimulationControlsToolbar(simulation: simulation, graph: graph, onChanged: () {}),
        ),
      );

  testWidgets('no operating-state dropdown when the session has none (no fabricated default)', (tester) async {
    final simulation = DiagramSimulationService(engine: SimulationEngine());
    final graph = buildGraph();
    await simulation.createSession(graph);

    await tester.pumpWidget(harness(simulation, graph));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('a real operating-state dropdown appears once a real domain profile is supplied, and setting it calls the real session', (tester) async {
    const keyOff = OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off');
    const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');
    final simulation = DiagramSimulationService(engine: SimulationEngine());
    final graph = buildGraph();
    await simulation.createSession(graph, availableOperatingStates: const [keyOff, keyOn]);

    await tester.pumpWidget(harness(simulation, graph));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(simulation.currentSession!.activeOperatingStateId, isNull);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Key On / Engine Off').last);
    await tester.pumpAndSettle();

    expect(simulation.currentSession!.activeOperatingStateId, 'key_on', reason: 'the real session, not a copy');
  });

  testWidgets('Phase 14: a loaded DomainProfile flows into the real session created by pressing Start', (tester) async {
    const keyOff = OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off');
    const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');
    const headlightSwitch = InputStateDefinition(id: 'headlight_switch', label: 'Headlight Switch');
    const profile = DomainProfile(
      id: 'trx300',
      name: 'TRX300',
      operatingStates: [keyOff, keyOn],
      inputStates: [headlightSwitch],
    );
    final simulation = DiagramSimulationService(engine: SimulationEngine());
    final graph = buildGraph();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SimulationControlsToolbar(simulation: simulation, graph: graph, onChanged: () {}, domainProfile: profile),
      ),
    ));
    await tester.pumpAndSettle();

    expect(simulation.hasSession, isFalse);
    await tester.tap(find.byTooltip('Start simulation'));
    await tester.pumpAndSettle();

    expect(simulation.hasSession, isTrue);
    // The exact real session this toolbar's own "Start" action created --
    // not a second, independently-constructed session -- carries the
    // profile's real states.
    expect(simulation.currentSession!.availableOperatingStates.map((s) => s.id), ['key_off', 'key_on']);
    expect(simulation.currentSession!.availableInputStates.single.id, 'headlight_switch');
  });
}
