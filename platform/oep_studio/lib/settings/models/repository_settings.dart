import 'settings_enums.dart';

/// Settings > Repository (SDD-023): "Default Repository, Auto-open,
/// Backup, Snapshots, Cache, Validation Defaults." Repository-scoped
/// settings (SDD-023 Repository Configuration: settings that apply to
/// one repository, stored with the repository) are explicitly out of
/// scope for this work package — this model holds only the *User
/// Configuration*-scoped defaults SDD-023 lists under this page
/// (a default repository path to auto-open, and preference toggles),
/// never per-repository data.
class RepositorySettings {
  const RepositorySettings({
    required this.defaultRepositoryPath,
    required this.autoOpenDefaultRepository,
    required this.backupEnabled,
    required this.snapshotsEnabled,
    required this.cacheEnabled,
    required this.validationStrictness,
  });

  factory RepositorySettings.defaults() => const RepositorySettings(
    defaultRepositoryPath: '',
    autoOpenDefaultRepository: false,
    backupEnabled: false,
    snapshotsEnabled: false,
    cacheEnabled: true,
    validationStrictness: ValidationStrictness.standard,
  );

  final String defaultRepositoryPath;
  final bool autoOpenDefaultRepository;
  final bool backupEnabled;
  final bool snapshotsEnabled;
  final bool cacheEnabled;
  final ValidationStrictness validationStrictness;

  RepositorySettings copyWith({
    String? defaultRepositoryPath,
    bool? autoOpenDefaultRepository,
    bool? backupEnabled,
    bool? snapshotsEnabled,
    bool? cacheEnabled,
    ValidationStrictness? validationStrictness,
  }) {
    return RepositorySettings(
      defaultRepositoryPath: defaultRepositoryPath ?? this.defaultRepositoryPath,
      autoOpenDefaultRepository: autoOpenDefaultRepository ?? this.autoOpenDefaultRepository,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      snapshotsEnabled: snapshotsEnabled ?? this.snapshotsEnabled,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      validationStrictness: validationStrictness ?? this.validationStrictness,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultRepositoryPath': defaultRepositoryPath,
    'autoOpenDefaultRepository': autoOpenDefaultRepository,
    'backupEnabled': backupEnabled,
    'snapshotsEnabled': snapshotsEnabled,
    'cacheEnabled': cacheEnabled,
    'validationStrictness': validationStrictness.name,
  };

  factory RepositorySettings.fromJson(Map<String, dynamic> json) {
    final defaults = RepositorySettings.defaults();
    return RepositorySettings(
      defaultRepositoryPath: json['defaultRepositoryPath'] as String? ?? defaults.defaultRepositoryPath,
      autoOpenDefaultRepository: json['autoOpenDefaultRepository'] as bool? ?? defaults.autoOpenDefaultRepository,
      backupEnabled: json['backupEnabled'] as bool? ?? defaults.backupEnabled,
      snapshotsEnabled: json['snapshotsEnabled'] as bool? ?? defaults.snapshotsEnabled,
      cacheEnabled: json['cacheEnabled'] as bool? ?? defaults.cacheEnabled,
      validationStrictness: ValidationStrictness.values.firstWhere(
        (value) => value.name == json['validationStrictness'],
        orElse: () => defaults.validationStrictness,
      ),
    );
  }
}
