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
}
