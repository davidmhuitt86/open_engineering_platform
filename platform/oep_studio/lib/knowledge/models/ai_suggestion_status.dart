/// An AI Suggestion's review status (Work Package 016
/// STUDIO-TASK-000048: "Support: Pending, Accepted, Edited, Rejected,
/// Deferred"). Deliberately its own, fifth vocabulary — distinct from
/// `EngineeringEntityStatus`/`EngineeringContextStatus`'s
/// `pending`/`accepted`/`ignored` — because an AI suggestion is
/// interpretive, not deterministically extracted, and can genuinely be
/// wrong in ways an engineer needs to *correct* (hence [edited], with
/// no equivalent on the deterministic Entity/Context models) rather
/// than merely accept or dismiss.
enum AiSuggestionStatus {
  /// Not yet reviewed.
  pending,

  /// Reviewed and approved as-is — created a Knowledge Candidate using
  /// the AI's own suggested type/name/description verbatim.
  accepted,

  /// The engineer corrected the suggested type/name/description before
  /// accepting; `AiSuggestion.editedType`/`editedName`/
  /// `editedDescription` hold the corrected values, and the AI's own
  /// original suggestion remains intact alongside them for audit.
  edited,

  /// Reviewed and declined — "Rejected suggestions remain available
  /// for auditing" (never deleted, the same non-destructive precedent
  /// `EngineeringEntityStatus.ignored`/`EngineeringContextStatus.ignored`
  /// already established).
  rejected,

  /// Reviewed but deliberately deferred — "not now, revisit later,"
  /// distinct from a considered rejection.
  deferred,
}
