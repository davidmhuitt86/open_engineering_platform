import 'dart:convert';
import 'dart:io';

import '../settings/services/settings_storage.dart';
import 'web_surface.dart';

/// Persists the open Web Surface tab list and the active tab id — the
/// same one-JSON-file-under-`SettingsStorage.root()` pattern
/// `DiagramTabsStorage` already uses, not a second persistence system.
/// `web_surface_tabs_controller.dart`'s own doc comment previously
/// documented this as a known, deliberately-deferred gap ("Phase 14:
/// persistence is documented, not implemented") — this file closes it.
abstract final class WebSurfaceTabsStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}web_surface_tabs.json');

  static Future<({List<WebSurface> surfaces, String? activeId})> load() async {
    final file = _file();
    if (!file.existsSync()) return (surfaces: <WebSurface>[], activeId: null);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return (surfaces: <WebSurface>[], activeId: null);
      final surfaces = (decoded['surfaces'] as List? ?? const [])
          .map(WebSurface.fromJson)
          .whereType<WebSurface>()
          .toList();
      return (surfaces: surfaces, activeId: decoded['activeId'] as String?);
    } on FormatException {
      return (surfaces: <WebSurface>[], activeId: null);
    }
  }

  static Future<void> save({required List<WebSurface> surfaces, required String? activeId}) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({
      'surfaces': surfaces.map((s) => s.toJson()).toList(),
      'activeId': activeId,
    }));
  }
}
