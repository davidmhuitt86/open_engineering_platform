/// Diagram Studio's own persisted preferences (WORK_PACKAGE_024,
/// ENGINE-TASK-000108) — deliberately **not** a sub-object of
/// `UserConfiguration` (SDD-023's Knowledge-Studio-shaped settings
/// schema, versioned via `SettingsMigrationService`). Diagram Studio's
/// preferences are new-document *defaults* for Engine-owned `ViewState`
/// (grid/snap/guides visibility) — genuinely separate data with no
/// reason to share Knowledge Studio's schema-versioning lifecycle.
/// Persisted independently via [DiagramStudioSettingsStorage].
class DiagramStudioSettings {
  final bool defaultGridVisible;
  final bool defaultSnapEnabled;
  final bool defaultGuidesVisible;

  const DiagramStudioSettings({
    this.defaultGridVisible = true,
    this.defaultSnapEnabled = true,
    this.defaultGuidesVisible = true,
  });

  static const DiagramStudioSettings defaults = DiagramStudioSettings();

  DiagramStudioSettings copyWith({
    bool? defaultGridVisible,
    bool? defaultSnapEnabled,
    bool? defaultGuidesVisible,
  }) {
    return DiagramStudioSettings(
      defaultGridVisible: defaultGridVisible ?? this.defaultGridVisible,
      defaultSnapEnabled: defaultSnapEnabled ?? this.defaultSnapEnabled,
      defaultGuidesVisible: defaultGuidesVisible ?? this.defaultGuidesVisible,
    );
  }

  Map<String, Object?> toJson() => {
        'defaultGridVisible': defaultGridVisible,
        'defaultSnapEnabled': defaultSnapEnabled,
        'defaultGuidesVisible': defaultGuidesVisible,
      };

  factory DiagramStudioSettings.fromJson(Map<String, Object?> json) => DiagramStudioSettings(
        defaultGridVisible: json['defaultGridVisible'] as bool? ?? true,
        defaultSnapEnabled: json['defaultSnapEnabled'] as bool? ?? true,
        defaultGuidesVisible: json['defaultGuidesVisible'] as bool? ?? true,
      );
}
