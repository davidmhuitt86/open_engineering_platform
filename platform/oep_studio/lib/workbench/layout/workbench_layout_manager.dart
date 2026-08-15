import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../settings/services/settings_storage.dart';
import '../perspective/perspective.dart';

/// WP-DS-006 Engineering Workbench — Layout Manager. Each Perspective owns
/// an independent [PerspectiveLayout], persisted to its own file under
/// `SettingsStorage.root()/workbench_layouts/<perspectiveId>.json` (e.g.
/// `diagram.json`, `simulation.json`, `inspection.json`, `publishing.json`
/// — the governing spec's own named examples). Changing one Perspective's
/// layout never touches another's file, and never touches
/// `workbench_active_perspective.json` ([PerspectiveManager]'s own,
/// separate concern).
class WorkbenchLayoutManager extends ChangeNotifier {
  WorkbenchLayoutManager({Directory? directory}) : _directory = directory ?? _defaultDirectory();

  static Directory _defaultDirectory() =>
      Directory('${SettingsStorage.root().path}${Platform.pathSeparator}workbench_layouts');

  final Directory _directory;
  final Map<String, PerspectiveLayout> _layouts = {};

  File _fileFor(String perspectiveId) => File('${_directory.path}${Platform.pathSeparator}$perspectiveId.json');

  /// The live layout for [perspective] — [perspective.defaultLayout] until
  /// [load] has been called for it (or a change has been made this
  /// session).
  PerspectiveLayout layoutFor(Perspective perspective) => _layouts[perspective.id] ?? perspective.defaultLayout;

  /// Loads the persisted layout for [perspective] from disk, falling back
  /// to [Perspective.defaultLayout] if no file exists yet or it's corrupt.
  /// Idempotent — safe to call every time a Perspective is activated.
  Future<void> load(Perspective perspective) async {
    final file = _fileFor(perspective.id);
    if (!file.existsSync()) {
      _layouts[perspective.id] = perspective.defaultLayout;
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      _layouts[perspective.id] =
          decoded is Map<String, Object?> ? PerspectiveLayout.fromJson(decoded) : perspective.defaultLayout;
    } on FormatException {
      _layouts[perspective.id] = perspective.defaultLayout;
    }
    notifyListeners();
  }

  /// Updates [perspective]'s live layout and persists it to its own file
  /// (fire and forget, matching this codebase's established "cheap, small
  /// JSON, write on every change" precedent).
  void update(Perspective perspective, PerspectiveLayout Function(PerspectiveLayout current) fn) {
    final next = fn(layoutFor(perspective));
    _layouts[perspective.id] = next;
    notifyListeners();
    unawaited(_persist(perspective.id, next));
  }

  Future<void> _persist(String perspectiveId, PerspectiveLayout layout) async {
    await _directory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _fileFor(perspectiveId).writeAsString(encoder.convert(layout.toJson()));
  }
}
