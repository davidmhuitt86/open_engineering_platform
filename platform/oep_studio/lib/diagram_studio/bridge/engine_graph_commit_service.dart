import 'package:engineering_engine/engineering_engine.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — step 6's "propagate into the Engine
/// model" entry point. Calls the registered `FoundationBridgePort`,
/// then writes the returned Foundation ids back onto the live graph's
/// nodes/relationships via `GraphService.addNode`/`addRelationship` —
/// already-existing methods, reused as-is (their "add" name is
/// misleading here: `EngineeringGraph.withNode`/`withRelationship`
/// replace-by-id on a map, which is exactly "patch this existing node's
/// `repositoryObjectId`" when passed a `copyWith`'d version of a node
/// already in the graph).
///
/// Deliberately not routed through `EditingCommand`/undo history: a
/// repository id landing after a real, already-completed external write
/// isn't a user edit, and "undoing" it wouldn't undo anything at
/// Foundation — Foundation already has the object/relationship
/// regardless of what Studio's undo stack does.
///
/// AP-OEP-DIAGRAM-REPOSITORY-001 — now wired into the Property
/// Inspector's existing "Repository Object"/"Repository Relationship"
/// rows (`diagram_repository_commit_action.dart`); this service itself
/// still has no UI knowledge — it stays the plain, callable, testable
/// mechanism that package added.
abstract final class EngineGraphCommitService {
  /// Commits [graph] via [bridge] and returns both the graph with every
  /// successfully-committed node/relationship's `repositoryObjectId`/
  /// `repositoryRelationshipId` populated, and the raw
  /// [GraphCommitResult] itself (so a caller can report exactly what was
  /// committed vs. excluded as unmapped — AP-OEP-DIAGRAM-REPOSITORY-001's
  /// own feedback requirement — without this service reproducing that
  /// reporting logic itself). On any failure, rethrows — matching
  /// `FoundationBridgePort.commitGraph`'s documented atomic-or-fails
  /// contract, so there is nothing partial for this layer to reconcile.
  static Future<({EngineeringGraph graph, GraphCommitResult result})> commit({
    required FoundationBridgePort bridge,
    required EngineeringGraph graph,
    required GraphService graphService,
  }) async {
    final result = await bridge.commitGraph(graph.toJson());

    var updated = graph;
    for (final entry in result.nodeRepositoryIds.entries) {
      final node = updated.nodes[entry.key];
      if (node == null) continue; // defensive — result only ever references ids that were in the submitted graph
      updated = await graphService.addNode(updated, node.copyWith(repositoryObjectId: entry.value));
    }
    for (final entry in result.relationshipRepositoryIds.entries) {
      final relationship = updated.relationships[entry.key];
      if (relationship == null) continue;
      updated = await graphService.addRelationship(
        updated,
        relationship.copyWith(repositoryRelationshipId: entry.value),
      );
    }
    return (graph: updated, result: result);
  }
}
