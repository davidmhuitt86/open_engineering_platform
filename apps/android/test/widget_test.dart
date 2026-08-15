import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_dmm/main.dart';

void main() {
  testWidgets('app launches into the Connect screen with host/port fields and a Connect button', (tester) async {
    await tester.pumpWidget(const OepDmmApp());

    expect(find.text('OEP'), findsOneWidget);
    expect(find.text('DIGITAL MULTIMETER'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Host IP address'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Port'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('an empty host address shows a validation error rather than attempting to connect', (tester) async {
    await tester.pumpWidget(const OepDmmApp());

    await tester.enterText(find.widgetWithText(TextField, 'Host IP address'), '');
    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Enter a valid host and port.'), findsOneWidget);
  });
}
