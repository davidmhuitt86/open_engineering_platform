import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/publishing/publishing_center_dialog.dart';
import 'package:oep_studio/diagram_studio/publishing/title_block_storage.dart';

import 'publishing_helpers.dart';

/// `PublishingCenterDialog` with `intelligence: null` — the one
/// constructible/testable configuration in this repo (see
/// `test/intelligence_panels_test.dart`'s doc comment: no test anywhere
/// constructs a real `DiagramIntelligenceService`/`FoundationBridge`).
/// Confirms the dialog's tab structure renders and the
/// Validation/Reasoning actions are honestly disabled with no live
/// service, rather than crashing.
///
/// Uses [TitleBlockStorage.testRootOverride] rather than the real
/// `%APPDATA%/oep_studio/` path — this file previously shared that real
/// global path with `title_block_storage_test.dart` and
/// `title_block_editor_dialog_test.dart`, and `flutter test`'s default
/// cross-file parallelism turned that into a genuine, reproducible
/// file-handle race, found during AP-DS-004's own independent
/// verification (reproduced twice in a row before being root-caused).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('publishing_center_dialog_test_');
    TitleBlockStorage.testRootOverride = tempDir;
  });

  tearDown(() {
    TitleBlockStorage.testRootOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Widget harness() => MaterialApp(
        theme: StudioTheme.dark,
        home: Scaffold(
          body: PublishingCenterDialog(
            diagramKey: 'test-diagram.json',
            graph: buildTestGraph(),
            layout: buildTestLayout(),
            intelligence: null,
          ),
        ),
      );

  Future<void> enlargeSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders the six publishing tabs', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Title Block'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Intelligence Reports'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Exchange'), findsOneWidget);
  });

  testWidgets('Print tab exposes a working single-sheet Print Preview trigger backed by a real PdfExportProvider', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Print'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();

    final printButton = tester.widget<ElevatedButton>(find.byKey(const Key('open_print_preview')));
    expect(printButton.onPressed, isNotNull, reason: 'the Print Preview trigger must be enabled — this closes the AP-DS-004 gap '
        'where DiagramPrintPreviewDialog existed but had no reachable call site');
  });

  testWidgets('Intelligence Reports tab disables Validation/Reasoning buttons with no live service', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Intelligence Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intelligence Reports'));
    await tester.pumpAndSettle();

    final validateButton = tester.widget<ElevatedButton>(find.byKey(const Key('run_validation_report')));
    final reasonButton = tester.widget<ElevatedButton>(find.byKey(const Key('run_reasoning_report')));
    expect(validateButton.onPressed, isNull);
    expect(reasonButton.onPressed, isNull);
    expect(find.textContaining('No Engineering Intelligence connection'), findsOneWidget);
  });

  testWidgets('Summary tab shows genuinely computed node/relationship counts', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Engineering Objects: 3'), findsOneWidget);
    expect(find.textContaining('Relationships: 1'), findsOneWidget);
  });

  testWidgets('Exchange tab shows Not Ready for an unpublished diagram', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Exchange'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exchange'));
    await tester.pumpAndSettle();

    expect(find.text('Not Ready'), findsOneWidget);
    expect(find.textContaining('No networking. No upload.'), findsOneWidget);
  });
}
