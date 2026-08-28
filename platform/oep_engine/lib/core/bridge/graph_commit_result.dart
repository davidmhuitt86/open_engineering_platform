import '../graph/models/engineering_node.dart';
import '../graph/models/engineering_relationship.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — the result of
/// [FoundationBridgePort.commitGraph]. Replaces the interface's original
/// bare `Future<String>` return, which implied a single Foundation
/// identity for the whole committed graph — a concept Foundation's own
/// model doesn't have (only individual Engineering Object/Relationship
/// identities exist). Zero callers of `commitGraph` existed before this
/// package, so this is a free change, not a breaking one.
///
/// Every id in [nodeRepositoryIds]/[relationshipRepositoryIds] is a real,
/// Foundation-assigned identity returned by a successful commit — never
/// fabricated, never equal to the corresponding Engine id. Keyed by
/// Engine node/relationship id (not by any positional/ordering
/// assumption) so callers can look up "what did Foundation assign to
/// *this* node" directly.
class GraphCommitResult {
  const GraphCommitResult({
    required this.nodeRepositoryIds,
    required this.relationshipRepositoryIds,
    this.unmappedNodeIds = const [],
    this.unmappedRelationshipIds = const [],
  });

  /// Engine [EngineeringNode.id] -> authoritative Foundation object id,
  /// for every node this commit successfully created (or that was
  /// already committed and therefore skipped — see the implementation's
  /// own doc comment on duplicate-commit handling).
  final Map<String, String> nodeRepositoryIds;

  /// Engine [EngineeringRelationship.id] -> authoritative Foundation
  /// relationship id, same rules as [nodeRepositoryIds].
  final Map<String, String> relationshipRepositoryIds;

  /// Engine node ids excluded from this commit because their
  /// [NodeCategory] has no corresponding Foundation object type — never
  /// silently reinterpreted, never committed under a guessed category.
  final List<String> unmappedNodeIds;

  /// Engine relationship ids excluded from this commit for the same
  /// reason as [unmappedNodeIds].
  final List<String> unmappedRelationshipIds;
}
