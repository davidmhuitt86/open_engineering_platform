/// WP-INGEST-010: distinguishes who/what produced an [EvidenceRegion] --
/// AP-INGEST-009 §5/§H's finding that "Machine Observation" and "Human
/// Annotation" already exist as distinct concepts in the pipeline
/// (`OcrWord`/`EngineeringEntity` vs. a hand-drawn region) but were never
/// structurally distinguishable on the region itself, only informally via
/// a free-text `notes` string.
///
/// Nullable everywhere this appears on [EvidenceRegion] -- a region
/// deserialized from a session file saved before this work package has no
/// recorded origin at all, and per AP-INGEST-009's own explicit
/// instruction ("Do not infer human origin from missing fields"), that
/// case must stay `null`/unknown, never silently default to [human] or
/// [machine].
enum EvidenceOrigin {
  /// Created automatically by UIF (e.g. `CandidateGenerationService`'s
  /// existing entity-to-region auto-generation) — never created by a
  /// person.
  machine,

  /// Created by a person, either via the existing drag-to-draw tool
  /// (`PdfSourceViewer`) or the new Extraction Inspector's "Classify this
  /// region" action.
  human,
}
