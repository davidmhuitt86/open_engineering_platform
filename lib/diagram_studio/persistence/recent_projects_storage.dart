import 'dart:convert';
import 'dart:io';

import '../../settings/services/settings_storage.dart';

/// One Most-Recently-Used entry for a repository-backed Engineering
/// Project (AP-DS-002). Unlike [RecentFilesStorage]'s local file paths,
/// a repository-backed project has no filesystem path — it is only
/// addressable as (repository identity, Project object id), so both are
/// recorded here.
class RecentProjectEntry {
  const RecentProjectEntry({
    required this.repositoryId,
    required this.repositoryName,
    required this.projectObjectId,
    required this.projectName,
    required this.lastOpenedUtc,
  });

  factory RecentProjectEntry.fromJson(Map<String, Object?> json) {
    return RecentProjectEntry(
      repositoryId: json['repositoryId'] as String? ?? '',
      repositoryName: json['repositoryName'] as String? ?? '',
      projectObjectId: json['projectObjectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      lastOpenedUtc: json['lastOpenedUtc'] as String? ?? '',
    );
  }

  /// Identifies which repository the project lives in (Repository
  /// Identity, per the spec's Project Browser section) — distinct
  /// projects in different repositories may share an object id, so
  /// [repositoryId] + [projectObjectId] together is the real key.
  final String repositoryId;
  final String repositoryName;

  /// The Engineering Object id of the Project object (Project Identity).
  final String projectObjectId;
  final String projectName;

  /// ISO-8601 UTC timestamp of the most recent open/save.
  final String lastOpenedUtc;

  Map<String, Object?> toJson() => {
        'repositoryId': repositoryId,
        'repositoryName': repositoryName,
        'projectObjectId': projectObjectId,
        'projectName': projectName,
        'lastOpenedUtc': lastOpenedUtc,
      };

  /// Identity used for de-duplication: same repository + same project.
  String get key => '$repositoryId::$projectObjectId';
}

/// Tracks the last N opened/saved repository-backed Engineering Projects
/// (AP-DS-002, Project Browser / Recent Projects). Mirrors
/// [RecentFilesStorage]'s persistence convention exactly — one JSON file
/// under `SettingsStorage.root()` — but keys entries by (repository id,
/// Project object id) instead of a local file path, since repository-
/// backed projects have no filesystem path.
abstract final class RecentProjectsStorage {
  static const int maxEntries = 10;

  static File _file() => File(
        '${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_recent_projects.json',
      );

  /// Returns recent projects, most-recently-used first. Unlike
  /// [RecentFilesStorage], entries are not pruned against live
  /// repository state here — callers (the Project Browser) are
  /// responsible for marking entries unreachable if the repository
  /// isn't currently open, since checking that requires the Foundation
  /// Bridge, which this storage class deliberately never touches.
  static Future<List<RecentProjectEntry>> load() async {
    final file = _file();
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return const [];
      final rawList = decoded['projects'];
      if (rawList is! List) return const [];
      return rawList
          .whereType<Map<String, Object?>>()
          .map(RecentProjectEntry.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  /// Records [entry] as the most-recently-used project, evicting any
  /// existing entry with the same [RecentProjectEntry.key] and trimming
  /// to [maxEntries].
  static Future<List<RecentProjectEntry>> recordOpened(RecentProjectEntry entry) async {
    final existing = await load();
    final updated = [entry, ...existing.where((e) => e.key != entry.key)];
    final trimmed = updated.take(maxEntries).toList(growable: false);
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(
      encoder.convert({'projects': [for (final e in trimmed) e.toJson()]}),
    );
    return trimmed;
  }

  /// Removes the entry matching [key] (e.g. a project the user chose to
  /// clear from the list, or one Migration replaced with a
  /// repository-backed equivalent).
  static Future<List<RecentProjectEntry>> remove(String key) async {
    final existing = await load();
    final trimmed = existing.where((e) => e.key != key).toList(growable: false);
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(
      encoder.convert({'projects': [for (final e in trimmed) e.toJson()]}),
    );
    return trimmed;
  }
}
