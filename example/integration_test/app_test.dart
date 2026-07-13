import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:engineering_engine_demonstration_host/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demonstration host boots, renders the seed graph, and selects a node',
      (tester) async {
    app.main();
    // First pump shows the loading spinner while the engine initializes and
    // symbols load from the asset bundle.
    await tester.pump();
    // Settle through async engine bootstrap (initialize + symbol load).
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Engineering Engine — Demonstration Host'), findsOneWidget);

    // The seed ignition-circuit graph should be visible in the Graph Explorer.
    expect(find.text('Battery'), findsOneWidget);
    expect(find.text('Chassis Ground'), findsOneWidget);

    // Status bar reflects a running, initialized engine with symbols loaded.
    expect(find.textContaining('Engine: initialized'), findsOneWidget);
    expect(find.textContaining('Symbols: 14'), findsOneWidget);

    // Selecting a node in the Graph Explorer updates the Property Inspector.
    expect(find.text('Nothing selected.'), findsOneWidget);
    await tester.tap(find.text('Battery'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing selected.'), findsNothing);
    expect(find.textContaining('Symbol: battery'), findsOneWidget);

    // Validation panel shows a report (clean, since the seed graph is
    // fully connected and every node has a symbol).
    expect(find.text('Clean — no findings.'), findsOneWidget);
  });
}
