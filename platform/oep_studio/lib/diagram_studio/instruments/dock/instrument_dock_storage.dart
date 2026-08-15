import 'dart:convert';
import 'dart:io';

import '../../../settings/services/settings_storage.dart';
import 'instrument_dock_state.dart';

/// Loads/saves [InstrumentDockState] to its own file,
/// `instrument_dock_layout.json`, under `SettingsStorage.root()` — same
/// shape as `WorkspaceStateStorage` (WORK_PACKAGE_024), one JSON file per
/// persisted concern rather than folding dock layout into the general
/// workspace state file.
abstract final class InstrumentDockStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}instrument_dock_layout.json');

  static Future<InstrumentDockState> load() async {
    final file = _file();
    if (!file.existsSync()) return InstrumentDockState.initial;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return InstrumentDockState.initial;
      return InstrumentDockState.fromJson(decoded);
    } on FormatException {
      return InstrumentDockState.initial;
    }
  }

  static Future<void> save(InstrumentDockState state) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(state.toJson()));
  }
}
