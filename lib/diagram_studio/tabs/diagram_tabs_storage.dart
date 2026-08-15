import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'diagram_tab.dart';

/// (OEP Diagram Studio -- Phase 5, Part 14/Part 20.) Persists the open
/// tab list, the active tab id, and the recently-closed list -- the
/// exact same one-JSON-file-under-`SettingsStorage.root()` pattern
/// `RecentFilesStorage`/`WorkspaceStateStorage` already use, not a
/// second persistence system.
abstract final class DiagramTabsStorage {
  static const int maxRecentlyClosed = 10;

  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_tabs.json');

  static Future<({List<DiagramTab> tabs, String? activeTabId, List<DiagramTab> recentlyClosed})> load() async {
    final file = _file();
    if (!file.existsSync()) return (tabs: <DiagramTab>[], activeTabId: null, recentlyClosed: <DiagramTab>[]);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return (tabs: <DiagramTab>[], activeTabId: null, recentlyClosed: <DiagramTab>[]);
      }
      final tabs = (decoded['tabs'] as List? ?? const [])
          .map(DiagramTab.fromJson)
          .whereType<DiagramTab>()
          .toList();
      final recentlyClosed = (decoded['recentlyClosed'] as List? ?? const [])
          .map(DiagramTab.fromJson)
          .whereType<DiagramTab>()
          .toList();
      return (tabs: tabs, activeTabId: decoded['activeTabId'] as String?, recentlyClosed: recentlyClosed);
    } on FormatException {
      return (tabs: <DiagramTab>[], activeTabId: null, recentlyClosed: <DiagramTab>[]);
    }
  }

  static Future<void> save({
    required List<DiagramTab> tabs,
    required String? activeTabId,
    required List<DiagramTab> recentlyClosed,
  }) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({
      'tabs': tabs.map((t) => t.toJson()).toList(),
      'activeTabId': activeTabId,
      'recentlyClosed': recentlyClosed.take(maxRecentlyClosed).map((t) => t.toJson()).toList(),
    }));
  }
}
