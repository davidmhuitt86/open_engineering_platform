import 'settings_enums.dart';

/// Settings > Security (SDD-023): "Credential Storage, Certificate
/// Management, Privacy, Encryption, Secure Storage." No credentials
/// exist anywhere in Studio yet (Work Package 016 shipped only a
/// no-credential Mock AI Provider), so `credentialStorageBackend` is
/// descriptive rather than backed by a real vault; `encryptionAtRest`
/// is an unwired placeholder. The Security page also displays a live,
/// truthful statement that no secrets are currently stored anywhere in
/// Studio — see `docs/STUDIO_SETTINGS.md`.
class SecuritySettings {
  const SecuritySettings({
    required this.credentialStorageBackend,
    required this.privacyModeEnabled,
    required this.encryptionAtRestEnabled,
  });

  factory SecuritySettings.defaults() => const SecuritySettings(
    credentialStorageBackend: CredentialStorageBackend.operatingSystem,
    privacyModeEnabled: false,
    encryptionAtRestEnabled: false,
  );

  final CredentialStorageBackend credentialStorageBackend;
  final bool privacyModeEnabled;
  final bool encryptionAtRestEnabled;

  SecuritySettings copyWith({
    CredentialStorageBackend? credentialStorageBackend,
    bool? privacyModeEnabled,
    bool? encryptionAtRestEnabled,
  }) {
    return SecuritySettings(
      credentialStorageBackend: credentialStorageBackend ?? this.credentialStorageBackend,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      encryptionAtRestEnabled: encryptionAtRestEnabled ?? this.encryptionAtRestEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'credentialStorageBackend': credentialStorageBackend.name,
    'privacyModeEnabled': privacyModeEnabled,
    'encryptionAtRestEnabled': encryptionAtRestEnabled,
  };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    final defaults = SecuritySettings.defaults();
    return SecuritySettings(
      credentialStorageBackend: CredentialStorageBackend.values.firstWhere(
        (value) => value.name == json['credentialStorageBackend'],
        orElse: () => defaults.credentialStorageBackend,
      ),
      privacyModeEnabled: json['privacyModeEnabled'] as bool? ?? defaults.privacyModeEnabled,
      encryptionAtRestEnabled: json['encryptionAtRestEnabled'] as bool? ?? defaults.encryptionAtRestEnabled,
    );
  }
}
