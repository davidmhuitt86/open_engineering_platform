import 'dart:convert';
import 'dart:io';

import '../settings/services/settings_storage.dart';

/// A persisted tab record: instance identity plus Surface type identity
/// — the smallest shape [WorkspaceTabsStorage] needs to reconstruct
/// [WorkspaceTab] instances, including more than one tab sharing the
/// same [surfaceId] (AP-OEP-WORKSPACE-MULTI-INSTANCE-001). No title/icon
/// (always resolved live through `SurfaceRegistry`) and no document/URL
/// content (a later package's concern, per that package's own scope
/// boundary).
typedef PersistedWorkspaceTab = ({String id, String surfaceId});

/// AP-OEP-WORKSPACE-PERSISTENCE-001/AP-OEP-WORKSPACE-MULTI-INSTANCE-001
/// — persists the Engineering Workspace's open tab identity: an ordered
/// list of `{id, surfaceId}` records and the active tab's `id`. One
/// small JSON file under `SettingsStorage.root()`, identity only, never
/// page/document state — unchanged in spirit from the original
/// AP-OEP-WORKSPACE-PERSISTENCE-001 shape, just now storing tab
/// *instances* rather than a bare list of surfaceId strings, so two
/// tabs sharing one `surfaceId` can be told apart on restore.
///
/// **Backward compatibility**: [load] also reads the original
/// `{"surfaces": [...], "activeId": "<surfaceId>"}` shape (every file
/// written before this package) — synthesizing one tab record per
/// surfaceId with the same deterministic id
/// (`'workspace-tab-<surfaceId>'`) [WorkspaceTabsController] always used
/// for singleton Surfaces, and resolving the legacy `activeId` (a
/// surfaceId) to that same synthesized tab id. This is sound because no
/// file written before this package could ever contain two tabs sharing
/// a surfaceId (multi-instance tabs did not exist yet). [save] always
/// writes the new `{"tabs": [...], "activeId": "<tabId>"}` shape going
/// forward; a legacy file is transparently upgraded on first write.
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

  Future<({List<PersistedWorkspaceTab> tabs, String? activeId})> load() async {
    final file = _file();
    if (!file.existsSync()) return (tabs: <PersistedWorkspaceTab>[], activeId: null);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return (tabs: <PersistedWorkspaceTab>[], activeId: null);

      final rawTabs = decoded['tabs'];
      if (rawTabs is List) {
        final tabs = <PersistedWorkspaceTab>[
          for (final entry in rawTabs)
            if (entry is Map<String, Object?> && entry['id'] is String && entry['surfaceId'] is String)
              (id: entry['id']! as String, surfaceId: entry['surfaceId']! as String),
        ];
        return (tabs: tabs, activeId: decoded['activeId'] as String?);
      }

      // Legacy shape (pre-AP-OEP-WORKSPACE-MULTI-INSTANCE-001): a bare
      // surfaceId list, always one tab per surfaceId.
      final surfaces = (decoded['surfaces'] as List? ?? const []).whereType<String>().toList();
      final tabs = <PersistedWorkspaceTab>[
        for (final surfaceId in surfaces) (id: 'workspace-tab-$surfaceId', surfaceId: surfaceId),
      ];
      final legacyActiveSurfaceId = decoded['activeId'] as String?;
      final activeId = legacyActiveSurfaceId == null ? null : 'workspace-tab-$legacyActiveSurfaceId';
      return (tabs: tabs, activeId: activeId);
    } on FormatException {
      return (tabs: <PersistedWorkspaceTab>[], activeId: null);
    }
  }

  Future<void> save({required List<PersistedWorkspaceTab> tabs, required String? activeId}) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert({
      'tabs': [for (final tab in tabs) {'id': tab.id, 'surfaceId': tab.surfaceId}],
      'activeId': activeId,
    }));
  }
}
