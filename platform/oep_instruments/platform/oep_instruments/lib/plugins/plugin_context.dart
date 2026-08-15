import '../session/engineering_session.dart';

/// OIP-PLUGIN-001 §10 — what the Runtime provides an [InstrumentPlugin]
/// during [InstrumentPlugin.initialize]: "Host Connection, Current
/// Session, Configuration, Theme, Localization, Capability Information,
/// Available Services. The Plugin shall not establish Host connections
/// directly." — a plugin never reaches outside this context to obtain
/// any of these; the Runtime hands them in.
class PluginContext {
  const PluginContext({
    required this.hostId,
    required this.session,
    this.configuration = const {},
    this.theme,
    this.locale,
  });

  final String hostId;
  final EngineeringSession session;
  final Map<String, Object?> configuration;

  /// A theme identifier (e.g. `'dark'`) — kept as a plain string, not a
  /// Flutter `ThemeData`, so this context stays serializable/testable
  /// without pulling a full theme object through the Runtime layer; the
  /// plugin's own UI layer resolves the identifier to real theme data
  /// (OIP-DS-001's Design System governs what that resolution means).
  final String? theme;

  final String? locale;
}
