import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/models/ai_settings.dart';
import 'package:oep_studio/settings/models/settings_exception.dart';
import 'package:oep_studio/settings/models/user_configuration.dart';
import 'package:oep_studio/settings/services/settings_migration_service.dart';

void main() {
  group('SettingsMigrationService', () {
    test('a file with no schemaVersion key is treated as schema 0 and upgraded', () {
      final result = SettingsMigrationService.migrate({
        'general': {'language': 'de-DE'},
      });

      expect(result.migrated, isTrue);
      expect(result.fromSchemaVersion, 0);
      expect(result.json['schemaVersion'], UserConfiguration.currentSchemaVersion);
      // The legacy value survives the upgrade.
      expect((result.json['general'] as Map<String, dynamic>)['language'], 'de-DE');
      // Every other top-level section was backfilled so `fromJson` can
      // apply its own per-field defaults.
      for (final section in [
        'appearance',
        'workspace',
        'repository',
        'knowledgeStudio',
        'ai',
        'plugins',
        'updates',
        'diagnostics',
        'security',
      ]) {
        expect(result.json.containsKey(section), isTrue, reason: 'missing section: $section');
      }
    });

    test('a file already at the current schema version passes through unmigrated', () {
      final json = UserConfiguration.defaults().toJson();
      final result = SettingsMigrationService.migrate(json);

      expect(result.migrated, isFalse);
      expect(result.fromSchemaVersion, UserConfiguration.currentSchemaVersion);
      expect(result.json['schemaVersion'], UserConfiguration.currentSchemaVersion);
    });

    test('a schemaVersion newer than this build throws a version-mismatch SettingsException', () {
      expect(
        () => SettingsMigrationService.migrate({'schemaVersion': UserConfiguration.currentSchemaVersion + 1}),
        throwsA(isA<SettingsException>()),
      );
    });

    test('a non-integer schemaVersion is treated as corrupt configuration', () {
      expect(() => SettingsMigrationService.migrate({'schemaVersion': 'not-a-number'}), throwsA(isA<SettingsException>()));
    });

    test('a schema-1 file predating maxOutputTokens is upgraded to schema 2 with the default backfilled', () {
      final result = SettingsMigrationService.migrate({
        'schemaVersion': 1,
        'ai': {'providerId': 'anthropic', 'modelId': 'claude-legacy'},
      });

      expect(result.migrated, isTrue);
      expect(result.fromSchemaVersion, 1);
      expect(result.json['schemaVersion'], 2);
      final ai = result.json['ai'] as Map<String, dynamic>;
      expect(ai['providerId'], 'anthropic'); // the legacy value survives
      expect(ai['modelId'], 'claude-legacy');
      expect(ai['maxOutputTokens'], isNotNull); // backfilled

      final config = UserConfiguration.fromJson(result.json);
      expect(config.ai.providerId, 'anthropic');
      expect(config.ai.maxOutputTokens, AiSettings.defaults().maxOutputTokens);
    });

    test('parsing the migrated JSON with UserConfiguration.fromJson produces a valid configuration', () {
      final result = SettingsMigrationService.migrate({
        'general': {'language': 'fr-FR', 'autosave': false},
      });
      final config = UserConfiguration.fromJson(result.json);

      expect(config.general.language, 'fr-FR');
      expect(config.general.autosave, isFalse);
      // Untouched sections fell back to defaults.
      expect(config.appearance.theme, UserConfiguration.defaults().appearance.theme);
    });
  });
}
