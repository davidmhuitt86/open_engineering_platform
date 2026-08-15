import '../models/settings_exception.dart';
import '../models/user_configuration.dart';

/// Validates a [UserConfiguration] before it is ever persisted (Work
/// Package 017 STUDIO-TASK-000053; SDD-023 Validation: "Settings shall
/// be validated before persistence. Invalid values shall never be
/// written."). Pure — no I/O, mirroring
/// `EntityValidationService`/`ContextValidationService`'s own
/// pure-validation-service precedent.
///
/// Collects every violation rather than stopping at the first, so a
/// caller can report the complete list in one professional message.
abstract final class SettingsValidationService {
  static void validate(UserConfiguration config) {
    final problems = <String>[];

    if (config.general.language.trim().isEmpty) {
      problems.add('Language must not be empty.');
    }
    if (config.general.region.trim().isEmpty) {
      problems.add('Region must not be empty.');
    }

    if (config.appearance.fontSize < 8 || config.appearance.fontSize > 32) {
      problems.add('Font size must be between 8 and 32.');
    }
    if (config.appearance.iconSize < 12 || config.appearance.iconSize > 40) {
      problems.add('Icon size must be between 12 and 40.');
    }
    if (config.appearance.workspaceScaling < 0.5 || config.appearance.workspaceScaling > 2.0) {
      problems.add('Workspace scaling must be between 0.5 and 2.0.');
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(config.appearance.accentColorHex)) {
      problems.add('Accent color must be a 6-digit hex color (e.g. #3B82F6).');
    }

    if (config.knowledgeStudio.defaultZoom < 0.25 || config.knowledgeStudio.defaultZoom > 5.0) {
      problems.add('Knowledge Studio default zoom must be between 0.25 and 5.0.');
    }

    if (config.ai.temperature < 0.0 || config.ai.temperature > 2.0) {
      problems.add('AI temperature must be between 0.0 and 2.0.');
    }
    if (config.ai.timeoutSeconds < 1 || config.ai.timeoutSeconds > 600) {
      problems.add('AI timeout must be between 1 and 600 seconds.');
    }
    if (config.ai.contextWindowTokens < 1) {
      problems.add('AI context window must be a positive number of tokens.');
    }
    if (config.ai.providerId.trim().isEmpty) {
      problems.add('AI provider ID must not be empty.');
    }

    if (problems.isNotEmpty) {
      throw SettingsException('Invalid configuration: ${problems.join(' ')}');
    }
  }
}
