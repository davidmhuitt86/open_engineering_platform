import 'package:engineering_engine/engineering_engine.dart';

import '../../core/foundation/foundation_bridge.dart';
import '../../core/foundation/oep_api_types.dart';
import 'foundation_commit_operations.dart';
import 'node_category_foundation_mapping.dart';
import 'relationship_type_foundation_mapping.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — the concrete `FoundationBridgePort`
/// implementation. Wraps the exact same, already-proven
/// `FoundationBridge` FFI calls Knowledge Studio's Repository Commit
/// feature uses (`docs/REPOSITORY_COMMIT.md`) — `beginTransaction`,
/// `createObject`/`createRelationship` in a loop (never the
/// `oep_batch_create_*` convenience functions, for the same documented
/// reason Knowledge Studio's own commit avoids them: a relationship
/// created in the same commit as its endpoint needs that endpoint's
/// just-assigned id, which a homogeneous batch call can't interleave),
/// `commitTransaction`/`rollbackTransaction`.
///
/// Talks to [FoundationCommitOperations] (an abstract seam), not
/// `FoundationBridge` directly — see that interface's own doc comment
/// for why. [operationsResolver]/[runtimeStateResolver] are plain
/// closures rather than a `Ref`, so this class (and therefore
/// `EngineRegistry`, and `oep_engine`) never needs a Riverpod
/// dependency — the same resolver-closure pattern
/// `LegacyV2StateAdapter.simulationServiceResolver` already uses in this
/// codebase for exactly this "reach a live Studio-level service from
/// Engine-adjacent code without a hard Riverpod dependency" problem.
class StudioFoundationBridgePort implements FoundationBridgePort {
  StudioFoundationBridgePort({
    required this.operationsResolver,
    required this.runtimeStateResolver,
  });

  /// Production wiring: adapts a single `FoundationBridge?` resolver
  /// (e.g. `() => ref.read(foundationRuntimeServiceProvider.notifier).bridge`)
  /// into both closures this class actually needs.
  factory StudioFoundationBridgePort.fromBridgeResolver(FoundationBridge? Function() bridgeResolver) {
    return StudioFoundationBridgePort(
      operationsResolver: () {
        final bridge = bridgeResolver();
        return bridge == null ? null : RealFoundationCommitOperations(bridge);
      },
      runtimeStateResolver: () => (bridgeResolver()?.state ?? FoundationRuntimeState.uninitialized).name,
    );
  }

  /// `null` when no Foundation runtime/repository is available right
  /// now (e.g. no repository open) — every method below treats that as
  /// a normal, expected failure mode (SDD-025: the Engine must operate
  /// fine with no bridge at all), not a bug.
  final FoundationCommitOperations? Function() operationsResolver;

  final String Function() runtimeStateResolver;

  @override
  Future<String> runtimeState() async => runtimeStateResolver();

  @override
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph) async {
    final operations = operationsResolver();
    if (operations == null) {
      throw StateError('No Foundation repository is open — cannot commit.');
    }
    final graph = EngineeringGraph.fromJson(serializedGraph);

    // Already-committed nodes/relationships are skipped, not
    // resubmitted — safe to call commitGraph again after only some
    // nodes were added since the last successful commit (duplicate/
    // retry semantics, mirroring `CommitTransactionService`'s own
    // pre-seed-already-committed-candidates pattern).
    final idByEngineNodeId = <String, String>{
      for (final node in graph.nodes.values)
        if (node.repositoryObjectId != null) node.id: node.repositoryObjectId!,
    };
    final objectNameById = <String, String>{
      for (final node in graph.nodes.values)
        if (node.repositoryObjectId != null) node.repositoryObjectId!: node.displayName,
    };

    final unmappedNodeIds = <String>[];
    final nodesToCommit = <EngineeringNode>[];
    for (final node in graph.nodes.values) {
      if (node.repositoryObjectId != null) continue; // already committed
      if (node.category.foundationCategory == null) {
        unmappedNodeIds.add(node.id);
        continue;
      }
      nodesToCommit.add(node);
    }

    final unmappedRelationshipIds = <String>[];
    final relationshipsToCommit = <EngineeringRelationship>[];
    final nodesToCommitIds = {for (final n in nodesToCommit) n.id};
    for (final relationship in graph.relationships.values) {
      if (relationship.repositoryRelationshipId != null) continue; // already committed
      final endpointsResolvable = (idByEngineNodeId.containsKey(relationship.sourceNode) ||
              nodesToCommitIds.contains(relationship.sourceNode)) &&
          (idByEngineNodeId.containsKey(relationship.targetNode) || nodesToCommitIds.contains(relationship.targetNode));
      if (relationship.relationshipType.foundationType == null || !endpointsResolvable) {
        unmappedRelationshipIds.add(relationship.id);
        continue;
      }
      relationshipsToCommit.add(relationship);
    }

    if (nodesToCommit.isEmpty && relationshipsToCommit.isEmpty) {
      return GraphCommitResult(
        nodeRepositoryIds: const {},
        relationshipRepositoryIds: const {},
        unmappedNodeIds: unmappedNodeIds,
        unmappedRelationshipIds: unmappedRelationshipIds,
      );
    }

    final nodeRepositoryIds = <String, String>{};
    final relationshipRepositoryIds = <String, String>{};

    try {
      operations.beginTransaction();

      for (final node in nodesToCommit) {
        final created = operations.createObject(
          category: node.category.foundationCategory!,
          name: node.displayName,
        );
        nodeRepositoryIds[node.id] = created.objectId;
        idByEngineNodeId[node.id] = created.objectId;
        objectNameById[created.objectId] = created.name;
      }

      for (final relationship in relationshipsToCommit) {
        final sourceObjectId = idByEngineNodeId[relationship.sourceNode];
        final targetObjectId = idByEngineNodeId[relationship.targetNode];
        if (sourceObjectId == null || targetObjectId == null) {
          // Defensive only — the filtering above already restricted
          // `relationshipsToCommit` to relationships whose endpoints
          // resolve. Same "treat as a commit failure, not a silent
          // skip" reasoning as `CommitTransactionService`'s own
          // identical defensive check.
          throw StateError('Relationship ${relationship.id} has an unresolved endpoint.');
        }
        final created = operations.createRelationship(
          sourceObjectId: sourceObjectId,
          targetObjectId: targetObjectId,
          type: relationship.relationshipType.foundationType!,
          objectNamesById: objectNameById,
        );
        relationshipRepositoryIds[relationship.id] = created.relationshipId;
      }

      operations.commitTransaction();
    } catch (_) {
      _safeRollback(operations);
      rethrow;
    }

    return GraphCommitResult(
      nodeRepositoryIds: nodeRepositoryIds,
      relationshipRepositoryIds: relationshipRepositoryIds,
      unmappedNodeIds: unmappedNodeIds,
      unmappedRelationshipIds: unmappedRelationshipIds,
    );
  }

  @override
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId) async {
    // AP-OEP-FOUNDATION-BRIDGE-002: the previous, repository-wide
    // enumeration behavior (see git history / ADR-004's
    // AP-OEP-FOUNDATION-BRIDGE-001 addendum for the prior "known
    // interface mismatch" note) is removed. `repositoryObjectId` is now
    // genuinely used as a membership scope: it names the diagram
    // identity `AP-OEP-FOUNDATION-GRAPH-IDENTITY-001` established
    // (an `OEP_OBJECT_TYPE_DIAGRAM` object's own object_id) whose
    // members alone are loaded via `oep_diagram_get_objects`/
    // `oep_diagram_get_relationships`. An invalid/nonexistent diagram id
    // fails the call (propagated from Foundation, never silently
    // downgraded to an empty graph); a valid, empty diagram succeeds and
    // returns an empty graph.
    final operations = operationsResolver();
    if (operations == null) {
      throw StateError('No Foundation repository is open — cannot load.');
    }
    final objects = operations.listObjectsForDiagram(repositoryObjectId);
    final objectNameById = {for (final o in objects) o.objectId: o.name};
    final relationships = operations.listRelationshipsForDiagram(repositoryObjectId, objectNamesById: objectNameById);

    final graph = EngineeringGraph(
      id: repositoryObjectId,
      nodes: {
        for (final object in objects)
          object.objectId: EngineeringNode(
            id: object.objectId,
            category: NodeCategory.unknown,
            displayName: object.name,
            repositoryObjectId: object.objectId,
          ),
      },
      relationships: {
        for (final relationship in relationships)
          relationship.relationshipId: EngineeringRelationship(
            id: relationship.relationshipId,
            relationshipType: RelationshipType.other,
            sourceNode: relationship.sourceObjectId,
            targetNode: relationship.targetObjectId,
            repositoryRelationshipId: relationship.relationshipId,
          ),
      },
    );
    return graph.toJson();
  }

  static void _safeRollback(FoundationCommitOperations operations) {
    try {
      if (operations.isTransactionActive) {
        operations.rollbackTransaction();
      }
    } catch (_) {
      // Best-effort only — the original failure is what the caller
      // needs, not a secondary one from cleanup (same reasoning as
      // `CommitTransactionService._safeRollback`).
    }
  }
}
