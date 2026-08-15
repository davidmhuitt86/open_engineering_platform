import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/exchange/settings/exchange_settings.dart';
import 'package:oep_studio/exchange/settings/exchange_settings_storage.dart';

/// `ExchangeSettings` -- the Engineering Exchange's REST API address
/// (WP-EXC-010), mirroring `diagram_studio_settings_test.dart`'s own
/// coverage shape for the same kind of independently-persisted settings
/// object.
void main() {
  test('ExchangeSettings.defaults points at exchange-api\'s own default port and versioned prefix', () {
    const defaults = ExchangeSettings.defaults;
    expect(defaults.apiBaseUrl, 'http://127.0.0.1:3000/api/v1');
  });

  test('round-trips through JSON', () {
    const settings = ExchangeSettings(apiBaseUrl: 'http://example.test/api/v1');
    final restored = ExchangeSettings.fromJson(settings.toJson());
    expect(restored.apiBaseUrl, 'http://example.test/api/v1');
  });

  test('fromJson falls back to defaults for missing keys', () {
    final restored = ExchangeSettings.fromJson(const {});
    expect(restored.apiBaseUrl, ExchangeSettings.defaults.apiBaseUrl);
  });

  test('copyWith changes only the given field', () {
    const settings = ExchangeSettings();
    final updated = settings.copyWith(apiBaseUrl: 'http://other/api/v1');
    expect(updated.apiBaseUrl, 'http://other/api/v1');
  });

  test('ExchangeSettingsStorage save() then load() round-trips a real change', () async {
    final original = await ExchangeSettingsStorage.load();
    const probe = ExchangeSettings(apiBaseUrl: 'http://probe.test/api/v1');

    try {
      await ExchangeSettingsStorage.save(probe);
      final reloaded = await ExchangeSettingsStorage.load();
      expect(reloaded.apiBaseUrl, 'http://probe.test/api/v1');
    } finally {
      await ExchangeSettingsStorage.save(original);
    }
  });
}
