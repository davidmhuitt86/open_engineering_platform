import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/features/packages/package_manager_page.dart';
import 'package:oep_studio/features/packages/packages_page.dart';

/// Smoke tests for the Package Integration UI (AP-DS-002). No
/// `oep_foundation_bridge` native library is available under `flutter
/// test`, so `FoundationRuntimeNotifier`'s connect attempt fails and
/// `isRepositoryOpen` is always false — the "open a repository" gate
/// this page degrades to, matching the convention already used by
/// `engineering_intelligence_page_test.dart`.
void main() {
  Widget harness(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('PackagesPage shows the open-a-repository gate with no repository connected', (tester) async {
    await tester.pumpWidget(harness(const PackagesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Open a repository to manage packages.'), findsOneWidget);
  });

  testWidgets('PackageManagerPage renders the same gate directly', (tester) async {
    await tester.pumpWidget(harness(const PackageManagerPage()));
    await tester.pumpAndSettle();

    expect(find.text('Open a repository to manage packages.'), findsOneWidget);
  });

  test('StudioDestination.packages is registered and routes to /packages', () {
    final registry = StudioRegistry.defaultRegistry;
    expect(registry.descriptorFor(StudioDestination.packages), isNotNull);

    final routes = StudioRegistry.defaultRegistry.buildRoutes();
    final route = routes.whereType<GoRoute>().firstWhere((r) => r.path == '/packages');
    expect(route.path, '/packages');
  });
}
