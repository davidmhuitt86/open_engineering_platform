/// A lightweight, explicit cancellation signal scoped to exactly one
/// [IngestionOrchestrator.run] execution (WP-INGEST-007 § 20-22:
/// "Implement the smallest coherent explicit cancellation mechanism
/// required for this lifecycle... Do not build a job scheduler. Do not
/// build distributed cancellation.").
///
/// A caller creates one token per ingestion execution it starts, keeps a
/// reference to it (e.g. so a "Cancel" button can call [cancel]), and
/// passes it to `IngestionOrchestrator.run(cancellationToken: ...)`. The
/// orchestrator checks [isCancelled] at stage boundaries and stops
/// executing further stages once it is true, without rolling back
/// stages that already completed (WP-INGEST-007 § 22).
///
/// Deliberately not a `Stream`/`Future`-based cancellation primitive
/// (e.g. Dart's `CancelableOperation`) -- a plain boolean flag checked
/// synchronously between stages is the entire mechanism this work
/// package authorizes; there is no cross-isolate/distributed
/// cancellation, no job queue, and no general-purpose application
/// cancellation framework here.
class IngestionCancellationToken {
  bool _cancelled = false;

  /// Requests cancellation of the execution this token is scoped to.
  /// Idempotent -- calling this more than once has no additional effect.
  void cancel() => _cancelled = true;

  /// Whether [cancel] has been called. The orchestrator observes this;
  /// it never resets a token back to "not cancelled" once true.
  bool get isCancelled => _cancelled;
}
