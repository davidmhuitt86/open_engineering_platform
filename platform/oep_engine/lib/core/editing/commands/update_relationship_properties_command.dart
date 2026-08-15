import '../editing_command.dart';
import '../editing_session.dart';

/// Merges a metadata patch into a relationship (ENGINE-TASK-000085).
/// `null` values in [patch] remove the key.
class UpdateRelationshipPropertiesCommand implements EditingCommand {
  final String relationshipId;
  final Map<String, Object?> patch;

  Map<String, Object?>? _previousMetadata;

  UpdateRelationshipPropertiesCommand(this.relationshipId, this.patch);

  @override
  String get description => 'Update relationship properties';

  @override
  EditingSession apply(EditingSession session) {
    final relationship = session.graph.relationships[relationshipId];
    if (relationship == null) return session;
    _previousMetadata = relationship.metadata;
    final merged = Map<String, Object?>.from(relationship.metadata);
    patch.forEach((key, value) {
      if (value == null) {
        merged.remove(key);
      } else {
        merged[key] = value;
      }
    });
    return session.copyWith(
      graph: session.graph
          .withRelationship(relationship.copyWith(metadata: merged)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousMetadata;
    final relationship = session.graph.relationships[relationshipId];
    if (previous == null || relationship == null) return session;
    return session.copyWith(
      graph: session.graph
          .withRelationship(relationship.copyWith(metadata: previous)),
    );
  }
}
