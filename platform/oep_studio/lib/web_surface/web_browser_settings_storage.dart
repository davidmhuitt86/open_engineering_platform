import 'dart:convert';
import 'dart:io';

import '../settings/services/settings_storage.dart';
import 'web_browser_settings.dart';

/// Persists [WebBrowserSettings] to one small JSON file under
/// `SettingsStorage.root()` — the same convention every other Studio
/// persistence class in this codebase already follows
/// (`WorkspaceTabsStorage`, `WebSurfaceTabsStorage`).
///
/// An instantiable class (not static-only) so tests can substitute an
/// in-memory fake by subclassing and overriding [load]/[save], the same
/// seam `WorkspaceTabsStorage` already established.
class WebBrowserSettingsStorage {
  const WebBrowserSettingsStorage();

  File _file() => File('${SettingsStorage.root().path}${Platform.pathSeparator}web_browser_settings.json');

  Future<WebBrowserSettings> load() async {
    final file = _file();
    if (!file.existsSync()) return const WebBrowserSettings();
    try {
      return WebBrowserSettings.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return const WebBrowserSettings();
    }
  }

  Future<void> save(WebBrowserSettings settings) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(settings.toJson()));
  }
}
