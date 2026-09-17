/// A single [StageResult]'s outcome. Distinguishes a stage that produced
/// nothing because there was nothing to do ([skipped] — e.g. relationship
/// extraction finding no co-located entities) from a stage that failed
/// outright ([failed] — e.g. the OCR engine being unavailable), which
/// WP-INGEST-001 § 6.3 requires be distinguishable.
enum StageExecutionStatus { succeeded, partial, failed, skipped }
