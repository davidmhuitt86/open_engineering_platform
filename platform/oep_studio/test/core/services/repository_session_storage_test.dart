import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/repository_session_storage.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

import '../../support/isolated_settings_storage.dart';

/// "Persist the last-opened Repository across restarts" -- direct
/// product feedback. Isolated from the real `%APPDATA%/oep_studio`
/// directory via [useIsolatedSettingsStorage], the same seam every other
/// Studio persistence test in this codebase already uses.
void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = useIsolatedSettingsStorage();
  });

  test('load returns null when nothing has ever been recorded', () async {
    expect(await RepositorySessionStorage.load(), isNull);
  });

  test('recordOpened then load round-trips the same path, when it still exists on disk', () async {
    final repoDir = Directory('${tempRoot.path}${Platform.pathSeparator}MyEngineeringRepository')
      ..createSync(recursive: true);

    await RepositorySessionStorage.recordOpened(repoDir.path);

    expect(await RepositorySessionStorage.load(), repoDir.path);
  });

  test('load returns null for a recorded path whose directory no longer exists', () async {
    final missingPath = '${tempRoot.path}${Platform.pathSeparator}DeletedRepository';
    await RepositorySessionStorage.recordOpened(missingPath);

    expect(await RepositorySessionStorage.load(), isNull);
  });

  test('recordOpened overwrites a previously recorded path', () async {
    final first = Directory('${tempRoot.path}${Platform.pathSeparator}First')..createSync();
    final second = Directory('${tempRoot.path}${Platform.pathSeparator}Second')..createSync();

    await RepositorySessionStorage.recordOpened(first.path);
    await RepositorySessionStorage.recordOpened(second.path);

    expect(await RepositorySessionStorage.load(), second.path);
  });

  test('load tolerates a corrupted settings file', () async {
    await SettingsStorage.root().create(recursive: true);
    final file = File('${SettingsStorage.root().path}${Platform.pathSeparator}last_repository.json');
    await file.writeAsString('{not valid json');

    expect(await RepositorySessionStorage.load(), isNull);
  });
}
