import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_studio/diagram_studio/persistence/diagram_workspace_state.dart';
import 'package:oep_studio/diagram_studio/persistence/workspace_state_storage.dart';

import 'support/isolated_settings_storage.dart';

/// `DiagramWorkspaceState` toJson/fromJson round-trip, plus
/// `WorkspaceStateStorage` (WORK_PACKAGE_024, ENGINE-TASK-000115).
/// AP-DIAGRAM-W2-D1: the `WorkspaceStateStorage` tests below use
/// `useIsolatedSettingsStorage()` rather than reading/backing up/
/// restoring this real machine's actual `%APPDATA%/oep_studio/` —
/// see that helper's own doc comment for why.
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
    useIsolatedSettingsStorage();
    // A fresh isolated root genuinely has no file yet, so this now
    // asserts the real fallback default exactly, not just "non-null".
    final loaded = await WorkspaceStateStorage.load();
    expect(loaded.lastDocumentPath, isNull);
    expect(loaded.showLayerPanel, isTrue);
    expect(loaded.showSearchPanel, isTrue);
  });

  test('WorkspaceStateStorage save() then load() round-trips a real change', () async {
    useIsolatedSettingsStorage();
    const probe = DiagramWorkspaceState(
      lastDocumentPath: 'workspace-storage-test-probe.json',
      showLayerPanel: false,
      showSearchPanel: false,
      explorerWidth: 199,
      sidePanelsWidth: 401,
    );

    await WorkspaceStateStorage.save(probe);
    final reloaded = await WorkspaceStateStorage.load();

    expect(reloaded.lastDocumentPath, 'workspace-storage-test-probe.json');
    expect(reloaded.showLayerPanel, isFalse);
    expect(reloaded.showSearchPanel, isFalse);
    expect(reloaded.explorerWidth, 199);
    expect(reloaded.sidePanelsWidth, 401);
  });
}
