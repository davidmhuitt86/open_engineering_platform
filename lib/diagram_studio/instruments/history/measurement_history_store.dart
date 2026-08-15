import 'dart:convert';
import 'dart:io';

import '../../../settings/services/settings_storage.dart';
import 'measurement_history_entry.dart';

/// JSON persistence for the Measurement History (WP-DS-005A). One file,
/// `measurement_history.json`, under `SettingsStorage.root()` — same
/// storage shape as `WorkspaceStateStorage`/`InstrumentDockStorage`.
///
/// **Disclosed scope**: this is a single Studio-wide history, not scoped
/// per-diagram-document — matching the spec's "maintain a measurement
/// history" (no per-document scoping requirement stated) and this
/// codebase's own settings-file precedent. Per-document history is
/// deferred (see IMPLEMENTATION_STATUS.md / MEASUREMENT_SYSTEM.md).
abstract final class MeasurementHistoryStore {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}measurement_history.json');

  static Future<List<MeasurementHistoryEntry>> load() async {
    final file = _file();
    if (!file.existsSync()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return [
        for (final entry in decoded)
          if (entry is Map) MeasurementHistoryEntry.fromJson(Map<String, Object?>.from(entry)),
      ];
    } on FormatException {
      return [];
    }
  }

  static Future<void> save(List<MeasurementHistoryEntry> entries) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert([for (final e in entries) e.toJson()]));
  }

  /// Exports the given entries as a standalone pretty-printed JSON string
  /// (WP-DS-005A "Export") — callers write it wherever the user chooses
  /// (a `saveFile` dialog from `diagram_studio_page.dart`'s own file-picker
  /// precedent); this store only produces the string.
  static String exportJson(List<MeasurementHistoryEntry> entries) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert([for (final e in entries) e.toJson()]);
  }
}
