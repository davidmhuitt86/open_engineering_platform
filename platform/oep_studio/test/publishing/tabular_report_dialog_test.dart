import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/publishing/tabular_report_dialog.dart';

import 'publishing_helpers.dart';

void main() {
  Widget harness() => MaterialApp(
        theme: StudioTheme.dark,
        home: Scaffold(
          body: TabularReportDialog(graph: buildTestGraph(), layout: buildTestLayout()),
        ),
      );

  Future<void> enlargeSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('defaults to Bill of Materials and shows its row count', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('2 row(s)'), findsOneWidget);
  });

  testWidgets('switching report kind via dropdown changes the rendered row count', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('report_kind_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Engineering Object Report').last);
    await tester.pumpAndSettle();

    // Engineering Object Report covers all 3 nodes, unlike BOM's 2.
    expect(find.text('3 row(s)'), findsOneWidget);
  });

  testWidgets('filter narrows the row count', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('report_filter_field')), 'Ignition');
    await tester.pumpAndSettle();

    expect(find.text('1 row(s)'), findsOneWidget);
  });

  testWidgets('export/preview action buttons are present', (tester) async {
    await enlargeSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report_export_csv')), findsOneWidget);
    expect(find.byKey(const Key('report_export_md')), findsOneWidget);
    expect(find.byKey(const Key('report_export_pdf')), findsOneWidget);
    expect(find.byKey(const Key('report_preview_pdf')), findsOneWidget);
  });
}
