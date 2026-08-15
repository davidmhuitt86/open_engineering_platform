/// Engineering Acquisition's own persisted preferences (WP-PLAT-020) —
/// mirrors `DiagramStudioSettings`: deliberately **not** a sub-object of
/// `UserConfiguration`, persisted independently via
/// [AcquisitionSettingsStorage]. Currently just the REST API address;
/// future settings (e.g. request timeout) extend this class the same
/// way, without touching the Settings Workspace shell.
class AcquisitionSettings {
  final String apiBaseUrl;

  const AcquisitionSettings({this.apiBaseUrl = 'http://127.0.0.1:8080'});

  static const AcquisitionSettings defaults = AcquisitionSettings();

  AcquisitionSettings copyWith({String? apiBaseUrl}) =>
      AcquisitionSettings(apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl);

  Map<String, Object?> toJson() => {'apiBaseUrl': apiBaseUrl};

  factory AcquisitionSettings.fromJson(Map<String, Object?> json) => AcquisitionSettings(
        apiBaseUrl: json['apiBaseUrl'] as String? ?? defaults.apiBaseUrl,
      );
}
