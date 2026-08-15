/// A Settings persistence/validation/migration failure (Work Package
/// 017 Error Handling: "Invalid configuration", "Corrupt
/// configuration", "Version mismatch", "Migration failure" — all
/// translated to this single exception type with a professional
/// message, mirroring `KnowledgeValidationException`'s own
/// one-type-many-messages precedent from Work Package 008 rather than
/// introducing a separate exception class per failure kind).
class SettingsException implements Exception {
  const SettingsException(this.message);

  final String message;

  @override
  String toString() => 'SettingsException: $message';
}
