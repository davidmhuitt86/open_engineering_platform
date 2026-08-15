import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../settings/services/settings_storage.dart';

/// Persisted UI state for [WorkbenchSidebar] — just the collapsed flag.
/// Not engineering state, not Perspective/Layout state; its own small file
/// (`workbench_sidebar.json`), matching every other Workbench concern's
/// "one small JSON file per concern" precedent.
class WorkbenchSidebarState extends ChangeNotifier {
  WorkbenchSidebarState({File? file, bool collapsed = false})
      : _file = file ?? _defaultFile(),
        _collapsed = collapsed;

  static File _defaultFile() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}workbench_sidebar.json');

  final File _file;
  bool _collapsed;

  bool get collapsed => _collapsed;

  static Future<WorkbenchSidebarState> load({File? file}) async {
    final resolvedFile = file ?? _defaultFile();
    if (!resolvedFile.existsSync()) return WorkbenchSidebarState(file: resolvedFile);
    try {
      final decoded = jsonDecode(await resolvedFile.readAsString());
      final collapsed = decoded is Map<String, Object?> ? (decoded['collapsed'] as bool? ?? false) : false;
      return WorkbenchSidebarState(file: resolvedFile, collapsed: collapsed);
    } on FormatException {
      return WorkbenchSidebarState(file: resolvedFile);
    }
  }

  void toggleCollapsed() {
    _collapsed = !_collapsed;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString(encoder.convert({'collapsed': _collapsed}));
  }
}
