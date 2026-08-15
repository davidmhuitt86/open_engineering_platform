import 'settings_enums.dart';

/// Settings > General (SDD-023): "Language, Region, Units, Date Format,
/// Time Format, Autosave, Startup Behavior, Logging."
class GeneralSettings {
  const GeneralSettings({
    required this.language,
    required this.region,
    required this.units,
    required this.dateFormat,
    required this.timeFormat,
    required this.autosave,
    required this.startupBehavior,
    required this.logging,
  });

  factory GeneralSettings.defaults() => const GeneralSettings(
    language: 'en-US',
    region: 'US',
    units: UnitSystem.metric,
    dateFormat: DateFormatPreference.iso8601,
    timeFormat: TimeFormatPreference.h24,
    autosave: true,
    startupBehavior: StartupBehaviorPreference.showDashboard,
    logging: LoggingLevel.info,
  );

  final String language;
  final String region;
  final UnitSystem units;
  final DateFormatPreference dateFormat;
  final TimeFormatPreference timeFormat;
  final bool autosave;
  final StartupBehaviorPreference startupBehavior;
  final LoggingLevel logging;

  GeneralSettings copyWith({
    String? language,
    String? region,
    UnitSystem? units,
    DateFormatPreference? dateFormat,
    TimeFormatPreference? timeFormat,
    bool? autosave,
    StartupBehaviorPreference? startupBehavior,
    LoggingLevel? logging,
  }) {
    return GeneralSettings(
      language: language ?? this.language,
      region: region ?? this.region,
      units: units ?? this.units,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      autosave: autosave ?? this.autosave,
      startupBehavior: startupBehavior ?? this.startupBehavior,
      logging: logging ?? this.logging,
    );
  }

  Map<String, dynamic> toJson() => {
    'language': language,
    'region': region,
    'units': units.name,
    'dateFormat': dateFormat.name,
    'timeFormat': timeFormat.name,
    'autosave': autosave,
    'startupBehavior': startupBehavior.name,
    'logging': logging.name,
  };

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    final defaults = GeneralSettings.defaults();
    return GeneralSettings(
      language: json['language'] as String? ?? defaults.language,
      region: json['region'] as String? ?? defaults.region,
      units: UnitSystem.values.firstWhere(
        (value) => value.name == json['units'],
        orElse: () => defaults.units,
      ),
      dateFormat: DateFormatPreference.values.firstWhere(
        (value) => value.name == json['dateFormat'],
        orElse: () => defaults.dateFormat,
      ),
      timeFormat: TimeFormatPreference.values.firstWhere(
        (value) => value.name == json['timeFormat'],
        orElse: () => defaults.timeFormat,
      ),
      autosave: json['autosave'] as bool? ?? defaults.autosave,
      startupBehavior: StartupBehaviorPreference.values.firstWhere(
        (value) => value.name == json['startupBehavior'],
        orElse: () => defaults.startupBehavior,
      ),
      logging: LoggingLevel.values.firstWhere(
        (value) => value.name == json['logging'],
        orElse: () => defaults.logging,
      ),
    );
  }
}
