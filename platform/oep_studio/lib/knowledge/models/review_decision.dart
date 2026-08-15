/// The kind of action a [ReviewDecision] records.
enum ReviewDecisionKind {
  created('Created'),
  edited('Edited'),
  accepted('Accepted'),
  rejected('Rejected'),
  deleted('Deleted');

  const ReviewDecisionKind(this.label);

  final String label;
}

/// A permanent record of one action taken against a Knowledge
/// Candidate during review (Work Package 008 STUDIO-TASK-000015
/// Persist: "Review Decisions"; SDD-017 Stage 3 Review: "Every
/// decision is recorded. Rejected proposals remain part of the
/// session history."; SDD-018 "Engineering Decisions ... Every
/// decision records: Who, When, Why, Evidence").
///
/// Append-only — a session's decision history is never edited or
/// truncated, including for candidates later deleted ([candidateName]
/// is a snapshot taken at decision time for exactly this reason, since
/// the candidate itself may no longer exist to look the name up from).
/// [reason]/evidence capture ("Why") has no UI in this work package —
/// nothing prompts the engineer for one — so it is always `null`
/// rather than a placeholder empty string masquerading as "no reason
/// given"; the field exists now because the decision record's shape
/// shouldn't need to change shape once a reason-capture UI exists.
class ReviewDecision {
  const ReviewDecision({
    required this.candidateId,
    required this.candidateName,
    required this.kind,
    required this.timestamp,
    required this.reviewer,
    this.reason,
  });

  final String candidateId;
  final String candidateName;
  final ReviewDecisionKind kind;
  final DateTime timestamp;
  final String reviewer;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'candidateId': candidateId,
    'candidateName': candidateName,
    'kind': kind.name,
    'timestamp': timestamp.toIso8601String(),
    'reviewer': reviewer,
    'reason': reason,
  };

  factory ReviewDecision.fromJson(Map<String, dynamic> json) {
    return ReviewDecision(
      candidateId: json['candidateId'] as String,
      candidateName: json['candidateName'] as String,
      kind: ReviewDecisionKind.values.byName(json['kind'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      reviewer: json['reviewer'] as String,
      reason: json['reason'] as String?,
    );
  }
}
