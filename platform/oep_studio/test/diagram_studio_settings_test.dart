import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/settings/diagram_studio_settings.dart';
import 'package:oep_studio/diagram_studio/settings/diagram_studio_settings_storage.dart';

/// `DiagramStudioSettings` — new-document ViewState defaults
/// (WORK_PACKAGE_024, ENGINE-TASK-000108), persisted independently of
/// `UserConfiguration` (see `docs/WORKSPACE_INTEGRATION.md` for why).
void main() {
  test('DiagramStudioSettings.defaults has grid/snap/guides all on', () {
    const defaults = DiagramStudioSettings.defaults;
    expect(defaults.defaultGridVisible, isTrue);
    expect(defaults.defaultSnapEnabled, isTrue);
    expect(defaults.defaultGuidesVisible, isTrue);
  });

  test('round-trips through JSON', () {
    const settings = DiagramStudioSettings(
      defaultGridVisible: false,
      defaultSnapEnabled: true,
      defaultGuidesVisible: false,
    );

    final restored = DiagramStudioSettings.fromJson(settings.toJson());

    expect(restored.defaultGridVisible, isFalse);
    expect(restored.defaultSnapEnabled, isTrue);
    expect(restored.defaultGuidesVisible, isFalse);
  });

  test('fromJson defaults missing keys to true', () {
    final restored = DiagramStudioSettings.fromJson(const {});
    expect(restored.defaultGridVisible, isTrue);
    expect(restored.defaultSnapEnabled, isTrue);
    expect(restored.defaultGuidesVisible, isTrue);
  });

  test('copyWith changes only the given field', () {
    const settings = DiagramStudioSettings();
    final updated = settings.copyWith(defaultGridVisible: false);
    expect(updated.defaultGridVisible, isFalse);
    expect(updated.defaultSnapEnabled, settings.defaultSnapEnabled);
    expect(updated.defaultGuidesVisible, settings.defaultGuidesVisible);
  });

  test('DiagramStudioSettingsStorage save() then load() round-trips a real change', () async {
    final original = await DiagramStudioSettingsStorage.load();
    const probe = DiagramStudioSettings(defaultGridVisible: false, defaultSnapEnabled: false);

    try {
      await DiagramStudioSettingsStorage.save(probe);
      final reloaded = await DiagramStudioSettingsStorage.load();
      expect(reloaded.defaultGridVisible, isFalse);
      expect(reloaded.defaultSnapEnabled, isFalse);
    } finally {
      await DiagramStudioSettingsStorage.save(original);
    }
  });
}
