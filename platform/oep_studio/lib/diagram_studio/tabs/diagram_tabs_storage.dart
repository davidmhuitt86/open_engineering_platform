import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'diagram_tab.dart';

/// (OEP Diagram Studio -- Phase 5, Part 14/Part 20.) Persists the open
/// tab list, the active tab id, and the recently-closed list -- the
/// exact same one-JSON-file-under-`SettingsStorage.root()` pattern
/// `RecentFilesStorage`/`WorkspaceStateStorage` already use, not a
/// second persistence system.
///
/// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 —
/// [load]/[save] take a [fileSuffix] so each Diagram Workspace instance
/// gets its own file, without this class needing to know anything about
/// "primary"/instance-id semantics itself (that mapping is the caller's
/// decision, § `diagram_tabs_controller.dart`). An empty [fileSuffix]
/// resolves to the exact original, unchanged filename
/// (`diagram_studio_tabs.json`) — the primary instance's persisted state
/// is therefore byte-for-byte backward compatible; only a genuinely new,
/// non-primary instance gets a new, suffixed file.
abstract final class DiagramTabsStorage {
  static const int maxRecentlyClosed = 10;

  static File _file(String fileSuffix) => File(
        '${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_tabs$fileSuffix.json',
      );

  static Future<({List<DiagramTab> tabs, String? activeTabId, List<DiagramTab> recentlyClosed})> load({
    String fileSuffix = '',
  }) async {
    final file = _file(fileSuffix);
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
    String fileSuffix = '',
  }) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file(fileSuffix).writeAsString(encoder.convert({
      'tabs': tabs.map((t) => t.toJson()).toList(),
      'activeTabId': activeTabId,
      'recentlyClosed': recentlyClosed.take(maxRecentlyClosed).map((t) => t.toJson()).toList(),
    }));
  }
}
