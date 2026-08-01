import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import '../models/library_entry.dart';

/// Loads/saves the Exchange's locally-tracked My Library/Downloads
/// history to its own file, `exchange_library.json`, alongside (but
/// independent of) the main `settings.json` -- mirrors
/// `AcquisitionSettingsStorage` exactly, adapted for a list of entries
/// rather than a single settings object.
abstract final class ExchangeLibraryStorage {
  static File _file() => File('${SettingsStorage.root().path}${Platform.pathSeparator}exchange_library.json');

  static Future<({List<LibraryEntry> library, List<DownloadEntry> downloads})> load() async {
    final file = _file();
    if (!file.existsSync()) return (library: <LibraryEntry>[], downloads: <DownloadEntry>[]);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return (library: <LibraryEntry>[], downloads: <DownloadEntry>[]);
      final library = (decoded['library'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(LibraryEntry.fromJson)
          .toList();
      final downloads = (decoded['downloads'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(DownloadEntry.fromJson)
          .toList();
      return (library: library, downloads: downloads);
    } on FormatException {
      return (library: <LibraryEntry>[], downloads: <DownloadEntry>[]);
    }
  }

  static Future<void> save(List<LibraryEntry> library, List<DownloadEntry> downloads) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({
      'library': library.map((entry) => entry.toJson()).toList(),
      'downloads': downloads.map((entry) => entry.toJson()).toList(),
    }));
  }
}
