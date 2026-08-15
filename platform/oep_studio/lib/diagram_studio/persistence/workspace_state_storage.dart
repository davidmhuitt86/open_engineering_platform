import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';
import 'diagram_workspace_state.dart';

/// Loads/saves [DiagramWorkspaceState] to its own file,
/// `diagram_studio_workspace.json`, under the same root directory as
/// every other Studio-owned settings/session file
/// (`SettingsStorage.root()`) — mirrors `KnowledgeSessionStorage`'s own
/// save/load shape (WORK_PACKAGE_024, ENGINE-TASK-000115).
abstract final class WorkspaceStateStorage {
  static File _file() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_workspace.json');

  static Future<DiagramWorkspaceState> load() async {
    final file = _file();
    if (!file.existsSync()) return DiagramWorkspaceState.initial;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return DiagramWorkspaceState.initial;
      return DiagramWorkspaceState.fromJson(decoded);
    } on FormatException {
      return DiagramWorkspaceState.initial;
    }
  }

  static Future<void> save(DiagramWorkspaceState state) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(state.toJson()));
  }
}
