import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/shared/navigation/evidence_navigation.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-DIAGRAM-CONTEXT-001 — the strongest Diagram → Surface workflow
/// found in the audit: `goToEvidence`, the real, already-shipped
/// "Go to Evidence" button in `EngineeringEvidenceLinkProperties`
/// (Diagram Studio's own Property Inspector mode for a selected
/// node/relationship's evidence link). The only change this package
/// makes is routing its final "switch to Knowledge Studio" step through
/// the same `openOrActivateDestination` helper AP-OEP-WORKSPACE-CONTEXT-
/// 001/002 already established and tested for every other cross-Surface
/// navigation function — everything else (the `sourceReference` lookup,
/// the explicit "could not be found" failure state, the engine
/// selection mirroring) is untouched, pre-existing behavior.
void main() {
  const link = EvidenceLink(id: 'evidence-1', kind: EvidenceKind.text, sourceReference: 'source-1');
  const unresolvableLink = EvidenceLink(id: 'evidence-2', kind: EvidenceKind.text, sourceReference: 'no-such-source');

  GoRouter buildRouter(String initialLocation, void Function(BuildContext, WidgetRef) action) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: StudioDestination.workspace.path, builder: (c, s) => _TriggerPage(action)),
          GoRoute(path: '/other', builder: (c, s) => _TriggerPage(action)),
          GoRoute(path: StudioDestination.knowledge.path, builder: (c, s) => const Scaffold(body: Text('standalone-knowledge'))),
        ],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required String initialLocation,
    required void Function(BuildContext, WidgetRef) action,
  }) async {
    useIsolatedSettingsStorage();
    final container = ProviderContainer(
      overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeFoundationNotifier.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: buildRouter(initialLocation, action)),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('within the Workspace, Go to Evidence opens/activates the Knowledge tab and selects the source material', (tester) async {
    final container = await pump(tester,
        initialLocation: StudioDestination.workspace.path, action: (c, r) => goToEvidence(c, r, link));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    final tabs = container.read(workspaceTabsControllerProvider);
    expect(tabs.tabs, hasLength(1));
    expect(tabs.active!.surfaceId, StudioDestination.knowledge.name);
    expect(container.read(foundationRuntimeServiceProvider).selectedSourceMaterial?.id, 'source-1');
    expect(find.text('standalone-knowledge'), findsNothing, reason: 'must not leave the Workspace route');
  });

  testWidgets('repeated navigation activates the one Knowledge tab, never a duplicate', (tester) async {
    final container = await pump(tester,
        initialLocation: StudioDestination.workspace.path, action: (c, r) => goToEvidence(c, r, link));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(container.read(workspaceTabsControllerProvider).tabs, hasLength(1));
  });

  testWidgets('outside the Workspace, original route navigation is unchanged', (tester) async {
    final container = await pump(tester, initialLocation: '/other', action: (c, r) => goToEvidence(c, r, link));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('standalone-knowledge'), findsOneWidget);
    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
  });

  testWidgets('an evidence link whose source material is missing fails safely: no navigation, no tab, an explicit message', (tester) async {
    final container = await pump(tester,
        initialLocation: StudioDestination.workspace.path, action: (c, r) => goToEvidence(c, r, unresolvableLink));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    expect(container.read(foundationRuntimeServiceProvider).selectedSourceMaterial, isNull);
    expect(find.text('That evidence could not be found in the active Knowledge Session.'), findsOneWidget);
  });
}

class _FakeFoundationNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        sourceMaterials: [
          SourceMaterial(
            id: 'source-1',
            originalFileName: 'wiring-spec.pdf',
            localPath: '/tmp/wiring-spec.pdf',
            type: SourceMaterialType.pdf,
            sizeBytes: 1024,
            importDate: DateTime(2026, 1, 1),
            addedBy: 'tester',
          ),
        ],
      );
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
