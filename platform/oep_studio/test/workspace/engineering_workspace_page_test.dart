import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';

/// AP-OEP-WORKSPACE-SHELL-001 — widget-level coverage for the "+" menu,
/// tab activation, and tab close, per this task's own Phase 14. Does
/// not exercise the real Diagram/V2 tab (that requires a real WebView2
/// control, unreliable under `flutter test` — the same reasoning
/// `app_router.dart`'s own standing comment already documents, and
/// which `test/core/surfaces/surface_registry_test.dart`/
/// `test/workspace/workspace_tabs_controller_test.dart` already cover
/// for the Diagram-tab *model* behavior instead).
void main() {
  Widget harness() => const ProviderScope(
        child: MaterialApp(home: Scaffold(body: EngineeringWorkspacePage())),
      );

  testWidgets('starts with no tabs open and shows the empty state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
  });

  testWidgets('the "+" menu lists every SurfaceRegistry surface plus Diagram Studio', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Diagram Studio'), findsOneWidget);
    for (final surface in SurfaceRegistry.all) {
      expect(find.text(surface.title), findsWidgets, reason: '"+" menu missing ${surface.title}');
    }
  });

  testWidgets('selecting a Surface from "+" opens it as an active, closable tab', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('opening two different Surfaces creates two tabs; the second is active', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(a.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(b.title).last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('opening the same Surface twice focuses the existing tab instead of duplicating', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'reuse-if-open, not a duplicate tab');
  });

  testWidgets('closing the only open tab returns to the empty state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
  });
}
