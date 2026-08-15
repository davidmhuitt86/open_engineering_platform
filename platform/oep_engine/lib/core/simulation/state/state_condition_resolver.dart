import '../../graph/models/engineering_graph.dart';
import 'operating_state.dart';

/// OEP Engineering Runtime -- Phase 10 (Operating/Input State Effects →
/// Signal Propagation) / Phase 12 (Component/Port Input-State Association
/// Architecture): the "condition resolution" mechanism Part 4 (Phase 10)
/// asks for -- answers "given the current runtime conditions, what
/// should this engineering object/relationship do?" for the two
/// independent real association mechanisms [InputStateDefinition] now
/// supports (Phase 12 Part 7: "do not force everything into component
/// targeting" -- both remain valid):
///
///   - [InputStateDefinition.targetRelationshipId]: a boolean input
///     directly names the relationship it blocks when `false` (Phase 10).
///   - [InputStateDefinition.targetObjectId]/[targetPortId]: a boolean
///     input names an [EngineeringNode] (Engineering Object) and,
///     optionally, a specific port on it; when `false`, every
///     relationship that node/port participates in is blocked (Phase 12).
///     Port-scoping reuses the exact same informal
///     `relationship.metadata['sourcePort']`/`['targetPort']` convention
///     [VerificationEngine]'s own connector check already established --
///     no new field, no new primitive.
///
/// Deliberately pure and Flutter/engine-independent (no dependency on
/// [SimulationSession]/[SignalPropagator] -- only [EngineeringGraph], the
/// existing read-only graph type, plus the plain definitions/values
/// types both already own), so [SimulationSession] can call it during
/// [SimulationSession.recompute] and [SignalPropagator] never needs to
/// know where the blocked-relationship set came from (Part 17: "The
/// propagator must remain independent of Flutter/UI" -- and, by the
/// same reasoning, independent of the state architecture that produced
/// its inputs).
///
/// No domain terminology appears here (Part 21/23): this class has no
/// concept of "ignition," "switch," or "headlight" -- it only resolves
/// whatever [InputStateDefinition]s, values, and graph a caller supplies.
class StateConditionResolver {
  const StateConditionResolver();

  /// The relationship ids that should be treated as non-conducting,
  /// given [graph] (needed only to resolve [InputStateDefinition.targetObjectId]/
  /// [InputStateDefinition.targetPortId] targeting, or
  /// [InputStateDefinition.topologyEffects], into concrete relationship
  /// ids -- [InputStateDefinition.targetRelationshipId] targeting never
  /// touches [graph]), [availableInputStates] (the input definitions a
  /// session was created with), and [activeInputStates] (the session's
  /// own current values, keyed by input id -- see
  /// `SimulationSession.activeInputStates`).
  ///
  /// Two independent rules per input, both consulted (Part 16: faults
  /// and state, and by the same reasoning the two mechanisms below,
  /// compose rather than override each other):
  ///
  ///  1. (Phase 10/12) The boolean rule: [InputStateDefinition.targetRelationshipId]/
  ///     [InputStateDefinition.targetObjectId] block their target(s) only
  ///     when the active value is exactly `false`.
  ///  2. (Phase 13) The topology-effect rule: whatever set
  ///     [InputStateDefinition.topologyEffects] maps the active value to
  ///     (via `toString()`) is blocked, for ANY value -- not just `false`
  ///     -- since a discrete position like `'positionA'` is exactly as
  ///     meaningful as `false` is to rule 1.
  ///
  /// An input with no active value yet, and no matching entry in either
  /// rule, never blocks anything -- the same "no fabricated default"
  /// choice established in Phase 10, preserved here so every
  /// pre-Phase-13 session behaves identically to before this phase.
  Set<String> resolveBlockedRelationshipIds(
    EngineeringGraph graph,
    List<InputStateDefinition> availableInputStates,
    Map<String, Object?> activeInputStates,
  ) {
    final blocked = <String>{};
    for (final input in availableInputStates) {
      final value = activeInputStates[input.id];
      if (value == null) continue;

      if (value == false) {
        final targetRelationshipId = input.targetRelationshipId;
        if (targetRelationshipId != null) blocked.add(targetRelationshipId);

        final targetObjectId = input.targetObjectId;
        if (targetObjectId != null) {
          blocked.addAll(_relationshipsForComponent(graph, targetObjectId, input.targetPortId));
        }
      }

      final topologyEffect = input.topologyEffects[value.toString()];
      if (topologyEffect != null) blocked.addAll(topologyEffect);
    }
    return blocked;
  }

  /// Every relationship id [targetObjectId] participates in -- narrowed
  /// to relationships specifically wired to [targetPortId] when supplied
  /// (via the existing `metadata['sourcePort']`/`['targetPort']`
  /// convention), or every relationship touching the node at all when
  /// [targetPortId] is `null` (a whole-component effect).
  Set<String> _relationshipsForComponent(EngineeringGraph graph, String targetObjectId, String? targetPortId) {
    final relationships = graph.relationshipsForNode(targetObjectId);
    if (targetPortId == null) {
      return relationships.map((r) => r.id).toSet();
    }
    return relationships
        .where((r) => r.metadata['sourcePort'] == targetPortId || r.metadata['targetPort'] == targetPortId)
        .map((r) => r.id)
        .toSet();
  }
}
