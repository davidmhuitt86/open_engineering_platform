import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/models/settings_exception.dart';
import 'package:oep_studio/settings/models/user_configuration.dart';
import 'package:oep_studio/settings/services/settings_service.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// Exercises real `dart:io` file access against
/// `%APPDATA%/oep_studio/settings.json` — mirroring
/// `knowledge_session_storage_test.dart`'s own precedent (Work Package
/// 008) of testing against the real path rather than an injected temp
/// directory. Unlike Knowledge Sessions (one directory per session,
/// each safely disposable), User Configuration is a *single* shared
/// file, so this suite backs up whatever is there before each test and
/// restores it afterward, leaving the machine exactly as it found it.
void main() {
  late File settingsFile;
  String? backupContents;

  setUp(() {
    settingsFile = File('${SettingsStorage.root().path}${Platform.pathSeparator}settings.json');
    backupContents = settingsFile.existsSync() ? settingsFile.readAsStringSync() : null;
  });

  tearDown(() async {
    if (backupContents == null) {
      if (settingsFile.existsSync()) await settingsFile.delete();
    } else {
      await settingsFile.parent.create(recursive: true);
      await settingsFile.writeAsString(backupContents!);
    }
  });

  group('SettingsService', () {
    test('load() returns defaults on a fresh install (no settings file)', () async {
      if (settingsFile.existsSync()) await settingsFile.delete();
      final config = await SettingsService.load();
      expect(config.general.language, UserConfiguration.defaults().general.language);
    });

    test('save() then load() round-trips a real change', () async {
      final defaults = UserConfiguration.defaults();
      final changed = defaults.copyWith(general: defaults.general.copyWith(language: 'de-DE', autosave: false));
      await SettingsService.save(changed);

      final reloaded = await SettingsService.load();
      expect(reloaded.general.language, 'de-DE');
      expect(reloaded.general.autosave, isFalse);
    });

    test('save() rejects an invalid configuration and writes nothing', () async {
      if (settingsFile.existsSync()) await settingsFile.delete();
      final invalid = UserConfiguration.defaults().copyWith(
        appearance: UserConfiguration.defaults().appearance.copyWith(fontSize: 999),
      );
      await expectLater(SettingsService.save(invalid), throwsA(isA<SettingsException>()));
      expect(settingsFile.existsSync(), isFalse);
    });

    test('resetToDefaults() persists and returns UserConfiguration.defaults()', () async {
      final defaults = UserConfiguration.defaults();
      final changed = defaults.copyWith(general: defaults.general.copyWith(language: 'fr-FR'));
      await SettingsService.save(changed);

      final reset = await SettingsService.resetToDefaults();
      expect(reset.general.language, defaults.general.language);

      final reloaded = await SettingsService.load();
      expect(reloaded.general.language, defaults.general.language);
    });

    test('exportToJson never contains a secret value or credential field', () {
      // `security.credentialStorageBackend` (descriptive enum) and
      // `ai.contextWindowTokens` (a token *count*, not an auth token)
      // are legitimate field names excluded from this ban; everything
      // else that would suggest an actual stored secret must not appear.
      final json = SettingsService.exportToJson(UserConfiguration.defaults()).toLowerCase();
      for (final forbidden in ['apikey', 'api_key', 'password', 'secret']) {
        expect(json, isNot(contains(forbidden)));
      }
    });

    test('importFromJson parses, migrates, and validates without saving', () async {
      if (settingsFile.existsSync()) await settingsFile.delete();
      final exported = SettingsService.exportToJson(
        UserConfiguration.defaults().copyWith(
          general: UserConfiguration.defaults().general.copyWith(language: 'ja-JP'),
        ),
      );
      final imported = SettingsService.importFromJson(exported);
      expect(imported.general.language, 'ja-JP');
      // Nothing was written to disk by import alone.
      expect(settingsFile.existsSync(), isFalse);
    });

    test('importFromJson rejects malformed JSON', () {
      expect(() => SettingsService.importFromJson('{not valid json'), throwsA(isA<SettingsException>()));
    });

    test('a corrupted settings file surfaces a professional SettingsException on load()', () async {
      await settingsFile.parent.create(recursive: true);
      await settingsFile.writeAsString('{not valid json');
      await expectLater(SettingsService.load(), throwsA(isA<SettingsException>()));
    });
  });
}
