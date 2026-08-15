import 'dart:convert';
import 'dart:io';

import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';
import '../services/engineering_project_service.dart';
import '../../settings/services/settings_storage.dart';

/// The Platform's centralized workspace lifecycle coordinator
/// (WP-STUDIO-029) — recent-workspace tracking, dirty-state
/// coordination, and crash-recovery, for Diagram Studio's document
/// lifecycle (`EngineeringProjectState`/`DiagramDocument`).
///
/// This is deliberately scoped to Diagram documents only: per this Work
/// Package's Architecture Review, Diagram Studio is the only Studio
/// with a dirty-state concept at all — Knowledge Curation Sessions
/// auto-persist on every change (`FoundationRuntimeNotifier
/// ._persistActiveSession`) and have no "unsaved changes" to coordinate.
/// `WorkspaceManager` does not invent one for Knowledge Studio; it
/// observes what already exists rather than redesigning what doesn't.
///
/// Backed by one small JSON file (`workspace_manager_state.json`, same
/// `SettingsStorage.root()` directory every other Studio/Settings file
/// already uses) holding the recent-workspace list and, when present, a
/// crash-recovery sentinel. [file] is injectable so tests never touch
/// the real user settings directory.
class WorkspaceManager {
  WorkspaceManager({File? file, PlatformEventBus? eventBus, this.maxRecentWorkspaces = 5})
      : _file = file ??
            File('${SettingsStorage.root().path}${Platform.pathSeparator}workspace_manager_state.json'),
        _eventBus = eventBus ?? PlatformEventBus.instance;

  final File _file;
  final PlatformEventBus _eventBus;
  final int maxRecentWorkspaces;

  List<String> _recentWorkspaces = const [];
  String? _recoverableWorkspacePath;
  bool _lastKnownDirty = false;
  String? _lastKnownPath;

  /// Recently opened/saved Diagram document paths, most recent first —
  /// capped at [maxRecentWorkspaces]. Empty until [initialize] loads the
  /// persisted list.
  List<String> get recentWorkspaces => _recentWorkspaces;

  /// The document path `initialize` found flagged dirty when the app
  /// last closed (or crashed) — `null` if there's nothing to recover, or
  /// after [clearRecoverable] runs. Populated once, by [initialize];
  /// use this instead of [hasUnsavedChanges] to decide whether to prompt
  /// at startup.
  String? get recoverableWorkspacePath => _recoverableWorkspacePath;

  /// Centralized dirty-state coordination: whether Diagram Studio's
  /// active document currently has unsaved changes, per the most recent
  /// [handleProjectStateChange] call. `false` before the first call.
  bool get hasUnsavedChanges => _lastKnownDirty;

  /// Loads the persisted recent-workspace list and checks for a
  /// crash-recovery sentinel — call once at app startup, before reading
  /// [recoverableWorkspacePath].
  Future<void> initialize() async {
    if (!_file.existsSync()) return;
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, Object?>) return;
      final recent = decoded['recentWorkspaces'];
      if (recent is List) {
        _recentWorkspaces = recent.whereType<String>().take(maxRecentWorkspaces).toList();
      }
      _recoverableWorkspacePath = decoded['recoverablePath'] as String?;
    } on FormatException {
      // A corrupted state file is no different from a fresh install —
      // there is nothing worth recovering from unreadable JSON.
    }
  }

  /// Called on every `EngineeringProjectState` change (`StudioShell`'s
  /// `ref.listenManual`) — updates the recent-workspace list on a path
  /// change, writes/clears the recovery sentinel on a dirty-state
  /// change, and publishes the corresponding [WorkspaceEvent]s. Never
  /// throws; a failed write here should not surface as an app-level
  /// error for something this ambient.
  Future<void> handleProjectStateChange(EngineeringProjectState state) async {
    final path = state.documentPath;
    final dirty = state.isDirty;
    var changed = false;

    if (path != _lastKnownPath) {
      _lastKnownPath = path;
      changed = true;
      if (path != null) {
        _recentWorkspaces = [path, ..._recentWorkspaces.where((p) => p != path)]
            .take(maxRecentWorkspaces)
            .toList();
        _eventBus.publish(WorkspaceEvent(kind: WorkspaceEventKind.opened, path: path));
      } else {
        _eventBus.publish(const WorkspaceEvent(kind: WorkspaceEventKind.closed));
      }
    }

    if (dirty != _lastKnownDirty) {
      _lastKnownDirty = dirty;
      changed = true;
      _eventBus.publish(WorkspaceEvent(kind: WorkspaceEventKind.dirtyChanged, path: path));
      if (dirty && path != null) {
        _recoverableWorkspacePath = path;
      } else if (!dirty) {
        _recoverableWorkspacePath = null;
        if (path != null) {
          _eventBus.publish(WorkspaceEvent(kind: WorkspaceEventKind.saved, path: path));
        }
      }
    }

    if (changed) await _persist();
  }

  /// Call after the user responds (either way) to a startup recovery
  /// prompt, so the same crash isn't offered for recovery twice.
  Future<void> clearRecoverable() async {
    _recoverableWorkspacePath = null;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await SettingsStorage.root().create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await _file.writeAsString(encoder.convert({
        'recentWorkspaces': _recentWorkspaces,
        if (_recoverableWorkspacePath != null) 'recoverablePath': _recoverableWorkspacePath,
      }));
    } on IOException {
      // Best-effort — a failed write here is not worth surfacing to the
      // user for something this ambient; the in-memory state (this
      // session's own recent list/dirty flag) is unaffected either way.
    }
  }

  static final WorkspaceManager instance = WorkspaceManager();
}
