/// A [KnowledgeCandidate]'s status within its owning Knowledge
/// Curation Session (Work Package 007: "Each proposal supports:
/// Accept, Reject, Edit, Delete"). Deliberately narrower than
/// SDD-020's full Decision Options (Accept/Reject/Merge/Edit/Postpone/
/// Duplicate) — this workspace's manual workflow doesn't implement
/// repository matching, so Merge/Duplicate/Postpone have nothing to
/// act against yet.
enum KnowledgeCandidateStatus {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected');

  const KnowledgeCandidateStatus(this.label);

  final String label;
}
