/// Kinds of internal engine events (SDD-026: "Node Selected, Relationship
/// Added, Graph Changed, Simulation Started, Validation Complete, Evidence
/// Selected").
enum EngineEventKind {
  nodeSelected,
  relationshipAdded,
  graphChanged,
  simulationStarted,
  validationComplete,
  evidenceSelected,
}

/// A single internal engine event. "Events remain internal to the
/// Engineering Engine" (SDD-026) — this type is not part of the public
/// service surface; providers/services consume it directly, and public
/// services (e.g. [SelectionProvider.changes], [NavigationProvider.events])
/// expose their own narrower, typed streams to external consumers.
class EngineEvent {
  final EngineEventKind kind;
  final String? graphId;
  final String? subjectId;
  final Map<String, Object?> payload;
  final DateTime timestamp;

  EngineEvent({
    required this.kind,
    this.graphId,
    this.subjectId,
    this.payload = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
