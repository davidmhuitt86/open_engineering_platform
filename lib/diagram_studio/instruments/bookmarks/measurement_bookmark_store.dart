import 'dart:convert';
import 'dart:io';

import '../../../settings/services/settings_storage.dart';
import 'measurement_bookmark.dart';

/// JSON persistence for Measurement Bookmarks (WP-DS-005A), file
/// `measurement_bookmarks.json` under `SettingsStorage.root()` — same
/// storage shape as `MeasurementHistoryStore`.
abstract final class MeasurementBookmarkStore {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}measurement_bookmarks.json');

  static Future<List<MeasurementBookmark>> load() async {
    final file = _file();
    if (!file.existsSync()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return [
        for (final entry in decoded)
          if (entry is Map) MeasurementBookmark.fromJson(Map<String, Object?>.from(entry)),
      ];
    } on FormatException {
      return [];
    }
  }

  static Future<void> save(List<MeasurementBookmark> bookmarks) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert([for (final b in bookmarks) b.toJson()]));
  }
}
