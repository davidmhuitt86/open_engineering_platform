import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/controllers/settings_controller.dart';
import 'package:oep_studio/settings/models/user_configuration.dart';

void main() {
  group('SettingsControllerState.isModified', () {
    test('is false when configuration matches savedConfiguration', () {
      final defaults = UserConfiguration.defaults();
      final state = SettingsControllerState(configuration: defaults, savedConfiguration: defaults, isLoading: false);
      expect(state.isModified, isFalse);
    });

    test('is true after a single field diverges from savedConfiguration', () {
      final saved = UserConfiguration.defaults();
      final draft = saved.copyWith(general: saved.general.copyWith(language: 'ja-JP'));
      final state = SettingsControllerState(configuration: draft, savedConfiguration: saved, isLoading: false);
      expect(state.isModified, isTrue);
    });

    test('returns to false once the draft matches savedConfiguration again', () {
      final saved = UserConfiguration.defaults();
      final draft = saved.copyWith(general: saved.general.copyWith(language: 'ja-JP'));
      final reverted = draft.copyWith(general: draft.general.copyWith(language: saved.general.language));
      final state = SettingsControllerState(configuration: reverted, savedConfiguration: saved, isLoading: false);
      expect(state.isModified, isFalse);
    });

    test('copyWith(clearError: true) removes a prior error message', () {
      final defaults = UserConfiguration.defaults();
      final state = SettingsControllerState(configuration: defaults, savedConfiguration: defaults, isLoading: false);
      final withError = state.copyWith(errorMessage: 'boom');
      expect(withError.errorMessage, 'boom');
      final cleared = withError.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });
  });
}
