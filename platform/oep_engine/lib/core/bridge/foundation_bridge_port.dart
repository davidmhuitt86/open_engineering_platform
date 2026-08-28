import 'graph_commit_result.dart';

/// Abstract contract for Foundation Bridge integration.
///
/// **AP-OEP-FOUNDATION-BRIDGE-001 — now implemented**, by
/// `oep_studio`'s `StudioFoundationBridgePort`
/// (`lib/diagram_studio/bridge/studio_foundation_bridge_port.dart`),
/// itself backed by the same `FoundationBridge`
/// (`oep_studio/lib/core/foundation/foundation_bridge.dart`) FFI layer
/// Knowledge Studio's Repository Commit feature already proved works
/// end-to-end (`docs/REPOSITORY_COMMIT.md`). This corrects the prior
/// "no implementation exists" state documented in ADR-004 — see that
/// ADR's own AP-OEP-FOUNDATION-BRIDGE-001 addendum for the full account
/// of what changed and why the original decision wasn't wrong at the
/// time.
///
/// SDD-025/026 require the Engineering Engine to talk to Foundation
/// "exclusively through the existing Foundation Bridge." SDD-025 still
/// explicitly allows an unbridged Engine: "Engineering Engine shall
/// operate without an open Repository where practical. Temporary
/// Engineering Graphs may exist before Repository Commit" — which is why
/// `EngineRegistry.foundationBridge` is nullable, unlike every other
/// provider getter there.
///
/// This interface exists to document the shape any implementation must
/// fill, and gives `EngineRegistry` a registration point — `oep_studio`
/// registers its own concrete implementation; this package (`oep_engine`)
/// never imports Foundation/FFI code directly.
///
/// See docs/ARCHITECTURE_DECISIONS.md (ADR-004) and
/// docs/ENGINEERING_ENGINE.md for the full dependency note.
abstract class FoundationBridgePort {
  /// Foundation runtime state, mirroring OEP-SPEC-022 §3 (Uninitialized /
  /// Initialized / Repository Open / Repository Closed / Shutdown).
  Future<String> runtimeState();

  /// Commits an Engineering Graph (in `EngineeringGraph.toJson`'s shape)
  /// to the currently open Repository, as one logical transaction —
  /// mirroring "Repository Commit shall execute as one logical
  /// transaction" (Work Package 012, `docs/REPOSITORY_COMMIT.md`).
  ///
  /// Returns a [GraphCommitResult] rather than a single id: Foundation
  /// has no "one identity for a whole graph" concept, only individual
  /// Engineering Object/Relationship identities, so a per-node/
  /// per-relationship result is the only shape an implementation can
  /// honestly return. A node/relationship whose category/type has no
  /// Foundation mapping is excluded (`unmappedNodeIds`/
  /// `unmappedRelationshipIds`), never committed under a guessed
  /// mapping. A node/relationship that already carries a
  /// `repositoryObjectId`/`repositoryRelationshipId` is treated as
  /// already committed and is not resubmitted (safe to call again after
  /// a partial edit — see the implementation's own doc comment for
  /// exact duplicate/retry semantics).
  ///
  /// The commit is atomic: on any failure, nothing is written back and
  /// the returned Future fails — implementations must never return a
  /// partially-populated [GraphCommitResult].
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph);

  /// Loads Engineering Objects/Relationships currently persisted in the
  /// open Repository, reconstructed as a serialized graph
  /// (`EngineeringGraph.fromJson`'s shape) with `repositoryObjectId`/
  /// `repositoryRelationshipId` populated from Foundation's own ids.
  ///
  /// **Known interface mismatch (AP-OEP-FOUNDATION-BRIDGE-001):** the
  /// [repositoryObjectId] parameter implies loading *one graph* scoped
  /// by a single seed id — but Foundation has no "graph" aggregate to
  /// scope by; only "every Object/Relationship currently in the open
  /// Repository" exists. Implementations therefore ignore
  /// [repositoryObjectId] as a scoping mechanism and return everything
  /// in the open Repository. Flagged explicitly rather than silently
  /// worked around; a real per-graph scoping mechanism would need a
  /// Foundation-side concept that doesn't exist today.
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId);
}
