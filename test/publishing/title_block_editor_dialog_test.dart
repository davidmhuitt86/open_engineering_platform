import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/publishing/title_block_editor_dialog.dart';
import 'package:oep_studio/diagram_studio/publishing/title_block_storage.dart';

/// Widget-structure test for `TitleBlockEditorDialog` — pure UI + real
/// disk persistence (an isolated temp directory, not the real
/// `%APPDATA%/oep_studio/` path — see [TitleBlockStorage.
/// testRootOverride]'s own doc comment for why: this file previously
/// shared that real global path with two other test files, and
/// `flutter test`'s default cross-file parallelism turned that into a
/// genuine, reproducible file-handle race found during AP-DS-004's own
/// independent verification), no `DiagramIntelligenceService`/
/// `FoundationBridge` involved, so this is fully testable under
/// `flutter test`.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('title_block_editor_dialog_test_');
    TitleBlockStorage.testRootOverride = tempDir;
  });

  tearDown(() {
    TitleBlockStorage.testRootOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File storageFile() => File('${tempDir.path}${Platform.pathSeparator}title_blocks.json');

  Widget harness() => MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: TitleBlockEditorDialog(diagramKey: 'test-diagram.json')),
      );

  Future<void> enlargeSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows the fixed title block fields and Save/Cancel actions', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Title Block & Revisions'), findsOneWidget);
    expect(find.byKey(const Key('titleblock_field_company')), findsOneWidget);
    expect(find.byKey(const Key('titleblock_field_drawingNumber')), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('editing company and saving persists to TitleBlockStorage', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('titleblock_field_company')), 'Acme Corp');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('titleblock_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(storageFile().existsSync(), isTrue);
    expect(storageFile().readAsStringSync(), contains('Acme Corp'));
  });

  testWidgets('Add revision adds a row to the revision history list', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('titleblock_add_revision')));
    await tester.pumpAndSettle();

    expect(find.text('R1'), findsOneWidget);
  });
}
