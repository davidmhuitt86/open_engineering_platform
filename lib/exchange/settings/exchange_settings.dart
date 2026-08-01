/// Engineering Exchange's own persisted preferences (WP-EXC-010) --
/// mirrors `AcquisitionSettings` exactly: deliberately **not** a
/// sub-object of `UserConfiguration`, persisted independently via
/// [ExchangeSettingsStorage]. Currently just the REST API address;
/// future settings extend this class the same way, without touching the
/// Settings Workspace shell. Defaults to `exchange-api`'s own default
/// port (`apps/exchange-api/src/server.ts`: `PORT ?? 3000`) plus its
/// versioned route prefix (`packages/api-contracts/src/version.ts`:
/// `EXCHANGE_API_VERSION = 'v1'`).
class ExchangeSettings {
  final String apiBaseUrl;

  const ExchangeSettings({this.apiBaseUrl = 'http://127.0.0.1:3000/api/v1'});

  static const ExchangeSettings defaults = ExchangeSettings();

  ExchangeSettings copyWith({String? apiBaseUrl}) => ExchangeSettings(apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl);

  Map<String, Object?> toJson() => {'apiBaseUrl': apiBaseUrl};

  factory ExchangeSettings.fromJson(Map<String, Object?> json) => ExchangeSettings(
        apiBaseUrl: json['apiBaseUrl'] as String? ?? defaults.apiBaseUrl,
      );
}
