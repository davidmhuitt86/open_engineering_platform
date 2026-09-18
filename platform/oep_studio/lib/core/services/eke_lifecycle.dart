import '../foundation/foundation_bridge_exception.dart';
import 'foundation_runtime_state.dart';

/// Pure, FFI-free orchestration of the Engineering Knowledge Engine
/// readiness lifecycle (WP-EKE-009): `Engineering Graph Load ->
/// Knowledge Graph Build -> EKE Ready`.
///
/// [FoundationRuntimeNotifier] remains the only place in Studio that
/// calls [FoundationBridge] — this class contains no FFI, builds no
/// graph of its own, and does not compete with `FoundationBridge` as a
/// second Foundation runtime service. It exists purely to give the
/// ordering/failure/diagnostic rules a single, independently testable
/// home: the notifier calls [initialize]/[rebuildKnowledgeGraphOnly],
/// passing the two real [FoundationBridge] calls
/// (`loadEngineeringGraph`/`buildKnowledgeGraph`) as closures, so unit
/// tests can exercise every transition (success, load failure, build
/// failure, ordering, diagnostics) without a live native Runtime.
class EkeLifecycle {
  const EkeLifecycle._();

  /// Runs Engineering Graph Load, then — only if that succeeds —
  /// Knowledge Graph Build, in that fixed order (WP-EKE-009 requirement
  /// 4: load must happen before build, never reversed; build is never
  /// attempted after a load failure). Returns the resulting
  /// [EkeReadiness] for [repositoryId].
  ///
  /// [loadGraph]/[buildGraph] are expected to throw
  /// [FoundationBridgeException] on failure, mirroring
  /// `FoundationBridge.loadEngineeringGraph`/`buildKnowledgeGraph`
  /// themselves — any other exception type propagates unmodified, since
  /// that indicates a programming error rather than a normal
  /// Foundation-reported failure.
  static EkeReadiness initialize({
    required String? repositoryId,
    required void Function() loadGraph,
    required void Function() buildGraph,
  }) {
    try {
      loadGraph();
    } on FoundationBridgeException catch (error) {
      return EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failedStage: EkeInitializationStage.engineeringGraphLoad,
        failureMessage: error.message,
        repositoryId: repositoryId,
        causingException: error,
      );
    }
    try {
      buildGraph();
    } on FoundationBridgeException catch (error) {
      return EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failedStage: EkeInitializationStage.knowledgeGraphBuild,
        failureMessage: error.message,
        repositoryId: repositoryId,
        causingException: error,
      );
    }
    return EkeReadiness(
      state: EkeReadinessState.ready,
      repositoryId: repositoryId,
    );
  }

  /// An explicit, Knowledge-Graph-only rebuild — WP-EKE-009 requirement
  /// 6B/7: legitimate explicit refreshes (e.g. the Knowledge Graph
  /// Explorer's "Rebuild Graph" button) and post-mutation refreshes
  /// reuse this same result shape rather than tracking a separate,
  /// page-local flag, so they still cooperate with the authoritative
  /// [EkeReadiness]. Does not touch the Engineering Graph — callers
  /// needing a full reload use [initialize].
  static EkeReadiness rebuildKnowledgeGraphOnly({
    required String? repositoryId,
    required void Function() buildGraph,
  }) {
    try {
      buildGraph();
    } on FoundationBridgeException catch (error) {
      return EkeReadiness(
        state: EkeReadinessState.initializationFailed,
        failedStage: EkeInitializationStage.knowledgeGraphBuild,
        failureMessage: error.message,
        repositoryId: repositoryId,
        causingException: error,
      );
    }
    return EkeReadiness(
      state: EkeReadinessState.ready,
      repositoryId: repositoryId,
    );
  }
}
