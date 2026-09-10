import '../state/operating_state.dart';

/// PRODUCT-READINESS-004 Phase A, §9 — the runtime operating/input state a
/// component behavior is evaluated against. Bundles exactly the same
/// shape [StateConditionResolver.resolveBlockedRelationshipIds]
/// (`state/state_condition_resolver.dart`) already takes as parameters —
/// no new operating-state model is introduced (§9's own instruction: "It
/// must NOT be persisted into the authoritative diagram document unless an
/// existing architecture explicitly defines a persisted operating-state
/// object" — [OperatingStateDefinition]/[InputStateDefinition] already ARE
/// that existing, non-persisted, runtime-only architecture from Phase 9/10
/// of this engine's own prior work; this phase reuses it rather than
/// building a second one).
///
/// [activeOperatingStateId] is the currently-active [OperatingStateDefinition.id]
/// (matching `SimulationSession.activeOperatingStateId`'s own concept),
/// `null` when no operating state has been selected yet.
class ElectricalOperatingContext {
  const ElectricalOperatingContext({
    this.activeOperatingStateId,
    this.availableInputStates = const [],
    this.activeInputStates = const {},
  });

  final String? activeOperatingStateId;
  final List<InputStateDefinition> availableInputStates;
  final Map<String, Object?> activeInputStates;

  /// The empty context — every component behaves as if no operating/input
  /// state has ever been set (matching a freshly-created
  /// `SimulationSession`'s own defaults).
  static const ElectricalOperatingContext none = ElectricalOperatingContext();
}
