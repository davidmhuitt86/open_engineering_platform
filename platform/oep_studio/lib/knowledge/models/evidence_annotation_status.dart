/// WP-INGEST-010 §3: a minimal review-status model for an
/// [EvidenceRegion] annotation -- AP-INGEST-009's own instruction: "Do not
/// create a larger review/approval state machine unless existing
/// architecture requires it." Deliberately just two values, not a
/// parallel copy of `KnowledgeCandidateStatus`'s pending/accepted/
/// rejected vocabulary -- an Evidence Region is not, and does not become,
/// a Knowledge Candidate or an Engineering Object by having a status at
/// all (SDD-015 Layer 2.5's "Evidence... does not become repository
/// truth" still holds unchanged).
enum EvidenceAnnotationStatus {
  /// The default for a newly-created human annotation -- created, not yet
  /// reviewed by anyone else.
  unverified,

  /// A second person (or the same annotator, later) has confirmed this
  /// annotation is correct. Still not repository truth, not a training
  /// example, not an Engineering Object -- see this work package's own
  /// explicit prohibitions.
  verified,
}
