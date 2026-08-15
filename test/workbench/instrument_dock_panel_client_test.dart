import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/core/engineering_instrument.dart';
import 'package:oep_studio/workbench/perspectives/instrument_dock_panel_client.dart';

class _FakeInstrument extends EngineeringInstrument {
  const _FakeInstrument();
  @override
  String get id => 'fake-instrument';
  @override
  String get title => 'Fake Instrument';
  @override
  IconData get icon => Icons.bolt;
  @override
  Widget buildPanel(BuildContext context) => const Text('fake-instrument-panel');
}

void main() {
  group('InstrumentDockPanelClient', () {
    test('passes id/title/icon through from the wrapped EngineeringInstrument', () {
      const client = InstrumentDockPanelClient(_FakeInstrument());
      expect(client.id, 'fake-instrument');
      expect(client.title, 'Fake Instrument');
      expect(client.icon, Icons.bolt);
    });

    testWidgets('buildPanel delegates to the wrapped instrument', (tester) async {
      const client = InstrumentDockPanelClient(_FakeInstrument());
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (context) => client.buildPanel(context))),
      );
      expect(find.text('fake-instrument-panel'), findsOneWidget);
    });
  });
}
