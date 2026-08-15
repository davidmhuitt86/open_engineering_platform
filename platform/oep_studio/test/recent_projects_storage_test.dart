import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/persistence/recent_projects_storage.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// `RecentProjectsStorage` (AP-DS-002, "Recent Projects") against the
/// real `%APPDATA%/oep_studio/` file it shares with `WorkspaceStateStorage`
/// and `RecentFilesStorage` — same real-file-with-cleanup convention as
/// `recent_files_storage_test.dart`.
void main() {
  File storageFile() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_recent_projects.json');

  RecentProjectEntry entry(String id, {String repo = 'repo-a'}) => RecentProjectEntry(
        repositoryId: repo,
        repositoryName: repo,
        projectObjectId: id,
        projectName: 'Project $id',
        lastOpenedUtc: '2026-08-01T00:00:00Z',
      );

  tearDown(() async {
    final file = storageFile();
    if (file.existsSync()) await file.delete();
  });

  test('load() returns empty list when nothing has been recorded', () async {
    expect(await RecentProjectsStorage.load(), isEmpty);
  });

  test('recordOpened() puts the newest project first and dedupes by repository + object id', () async {
    await RecentProjectsStorage.recordOpened(entry('p1'));
    await RecentProjectsStorage.recordOpened(entry('p2'));
    await RecentProjectsStorage.recordOpened(entry('p1'));

    final recent = await RecentProjectsStorage.load();

    expect(recent.map((e) => e.projectObjectId), ['p1', 'p2']);
  });

  test('same project object id in a different repository is a distinct entry', () async {
    await RecentProjectsStorage.recordOpened(entry('p1', repo: 'repo-a'));
    await RecentProjectsStorage.recordOpened(entry('p1', repo: 'repo-b'));

    final recent = await RecentProjectsStorage.load();

    expect(recent, hasLength(2));
    expect(recent.map((e) => e.repositoryId), containsAll(['repo-a', 'repo-b']));
  });

  test('recordOpened() trims to maxEntries', () async {
    for (var i = 0; i < RecentProjectsStorage.maxEntries + 3; i++) {
      await RecentProjectsStorage.recordOpened(entry('p$i'));
    }

    final recent = await RecentProjectsStorage.load();

    expect(recent.length, RecentProjectsStorage.maxEntries);
    expect(recent.first.projectObjectId, 'p${RecentProjectsStorage.maxEntries + 2}');
  });

  test('remove() drops the matching entry only', () async {
    await RecentProjectsStorage.recordOpened(entry('p1'));
    await RecentProjectsStorage.recordOpened(entry('p2'));

    final remaining = await RecentProjectsStorage.remove(entry('p1').key);

    expect(remaining.map((e) => e.projectObjectId), ['p2']);
  });
}
