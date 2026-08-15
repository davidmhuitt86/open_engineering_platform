import '../capability/capability.dart';

/// OIP-PLUGIN-001 §6/§7 — every plugin's required declarative metadata.
class PluginManifest {
  const PluginManifest({
    required this.pluginId,
    required this.displayName,
    required this.version,
    required this.author,
    required this.description,
    required this.supportedProtocolVersion,
    required this.supportedRuntimeVersion,
    required this.instrumentCategory,
    required this.capabilities,
    required this.entryPoint,
    this.dependencies = const [],
    this.icon,
    this.license,
  });

  final String pluginId;
  final String displayName;
  final String version;
  final String author;
  final String description;
  final String supportedProtocolVersion;
  final String supportedRuntimeVersion;

  /// OIP-PLUGIN-001 §7 — Measurement / Analysis / Diagnostics /
  /// Communication / Monitoring / future categories. Kept as a plain
  /// string, matching [Measurement.source]'s own reasoning: the
  /// Constitution requires future categories to register without
  /// editing this package.
  final String instrumentCategory;

  final List<Capability> capabilities;
  final List<String> dependencies;

  /// The plugin's own registration entry point identifier — how the
  /// Plugin Manager locates the concrete [InstrumentPlugin]
  /// implementation. A string (not a direct class reference) so this
  /// manifest stays a pure data value, serializable independent of the
  /// plugin's own Dart implementation being loaded yet (§9: "Discovered"
  /// precedes "Loaded").
  final String entryPoint;

  final String? icon;
  final String? license;

  Map<String, Object?> toJson() => {
        'pluginId': pluginId,
        'displayName': displayName,
        'version': version,
        'author': author,
        'description': description,
        'supportedProtocolVersion': supportedProtocolVersion,
        'supportedRuntimeVersion': supportedRuntimeVersion,
        'instrumentCategory': instrumentCategory,
        'capabilities': capabilities.map((c) => c.toJson()).toList(),
        'dependencies': dependencies,
        'entryPoint': entryPoint,
        if (icon != null) 'icon': icon,
        if (license != null) 'license': license,
      };
}
