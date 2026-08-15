import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/core/engineering_instrument.dart';
import 'package:oep_studio/diagram_studio/instruments/dock/instrument_dock.dart';
import 'package:oep_studio/diagram_studio/instruments/dock/instrument_dock_controller.dart';
import 'package:oep_studio/diagram_studio/instruments/dock/instrument_dock_state.dart';

class _FakeInstrument extends EngineeringInstrument {
  const _FakeInstrument(this.id, this.label);

  @override
  final String id;
  final String label;

  @override
  String get title => label;

  @override
  IconData get icon => Icons.speed_outlined;

  @override
  Widget buildPanel(BuildContext context) => Text('panel-$id');
}

Widget _harness(InstrumentDockController controller, InstrumentRegistry registry) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [InstrumentDock(controller: controller, registry: registry)]),
      ),
    );

void main() {
  testWidgets('InstrumentDock renders nothing when hidden or the registry is empty', (tester) async {
    final controller = InstrumentDockController();
    final registry = InstrumentRegistry();
    await tester.pumpWidget(_harness(controller, registry));
    expect(find.byType(InstrumentDock), findsOneWidget);
    expect(find.text('panel-mm'), findsNothing);

    registry.register(const _FakeInstrument('mm', 'Multimeter'));
    await tester.pump();
    expect(find.text('panel-mm'), findsNothing, reason: 'still hidden -- registering alone must not show it');
  });

  testWidgets('InstrumentDock (bottom, visible) shows the active instrument panel and tab', (tester) async {
    final controller = InstrumentDockController(initial: const InstrumentDockState(visible: true));
    final registry = InstrumentRegistry()..register(const _FakeInstrument('mm', 'Multimeter'));
    await tester.pumpWidget(_harness(controller, registry));
    await tester.pump();

    expect(find.text('Multimeter'), findsOneWidget);
    expect(find.text('panel-mm'), findsOneWidget);
  });

  testWidgets('Tab bar switches the active instrument', (tester) async {
    final controller = InstrumentDockController(initial: const InstrumentDockState(visible: true));
    final registry = InstrumentRegistry()
      ..register(const _FakeInstrument('mm', 'Multimeter'))
      ..register(const _FakeInstrument('scope', 'Oscilloscope'));
    await tester.pumpWidget(_harness(controller, registry));
    await tester.pump();

    expect(find.text('panel-mm'), findsOneWidget);
    await tester.tap(find.text('Oscilloscope'));
    await tester.pump();
    expect(find.text('panel-scope'), findsOneWidget);
    expect(find.text('panel-mm'), findsNothing);
  });

  testWidgets('Float button switches the dock to floating and back', (tester) async {
    final controller = InstrumentDockController(initial: const InstrumentDockState(visible: true));
    final registry = InstrumentRegistry()..register(const _FakeInstrument('mm', 'Multimeter'));
    await tester.pumpWidget(_harness(controller, registry));
    await tester.pump();

    expect(controller.state.position, DockPosition.bottom);
    await tester.tap(find.byTooltip('Float'));
    await tester.pump();
    expect(controller.state.position, DockPosition.floating);
    expect(find.text('panel-mm'), findsOneWidget, reason: 'floating frame renders the same active panel');
  });

  testWidgets('Close button hides the dock', (tester) async {
    final controller = InstrumentDockController(initial: const InstrumentDockState(visible: true));
    final registry = InstrumentRegistry()..register(const _FakeInstrument('mm', 'Multimeter'));
    await tester.pumpWidget(_harness(controller, registry));
    await tester.pump();

    await tester.tap(find.byTooltip('Hide instrument dock'));
    await tester.pump();
    expect(controller.state.visible, isFalse);
    expect(find.text('panel-mm'), findsNothing);
  });
}
