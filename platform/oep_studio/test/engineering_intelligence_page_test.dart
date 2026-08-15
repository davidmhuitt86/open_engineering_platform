import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/engineering_intelligence/engineering_intelligence_page.dart';

/// Smoke tests for the Engineering Intelligence Studio (WP-EKE-008).
/// No `oep_foundation_bridge` native library is available under `flutter
/// test`, so `FoundationRuntimeNotifier`'s connect attempt fails and
/// `FoundationServiceState.isRepositoryOpen` is always false in this
/// environment — exactly the "No Repository Open" gate every page
/// behind it degrades to. That gate, and the Studio's registration, are
/// what these tests can verify without a live Foundation process;
/// interactive behavior against real bridge data is covered by manual
/// verification (see WP-EKE-008's report).
void main() {
  Widget harness() {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: EngineeringIntelligencePage()),
      ),
    );
  }

  testWidgets('shows the No Repository Open gate when Foundation has no open repository', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('No Repository Open'), findsOneWidget);
    expect(find.text('Go to Repository Explorer'), findsOneWidget);
  });

  test('is registered in StudioRegistry.defaultRegistry with all eight capabilities', () {
    final registry = StudioRegistry.defaultRegistry;
    final descriptor = registry.descriptorFor(StudioDestination.engineeringIntelligence);

    expect(descriptor, isNotNull);
    expect(descriptor!.capabilities, hasLength(8));
    expect(registry.validateCapabilities(), isEmpty);
  });

  test('builds a GoRoute at /engineering-intelligence', () {
    final routes = StudioRegistry.defaultRegistry.buildRoutes();
    final route = routes.whereType<GoRoute>().firstWhere((r) => r.path == '/engineering-intelligence');
    expect(route.path, '/engineering-intelligence');
  });
}
