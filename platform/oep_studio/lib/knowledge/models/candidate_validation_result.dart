/// A Knowledge Candidate's computed validation severity (Work Package
/// 010 STUDIO-TASK-000025). `error` covers findings that would block a
/// future Repository Commit (once Repository Commit exists — it is not
/// implemented by this work package); `warning` covers findings that
/// are incomplete but not structurally invalid.
enum ValidationSeverity { ok, warning, error }

/// The result of validating one Knowledge Candidate (Work Package 010:
/// "Display validation status for every Knowledge Candidate."). Always
/// computed fresh from the session's current candidates/relationship
/// candidates/evidence links/procedure steps by
/// `KnowledgeSessionService.computeCandidateValidation` — never stored
/// on the candidate and never persisted to `session.json` (Work Package
/// 010: "Validation shall never modify candidate data."), the same
/// derived-not-stored discipline `CommitPreview` already established
/// for the session as a whole.
class CandidateValidationResult {
  const CandidateValidationResult({required this.candidateId, required this.severity, required this.issues});

  final String candidateId;
  final ValidationSeverity severity;

  /// Human-readable findings, worst-first — empty only when [severity]
  /// is [ValidationSeverity.ok].
  final List<String> issues;
}
