import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/instruments/probe/probe_overlay.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

import '../simulation/simulation_test_fixtures.dart';

void main() {
  late MultimeterController controller;
  late DiagramLayoutState layout;

  setUp(() async {
    final service = DiagramSimulationService(engine: SimulationEngine());
    await service.createSession(buildSimulationTestGraph(), name: 'probe-test');
    controller = MultimeterController(simulationService: service);
    layout = buildSimulationTestLayout();
  });

  Widget harness() => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ProbeOverlay(
                controller: controller,
                graph: buildSimulationTestGraph(),
                layout: layout,
                // The fixture graph's nodes carry no `symbolId`, so every
                // `resolve` call falls back to `SymbolDefinition.unknown`
                // (empty `ports`) regardless of whether this library was
                // ever `initialize()`d from real symbol assets -- fine
                // for these node-level-anchoring tests.
                symbols: SymbolLibrary(),
                pan: const Point2D(0, 0),
                zoom: 1,
                active: true,
              ),
            ],
          ),
        ),
      );

  testWidgets('renders no markers with no probes placed', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.byTooltip('Probe A (black): battery'), findsNothing);
  });

  testWidgets('renders a marker for each placed probe with the correct tooltip', (tester) async {
    controller
      ..setProbeA(const ProbePoint(nodeId: 'battery'))
      ..setProbeB(const ProbePoint(nodeId: 'lamp'));
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byTooltip('Probe A (black): battery'), findsOneWidget);
    expect(find.byTooltip('Probe B (red): lamp'), findsOneWidget);
  });

  test('placeByNodeTap sets the given slot to a ProbePoint anchored at that node', () {
    ProbeOverlay.placeByNodeTap(controller, ProbeSlot.a, 'fuse1');
    expect(controller.probeA?.nodeId, 'fuse1');
    expect(controller.probeB, isNull);

    ProbeOverlay.placeByNodeTap(controller, ProbeSlot.b, 'chassis');
    expect(controller.probeB?.nodeId, 'chassis');
  });

  test('placeByPortTap sets the given slot to a ProbePoint anchored at that specific port', () {
    // Regression test: a node with more than one terminal (e.g. a real
    // battery's positive/negative) must be probeable at a *specific*
    // terminal, not just "the node as a whole" -- see this file's own
    // module doc comment.
    ProbeOverlay.placeByPortTap(controller, ProbeSlot.a, const PortReference(nodeId: 'battery', portId: 'positive'));
    expect(controller.probeA?.nodeId, 'battery');
    expect(controller.probeA?.portId, 'positive');

    ProbeOverlay.placeByPortTap(controller, ProbeSlot.b, const PortReference(nodeId: 'battery', portId: 'negative'));
    expect(controller.probeB?.nodeId, 'battery');
    expect(controller.probeB?.portId, 'negative');
  });

  testWidgets('a probe placed on a specific port renders at that port\'s position, not the node center', (tester) async {
    final symbols = SymbolLibrary()
      ..register(const SymbolDefinition(
        identifier: 'battery',
        name: 'Battery',
        category: SymbolCategory.electrical,
        description: 'DC voltage source.',
        geometry: SymbolGeometry(kind: GeometryKind.svgAsset, assetPath: 'battery.svg', width: 100, height: 100),
        ports: [
          SymbolPort(id: 'positive', displayName: 'Positive', connectionType: 'power', x: 0.0, y: 0.5),
          SymbolPort(id: 'negative', displayName: 'Negative', connectionType: 'power', x: 1.0, y: 0.5),
        ],
      ));
    final graph = buildSimulationTestGraph();
    final graphWithSymbol = graph.copyWith(
      nodes: {
        ...graph.nodes,
        'battery': graph.nodes['battery']!.copyWith(symbolId: 'battery'),
      },
    );

    controller.setProbeA(const ProbePoint(nodeId: 'battery', portId: 'positive'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ProbeOverlay(
              controller: controller,
              graph: graphWithSymbol,
              layout: layout,
              symbols: symbols,
              pan: const Point2D(0, 0),
              zoom: 1,
              active: true,
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.byTooltip('Probe A (black): battery (positive)'), findsOneWidget);

    // battery sits at (0,0) with a 100x100 box (this overlay's default
    // `nodeSize`); `positive` is at normalized (0.0, 0.5) -> world (0, 50)
    // -> the marker's Positioned `left`/`top` are offset by -8 for the
    // 16x16 marker itself.
    final positioned = tester.widget<Positioned>(find.ancestor(
      of: find.byTooltip('Probe A (black): battery (positive)'),
      matching: find.byType(Positioned),
    ));
    expect(positioned.left, -8);
    expect(positioned.top, 42);
  });
}
