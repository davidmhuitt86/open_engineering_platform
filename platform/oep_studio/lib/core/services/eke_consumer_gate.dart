import 'foundation_runtime_state.dart';

/// WP-EKE-FOLLOWUP-001: the single, shared execution-gate predicate every
/// Engineering Knowledge Engine consumer page (`analysis_dashboard_page`,
/// `engineering_explorer_page`, `knowledge_graph_explorer_page`,
/// `query_console_page`, `reasoning_dashboard_page`,
/// `recommendation_panel_page`, `validation_dashboard_page`) uses to
/// decide whether it may invoke an actual EKE operation
/// (`engineeringQuery`/`engineeringAnalysis`/`engineeringRecommendations`/
/// `validateContext`/`validateObject`/`createReasoningSession`/
/// `executeReasoning`/`queryKnowledgeGraph`/etc.) against the graph.
///
/// WP-EKE-009 already made [FoundationServiceState.ekeReadiness] the one
/// authoritative readiness value; this follow-up work package corrects a
/// defect where several consumer pages called
/// `FoundationRuntimeNotifier.ensureEkeReady()` and inspected
/// `EkeReadiness.hasFailed` purely to *display* an error, but then ran
/// their EKE operation regardless of the actual state — using the
/// readiness check as an error-display mechanism, not an execution gate.
///
/// [allows] is the one place that predicate lives: **only**
/// [EkeReadinessState.ready] permits an EKE operation to run. Every other
/// state — `disconnected`, `repositoryClosed`, `graphNotLoaded`,
/// `initializing` (never treated as ready, even though initialization is
/// actively in flight), `engineeringGraphLoaded` (Engineering Graph
/// loaded, Knowledge Graph not yet built), and `initializationFailed` —
/// blocks. An empty (non-null) `FoundationServiceState.objectList` is
/// deliberately **not** consulted here — object-list emptiness has never
/// been, and must never become, a readiness proxy (WP-EKE-009
/// requirements 1/8).
///
/// This is deliberately a single pure function, not a new
/// provider/service/cache — every page still reads
/// [FoundationServiceState.ekeReadiness] through
/// `foundationRuntimeServiceProvider` exactly as WP-EKE-009 established;
/// this only factors out the one boolean every page's own
/// `_ensureGraphReady()` gate needs, so the predicate itself — and the
/// tests proving it — have exactly one home instead of seven near-copies.
class EkeConsumerGate {
  const EkeConsumerGate._();

  /// Whether an EKE consumer may invoke an EKE operation against
  /// [readiness]'s graph. See the class doc for the full state-by-state
  /// rationale.
  static bool allows(EkeReadiness readiness) =>
      readiness.state == EkeReadinessState.ready;

  /// The message an EKE consumer should surface when [allows] returns
  /// `false` for [readiness]: [EkeReadiness.failureMessage] when one was
  /// recorded (preserving the real diagnostic from an
  /// [EkeReadinessState.initializationFailed] — never overwritten with a
  /// generic message), otherwise a generic "not ready" message.
  static String blockedMessage(EkeReadiness readiness) =>
      readiness.failureMessage ?? 'Engineering Knowledge Engine is not ready.';
}
