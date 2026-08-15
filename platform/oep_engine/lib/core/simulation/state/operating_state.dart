/// OEP Engineering Runtime -- Phase 9 (Operating State & Input-State
/// Architecture).
///
/// A generic, domain-agnostic vocabulary for describing the operating
/// condition of an engineering system (automotive "Key ON", electrical
/// "Energized", industrial "Startup", ...) and the individual control/
/// input signals that exist within that condition (a switch, a sensor,
/// a control signal). Neither type hard-codes any domain's terminology --
/// automotive Key/Ignition states are a *consumer* of this vocabulary
/// (a caller-supplied list of [OperatingStateDefinition]s), never a
/// built-in enum of this engine.
///
/// Per Part 5's "only implement fields justified by the existing
/// architecture" instruction, these definitions intentionally carry
/// only `id`/`name`/`description`/`metadata` -- the same minimal shape
/// [SimulationFault] and other AP-DS-005 value types already use
/// (compare `simulation_fault.dart`). No parent-state, category, or
/// activation-condition fields are included because nothing in the
/// current engine consumes them; a future phase can add them once a
/// real requirement demands it.
library;

/// A single, named operating condition an engineering system can be in
/// (e.g. "Key ON / Engine OFF"). Purely descriptive data -- becoming the
/// *active* state of a session is done through
/// [SimulationSession.setOperatingState], never by this type itself.
class OperatingStateDefinition {
  const OperatingStateDefinition({required this.id, required this.name, this.description = '', this.metadata = const {}});

  final String id;
  final String name;
  final String description;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'description': description, 'metadata': metadata};

  factory OperatingStateDefinition.fromJson(Map<String, Object?> json) => OperatingStateDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      );

  @override
  String toString() => 'OperatingStateDefinition($id: $name)';
}

/// What kind of value an [InputStateDefinition] holds. Kept to the
/// smallest set that distinguishes the shapes Part 8 actually calls
/// out as needing different treatment (a switch is boolean, a
/// multi-position control is discrete, a sensor reading is analog) --
/// not the full SPST/SPDT/relay/actuator taxonomy Part 8 explicitly
/// says not to build until something requires it.
enum InputValueType { boolean, discrete, analog }

/// A single, named control/input signal within an operating system
/// (e.g. "Headlight Switch"), distinct from the [OperatingStateDefinition]
/// it exists under (Part 7: "Operating state and input state must
/// remain distinct").
///
/// [targetRelationshipId] (Phase 10 -- Operating/Input State Effects,
/// Part 5/6/8) is this input's association with the existing engineering
/// graph: the id of an [EngineeringRelationship] this boolean input
/// controls, using the exact same "does this edge conduct" question
/// [FaultOverlay.hasOpenCircuitOn] already answers for faults -- no new
/// primitive was introduced (Part 6's "do not introduce a new
/// primitive"), because a switch is already representable as a
/// `connectedTo`/wire relationship whose conductivity can be gated, the
/// identical shape `SimulationFault.openCircuit` already gates. `null`
/// (the default) means this input has no simulation effect yet -- it
/// remains observable/settable but inert, which is also what a whole
/// analog/discrete input (Part 7: "do not implement analog behavior
/// simply because the enum exists") stays this phase: only the boolean
/// + relationship vertical slice is wired to real propagation.
///
/// [targetObjectId]/[targetPortId] (Phase 12 -- Component/Port Input-State
/// Association Architecture, Part 5/7/10/11) are a SECOND, independent
/// association mechanism, using the exact same `Engineering Object`
/// identity ([EngineeringNode.id]) and the exact same informal
/// `relationship.metadata['sourcePort']`/`['targetPort']` port-reference
/// convention [VerificationEngine]'s own connector check already
/// established (`verification_engine.dart`'s `_portReferenced`) -- no new
/// primitive, no new port-owner field, no `ComponentInputBinding` type.
/// When set, a `false` active value blocks every relationship the
/// resolved node/port participates in (see `StateConditionResolver`),
/// rather than one specifically-named relationship -- appropriate for
/// "this component is off" as opposed to "this one wire is cut."
/// [targetRelationshipId] and [targetObjectId]/[targetPortId] are both
/// valid, independent mechanisms (Part 7 explicitly forbids forcing
/// everything into one) -- a given [InputStateDefinition] would
/// typically use only one, but nothing prevents both being resolved
/// together.
///
/// [topologyEffects] (Phase 13 -- Generic Component Behavior & Topology
/// Switching, Part 4/5/12/13) generalizes the single boolean
/// "false blocks [targetRelationshipId]" rule above into a component
/// BEHAVIOR DEFINITION: a mapping from this input's possible discrete
/// values (a switch position, e.g. `'positionA'`) to the set of
/// relationship ids blocked while the input holds that value. This is
/// the smallest extension that answers Part 4's question ("how can a
/// component declare that its runtime state changes connectivity?")
/// without a new primitive or a new class -- `StateConditionResolver`
/// still only ever produces the same `Set<String> blockedRelationshipIds`
/// it always has (Part 13's own finding: "active = graph relationships -
/// blocked is sufficient"), so [SignalPropagator] needs no changes at
/// all. A single-pole/single-throw switch is representable with one
/// entry (subsuming the boolean mechanism, kept separate for backward
/// compatibility -- Part 28: "do not weaken tests"); a single-pole/
/// double-throw switch is two entries, one per position, each blocking
/// the OTHER position's relationship -- mutual exclusion falls out of
/// how the two entries are authored, not from any special-cased
/// "exactly one active" enforcement in this engine (this class has no
/// concept of "switch," "SPST," or "SPDT"). Extending to N positions is
/// simply N map entries -- proving the mechanism is not hard-coded to
/// two states (Part 8).
class InputStateDefinition {
  const InputStateDefinition({
    required this.id,
    required this.label,
    this.valueType = InputValueType.boolean,
    this.metadata = const {},
    this.targetRelationshipId,
    this.targetObjectId,
    this.targetPortId,
    this.topologyEffects = const {},
  });

  final String id;
  final String label;
  final InputValueType valueType;
  final Map<String, Object?> metadata;
  final String? targetRelationshipId;

  /// The id of the [EngineeringNode] (Engineering Object) this input is
  /// associated with, if any.
  final String? targetObjectId;

  /// An optional, more specific port on [targetObjectId] this input is
  /// associated with. Meaningless without [targetObjectId] set.
  final String? targetPortId;

  /// Maps this input's discrete active value (compared via `toString()`,
  /// so a boolean `true`/`false` or a String position id both work) to
  /// the relationship ids blocked while the input holds that value.
  /// Empty by default -- no fabricated effect for a value this map
  /// doesn't mention.
  final Map<String, Set<String>> topologyEffects;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'valueType': valueType.name,
        'metadata': metadata,
        if (targetRelationshipId != null) 'targetRelationshipId': targetRelationshipId,
        if (targetObjectId != null) 'targetObjectId': targetObjectId,
        if (targetPortId != null) 'targetPortId': targetPortId,
        if (topologyEffects.isNotEmpty)
          'topologyEffects': topologyEffects.map((value, ids) => MapEntry(value, ids.toList())),
      };

  factory InputStateDefinition.fromJson(Map<String, Object?> json) => InputStateDefinition(
        id: json['id'] as String,
        label: json['label'] as String,
        valueType: InputValueType.values.firstWhere(
          (t) => t.name == json['valueType'],
          orElse: () => InputValueType.boolean,
        ),
        metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
        targetRelationshipId: json['targetRelationshipId'] as String?,
        targetObjectId: json['targetObjectId'] as String?,
        targetPortId: json['targetPortId'] as String?,
        topologyEffects: (json['topologyEffects'] as Map? ?? const {}).map(
          (value, ids) => MapEntry(value as String, Set<String>.from(ids as List)),
        ),
      );

  @override
  String toString() => 'InputStateDefinition($id: $label)';
}
