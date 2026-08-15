import 'capability.dart';
import 'capability_category.dart';

/// OIP-CAPABILITY-001 §17/§18 — Capability Discovery and Negotiation.
///
/// One registry per instrument instance (an instrument's own declared
/// capability set), queried by the Runtime/Host to discover what an
/// instrument supports without needing instrument-specific knowledge
/// (§17: "Discovery shall require no instrument-specific knowledge.").
class CapabilityRegistry {
  final Map<String, Capability> _capabilities = {};

  List<Capability> get all => List.unmodifiable(_capabilities.values);

  /// Registers [capability]. Throws [StateError] on a duplicate id —
  /// registering under an existing id would silently redefine a
  /// capability rather than version it (§19), which this constitution
  /// disallows.
  void register(Capability capability) {
    if (_capabilities.containsKey(capability.id)) {
      throw StateError('CapabilityRegistry: capability "${capability.id}" is already registered.');
    }
    _capabilities[capability.id] = capability;
  }

  Capability? byId(String id) => _capabilities[id];

  List<Capability> byCategory(CapabilityCategory category) =>
      _capabilities.values.where((c) => c.category == category).toList();

  bool supports(String id) => _capabilities.containsKey(id);

  /// Validates every registered capability's declared [Capability
  /// .dependencies] actually resolve within this same registry (§16:
  /// "Dependencies shall be declared explicitly.") — a dependency on an
  /// unregistered capability id is a configuration error, reported here
  /// rather than discovered later as a runtime failure.
  List<String> validateDependencies() {
    final issues = <String>[];
    for (final capability in _capabilities.values) {
      for (final dependencyId in capability.dependencies) {
        if (!_capabilities.containsKey(dependencyId)) {
          issues.add('Capability "${capability.id}" depends on unregistered capability "$dependencyId".');
        }
      }
    }
    return issues;
  }

  /// OIP-CAPABILITY-001 §18 — Capability Negotiation: the subset of
  /// [requested] capability ids this registry actually supports, i.e.
  /// the "Available Features" from a Host/instrument negotiation. Does
  /// not mutate either side; a pure intersection query.
  Set<String> negotiate(Iterable<String> requested) =>
      requested.where(supports).toSet();
}
