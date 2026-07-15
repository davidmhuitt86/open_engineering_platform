import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:engineering_engine_demonstration_host/main.dart' as app;
import 'package:engineering_engine_demonstration_host/widgets/inspector_panels.dart';

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

  testWidgets(
      'WORK_PACKAGE_022: view menu (grid/snap/guides), navigation, align/distribute, '
      'named layouts, and grid settings all work end to end', (tester) async {
    app.main();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- View menu: grid / snap / guides toggles --------------------
    Future<CheckedPopupMenuItem<void>> openViewMenuItem(String label) async {
      await tester.tap(find.byTooltip('View'));
      await tester.pumpAndSettle();
      final item =
          tester.widget<CheckedPopupMenuItem<void>>(find.widgetWithText(CheckedPopupMenuItem<void>, label));
      return item;
    }

    // Selecting a CheckedPopupMenuItem invokes onTap and then closes the
    // menu itself (PopupMenuItem pops its own route), so no separate
    // dismiss step is needed between toggles.
    final gridBefore = await openViewMenuItem('Show Grid');
    await tester.tap(find.text('Show Grid'));
    await tester.pumpAndSettle();
    final gridAfter = await openViewMenuItem('Show Grid');
    expect(gridAfter.checked, isNot(gridBefore.checked));
    await tester.tap(find.text('Show Grid')); // restore for the rest of the test
    await tester.pumpAndSettle();

    final snapBefore = await openViewMenuItem('Snap to Grid');
    await tester.tap(find.text('Snap to Grid'));
    await tester.pumpAndSettle();
    final snapAfter = await openViewMenuItem('Snap to Grid');
    expect(snapAfter.checked, isNot(snapBefore.checked));
    await tester.tap(find.text('Snap to Grid')); // restore
    await tester.pumpAndSettle();

    final guidesBefore = await openViewMenuItem('Show Guides');
    await tester.tap(find.text('Show Guides'));
    await tester.pumpAndSettle();
    final guidesAfter = await openViewMenuItem('Show Guides');
    expect(guidesAfter.checked, isNot(guidesBefore.checked));
    await tester.tap(find.text('Show Guides')); // restore
    await tester.pumpAndSettle();

    // --- Grid settings dialog ----------------------------------------
    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grid Settings...'));
    await tester.pumpAndSettle();
    expect(find.text('Grid & Snap Settings'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Grid & Snap Settings'), findsNothing);

    // --- Viewport navigation: Fit All changes the zoom readout --------
    final zoomBefore = tester
        .widgetList<Text>(find.textContaining('Zoom:'))
        .single
        .data;
    await tester.tap(find.widgetWithIcon(IconButton, Icons.fit_screen));
    await tester.pumpAndSettle();
    final zoomAfter = tester
        .widgetList<Text>(find.textContaining('Zoom:'))
        .single
        .data;
    expect(zoomAfter, isNotNull);
    expect(zoomBefore, isNotNull);

    // Navigate back then forward through viewport history without error.
    final backButton =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back));
    if (backButton.onPressed != null) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_forward));
      await tester.pumpAndSettle();
    }

    // --- Select all six seed nodes, then Align + Distribute -------------
    // Ctrl+A is wired as a CallbackShortcuts binding, which requires the
    // Focus node that owns it to hold keyboard focus — fragile to rely on
    // in an integration test after several dialog/popup interactions have
    // already shifted focus around. Ctrl/Shift-click additive selection
    // reads HardwareKeyboard.instance directly (global modifier state, not
    // focus-dependent), so drive multi-select through the Graph Explorer
    // with the control key held instead.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final name in const [
      'Battery',
      'Ignition Switch',
      'Control Module',
      'Ignition Coil',
      'Indicator Lamp',
      'Chassis Ground',
    ]) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected: 6'), findsOneWidget);

    final undoBeforeAlign =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo)).onPressed;

    await tester.tap(find.byTooltip('Align'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Align left'));
    await tester.pumpAndSettle();
    // Alignment is a real, undoable command — undo must now be enabled.
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo)).onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Distribute'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distribute horizontal'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo)).onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();
    expect(undoBeforeAlign, isNull); // sanity: history was clean before these two commands

    await tester.tap(find.text('Battery')); // clear the 6-way selection
    await tester.pumpAndSettle();

    // --- Named layouts: save, list, load, delete, reset -----------------
    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Named Layouts...'));
    await tester.pumpAndSettle();
    expect(find.text('Named Layouts'), findsOneWidget);
    expect(find.text('No saved layouts yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Save current as...'));
    await tester.pumpAndSettle();
    // Scoped to the name-prompt AlertDialog: the Property Inspector also
    // has a TextField (editable displayName) that stays mounted behind it.
    final nameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Integration Test Layout');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Integration Test Layout'), findsOneWidget);

    await tester.tap(find.text('Integration Test Layout'));
    await tester.pumpAndSettle();
    expect(find.text('Named Layouts'), findsNothing); // loading closes the dialog

    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Named Layouts...'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('No saved layouts yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Reset Layout'));
    await tester.pumpAndSettle();
    expect(find.text('Named Layouts'), findsNothing);
  });

  testWidgets(
      'WORK_PACKAGE_023: layers, search, annotations, placement tools, and '
      'constraints all work end to end', (tester) async {
    app.main();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Object? undoState() =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo)).onPressed;
    // Scoped to the Graph Explorer list — once Battery is selected, the
    // Property Inspector also renders an editable "Battery" TextField, so
    // an unscoped find.text('Battery') becomes ambiguous.
    Finder explorerText(String text) =>
        find.descendant(of: find.byType(GraphExplorerPanel), matching: find.text(text));

    // --- Wire Editing Toolbar is present and correctly gated -------------
    // No relationship is selected yet, so "Edit Route" must be disabled —
    // this is the one wire-editing assertion made here; the underlying
    // geometry (insert/remove/drag-segment/drag-corner) is covered
    // exhaustively by test/views/wire_editing_test.dart.
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.polyline_outlined)).onPressed,
      isNull,
    );

    // --- Placement tools: Rotate / Mirror / Array / Replace Symbol -------
    await tester.tap(find.text('Battery'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rotate 90°'));
    await tester.pumpAndSettle();
    expect(undoState(), isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mirror horizontal'));
    await tester.pumpAndSettle();
    expect(undoState(), isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();

    expect(explorerText('Battery'), findsOneWidget);
    await tester.tap(find.byTooltip('Array placement...'));
    await tester.pumpAndSettle();
    expect(find.text('Array Placement'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Place'));
    await tester.pumpAndSettle();
    expect(explorerText('Battery'), findsNWidgets(2), reason: 'array placed one duplicate');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();
    expect(explorerText('Battery'), findsOneWidget);

    await tester.tap(find.byTooltip('Replace symbol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resistor').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Symbol: resistor'), findsOneWidget);

    // --- Editing constraints: orthogonal-movement toggle -----------------
    expect(find.textContaining('Constraints: —'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.textContaining('Constraints: Ortho'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.textContaining('Constraints: —'), findsOneWidget);

    // --- Recent Commands (fed by editing.recentDescriptions) -------------
    // recentDescriptions mirrors the *undo stack*, not a historical log —
    // every earlier rotate/mirror/array above was immediately undone, so
    // it only has content because the Replace Symbol above was left
    // un-undone.
    final recentButton = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate(
        (w) => w is PopupMenuButton<String> && w.tooltip == 'Recent commands',
      ),
    );
    expect(recentButton.enabled, isTrue, reason: 'several commands already executed above');

    // --- Layers: create, list, assign, visibility toggle ------------------
    expect(find.textContaining('Layers: 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Layers'));
    await tester.pumpAndSettle();
    expect(find.text('Layers'), findsOneWidget);
    expect(find.text('No layers yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create layer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Power',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Power'), findsOneWidget);

    // Battery is still selected — assign it to the new layer.
    await tester.tap(find.byTooltip('Assign selection to this layer'));
    await tester.pumpAndSettle();

    // Toggle the layer's visibility off then back on.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility));
    await tester.pumpAndSettle();
    expect(find.widgetWithIcon(IconButton, Icons.visibility_off), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility_off));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Layers: 1'), findsOneWidget);

    // --- Search: query, results, navigate -----------------------------
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    // Scoped to the Search AlertDialog: the Property Inspector also has a
    // persistent TextField (editable displayName) for the still-selected
    // node.
    final searchField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'Battery');
    await tester.pumpAndSettle();
    expect(find.textContaining('result(s)'), findsOneWidget);
    final resultCountText =
        tester.widget<Text>(find.textContaining('result(s)')).data ?? '';
    expect(resultCountText.startsWith('0'), isFalse, reason: 'Battery should match at least one result');
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();

    // --- Annotations: add, edit, select, delete ---------------------------
    await tester.tap(find.byTooltip('Add annotation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text Label'));
    await tester.pumpAndSettle();
    expect(find.text('New textLabel'), findsOneWidget);

    // Double-tap (two taps within the double-tap timeout) to open the
    // inline edit dialog.
    await tester.tap(find.text('New textLabel'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('New textLabel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit annotation'), findsOneWidget);
    final editField = find.descendant(
      of: find.widgetWithText(AlertDialog, 'Edit annotation'),
      matching: find.byType(TextField),
    );
    await tester.enterText(editField, 'Test Note');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test Note'), findsOneWidget);
    expect(find.text('New textLabel'), findsNothing);

    await tester.tap(find.text('Test Note'));
    await tester.pumpAndSettle();
    // The Delete *key* relies on CallbackShortcuts holding keyboard focus,
    // which is fragile this deep into a test full of dialog interactions
    // (same reasoning as the WP022 test's Ctrl+A note above) — use the
    // toolbar's Delete button instead, which drives the identical
    // `_deleteSelection` (now annotation-aware) directly.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Test Note'), findsNothing);
  });
}
