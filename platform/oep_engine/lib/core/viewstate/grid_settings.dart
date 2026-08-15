/// Configurable grid + snap settings (WORK_PACKAGE_022,
/// ENGINE-TASK-000090). Part of [ViewState] — runtime visualization
/// preference, never Engineering Knowledge and never Diagram Layout.
class GridSettings {
  /// Distance between minor grid lines, in scene units.
  final double spacing;

  /// Every Nth minor line is drawn as a major line (e.g. 5 → every 5th).
  final int majorEvery;

  final bool visible;
  final bool snapEnabled;

  const GridSettings({
    this.spacing = 20,
    this.majorEvery = 5,
    this.visible = true,
    this.snapEnabled = true,
  });

  GridSettings copyWith({
    double? spacing,
    int? majorEvery,
    bool? visible,
    bool? snapEnabled,
  }) {
    return GridSettings(
      spacing: spacing ?? this.spacing,
      majorEvery: majorEvery ?? this.majorEvery,
      visible: visible ?? this.visible,
      snapEnabled: snapEnabled ?? this.snapEnabled,
    );
  }

  Map<String, Object?> toJson() => {
        'spacing': spacing,
        'majorEvery': majorEvery,
        'visible': visible,
        'snapEnabled': snapEnabled,
      };

  factory GridSettings.fromJson(Map<String, Object?> json) => GridSettings(
        spacing: (json['spacing'] as num?)?.toDouble() ?? 20,
        majorEvery: (json['majorEvery'] as num?)?.toInt() ?? 5,
        visible: json['visible'] as bool? ?? true,
        snapEnabled: json['snapEnabled'] as bool? ?? true,
      );
}
