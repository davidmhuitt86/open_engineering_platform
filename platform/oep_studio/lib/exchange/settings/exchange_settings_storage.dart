import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'exchange_settings.dart';

/// Loads/saves [ExchangeSettings] to their own file,
/// `exchange_settings.json`, alongside (but independent of) the main
/// `settings.json` -- mirrors `AcquisitionSettingsStorage` exactly.
abstract final class ExchangeSettingsStorage {
  static File _file() => File('${SettingsStorage.root().path}${Platform.pathSeparator}exchange_settings.json');

  static Future<ExchangeSettings> load() async {
    final file = _file();
    if (!file.existsSync()) return ExchangeSettings.defaults;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return ExchangeSettings.defaults;
      return ExchangeSettings.fromJson(decoded);
    } on FormatException {
      return ExchangeSettings.defaults;
    }
  }

  static Future<void> save(ExchangeSettings settings) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(settings.toJson()));
  }
}
