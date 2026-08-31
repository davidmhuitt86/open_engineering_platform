import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/engineering_intelligence/engineering_intelligence_page.dart';
import 'package:oep_studio/exchange/models/exchange_package.dart';
import 'package:oep_studio/exchange/models/installation.dart';
import 'package:oep_studio/exchange/panels/exchange_my_library_panel.dart';
import 'package:oep_studio/exchange/panels/exchange_package_detail_panel.dart';
import 'package:oep_studio/exchange/services/exchange_runtime_service.dart';
import 'package:oep_studio/exchange/services/exchange_runtime_state.dart';
import 'package:oep_studio/features/graph/graph_page.dart';
import 'package:oep_studio/features/objects/objects_page.dart';
import 'package:oep_studio/features/relationships/relationships_page.dart';
import 'package:oep_studio/features/repository/repository_page.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-NAVIGATION-CONVERGENCE-002 — the completeness
/// audit's remaining Workspace-escape sites: native pages that are
/// themselves rendered as Workspace tabs but still called raw
/// `context.go(StudioDestination.X.path)` for a destination that already
/// has a Workspace Surface equivalent. Each now routes through the same
/// `openOrActivateDestination` primitive AP-001 already proved correct
/// for Project Explorer's Diagram links -- these tests only prove each
/// remaining call site actually uses it and that the Workspace shell is
/// never left.
void main() {
  setUp(useIsolatedSettingsStorage);

  GoRouter buildRouter(String initialLocation, Widget workspaceChild) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: StudioDestination.workspace.path, builder: (c, s) => Scaffold(body: workspaceChild)),
          GoRoute(path: StudioDestination.packages.path, builder: (c, s) => const Scaffold(body: Text('standalone-packages'))),
          GoRoute(path: StudioDestination.graph.path, builder: (c, s) => const Scaffold(body: Text('standalone-graph'))),
          GoRoute(path: StudioDestination.objects.path, builder: (c, s) => const Scaffold(body: Text('standalone-objects'))),
          GoRoute(path: StudioDestination.dashboard.path, builder: (c, s) => const Scaffold(body: Text('standalone-dashboard'))),
          GoRoute(path: StudioDestination.repository.path, builder: (c, s) => const Scaffold(body: Text('standalone-repository'))),
          GoRoute(path: StudioDestination.projectExplorer.path, builder: (c, s) => const Scaffold(body: Text('standalone-project-explorer'))),
        ],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Widget child,
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: StudioTheme.dark, routerConfig: buildRouter(StudioDestination.workspace.path, child)),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  group('Repository page', () {
    testWidgets('Packages button opens/activates the Packages tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const RepositoryPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoOpenNotifier.new)],
      );

      await tester.tap(find.text('Packages'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.packages.name);
      expect(find.text('standalone-packages'), findsNothing);
    });

    testWidgets('Knowledge Graph button opens/activates the Graph tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const RepositoryPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoOpenNotifier.new)],
      );

      await tester.tap(find.text('Knowledge Graph'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.graph.name);
      expect(find.text('standalone-graph'), findsNothing);
    });

    testWidgets('selecting a category opens/activates the Objects tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const RepositoryPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoOpenNotifier.new)],
      );

      await tester.tap(find.text(ObjectCategory.component.label));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.objects.name);
      expect(container.read(foundationRuntimeServiceProvider).selectedCategory, ObjectCategory.component);
      expect(find.text('standalone-objects'), findsNothing);
    });

    testWidgets('"Open Repository" (no repository open) opens/activates the Dashboard tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const RepositoryPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new)],
      );

      await tester.tap(find.text('Open Repository'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.dashboard.name);
      expect(find.text('standalone-dashboard'), findsNothing);
    });
  });

  group('Objects page', () {
    testWidgets('"Go to Repository Explorer" opens/activates the Repository tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const ObjectsPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoOpenNotifier.new)],
      );

      await tester.tap(find.text('Go to Repository Explorer'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.repository.name);
      expect(find.text('standalone-repository'), findsNothing);
    });
  });

  group('Graph page', () {
    testWidgets('"Open Repository" (no repository open) opens/activates the Dashboard tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const GraphPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new)],
      );

      await tester.tap(find.text('Open Repository'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.dashboard.name);
      expect(find.text('standalone-dashboard'), findsNothing);
    });
  });

  group('Relationships page', () {
    testWidgets('"Open Repository" (no repository open) opens/activates the Dashboard tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const RelationshipsPage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new)],
      );

      await tester.tap(find.text('Open Repository'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.dashboard.name);
      expect(find.text('standalone-dashboard'), findsNothing);
    });
  });

  group('Engineering Intelligence page', () {
    testWidgets('"Go to Repository Explorer" opens/activates the Repository tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const EngineeringIntelligencePage(),
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new)],
      );

      await tester.tap(find.text('Go to Repository Explorer'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.repository.name);
      expect(find.text('standalone-repository'), findsNothing);
    });
  });

  group('Exchange My Library panel', () {
    testWidgets('"Refresh Repository" opens/activates the Repository tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const ExchangeMyLibraryPanel(),
        overrides: [
          foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new),
          exchangeRuntimeServiceProvider.overrideWith(_FakeExchangeNotifier.new),
        ],
      );

      await tester.tap(find.text('Refresh Repository'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.repository.name);
      expect(find.text('standalone-repository'), findsNothing);
    });
  });

  group('Exchange Package Detail panel', () {
    const package = ExchangePackage(
      id: 'pkg-1',
      packageId: 'pkg-1',
      publisherId: 'pub-1',
      displayName: 'Package One',
      description: 'A package',
      categoryId: null,
      currentVersion: '1.0',
      status: 'active',
      createdAt: '',
      updatedAt: '',
    );

    testWidgets('"Open Installed Package" opens/activates the Repository tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const ExchangePackageDetailPanel(package: package),
        overrides: [
          foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new),
          exchangeRuntimeServiceProvider.overrideWith(_FakeExchangeWithInstallationNotifier.new),
        ],
      );

      await tester.tap(find.text('Open Installed Package'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.repository.name);
      expect(find.text('standalone-repository'), findsNothing);
    });

    testWidgets('"Open in Engineering Workspace" opens/activates the Project Explorer tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        child: const ExchangePackageDetailPanel(package: package),
        overrides: [
          foundationRuntimeServiceProvider.overrideWith(_FakeRepoClosedNotifier.new),
          exchangeRuntimeServiceProvider.overrideWith(_FakeExchangeWithInstallationNotifier.new),
        ],
      );

      await tester.tap(find.text('Open in Engineering Workspace'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.projectExplorer.name);
      expect(find.text('standalone-project-explorer'), findsNothing);
    });
  });
}

/// A repository-open state with one Component-category object, so
/// `RepositoryPage`'s category tile renders and can be tapped.
class _FakeRepoOpenNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => const FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        runtimeState: FoundationRuntimeState.repositoryOpen,
        repositoryStatus: RepositoryStatus(
          repositoryId: 'repo-1',
          repositoryName: 'Repo One',
          repositoryVersion: '1.0',
          loadedPackageCount: 0,
        ),
        objectList: [
          EngineeringObjectSummary(objectId: 'obj-1', category: ObjectCategory.component, name: 'Widget', author: 'alice', version: '1.0'),
        ],
      );
}

/// No repository open -- exercises each page's own "Open Repository" /
/// "Go to Repository Explorer" empty-state affordance.
class _FakeRepoClosedNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => const FoundationServiceState(phase: FoundationConnectionPhase.connected);
}

/// Mirrors the network-free fake pattern already established in
/// `unified_navigation_workspace_context002_test.dart`.
class _FakeExchangeNotifier extends ExchangeRuntimeNotifier {
  @override
  ExchangeServiceState build() => const ExchangeServiceState();
}

class _FakeExchangeWithInstallationNotifier extends ExchangeRuntimeNotifier {
  @override
  ExchangeServiceState build() => const ExchangeServiceState(
        selectedPackageInstallation: Installation(
          id: 'inst-1',
          packageId: 'pkg-1',
          version: '1.0',
          status: 'completed',
          repositoryPackageId: 'robj-1',
          errorMessage: null,
          requestedAt: '',
          completedAt: '',
        ),
      );
}
