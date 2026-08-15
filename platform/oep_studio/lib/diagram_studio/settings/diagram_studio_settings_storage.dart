import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'diagram_studio_settings.dart';

/// Loads/saves [DiagramStudioSettings] to their own file,
/// `diagram_studio_settings.json`, alongside (but independent of) the
/// main `settings.json` — same root directory
/// (`SettingsStorage.root()`), separate file, no shared schema.
abstract final class DiagramStudioSettingsStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_settings.json');

  static Future<DiagramStudioSettings> load() async {
    final file = _file();
    if (!file.existsSync()) return DiagramStudioSettings.defaults;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return DiagramStudioSettings.defaults;
      return DiagramStudioSettings.fromJson(decoded);
    } on FormatException {
      return DiagramStudioSettings.defaults;
    }
  }

  static Future<void> save(DiagramStudioSettings settings) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(settings.toJson()));
  }
}
