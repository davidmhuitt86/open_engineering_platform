import '../../graph/models/engineering_relationship.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Deletes a relationship, capturing it for [revert] (ENGINE-TASK-000079).
class DeleteRelationshipCommand implements EditingCommand {
  final String relationshipId;

  EngineeringRelationship? _removed;

  DeleteRelationshipCommand(this.relationshipId);

  @override
  String get description => 'Delete relationship';

  @override
  EditingSession apply(EditingSession session) {
    _removed = session.graph.relationships[relationshipId];
    return session.copyWith(graph: session.graph.withoutRelationship(relationshipId));
  }

  @override
  EditingSession revert(EditingSession session) {
    final removed = _removed;
    if (removed == null) return session;
    return session.copyWith(graph: session.graph.withRelationship(removed));
  }
}
