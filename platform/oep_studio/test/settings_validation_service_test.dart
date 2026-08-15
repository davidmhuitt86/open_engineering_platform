import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/models/settings_exception.dart';
import 'package:oep_studio/settings/models/user_configuration.dart';
import 'package:oep_studio/settings/services/settings_validation_service.dart';

void main() {
  group('SettingsValidationService', () {
    test('the default configuration is always valid', () {
      expect(() => SettingsValidationService.validate(UserConfiguration.defaults()), returnsNormally);
    });

    test('an empty language is rejected', () {
      final config = UserConfiguration.defaults().copyWith(
        general: UserConfiguration.defaults().general.copyWith(language: ''),
      );
      expect(() => SettingsValidationService.validate(config), throwsA(isA<SettingsException>()));
    });

    test('an out-of-range font size is rejected', () {
      final config = UserConfiguration.defaults().copyWith(
        appearance: UserConfiguration.defaults().appearance.copyWith(fontSize: 999),
      );
      expect(() => SettingsValidationService.validate(config), throwsA(isA<SettingsException>()));
    });

    test('a malformed accent color hex is rejected', () {
      final config = UserConfiguration.defaults().copyWith(
        appearance: UserConfiguration.defaults().appearance.copyWith(accentColorHex: 'blue'),
      );
      expect(() => SettingsValidationService.validate(config), throwsA(isA<SettingsException>()));
    });

    test('an out-of-range AI temperature is rejected', () {
      final config = UserConfiguration.defaults().copyWith(ai: UserConfiguration.defaults().ai.copyWith(temperature: 5.0));
      expect(() => SettingsValidationService.validate(config), throwsA(isA<SettingsException>()));
    });

    test('an out-of-range AI timeout is rejected', () {
      final config = UserConfiguration.defaults().copyWith(
        ai: UserConfiguration.defaults().ai.copyWith(timeoutSeconds: 0),
      );
      expect(() => SettingsValidationService.validate(config), throwsA(isA<SettingsException>()));
    });

    test('multiple violations are reported together in one message', () {
      final config = UserConfiguration.defaults().copyWith(
        general: UserConfiguration.defaults().general.copyWith(language: '', region: ''),
      );
      try {
        SettingsValidationService.validate(config);
        fail('expected a SettingsException');
      } on SettingsException catch (error) {
        expect(error.message, contains('Language'));
        expect(error.message, contains('Region'));
      }
    });
  });
}
