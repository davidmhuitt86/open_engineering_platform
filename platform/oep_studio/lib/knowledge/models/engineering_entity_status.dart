/// An Engineering Entity's review status (Work Package 014
/// STUDIO-TASK-000039: "Engineers may: Accept, Ignore"). Mirrors
/// `KnowledgeCandidateStatus`'s pending/decided shape, but with the
/// Entity Review Workspace's own vocabulary — "Ignore," not "Reject,"
/// since ignoring an entity is dismissing a suggestion, not rejecting
/// a proposal already put forward for engineering review.
enum EngineeringEntityStatus {
  /// Not yet reviewed — the default for every freshly-extracted entity.
  pending,

  /// Accepted — a Knowledge Candidate has been created from this
  /// entity (see `EngineeringEntity.createdCandidateId`).
  accepted,

  /// Dismissed by the engineer. "Ignoring shall never delete OCR
  /// evidence" — the underlying `OcrPageResult`/`OcrWord`s this entity
  /// was extracted from are never touched; only this entity's own
  /// status changes. The entity record itself is kept, not deleted,
  /// the same way a rejected Knowledge Candidate is kept, not deleted
  /// (Work Package 007/008).
  ignored,
}
