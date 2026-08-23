import 'dart:convert';
import 'dart:io';

import '../settings/services/settings_storage.dart';

/// AP-OEP-WORKSPACE-PERSISTENCE-001 — persists the Engineering
/// Workspace's open Surface identity: an ordered list of surfaceIds and
/// the active surfaceId. This is deliberately the exact same shape and
/// convention `WebSurfaceTabsStorage` (`lib/web_surface/
/// web_surface_tabs_storage.dart`) already established and ships today
/// for Diagram Studio's own, separate Web Surface tab host — one small
/// JSON file under `SettingsStorage.root()`, identity only, never page
/// state. This is a distinct file/class (not a generalization of
/// `WebSurfaceTabsStorage`) because the two persist different, smaller
/// shapes: `WebSurface` tabs carry `id`/`title`/`initialUrl`/
/// `application`, whereas a Workspace tab carries nothing but a
/// surfaceId (`WorkspaceTab`'s own doc comment: title/icon are always
/// resolved live through `SurfaceRegistry`, never stored) — generalizing
/// the two into one shared type would either lose that simplicity or
/// force `WebSurface`'s richer shape onto the Workspace for no reason.
///
/// Not to be confused with `WorkspaceStateStorage`
/// (`lib/diagram_studio/persistence/workspace_state_storage.dart`) — an
/// unrelated, pre-existing concept for Diagram Studio's own internal
/// panel/layout persistence, sharing only the word "workspace".
///
/// An instantiable class (not `abstract final` with static members, the
/// way `WebSurfaceTabsStorage` is) so tests can substitute an in-memory
/// fake by subclassing and overriding [load]/[save] — see
/// `AP-OEP-WORKSPACE-STATE-001`'s own audit for why this package must
/// not couple its tests to the real filesystem.
class WorkspaceTabsStorage {
  const WorkspaceTabsStorage();

  File _file() => File('${SettingsStorage.root().path}${Platform.pathSeparator}workspace_tabs.json');

  Future<({List<String> surfaces, String? activeId})> load() async {
    final file = _file();
    if (!file.existsSync()) return (surfaces: <String>[], activeId: null);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return (surfaces: <String>[], activeId: null);
      final surfaces = (decoded['surfaces'] as List? ?? const []).whereType<String>().toList();
      return (surfaces: surfaces, activeId: decoded['activeId'] as String?);
    } on FormatException {
      return (surfaces: <String>[], activeId: null);
    }
  }

  Future<void> save({required List<String> surfaces, required String? activeId}) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({
      'surfaces': surfaces,
      'activeId': activeId,
    }));
  }
}
