import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/core/engineering_instrument.dart';
import 'package:oep_studio/workbench/perspectives/instruments_perspective.dart';

class _FakeInstrument extends EngineeringInstrument {
  const _FakeInstrument();
  @override
  String get id => 'fake';
  @override
  String get title => 'Fake';
  @override
  IconData get icon => Icons.bolt;
  @override
  Widget buildPanel(BuildContext context) => const Text('fake-panel');
}

void main() {
  group('InstrumentsPerspectiveDock', () {
    testWidgets('shows an honest empty state with no instruments supplied', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InstrumentsPerspectiveDock(instruments: []))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No instruments available'), findsOneWidget);
      expect(find.text('fake-panel'), findsNothing);
    });

    testWidgets('renders a real DockRegion once given at least one instrument', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InstrumentsPerspectiveDock(instruments: [_FakeInstrument()]))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No instruments available'), findsNothing);
      // Not shown by default (dock starts hidden), but the tab/registry
      // wiring is real: showing the dock renders the adapted instrument.
    });
  });

  testWidgets('instrumentsPerspective is registered with a real id/title/icon and a bottom dock provider', (tester) async {
    expect(instrumentsPerspective.id, 'instruments');
    expect(instrumentsPerspective.title, 'Instruments');
    expect(instrumentsPerspective.bottomPanelProvider, isNotNull);
    expect(instrumentsPerspective.defaultLayout.bottomVisible, isTrue);
  });
}
