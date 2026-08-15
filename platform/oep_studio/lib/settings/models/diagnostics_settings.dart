/// Settings > Diagnostics (SDD-023): "Logging, Performance, Memory,
/// GPU, Foundation Runtime, Studio Runtime, Reset Studio." The Logging
/// level itself lives on [GeneralSettings] (SDD-023 lists "Logging"
/// under General too) and is only *displayed* here; Performance/Memory/
/// GPU monitoring are unwired placeholder toggles (no telemetry
/// collector exists yet); Foundation Runtime/Studio Runtime are live,
/// read-only information sourced directly from the Connection Manager
/// on the Diagnostics page, not stored here; "Reset Studio" is a
/// placeholder control (see `docs/STUDIO_SETTINGS.md`) since resetting
/// all local Studio state is a destructive, irreversible action out of
/// this work package's scope.
class DiagnosticsSettings {
  const DiagnosticsSettings({
    required this.performanceMonitoringEnabled,
    required this.memoryMonitoringEnabled,
    required this.gpuMonitoringEnabled,
  });

  factory DiagnosticsSettings.defaults() => const DiagnosticsSettings(
    performanceMonitoringEnabled: false,
    memoryMonitoringEnabled: false,
    gpuMonitoringEnabled: false,
  );

  final bool performanceMonitoringEnabled;
  final bool memoryMonitoringEnabled;
  final bool gpuMonitoringEnabled;

  DiagnosticsSettings copyWith({
    bool? performanceMonitoringEnabled,
    bool? memoryMonitoringEnabled,
    bool? gpuMonitoringEnabled,
  }) {
    return DiagnosticsSettings(
      performanceMonitoringEnabled: performanceMonitoringEnabled ?? this.performanceMonitoringEnabled,
      memoryMonitoringEnabled: memoryMonitoringEnabled ?? this.memoryMonitoringEnabled,
      gpuMonitoringEnabled: gpuMonitoringEnabled ?? this.gpuMonitoringEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'performanceMonitoringEnabled': performanceMonitoringEnabled,
    'memoryMonitoringEnabled': memoryMonitoringEnabled,
    'gpuMonitoringEnabled': gpuMonitoringEnabled,
  };

  factory DiagnosticsSettings.fromJson(Map<String, dynamic> json) {
    final defaults = DiagnosticsSettings.defaults();
    return DiagnosticsSettings(
      performanceMonitoringEnabled: json['performanceMonitoringEnabled'] as bool? ?? defaults.performanceMonitoringEnabled,
      memoryMonitoringEnabled: json['memoryMonitoringEnabled'] as bool? ?? defaults.memoryMonitoringEnabled,
      gpuMonitoringEnabled: json['gpuMonitoringEnabled'] as bool? ?? defaults.gpuMonitoringEnabled,
    );
  }
}
