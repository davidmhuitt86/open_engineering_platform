/// A Knowledge Curation Session's lifecycle state (Work Package 007
/// "Session Workflow": Created → Preparing → Reviewing → Ready to
/// Commit, or → Cancelled).
///
/// Deliberately narrower than SDD-017's full seven-stage Curation
/// Lifecycle (Preparation → Analysis → Review → Validation →
/// Repository Preview → Commit → Audit) — this work package explicitly
/// scopes out AI analysis, validation, and repository commit
/// ("Repository Commit is intentionally not implemented in this work
/// package"), so only the Studio-only portion of that lifecycle is
/// modeled here. See `docs/KNOWLEDGE_STUDIO.md` for how this maps onto
/// SDD-017's full lifecycle.
enum SessionStatus {
  created('Created'),
  preparing('Preparing'),
  reviewing('Reviewing'),
  readyToCommit('Ready to Commit'),
  cancelled('Cancelled');

  const SessionStatus(this.label);

  final String label;
}
