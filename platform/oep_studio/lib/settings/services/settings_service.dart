import 'dart:convert';

import '../models/settings_exception.dart';
import '../models/user_configuration.dart';
import 'settings_migration_service.dart';
import 'settings_storage.dart';
import 'settings_validation_service.dart';

/// Orchestrates User Configuration persistence (Work Package 017
/// STUDIO-TASK-000053): [SettingsStorage] (I/O) + [SettingsMigrationService]
/// (pure) + [SettingsValidationService] (pure), the same
/// storage/cache/validation-split-into-pure-services-plus-one-I/O-orchestrator
/// shape Work Package 013's OCR pipeline established. Widgets and the
/// `SettingsController` never touch [SettingsStorage] directly.
abstract final class SettingsService {
  /// Loads the User Configuration, or [UserConfiguration.defaults] on a
  /// fresh install (no settings file yet). Runs the raw JSON through
  /// [SettingsMigrationService] first; if migration actually changed
  /// anything, the migrated file is written straight back so migration
  /// only ever runs once per file.
  static Future<UserConfiguration> load() async {
    final raw = await SettingsStorage.readRaw();
    if (raw == null) return UserConfiguration.defaults();
    final migration = SettingsMigrationService.migrate(raw);
    final config = UserConfiguration.fromJson(migration.json);
    if (migration.migrated) {
      await SettingsStorage.writeRaw(config.toJson());
    }
    return config;
  }

  /// Validates, then persists, [config]. Throws [SettingsException]
  /// (translated from [SettingsValidationService]) without writing
  /// anything if [config] is invalid — SDD-023 Validation: "Invalid
  /// values shall never be written."
  static Future<void> save(UserConfiguration config) async {
    SettingsValidationService.validate(config);
    await SettingsStorage.writeRaw(config.toJson());
  }

  /// Persists and returns [UserConfiguration.defaults] (SDD-023 Import
  /// / Export: "Reset to Defaults").
  static Future<UserConfiguration> resetToDefaults() async {
    final defaults = UserConfiguration.defaults();
    await save(defaults);
    return defaults;
  }

  /// Serializes [config] for "Export User Settings" (SDD-023 Import /
  /// Export). No sub-model of [UserConfiguration] carries a credential
  /// field, so this export is always secret-free by construction —
  /// SDD-023 Security: "Secrets shall never be exported" / this work
  /// package's own "Do not store secrets in exported configuration."
  static String exportToJson(UserConfiguration config) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config.toJson());
  }

  /// Parses, migrates, and validates an "Import User Settings" source
  /// string. Does **not** save on its own — importing and saving are
  /// separate actions, mirroring SDD-023 listing them as distinct
  /// Import/Export operations; the caller decides whether to call
  /// [save] with the result.
  static UserConfiguration importFromJson(String source) {
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(source);
      if (parsed is! Map<String, dynamic>) {
        throw const SettingsException('The imported settings file is not valid.');
      }
      decoded = parsed;
    } on FormatException catch (error) {
      throw SettingsException('The imported settings file is not valid JSON (${error.message}).');
    }
    final migration = SettingsMigrationService.migrate(decoded);
    final config = UserConfiguration.fromJson(migration.json);
    SettingsValidationService.validate(config);
    return config;
  }
}
