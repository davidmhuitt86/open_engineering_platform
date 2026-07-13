import '../../graph/models/engineering_relationship.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Re-points a relationship's source and/or target node (ENGINE-TASK-000079:
/// "Reconnect Relationship").
class ReconnectRelationshipCommand implements EditingCommand {
  final String relationshipId;
  final String? newSourceNode;
  final String? newTargetNode;

  EngineeringRelationship? _original;

  ReconnectRelationshipCommand(
    this.relationshipId, {
    this.newSourceNode,
    this.newTargetNode,
  });

  @override
  String get description => 'Reconnect relationship';

  @override
  EditingSession apply(EditingSession session) {
    final original = session.graph.relationships[relationshipId];
    if (original == null) return session;
    _original = original;
    final reconnected = EngineeringRelationship(
      id: original.id,
      relationshipType: original.relationshipType,
      sourceNode: newSourceNode ?? original.sourceNode,
      targetNode: newTargetNode ?? original.targetNode,
      repositoryRelationshipId: original.repositoryRelationshipId,
      metadata: original.metadata,
      evidenceLinks: original.evidenceLinks,
      runtime: original.runtime,
    );
    return session.copyWith(graph: session.graph.withRelationship(reconnected));
  }

  @override
  EditingSession revert(EditingSession session) {
    final original = _original;
    if (original == null) return session;
    return session.copyWith(graph: session.graph.withRelationship(original));
  }
}
