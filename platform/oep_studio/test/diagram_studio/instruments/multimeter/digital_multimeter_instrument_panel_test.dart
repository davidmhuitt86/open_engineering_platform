import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/instruments/multimeter/digital_multimeter_instrument.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/digital_multimeter_instrument_panel.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

/// PRODUCT-READINESS-008 §3/§17 — the DMM instrument panel's own
/// presentation logic, tested in isolation from the live WebView (which
/// no widget test in this repo drives directly — real WebView2 E2E is a
/// separate, dedicated test). [multimeterRuntimeServiceProvider] is
/// overridden directly with a real [MultimeterController] (same
/// construction this controller's own dedicated test file uses); no
/// `engineeringProjectServiceProvider` override is set up (graph stays
/// `null`), so these tests cover mode selection, probe display/clear, and
/// structured-state rendering (via a REAL [MultimeterController
/// .measureElectrical] call against a hand-built graph, driven directly
/// from the test the same way `multimeter_controller_test.dart` already
/// does) — not diagram-selection-driven probe placement, which is a thin
/// wrapper over `EngineeringProjectState.selection` already proven
/// elsewhere (`v2_measurement_bridge_test.dart`'s own operating-context
/// translation test proves the underlying data flow this panel reads).
void main() {
  late MultimeterController controller;

  setUp(() {
    final service = DiagramSimulationService(engine: SimulationEngine());
    controller = MultimeterController(simulationService: service);
  });

  // No manual tearDown/dispose here: `ProviderScope`'s own teardown already
  // disposes the `ChangeNotifierProvider`-vended controller once the
  // widget tree unmounts between tests -- disposing it again here would
  // double-dispose.

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [multimeterRuntimeServiceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: Scaffold(body: DigitalMultimeterInstrumentPanel())),
      ),
    );
    await tester.pump();
  }

  testWidgets('no diagram session: an honest message, not a blank/crashed panel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [multimeterRuntimeServiceProvider.overrideWith((ref) => null)],
        child: const MaterialApp(home: Scaffold(body: DigitalMultimeterInstrumentPanel())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Open or create a diagram first'), findsOneWidget);
  });

  testWidgets('mode selector: tapping a chip changes the controller\'s own selectedType', (tester) async {
    await pumpPanel(tester);
    expect(controller.selectedType, MeasurementType.voltageDc);

    await tester.tap(find.text('Ω'));
    await tester.pump();
    expect(controller.selectedType, MeasurementType.resistance);

    await tester.tap(find.text('•)))'));
    await tester.pump();
    expect(controller.selectedType, MeasurementType.continuity);
  });

  testWidgets('probe controls: show "Not placed" until assigned, and arming shows the prompt', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Not placed'), findsNWidgets(2));

    // Tap the RED probe's own describe-text ("Not placed") -- that's what
    // is actually wrapped in the tappable arm/disarm InkWell, not the
    // plain "RED" label above it.
    await tester.tap(find.text('Not placed').first);
    await tester.pump();
    expect(find.text('Select a terminal…'), findsOneWidget);
  });

  testWidgets('§17 structured display: VALID renders the real number, never "----"', (tester) async {
    final graph = EngineeringGraph(id: 'g', nodes: {
      'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', metadata: {'v2Category': 'power'}, properties: {'nominalVoltageV': 13.82}),
      'b': const EngineeringNode(id: 'b', category: NodeCategory.ground, displayName: 'B'),
    }, relationships: {
      'w': const EngineeringRelationship(id: 'w', relationshipType: RelationshipType.connectedTo, sourceNode: 'a', targetNode: 'b'),
    });
    controller.setProbeA(const ProbePoint(nodeId: 'a'));
    controller.setProbeB(const ProbePoint(nodeId: 'b'));
    await controller.measureElectrical(graph: graph, solver: const ElectricalSolver(), generationCounter: ElectricalSolutionGenerationCounter());

    await pumpPanel(tester);
    expect(find.textContaining('13.82'), findsOneWidget);
  });

  testWidgets('§17 structured display: OPEN renders OL, never a fabricated zero', (tester) async {
    final graph = EngineeringGraph(id: 'g', nodes: {
      'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
      'b': const EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B'),
    }, relationships: const {});
    controller
      ..setProbeA(const ProbePoint(nodeId: 'a'))
      ..setProbeB(const ProbePoint(nodeId: 'b'))
      ..setType(MeasurementType.resistance);
    await controller.measureElectrical(graph: graph, solver: const ElectricalSolver(), generationCounter: ElectricalSolutionGenerationCounter());

    await pumpPanel(tester);
    expect(find.text('OL'), findsOneWidget);
  });

  testWidgets('§26 debug panel is hidden by default and shows real fields when toggled', (tester) async {
    await pumpPanel(tester);
    expect(find.text('solution generation'), findsNothing);

    await tester.tap(find.text('INFO'));
    await tester.pump();
    expect(find.text('solution generation'), findsOneWidget);
    expect(find.text('diagram instance'), findsOneWidget);
  });

  test('DigitalMultimeterInstrument identifies itself correctly (§19/§20)', () {
    const instrument = DigitalMultimeterInstrument();
    expect(instrument.id, 'digitalMultimeter');
    expect(instrument.title, isNotEmpty);
  });
}
