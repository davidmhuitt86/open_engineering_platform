import '../graph/models/engineering_node.dart';
import '../graph/models/engineering_relationship.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — the result of
/// [FoundationBridgePort.commitGraph]. Replaces the interface's original
/// bare `Future<String>` return, which implied a single Foundation
/// identity for the whole committed graph — a concept Foundation's own
/// model didn't originally have (only individual Engineering
/// Object/Relationship identities existed). Zero callers of
/// `commitGraph` existed before this package, so this is a free change,
/// not a breaking one.
///
/// **AP-OEP-FOUNDATION-BRIDGE-003** — Foundation now does have a
/// whole-graph identity after all: [diagramRepositoryId], a Foundation
/// `ObjectType::Diagram` object established (or reused) for this commit.
/// [nodeRepositoryIds]/[relationshipRepositoryIds] remain per-member
/// mappings, unchanged in shape — [diagramRepositoryId] is additive, the
/// identity a caller needs to later scope-load this same graph back via
/// `FoundationBridgePort.loadCommittedGraph`.
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
    this.diagramRepositoryId,
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

  /// AP-OEP-FOUNDATION-BRIDGE-003 — the Foundation diagram identity
  /// (`ObjectType::Diagram` object id) every newly-created node/
  /// relationship in this commit was assigned to, or an existing
  /// diagram id this commit reused because the graph already carried
  /// one. Null only when this commit created (and reused) nothing —
  /// an empty graph, or a graph whose every member was already
  /// committed and had no prior diagram identity to report — never a
  /// fabricated or guessed value.
  final String? diagramRepositoryId;
}
