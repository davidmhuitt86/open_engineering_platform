import 'capability_category.dart';

/// OIP-CAPABILITY-001 — a declarative description of a feature an
/// instrument supports (§4: "Capabilities describe support. They do not
/// describe implementation."). Never performs engineering work; the
/// Runtime never infers a capability that wasn't explicitly declared
/// (§2).
class Capability {
  const Capability({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.version,
    this.dependencies = const [],
  });

  /// Stable, globally-unique identifier (e.g. `'measurement.dcVoltage'`).
  final String id;

  final String displayName;
  final String description;
  final CapabilityCategory category;

  /// Independently versioned (§19) — backward-compatible evolution is
  /// preferred; a breaking change requires a new capability id/version,
  /// not silently redefining this one.
  final String version;

  /// Other [Capability.id]s this capability requires (§16 — e.g.
  /// Waveform Recording depends on Waveform Display). Declared
  /// explicitly; the Runtime never infers a dependency.
  final List<String> dependencies;

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'description': description,
        'category': category.name,
        'version': version,
        'dependencies': dependencies,
      };

  factory Capability.fromJson(Map<String, Object?> json) => Capability(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        description: json['description'] as String,
        category: CapabilityCategory.values.firstWhere((c) => c.name == json['category']),
        version: json['version'] as String,
        dependencies: (json['dependencies'] as List? ?? const []).cast<String>(),
      );

  @override
  bool operator ==(Object other) => other is Capability && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);
}
