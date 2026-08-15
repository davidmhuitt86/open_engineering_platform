/// Session-wide engineering quality metrics for the Session Health
/// Dashboard (Work Package 011 STUDIO-TASK-000029) — "informational
/// only," computed on demand by
/// `SessionHealthService.computeSessionHealth` and never persisted or
/// used to modify session data.
class SessionHealthMetrics {
  const SessionHealthMetrics({
    required this.candidateCount,
    required this.relationshipCandidateCount,
    required this.evidenceRegionCount,
    required this.procedureCount,
    required this.specificationCount,
    required this.validationErrorCount,
    required this.candidatesMissingEvidenceCount,
    required this.duplicateCandidateCount,
    required this.orphanedCandidateCount,
    required this.relationshipDensity,
    required this.averageEvidenceCoveragePercent,
  });

  final int candidateCount;
  final int relationshipCandidateCount;
  final int evidenceRegionCount;

  /// Candidates of type `procedure`.
  final int procedureCount;

  /// Candidates of type `specification`.
  final int specificationCount;

  /// Candidates whose `CandidateValidationResult.severity` is `error`.
  final int validationErrorCount;

  /// Candidates with zero linked Evidence Regions.
  final int candidatesMissingEvidenceCount;

  /// Candidates whose name collides (case-insensitively) with at least
  /// one other candidate in the session.
  final int duplicateCandidateCount;

  /// Candidates with no Evidence Links, no Relationship Candidates
  /// (as source or target), and no Procedure Step reference in either
  /// direction — completely disconnected from the rest of the
  /// Knowledge Session Graph. See `docs/KNOWLEDGE_GRAPH.md` § Session
  /// Health Model for why this reading of "orphaned" was chosen.
  final int orphanedCandidateCount;

  /// Relationship Candidates per Knowledge Candidate
  /// (`relationshipCandidateCount / candidateCount`), `0` if there are
  /// no candidates. See `docs/KNOWLEDGE_GRAPH.md` § Session Health
  /// Model for why this formula was chosen over a combinatorial
  /// "possible edges" density.
  final double relationshipDensity;

  /// The percentage of candidates with at least one linked Evidence
  /// Region, `0` if there are no candidates. See
  /// `docs/KNOWLEDGE_GRAPH.md` § Session Health Model for why
  /// "coverage" was read as a fraction-of-candidates-covered rather
  /// than an average link count per candidate.
  final double averageEvidenceCoveragePercent;
}
