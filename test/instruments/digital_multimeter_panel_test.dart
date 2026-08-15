import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/digital_multimeter_panel.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

import '../simulation/simulation_test_fixtures.dart';

void main() {
  late DiagramSimulationService service;
  late MultimeterController controller;

  setUp(() async {
    service = DiagramSimulationService(engine: SimulationEngine());
    await service.createSession(buildSimulationTestGraph(), name: 'panel-test');
    controller = MultimeterController(simulationService: service);
  });

  Widget harness() => MaterialApp(
        home: Scaffold(body: DigitalMultimeterPanel(controller: controller)),
      );

  testWidgets('shows "not yet supported" for capacitance/temperature in the type dropdown', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(DropdownButton<MeasurementType>).first);
    await tester.pumpAndSettle();
    expect(find.text('capacitance (not yet supported)'), findsOneWidget);
    expect(find.text('temperature (not yet supported)'), findsOneWidget);
  });

  testWidgets('Measure button is disabled until both probes are set', (tester) async {
    await tester.pumpWidget(harness());
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Measure'));
    expect(button.onPressed, isNull);

    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'));
    await tester.pump();

    final enabledButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Measure'));
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('after measuring, the full result readout is displayed', (tester) async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'))
      ..setType(MeasurementType.voltageDc);
    await tester.pumpWidget(harness());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Measure'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reachable:'), findsOneWidget);
    expect(find.textContaining('Measured:'), findsOneWidget);
    expect(find.textContaining('Expected:'), findsOneWidget);
    expect(find.textContaining('Difference:'), findsOneWidget);
    expect(find.textContaining('Path:'), findsOneWidget);
    expect(find.textContaining('Power source:'), findsOneWidget);
    expect(find.textContaining('Ground source:'), findsOneWidget);
    expect(find.textContaining('Contributing relationships:'), findsOneWidget);
    expect(find.textContaining('Timestamp:'), findsOneWidget);
    expect(find.textContaining('Mode:'), findsOneWidget);
  });
}
