import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/features/project_explorer/project_explorer_page.dart';

/// AP-DS-002's Project Browser additions to `ProjectExplorerPage`: a
/// "Recent Projects" branch and an "Open from Repository" entry point,
/// added instead of a second, duplicate explorer (see the task report
/// for why extending this page was chosen over building a new one).
/// Same no-native-library gate convention as
/// `engineering_intelligence_page_test.dart`.
void main() {
  Widget harness() {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: ProjectExplorerPage()),
      ),
    );
  }

  testWidgets('shows an Open from Repository entry point alongside New Project', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Open from Repository'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
  });

  testWidgets('shows a Recent Projects branch in the tree', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Recent Projects'), findsOneWidget);
  });

  testWidgets('Open from Repository warns when no repository is open', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open from Repository'));
    await tester.pump();

    expect(find.text('Open a repository from the Dashboard first.'), findsOneWidget);
  });
}
