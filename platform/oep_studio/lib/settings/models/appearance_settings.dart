import 'settings_enums.dart';

/// Settings > Appearance (SDD-023): "Theme, Accent Color, Density, Font
/// Size, Icon Size, Animations, Workspace Scaling."
///
/// Stored, validated, and versioned in full — but `StudioTheme` remains
/// Studio's single ratified dark theme (see
/// `lib/core/theme/studio_theme.dart`); these values do not yet change
/// what is rendered. See `docs/STUDIO_SETTINGS.md` Architectural
/// Observations.
class AppearanceSettings {
  const AppearanceSettings({
    required this.theme,
    required this.accentColorHex,
    required this.density,
    required this.fontSize,
    required this.iconSize,
    required this.animationsEnabled,
    required this.workspaceScaling,
  });

  factory AppearanceSettings.defaults() => const AppearanceSettings(
    theme: StudioThemePreference.dark,
    accentColorHex: '#3B82F6',
    density: UiDensity.comfortable,
    fontSize: 13,
    iconSize: 18,
    animationsEnabled: true,
    workspaceScaling: 1.0,
  );

  final StudioThemePreference theme;
  final String accentColorHex;
  final UiDensity density;
  final double fontSize;
  final double iconSize;
  final bool animationsEnabled;
  final double workspaceScaling;

  AppearanceSettings copyWith({
    StudioThemePreference? theme,
    String? accentColorHex,
    UiDensity? density,
    double? fontSize,
    double? iconSize,
    bool? animationsEnabled,
    double? workspaceScaling,
  }) {
    return AppearanceSettings(
      theme: theme ?? this.theme,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      density: density ?? this.density,
      fontSize: fontSize ?? this.fontSize,
      iconSize: iconSize ?? this.iconSize,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      workspaceScaling: workspaceScaling ?? this.workspaceScaling,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'accentColorHex': accentColorHex,
    'density': density.name,
    'fontSize': fontSize,
    'iconSize': iconSize,
    'animationsEnabled': animationsEnabled,
    'workspaceScaling': workspaceScaling,
  };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppearanceSettings.defaults();
    return AppearanceSettings(
      theme: StudioThemePreference.values.firstWhere(
        (value) => value.name == json['theme'],
        orElse: () => defaults.theme,
      ),
      accentColorHex: json['accentColorHex'] as String? ?? defaults.accentColorHex,
      density: UiDensity.values.firstWhere(
        (value) => value.name == json['density'],
        orElse: () => defaults.density,
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaults.fontSize,
      iconSize: (json['iconSize'] as num?)?.toDouble() ?? defaults.iconSize,
      animationsEnabled: json['animationsEnabled'] as bool? ?? defaults.animationsEnabled,
      workspaceScaling: (json['workspaceScaling'] as num?)?.toDouble() ?? defaults.workspaceScaling,
    );
  }
}
