import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../settings/services/settings_storage.dart';
import 'perspective.dart';

/// WP-DS-006 Engineering Workbench — Perspective registration, activation,
/// and persistence (governing spec's "Perspective Manager" responsibilities:
/// register perspectives, activate perspective, persist current perspective,
/// notify listeners, restore last perspective).
///
/// Perspectives are pluggable: [EngineeringWorkbenchPage] and every widget
/// under `workbench/widgets/` iterate [perspectives] / read [active] —
/// nothing in this framework, or in the shell widget built on top of it,
/// contains a `switch` over a fixed perspective id (the governing spec's own
/// explicit constraint). Adding an eleventh Perspective later is a call to
/// [register], not an edit to the shell.
class PerspectiveManager extends ChangeNotifier {
  PerspectiveManager({File? file}) : _file = file ?? _defaultFile();

  /// The app-wide instance, shared between [EngineeringWorkbenchPage] (which
  /// renders the active Perspective's content) and `WorkbenchSidebar` when
  /// hoisted to `StudioShell` as the app's single left sidebar — both must
  /// observe/activate the same Perspective selection. Mirrors the same
  /// `static final ... instance` pattern already used by `WorkspaceManager`.
  static final PerspectiveManager instance = PerspectiveManager();

  static File _defaultFile() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}workbench_active_perspective.json');

  final File _file;
  final List<Perspective> _perspectives = [];
  String? _activeId;

  /// In registration order.
  List<Perspective> get perspectives => List.unmodifiable(_perspectives);

  Perspective? get active => _activeId == null ? null : byId(_activeId!);

  Perspective? byId(String id) {
    for (final perspective in _perspectives) {
      if (perspective.id == id) return perspective;
    }
    return null;
  }

  /// Registers [perspective]. Throws [StateError] on a duplicate id, the
  /// same defensive check [InstrumentRegistry]/`StudioRegistry` already use
  /// elsewhere in this codebase for the same class of mistake.
  void register(Perspective perspective) {
    if (byId(perspective.id) != null) {
      throw StateError('PerspectiveManager: a perspective with id "${perspective.id}" is already registered.');
    }
    _perspectives.add(perspective);
    notifyListeners();
  }

  /// Registers every entry in [perspectives], in order — the normal way
  /// [EngineeringWorkbenchPage] seeds a fresh manager from
  /// `perspectives/workbench_perspectives.dart`'s fixed list.
  void registerAll(Iterable<Perspective> perspectives) {
    for (final perspective in perspectives) {
      register(perspective);
    }
  }

  /// Activates [id] and persists it as "last active perspective" (fire and
  /// forget — same "cheap, small JSON, write on every change" precedent
  /// `InstrumentDockController`/`WorkspaceStateStorage` already use). A
  /// no-op if [id] isn't registered or is already active.
  void activate(String id) {
    if (_activeId == id) return;
    if (byId(id) == null) return;
    _activeId = id;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString(encoder.convert({'activePerspectiveId': _activeId}));
  }

  /// Restores the last-active perspective from disk, falling back to
  /// [fallbackId] (or the first registered perspective) if nothing was
  /// persisted, the persisted id is no longer registered, or the file is
  /// missing/corrupt. Call once, after every [register]/[registerAll] call,
  /// before the shell first builds.
  Future<void> restoreLastPerspective({String? fallbackId}) async {
    String? restoredId;
    if (_file.existsSync()) {
      try {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is Map<String, Object?>) {
          restoredId = decoded['activePerspectiveId'] as String?;
        }
      } on FormatException {
        restoredId = null;
      }
    }
    final resolved = (restoredId != null && byId(restoredId) != null)
        ? restoredId
        : (fallbackId != null && byId(fallbackId) != null)
            ? fallbackId
            : (_perspectives.isNotEmpty ? _perspectives.first.id : null);
    if (resolved != null) activate(resolved);
  }
}
