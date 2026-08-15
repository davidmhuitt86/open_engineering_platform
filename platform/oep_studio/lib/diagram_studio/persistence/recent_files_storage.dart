import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';

/// Tracks the last N opened/saved Diagram Studio document paths
/// (AP-DS-001A, Documents review) — persisted the same way
/// [WorkspaceStateStorage] persists workspace chrome: one JSON file
/// under `SettingsStorage.root()`.
abstract final class RecentFilesStorage {
  static const int maxEntries = 10;

  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_recent_files.json');

  /// Returns recent paths, most-recently-used first. Entries whose file
  /// no longer exists on disk are silently dropped.
  static Future<List<String>> load() async {
    final file = _file();
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return const [];
      final rawList = decoded['paths'];
      if (rawList is! List) return const [];
      return rawList
          .whereType<String>()
          .where((path) => File(path).existsSync())
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  /// Records [path] as the most-recently-used document, evicting
  /// duplicates and trimming to [maxEntries].
  static Future<List<String>> recordOpened(String path) async {
    final existing = await load();
    final updated = [path, ...existing.where((p) => p != path)];
    final trimmed = updated.take(maxEntries).toList(growable: false);
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({'paths': trimmed}));
    return trimmed;
  }
}
