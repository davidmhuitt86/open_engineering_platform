import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'acquisition_settings.dart';

/// Loads/saves [AcquisitionSettings] to their own file,
/// `acquisition_settings.json`, alongside (but independent of) the main
/// `settings.json` — mirrors `DiagramStudioSettingsStorage` exactly.
abstract final class AcquisitionSettingsStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}acquisition_settings.json');

  static Future<AcquisitionSettings> load() async {
    final file = _file();
    if (!file.existsSync()) return AcquisitionSettings.defaults;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return AcquisitionSettings.defaults;
      return AcquisitionSettings.fromJson(decoded);
    } on FormatException {
      return AcquisitionSettings.defaults;
    }
  }

  static Future<void> save(AcquisitionSettings settings) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(settings.toJson()));
  }
}
