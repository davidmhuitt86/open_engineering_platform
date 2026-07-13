import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:engineering_engine_demonstration_host/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'demonstration host boots, renders the seed graph, selects, edits, and undoes/redoes',
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
    expect(find.textContaining('Selected: 1'), findsOneWidget);

    // Validation panel shows a report (clean, since the seed graph is
    // fully connected and every node has a symbol).
    expect(find.text('Clean — no findings.'), findsOneWidget);

    // --- WORK_PACKAGE_021: editing, undo/redo -----------------------

    // Undo/redo start disabled (no history yet).
    expect(find.widgetWithIcon(IconButton, Icons.undo), findsOneWidget);
    final undoButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undoButton.onPressed, isNull);

    // Add a node via the toolbar (ENGINE-TASK-000079).
    await tester.tap(find.byIcon(Icons.add_box));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resistor').last);
    await tester.pumpAndSettle();
    expect(find.text('Resistor'), findsWidgets); // menu item + explorer entry + inspector

    // Undo is now enabled; undo removes the node.
    final undoAfterAdd =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undoAfterAdd.onPressed, isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();

    // Redo brings it back.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.redo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Symbol: resistor'), findsOneWidget);

    // Delete the freshly-added (still selected) node via the toolbar.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    expect(find.textContaining('Symbol: resistor'), findsNothing);
  });
}
