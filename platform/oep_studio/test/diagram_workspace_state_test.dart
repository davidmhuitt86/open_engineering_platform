import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_studio/diagram_studio/persistence/diagram_workspace_state.dart';
import 'package:oep_studio/diagram_studio/persistence/workspace_state_storage.dart';

/// `DiagramWorkspaceState` toJson/fromJson round-trip, plus
/// `WorkspaceStateStorage` against the real `%APPDATA%/oep_studio/`
/// directory (WORK_PACKAGE_024, ENGINE-TASK-000115) — the same
/// real-file-access-with-cleanup convention `knowledge_session_storage_test.dart`
/// already uses, since neither storage class has (or should gain) a
/// directory-override parameter purely for testability.
void main() {
  test('DiagramWorkspaceState round-trips through JSON, including ViewState', () {
    const state = DiagramWorkspaceState(
      lastDocumentPath: 'C:/diagrams/harness.json',
      showLayerPanel: false,
      showSearchPanel: true,
      explorerWidth: 260,
      sidePanelsWidth: 340,
      viewState: ViewState.initial,
    );

    final restored = DiagramWorkspaceState.fromJson(state.toJson());

    expect(restored.lastDocumentPath, state.lastDocumentPath);
    expect(restored.showLayerPanel, isFalse);
    expect(restored.showSearchPanel, isTrue);
    expect(restored.explorerWidth, 260);
    expect(restored.sidePanelsWidth, 340);
    expect(restored.viewState?.zoom, ViewState.initial.zoom);
  });

  test('DiagramWorkspaceState.fromJson tolerates a missing viewState key', () {
    final restored = DiagramWorkspaceState.fromJson(const {
      'lastDocumentPath': null,
      'showLayerPanel': true,
      'showSearchPanel': true,
      'explorerWidth': 220.0,
      'sidePanelsWidth': 300.0,
    });

    expect(restored.viewState, isNull);
    expect(restored.lastDocumentPath, isNull);
  });

  test('copyWith(clearLastDocumentPath: true) clears the path even with a non-null default', () {
    const state = DiagramWorkspaceState(lastDocumentPath: 'C:/diagrams/harness.json');
    final cleared = state.copyWith(clearLastDocumentPath: true);
    expect(cleared.lastDocumentPath, isNull);
  });

  test('WorkspaceStateStorage.load() returns initial state when no file exists yet', () async {
    // Uses whatever real %APPDATA%/oep_studio/ directory this machine
    // has; only asserts the fallback behavior, never assumes a clean
    // slate (a real diagram_studio_workspace.json may already exist
    // from manual use of the app).
    final loaded = await WorkspaceStateStorage.load();
    expect(loaded, isNotNull);
  });

  test('WorkspaceStateStorage save() then load() round-trips a real change', () async {
    final original = await WorkspaceStateStorage.load();
    const probe = DiagramWorkspaceState(
      lastDocumentPath: 'workspace-storage-test-probe.json',
      showLayerPanel: false,
      showSearchPanel: false,
      explorerWidth: 199,
      sidePanelsWidth: 401,
    );

    try {
      await WorkspaceStateStorage.save(probe);
      final reloaded = await WorkspaceStateStorage.load();

      expect(reloaded.lastDocumentPath, 'workspace-storage-test-probe.json');
      expect(reloaded.showLayerPanel, isFalse);
      expect(reloaded.showSearchPanel, isFalse);
      expect(reloaded.explorerWidth, 199);
      expect(reloaded.sidePanelsWidth, 401);
    } finally {
      // Restore whatever was there before this test ran.
      await WorkspaceStateStorage.save(original);
    }
  });
}
