import 'operating_state.dart';

/// OEP Engineering Runtime -- Phase 14 (UI Layout Ratification): the
/// missing "domain-profile source" Phase 9 (Part 22/9) explicitly
/// deferred -- "There is currently no production domain-profile
/// source... document the exact missing data contract." This is that
/// contract: a small, purely-data bundle of the operating/input state
/// definitions a specific engineering diagram supports (e.g. a
/// vehicle's Key/Switch states), separate from the diagram's own
/// `EngineeringGraph` (the graph is the design; this is the runtime
/// behavior vocabulary that design supports -- matching the
/// `legacy_wiring_sim_v2` reference tool's own separation of its
/// `vehicle.json`/diagram data from `layout.json`/graph data).
///
/// Deliberately just a bundle -- no new persistence mechanism, no new
/// primitive. [operatingStates]/[inputStates] round-trip through the
/// exact same [OperatingStateDefinition.toJson]/[InputStateDefinition.toJson]
/// every `SimulationSession` export/import already uses (Phase 9/10).
/// A profile references real relationship/node/port ids from a
/// specific diagram (via [InputStateDefinition.targetRelationshipId]/
/// [targetObjectId]/[targetPortId]) -- it is not universally portable
/// across diagrams, the same way the reference tool's per-vehicle
/// files are not.
class DomainProfile {
  const DomainProfile({
    required this.id,
    required this.name,
    this.operatingStates = const [],
    this.inputStates = const [],
  });

  final String id;
  final String name;
  final List<OperatingStateDefinition> operatingStates;
  final List<InputStateDefinition> inputStates;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'operatingStates': operatingStates.map((s) => s.toJson()).toList(),
        'inputStates': inputStates.map((s) => s.toJson()).toList(),
      };

  factory DomainProfile.fromJson(Map<String, Object?> json) => DomainProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        operatingStates: (json['operatingStates'] as List? ?? const [])
            .map((s) => OperatingStateDefinition.fromJson(Map<String, Object?>.from(s as Map)))
            .toList(),
        inputStates: (json['inputStates'] as List? ?? const [])
            .map((s) => InputStateDefinition.fromJson(Map<String, Object?>.from(s as Map)))
            .toList(),
      );

  @override
  String toString() => 'DomainProfile($id: $name, ${operatingStates.length} operating states, ${inputStates.length} inputs)';
}
