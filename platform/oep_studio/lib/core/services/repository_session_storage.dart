import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';

/// Persists which Foundation Repository directory was open most
/// recently, so a fresh app launch can reopen it automatically instead
/// of always landing on the Dashboard with nothing open. One small JSON
/// file under `SettingsStorage.root()`, the same shape
/// `RecentFilesStorage`/`WorkspaceTabsStorage` already establish for this
/// kind of "remember one piece of session identity across restarts"
/// persistence -- identity only (a directory path), never Repository
/// content itself.
abstract final class RepositorySessionStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}last_repository.json');

  /// The last-opened Repository directory path, or `null` if none was
  /// ever recorded, the file is corrupt, or the recorded path no longer
  /// exists on disk (a Repository directory the user deleted/moved
  /// should never be silently re-attempted on every future launch).
  static Future<String?> load() async {
    final file = _file();
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final path = decoded['lastRepositoryPath'];
      if (path is! String || path.isEmpty) return null;
      return Directory(path).existsSync() ? path : null;
    } on FormatException {
      return null;
    }
  }

  /// Records [path] as the Repository to reopen on the next launch.
  static Future<void> recordOpened(String path) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({'lastRepositoryPath': path}));
  }
}
