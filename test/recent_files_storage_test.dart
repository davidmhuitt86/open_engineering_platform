import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/persistence/recent_files_storage.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// `RecentFilesStorage` against the real `%APPDATA%/oep_studio/` file it
/// shares with `WorkspaceStateStorage` (AP-DS-001A Documents review) —
/// same real-file-with-cleanup convention as
/// `diagram_workspace_state_test.dart`.
void main() {
  late Directory tempDir;
  late File recentA;
  late File recentB;

  File storageFile() =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_recent_files.json');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('recent_files_storage_test_');
    recentA = File('${tempDir.path}/a.json')..writeAsStringSync('{}');
    recentB = File('${tempDir.path}/b.json')..writeAsStringSync('{}');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final file = storageFile();
    if (file.existsSync()) await file.delete();
  });

  test('load() returns empty list when nothing has been recorded', () async {
    expect(await RecentFilesStorage.load(), isEmpty);
  });

  test('recordOpened() puts the newest path first and dedupes', () async {
    await RecentFilesStorage.recordOpened(recentA.path);
    await RecentFilesStorage.recordOpened(recentB.path);
    await RecentFilesStorage.recordOpened(recentA.path);

    final recent = await RecentFilesStorage.load();

    expect(recent, [recentA.path, recentB.path]);
  });

  test('load() drops entries whose file no longer exists on disk', () async {
    await RecentFilesStorage.recordOpened(recentA.path);
    await recentA.delete();

    expect(await RecentFilesStorage.load(), isEmpty);
  });

  test('recordOpened() trims to maxEntries', () async {
    final files = List.generate(RecentFilesStorage.maxEntries + 3, (index) {
      final file = File('${tempDir.path}/f$index.json')..writeAsStringSync('{}');
      return file;
    });
    for (final file in files) {
      await RecentFilesStorage.recordOpened(file.path);
    }

    final recent = await RecentFilesStorage.load();

    expect(recent.length, RecentFilesStorage.maxEntries);
    expect(recent.first, files.last.path);
  });
}
