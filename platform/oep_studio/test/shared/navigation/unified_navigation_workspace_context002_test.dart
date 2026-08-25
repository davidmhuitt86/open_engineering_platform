import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart' as engine;

import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/models/relationship_summary.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/core/models/unified_search_result.dart';
import 'package:oep_studio/core/objects/engineering_object_runtime.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/exchange/models/exchange_package.dart';
import 'package:oep_studio/exchange/services/exchange_runtime_service.dart';
import 'package:oep_studio/exchange/services/exchange_runtime_state.dart';
import 'package:oep_studio/shared/navigation/explorer_navigation.dart';
import 'package:oep_studio/shared/navigation/unified_navigation.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-CONTEXT-002 — extends AP-001's workspace-aware
/// pattern (proven for `goToDiagramElement`) across the rest of
/// `unified_navigation.dart`/`explorer_navigation.dart`, all now
/// routed through the one shared `openOrActivateDestination` helper.
///
/// Each converted function keeps its own, already-existing, already-
/// tested selection mechanism untouched (`EngineeringObjectRuntime`
/// lookups, a runtime notifier's own `select*` call) — these tests only
/// prove the *new* part: the destination becomes a workspace tab
/// in-Workspace, and an unchanged route navigation outside it.
///
/// `goToKnowledgeObject`'s manually-created-candidate branch and
/// `goToKnowledgeRelationship` are deliberately not given their own
/// tests here: the former requires bootstrapping a full Knowledge
/// Curation Session unrelated to this task, and the latter is a thin
/// delegation to `goToRelationship` (already covered below) plus an
/// `EngineeringObjectRuntime` lookup identical to `goToKnowledgeObject`'s
/// own (also covered below) — both go through the exact same helper
/// already exercised by every other test in this file, so a dedicated
/// test would only re-prove `openOrActivateDestination` a third time.
void main() {
  const testWidget = EngineeringObjectSummary(
    objectId: 'obj-1',
    category: ObjectCategory.component,
    name: 'Widget',
    author: 'alice',
    version: '1.0',
  );
  const testRelationship = RelationshipSummary(
    relationshipId: 'rel-1',
    sourceObjectId: 'obj-1',
    targetObjectId: 'obj-2',
    sourceObjectName: 'Widget',
    targetObjectName: 'Gadget',
    type: RelationshipType.references,
    author: 'alice',
  );

  void seedObjectRuntime() {
    EngineeringObjectRuntime.instance.updateFromFoundationState(
      const FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        objectList: [testWidget],
        relationshipList: [testRelationship],
      ),
    );
  }

  void clearObjectRuntime() {
    EngineeringObjectRuntime.instance.updateFromFoundationState(
      const FoundationServiceState(phase: FoundationConnectionPhase.connecting),
    );
  }

  GoRouter buildRouter(String initialLocation, void Function(BuildContext, WidgetRef) action) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: StudioDestination.workspace.path, builder: (c, s) => _TriggerPage(action)),
          GoRoute(path: '/other', builder: (c, s) => _TriggerPage(action)),
          GoRoute(path: StudioDestination.objects.path, builder: (c, s) => const Scaffold(body: Text('standalone-objects'))),
          GoRoute(path: StudioDestination.relationships.path, builder: (c, s) => const Scaffold(body: Text('standalone-relationships'))),
          GoRoute(path: StudioDestination.acquisition.path, builder: (c, s) => const Scaffold(body: Text('standalone-acquisition'))),
          GoRoute(path: StudioDestination.exchange.path, builder: (c, s) => const Scaffold(body: Text('standalone-exchange'))),
          GoRoute(path: StudioDestination.validation.path, builder: (c, s) => const Scaffold(body: Text('standalone-validation'))),
          GoRoute(path: StudioDestination.diagram.path, builder: (c, s) => const Scaffold(body: Text('standalone-diagram'))),
        ],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required String initialLocation,
    required void Function(BuildContext, WidgetRef) action,
    List<Override> overrides = const [],
  }) async {
    useIsolatedSettingsStorage();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: buildRouter(initialLocation, action)),
    ));
    await tester.pump();
    return container;
  }

  group('goToObject', () {
    setUp(seedObjectRuntime);
    tearDown(clearObjectRuntime);

    testWidgets('within the Workspace, opens/activates the Objects tab and selects the object on the shared authority', (tester) async {
      final container = await pump(tester,
          initialLocation: StudioDestination.workspace.path, action: (c, r) => goToObject(c, r, 'obj-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.objects.name);
      expect(container.read(foundationRuntimeServiceProvider).selectedObject?.objectId, 'obj-1');
      expect(find.text('standalone-objects'), findsNothing, reason: 'must not leave the Workspace route');
    });

    testWidgets('repeated navigation activates the one Objects tab, never a duplicate', (tester) async {
      final container = await pump(tester,
          initialLocation: StudioDestination.workspace.path, action: (c, r) => goToObject(c, r, 'obj-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(container.read(workspaceTabsControllerProvider).tabs, hasLength(1));
    });

    testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
      final container =
          await pump(tester, initialLocation: '/other', action: (c, r) => goToObject(c, r, 'obj-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('standalone-objects'), findsOneWidget);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    });

    testWidgets('an unknown object id fails safely: no navigation, no tab, no crash', (tester) async {
      final container =
          await pump(tester, initialLocation: StudioDestination.workspace.path, action: (c, r) => goToObject(c, r, 'no-such-object'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
      expect(container.read(foundationRuntimeServiceProvider).selectedObject, isNull);
    });
  });

  group('goToRelationship', () {
    setUp(seedObjectRuntime);
    tearDown(clearObjectRuntime);

    testWidgets('within the Workspace, opens/activates the Relationships tab and selects the relationship', (tester) async {
      final container = await pump(tester,
          initialLocation: StudioDestination.workspace.path, action: (c, r) => goToRelationship(c, r, 'rel-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.relationships.name);
      expect(container.read(foundationRuntimeServiceProvider).selectedRelationship?.relationshipId, 'rel-1');
    });

    testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
      final container =
          await pump(tester, initialLocation: '/other', action: (c, r) => goToRelationship(c, r, 'rel-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('standalone-relationships'), findsOneWidget);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    });
  });

  group('goToKnowledgeObject (Engineering Object branch)', () {
    setUp(seedObjectRuntime);
    tearDown(clearObjectRuntime);

    testWidgets('an Engineering Object id cascades to the same Objects-tab behavior as goToObject', (tester) async {
      final container = await pump(tester,
          initialLocation: StudioDestination.workspace.path, action: (c, r) => goToKnowledgeObject(c, r, 'obj-1'));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.objects.name);
    });
  });

  group('goToValidationResult (no resolvable subject)', () {
    testWidgets('within the Workspace, a finding with no subjectId opens/activates the Validation tab', (tester) async {
      final container = await pump(
        tester,
        initialLocation: StudioDestination.workspace.path,
        action: (c, r) => goToValidationResult(
          c,
          r,
          const engine.ValidationFinding(code: 'E001', severity: engine.ValidationSeverity.error, message: 'boom'),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.validation.name);
    });

    testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
      final container = await pump(
        tester,
        initialLocation: '/other',
        action: (c, r) => goToValidationResult(
          c,
          r,
          const engine.ValidationFinding(code: 'E001', severity: engine.ValidationSeverity.error, message: 'boom'),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('standalone-validation'), findsOneWidget);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    });
  });

  group('goToAcquisitionResult', () {
    testWidgets('a Job result: within the Workspace, opens/activates the Acquisition tab and selects the job', (tester) async {
      final container = await pump(
        tester,
        initialLocation: StudioDestination.workspace.path,
        overrides: [acquisitionRuntimeServiceProvider.overrideWith(_FakeAcquisitionNotifier.new)],
        action: (c, r) => goToAcquisitionResult(
          c,
          r,
          UnifiedSearchResult.fromAcquisition(
            category: UnifiedSearchResultCategory.acquisitionJob,
            id: 'job-1',
            label: 'Job One',
            objectTypeLabel: 'Job',
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.acquisition.name);
      expect(container.read(acquisitionRuntimeServiceProvider).selectedJobId, 'job-1');
    });

    testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
      final container = await pump(
        tester,
        initialLocation: '/other',
        overrides: [acquisitionRuntimeServiceProvider.overrideWith(_FakeAcquisitionNotifier.new)],
        action: (c, r) => goToAcquisitionResult(
          c,
          r,
          UnifiedSearchResult.fromAcquisition(
            category: UnifiedSearchResultCategory.acquisitionJob,
            id: 'job-1',
            label: 'Job One',
            objectTypeLabel: 'Job',
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('standalone-acquisition'), findsOneWidget);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    });
  });

  group('goToExchangeResult', () {
    testWidgets('a Package result: within the Workspace, opens/activates the Exchange tab and selects the package', (tester) async {
      final container = await pump(
        tester,
        initialLocation: StudioDestination.workspace.path,
        overrides: [exchangeRuntimeServiceProvider.overrideWith(_FakeExchangeNotifier.new)],
        action: (c, r) => goToExchangeResult(
          c,
          r,
          UnifiedSearchResult.fromExchange(
            category: UnifiedSearchResultCategory.exchangePackage,
            id: 'pkg-1',
            label: 'Package One',
            objectTypeLabel: 'Package',
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.exchange.name);
      expect(container.read(exchangeRuntimeServiceProvider).selectedPackage?.id, 'pkg-1');
    });
  });

  group('goToSearchResult (symbol/annotation/layer fallback)', () {
    testWidgets('within the Workspace, a symbol result opens/activates the Diagram tab', (tester) async {
      final result = UnifiedSearchResult.fromEngine(
        const engine.SearchResult(id: 'sym-1', kind: engine.SearchResultKind.symbol, label: 'A Symbol', matchedField: 'alias'),
        repositoryLocation: 'Untitled Diagram',
      );
      final container = await pump(tester,
          initialLocation: StudioDestination.workspace.path, action: (c, r) => goToSearchResult(c, r, result));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.isDiagram, isTrue);
    });

    testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
      final result = UnifiedSearchResult.fromEngine(
        const engine.SearchResult(id: 'sym-1', kind: engine.SearchResultKind.symbol, label: 'A Symbol', matchedField: 'alias'),
        repositoryLocation: 'Untitled Diagram',
      );
      final container =
          await pump(tester, initialLocation: '/other', action: (c, r) => goToSearchResult(c, r, result));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('standalone-diagram'), findsOneWidget);
      expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    });
  });
}

/// Overrides only the network-backed pipeline refresh so this test
/// exercises the real `state.selectedJobId` assignment without making
/// live HTTP calls — the same seam `acquisition_operation_reporting_test.dart`
/// already established for this notifier.
class _FakeAcquisitionNotifier extends AcquisitionRuntimeNotifier {
  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<void> selectJob(String jobId) async {
    state = state.copyWith(selectedJobId: jobId);
  }
}

/// Same reasoning as [_FakeAcquisitionNotifier], for Exchange's own
/// network-backed `selectPackage`/`selectPublisher`.
class _FakeExchangeNotifier extends ExchangeRuntimeNotifier {
  @override
  ExchangeServiceState build() => const ExchangeServiceState();

  @override
  Future<void> selectPackage(String packageId) async {
    state = state.copyWith(
      selectedPackage: ExchangePackage(
        id: packageId,
        packageId: packageId,
        publisherId: 'pub-1',
        displayName: 'Package One',
        description: '',
        categoryId: null,
        currentVersion: '1.0',
        status: 'active',
        createdAt: '',
        updatedAt: '',
      ),
    );
  }
}

class _TriggerPage extends ConsumerWidget {
  const _TriggerPage(this.action);

  final void Function(BuildContext, WidgetRef) action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => action(context, ref),
        child: const Text('trigger'),
      ),
    );
  }
}
