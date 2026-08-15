/// The presentation-independent capability model (Architecture spec §
/// 7). A capability is a fact about what is currently possible, never a
/// menu label — the same capability may back several different
/// commands, and no command's presence is decided by anything other
/// than capability resolution.
///
/// Grouped by the categories the spec lists (§ 3 of this phase's own
/// brief): Measurement, Diagnostic, Engineering Simulation, Knowledge,
/// AI, General.
enum EngineeringCapability {
  // Measurement
  voltageMeasurement,
  voltageDropMeasurement,
  resistanceMeasurement,
  continuityMeasurement,
  currentMeasurement,
  dmmProbePlacement,

  // Diagnostic
  diagnosticSimulation,
  openCircuitFault,
  shortToGroundFault,
  shortToPowerFault,
  highResistanceFault,
  intermittentFault,
  componentStateControl,

  // Engineering simulation
  engineeringSimulation,
  simulationControl,
  signalMeasurement,
  eventInspection,

  // Knowledge
  knowledgeLookup,
  knowledgeSourceAccess,
  chainOfCustodyAccess,

  // AI
  aiAnalysis,
  contextualAiAnalysis,

  // General
  objectInspection,
  propertyInspection,
  relationshipInspection,
  annotation,
}

/// Whether a capability is currently exercisable (Contract spec § 15).
/// [restricted] exists for a future authorization system (Contract §
/// 13) — nothing in this build produces it yet, since no permission
/// system exists (see `PermissionContext`'s own doc comment).
enum CapabilityAvailability { available, unavailable, restricted }

/// One resolved capability, with the source that established it
/// (Contract spec § 16 — "Capability Provenance": "especially valuable
/// for debugging and future diagnostics of the command system").
class ResolvedCapability {
  const ResolvedCapability({required this.capability, required this.availability, required this.source, this.reason});

  final EngineeringCapability capability;
  final CapabilityAvailability availability;

  /// Which adapter/source established this — e.g. `"MeasurementCapabilityAdapter"`,
  /// never a UI-facing string.
  final String source;

  /// Present only when [availability] is not `.available` and there is
  /// a useful, specific reason to surface (Resolution spec § 5 — "Use
  /// disabled when the reason for temporary unavailability is useful
  /// to the user").
  final String? reason;

  bool get isAvailable => availability == CapabilityAvailability.available;
}

/// The result of running every registered capability adapter against
/// one [EngineeringInteractionContext] — the Contextual Command
/// Resolver's only input besides the context itself and the command
/// list (Architecture spec § 5's "Normalized capabilities").
class CapabilitySet {
  const CapabilitySet(this._resolved);

  final Map<EngineeringCapability, ResolvedCapability> _resolved;

  static const CapabilitySet empty = CapabilitySet({});

  bool isAvailable(EngineeringCapability capability) => _resolved[capability]?.isAvailable ?? false;

  ResolvedCapability? resolutionFor(EngineeringCapability capability) => _resolved[capability];

  Iterable<ResolvedCapability> get all => _resolved.values;
}
