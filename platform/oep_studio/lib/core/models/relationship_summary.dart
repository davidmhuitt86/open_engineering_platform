import '../foundation/oep_api_native_types.dart';
import '../foundation/oep_api_types.dart';
import 'relationship_type.dart';

/// A read-only summary of a Relationship, as the Relationship Explorer
/// (STUDIO-TASK-000009/000011) and Property Inspector display it.
///
/// Mirrors `oep_relationship_info_t` (`oep_api.h`, Work Package 013)
/// field-for-field, except Foundation's struct stores only
/// [sourceObjectId]/[targetObjectId] — no display name. [sourceObjectName]/
/// [targetObjectName] are resolved by [fromNative] against the caller's
/// already-fetched Current Object List (a Studio-side join across two
/// Foundation-returned lists, not independent business logic), falling
/// back to the raw ID if the object can't be found there.
class RelationshipSummary {
  const RelationshipSummary({
    required this.relationshipId,
    required this.sourceObjectId,
    required this.targetObjectId,
    required this.sourceObjectName,
    required this.targetObjectName,
    required this.type,
    required this.author,
    this.description = '',
    this.createdUtc = '',
  });

  /// Decodes an `oep_relationship_info_t` (via [OepRelationshipInfoNative])
  /// into a plain Dart model. [objectNamesById] maps `object_id` ->
  /// display name, built from the Current Object List; a missing entry
  /// (e.g. the object list failed to load independently) degrades to
  /// showing the raw ID rather than a blank or fabricated name.
  factory RelationshipSummary.fromNative(
    OepRelationshipInfoNative native, {
    required Map<String, String> objectNamesById,
  }) {
    final sourceId = decodeFixedCString(native.sourceObjectId, oepMaxObjectId);
    final targetId = decodeFixedCString(native.targetObjectId, oepMaxObjectId);
    return RelationshipSummary(
      relationshipId: decodeFixedCString(native.relationshipId, oepMaxRelationshipId),
      sourceObjectId: sourceId,
      targetObjectId: targetId,
      sourceObjectName: objectNamesById[sourceId] ?? sourceId,
      targetObjectName: objectNamesById[targetId] ?? targetId,
      type: RelationshipType.fromNative(native.relationshipType),
      author: decodeFixedCString(native.author, oepMaxObjectAuthor),
      description: decodeFixedCString(native.description, oepMaxObjectDescription),
      createdUtc: decodeFixedCString(native.createdUtc, oepMaxTimestamp),
    );
  }

  final String relationshipId;

  /// The source Engineering Object's `object_id`, used to navigate to it
  /// ("Go To Source", STUDIO-TASK-000011) — resolving a name is a
  /// display concern, but navigation needs the real ID.
  final String sourceObjectId;
  final String targetObjectId;

  /// Display name of the source Engineering Object, resolved at decode
  /// time (see [fromNative]).
  final String sourceObjectName;
  final String targetObjectName;
  final RelationshipType type;
  final String author;
  final String description;
  final String createdUtc;
}
