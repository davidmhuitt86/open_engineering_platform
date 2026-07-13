import '../../graph/models/engineering_relationship.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Creates a relationship (ENGINE-TASK-000079).
class CreateRelationshipCommand implements EditingCommand {
  final EngineeringRelationship relationship;

  CreateRelationshipCommand(this.relationship);

  @override
  String get description => 'Connect nodes';

  @override
  EditingSession apply(EditingSession session) {
    return session.copyWith(graph: session.graph.withRelationship(relationship));
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(graph: session.graph.withoutRelationship(relationship.id));
  }
}
