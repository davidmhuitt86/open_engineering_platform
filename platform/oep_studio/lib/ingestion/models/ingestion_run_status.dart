/// The canonical `IngestionRun` state vocabulary (AP-INGEST-001 § 6.1,
/// WP-INGEST-001 § 6.2). `partial` is mandatory: "an ingestion run may
/// successfully process some portions of an artifact while another
/// portion fails" (e.g. some OCR pages fail while others, and every
/// preceding stage, succeed).
enum IngestionRunStatus {
  queued,
  running,
  completed,
  partial,
  failed,
  cancelled;

  bool get isTerminal =>
      this == IngestionRunStatus.completed ||
      this == IngestionRunStatus.partial ||
      this == IngestionRunStatus.failed ||
      this == IngestionRunStatus.cancelled;

  /// Whether an [IngestionRun] currently in `this` status may legally
  /// transition to [next] (WP-INGEST-007 § 6): the smallest
  /// transition-validation mechanism this work package authorizes --
  /// not a general-purpose state-machine framework, just this lookup.
  ///
  /// Legal transitions:
  ///
  ///     queued    -> running, failed, cancelled
  ///     running   -> completed, partial, failed, cancelled
  ///
  /// Every terminal status ([isTerminal]) returns `false` for every
  /// [next] -- a terminal run can never transition again, in particular
  /// never back to [running] (WP-INGEST-007 § 6/§ 37).
  bool canTransitionTo(IngestionRunStatus next) {
    switch (this) {
      case IngestionRunStatus.queued:
        return next == IngestionRunStatus.running ||
            next == IngestionRunStatus.failed ||
            next == IngestionRunStatus.cancelled;
      case IngestionRunStatus.running:
        return next == IngestionRunStatus.completed ||
            next == IngestionRunStatus.partial ||
            next == IngestionRunStatus.failed ||
            next == IngestionRunStatus.cancelled;
      case IngestionRunStatus.completed:
      case IngestionRunStatus.partial:
      case IngestionRunStatus.failed:
      case IngestionRunStatus.cancelled:
        return false;
    }
  }
}
