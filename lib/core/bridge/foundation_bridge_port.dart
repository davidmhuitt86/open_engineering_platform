/// Abstract contract for future Foundation Bridge integration.
///
/// **No implementation exists yet — and none is provided in Phase 1.**
///
/// SDD-025/026 require the Engineering Engine to talk to Foundation
/// "exclusively through the existing Foundation Bridge," but no reusable
/// Dart Foundation Bridge package exists outside `oep_studio`'s internal
/// FFI code, and `OEP-SPEC-022 (Foundation Bridge Support)` in
/// `oep_foundation` is still `Draft`. SDD-025 explicitly allows this:
/// "Engineering Engine shall operate without an open Repository where
/// practical. Temporary Engineering Graphs may exist before Repository
/// Commit." Phase 1's `GraphService` is backed by
/// `InMemoryGraphProvider` + `JsonFileSerializationProvider` instead.
///
/// This interface exists purely to document the shape a future
/// implementation must fill, and to give `EngineRegistry` a registration
/// point once one exists. Nothing in Phase 1 constructs or calls it.
///
/// See docs/ARCHITECTURE_DECISIONS.md (ADR-004) and
/// docs/ENGINEERING_ENGINE.md for the full dependency note.
abstract class FoundationBridgePort {
  /// Foundation runtime state, mirroring OEP-SPEC-022 §3 (Uninitialized /
  /// Initialized / Repository Open / Repository Closed / Shutdown).
  Future<String> runtimeState();

  /// Commits an Engineering Graph, in Foundation's persisted representation,
  /// to the currently open Repository. Repository object id shape is
  /// defined by Foundation, not by this port.
  Future<String> commitGraph(Map<String, Object?> serializedGraph);

  /// Loads a previously committed graph by Foundation object id.
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId);
}
