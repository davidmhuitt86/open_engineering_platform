import '../models/engineering_graph.dart';

/// Pure, live validity check for a proposed connection — used to drive
/// drag-to-connect preview feedback (valid/invalid) *before* a
/// `CreateRelationshipCommand` commits (WORK_PACKAGE_022,
/// ENGINE-TASK-000093). Distinct from `ValidationService`, which reports
/// on an already-committed graph; this answers "would creating this
/// relationship right now be valid?"
///
/// Rules, exactly as specified: no self-loops, no duplicate relationships
/// (same source+target pair, in either direction).
class ConnectionValidator {
  ConnectionValidator._();

  static bool canConnect(EngineeringGraph graph, String sourceNodeId, String targetNodeId) {
    if (sourceNodeId == targetNodeId) return false;
    final isDuplicate = graph.relationships.values.any((r) =>
        (r.sourceNode == sourceNodeId && r.targetNode == targetNodeId) ||
        (r.sourceNode == targetNodeId && r.targetNode == sourceNodeId));
    return !isDuplicate;
  }
}
