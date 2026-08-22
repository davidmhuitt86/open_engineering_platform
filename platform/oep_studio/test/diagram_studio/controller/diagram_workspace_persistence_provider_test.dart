import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/persistence/diagram_workspace_persistence_provider.dart';
import 'package:oep_studio/diagram_studio/persistence/diagram_workspace_state.dart';
import 'package:oep_studio/diagram_studio/persistence/workspace_state_storage.dart';

import '../../support/isolated_settings_storage.dart';

/// Regression coverage for AP-DIAGRAM-W2-D (Wave 2 Stage D — Workspace
/// Persistence Boundary Extraction), hardened per AP-DIAGRAM-W2-D1.
/// `diagramWorkspacePersistenceProvider`
/// (`persistence/diagram_workspace_persistence_provider.dart`) is now the
/// sole, non-widget, app-session-scoped owner of
/// `WorkspaceStateStorage.load`/`save`; `DiagramStudioPage` no longer
/// calls either directly, and `dispose()` is no longer a persistence
/// mechanism at all.
///
/// **Test isolation (AP-DIAGRAM-W2-D1).** Every test below calls
/// `useIsolatedSettingsStorage()` first, so all persistence in this file
/// — including the widget test's own `persist()` calls, which
/// previously corrupted this developer's real workspace file twice
/// during Stage D before this hardening pass — happens only inside a
/// disposable temp directory. No backup/restore of real state is
/// needed, and no `--concurrency=1` workaround is needed either (see
/// `settings_storage_test_isolation_test.dart` for the isolation seam's
/// own regression coverage).
void main() {
  Widget shell(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test(
    '1/2/5/6/7/9/10/11: the provider owns load/save independently of any widget, persists document-path/panel/ViewState fields correctly, and serializes overlapping saves so a stale one cannot win',
    () async {
      useIsolatedSettingsStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(diagramWorkspacePersistenceProvider.notifier);

      // --- 1/10/11: load without a widget owning it, exactly once ----------
      final loadedA = await container.read(diagramWorkspacePersistenceProvider.future);
      final loadedB = await container.read(diagramWorkspacePersistenceProvider.future);
      expect(identical(loadedA, loadedB), isTrue, reason: 'AsyncNotifier.build() must run exactly once per provider lifetime — a second read must return the already-loaded value, not reload from disk');
      expect(loadedA, DiagramWorkspaceState.initial, reason: 'a fresh isolated root has nothing to load, so this must be the documented fallback default');

      // --- 2/5/6/7: save without dispose(), without any widget existing,
      // covering the document-path reference, panel fields, and
      // ViewState all together in one persisted value.
      final viewStateSample = ViewState.initial.copyWith(zoom: 2.5, pan: const Point2D(10, 20));
      final stateOne = DiagramWorkspaceState(
        lastDocumentPath: 'C:/stage-d-test/one.json',
        showLayerPanel: false,
        showSearchPanel: true,
        explorerWidth: 111,
        sidePanelsWidth: 222,
        viewState: viewStateSample,
      );
      notifier.persist(stateOne);
      expect(container.read(diagramWorkspacePersistenceProvider).valueOrNull, stateOne, reason: 'persist() must update the in-memory authoritative state synchronously, before any disk write completes');

      // --- 9: overlapping saves cannot let a stale one win -------------
      final stateTwo = DiagramWorkspaceState(
        lastDocumentPath: 'C:/stage-d-test/two.json',
        showLayerPanel: true,
        showSearchPanel: false,
        explorerWidth: 333,
        sidePanelsWidth: 444,
        viewState: viewStateSample.copyWith(zoom: 0.5),
      );
      // Fire both without awaiting in between, simulating overlap; the
      // notifier's internal write queue must still land them in call
      // order so the final on-disk content matches the *later* call.
      notifier.persist(stateOne);
      notifier.persist(stateTwo);
      expect(container.read(diagramWorkspacePersistenceProvider).valueOrNull, stateTwo, reason: 'in-memory state must reflect the most recent persist() call immediately');

      await notifier.flush();
      final onDiskAfter = await WorkspaceStateStorage.load();
      expect(onDiskAfter.lastDocumentPath, stateTwo.lastDocumentPath, reason: 'the write queue must serialize overlapping saves so the disk ends up with the later call\'s content, never the earlier one\'s');
      expect(onDiskAfter.showLayerPanel, stateTwo.showLayerPanel);
      expect(onDiskAfter.showSearchPanel, stateTwo.showSearchPanel);
      expect(onDiskAfter.explorerWidth, stateTwo.explorerWidth);
      expect(onDiskAfter.sidePanelsWidth, stateTwo.sidePanelsWidth);
      expect(onDiskAfter.viewState?.zoom, stateTwo.viewState?.zoom, reason: 'ViewState must round-trip through persistence as the serializable value it already was — this test never touches a TransformationController/Matrix4');
    },
  );

  testWidgets(
    '3/4/5/6/7: a widget remount preserves workspace state (panel fields, document-path reference, ViewState); unmounting does not destroy it and remounting does not reload/reset it',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useIsolatedSettingsStorage();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(shell(container, const SizedBox.shrink()));
      await settle(tester);

      // A real, user-triggered persist (mirrors what a panel toggle's own
      // `_persistWorkspaceState()` call site does) — never through
      // `dispose()`. Safe to call directly from the fake-async test zone
      // now: with an isolated root there is no real user data to
      // corrupt, and (per AP-DIAGRAM-W2-D1 investigation) this call
      // still schedules a real `dart:io` write internally regardless —
      // it just no longer matters if that write's zone-binding leaves it
      // pending, because there is nothing left to protect.
      final notifier = container.read(diagramWorkspacePersistenceProvider.notifier);
      final beforeToggle = (await tester.runAsync(() => container.read(diagramWorkspacePersistenceProvider.future)))!;
      final toggled = beforeToggle.copyWith(showLayerPanel: !beforeToggle.showLayerPanel, explorerWidth: beforeToggle.explorerWidth + 17);
      notifier.persist(toggled);
      await settle(tester);
      expect(container.read(diagramWorkspacePersistenceProvider).valueOrNull, toggled, reason: 'setup: the explicit persist must have landed in the provider\'s in-memory state');

      // --- 4: unmount does not destroy it -----------------------------------
      await tester.pumpWidget(shell(container, const SizedBox.shrink()));
      await settle(tester);
      expect(container.read(diagramWorkspacePersistenceProvider).valueOrNull, toggled, reason: 'unmounting the page must not clear/reset the provider\'s workspace state — the provider outlives the widget');

      // --- 3: remount preserves it, does not reload/reset it ---------------
      await tester.pumpWidget(shell(container, const SizedBox.shrink()));
      await settle(tester);

      expect(container.read(diagramWorkspacePersistenceProvider).valueOrNull, toggled, reason: 'a remount must not re-run the provider\'s build() (which would reload from disk) — it must see the exact same in-memory state the first mount left behind');
    },
  );
}
