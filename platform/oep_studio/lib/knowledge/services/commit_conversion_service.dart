import '../../core/models/object_category.dart';
import '../../core/models/relationship_type.dart';
import '../models/knowledge_candidate.dart';
import '../models/relationship_candidate.dart';

/// The Foundation Bridge call arguments for creating one Engineering
/// Object — everything `FoundationBridge.createObject` needs, computed
/// ahead of time and kept pure so it can be unit-tested without a real
/// Bridge.
class ObjectCreateArgs {
  const ObjectCreateArgs({
    required this.category,
    required this.name,
    required this.description,
    required this.author,
    required this.tags,
  });

  final ObjectCategory category;
  final String name;
  final String description;
  final String author;
  final List<String> tags;
}

/// The Foundation Bridge call arguments for creating one Relationship.
class RelationshipCreateArgs {
  const RelationshipCreateArgs({
    required this.sourceObjectId,
    required this.targetObjectId,
    required this.type,
    required this.author,
    required this.description,
  });

  final String sourceObjectId;
  final String targetObjectId;
  final RelationshipType type;
  final String author;
  final String description;
}

/// Pure Knowledge Workspace → Foundation conversion logic (Work
/// Package 012 STUDIO-TASK-000031). Holds no state and performs no
/// Foundation I/O — it only computes the *arguments* a later call to
/// `FoundationBridge.createObject`/`createRelationship` needs.
/// `CommitTransactionService` is what actually calls the Bridge.
abstract final class CommitConversionService {
  /// Tags identifying which Knowledge Candidate/session produced a
  /// committed Engineering Object — "Only provenance references
  /// transfer" (this work package's own text). No Evidence Region
  /// coordinate, no Source Material file, no PDF, and no other
  /// Workspace-only data ever crosses into these tags or any other
  /// argument this service builds — just the two IDs needed to trace a
  /// Foundation object back to the Knowledge Curation Session that
  /// produced it.
  static const candidateTagPrefix = 'knowledge-candidate:';
  static const sessionTagPrefix = 'knowledge-session:';

  /// Builds the [ObjectCreateArgs] for [candidate]. Throws
  /// [ArgumentError] if [candidate.type] has no
  /// [KnowledgeCandidateType.foundationCategory] — callers (only
  /// `CommitTransactionService`) must only invoke this for candidates
  /// `CommitPlanService` already included in [CommitPlan.newObjects],
  /// which is already filtered to mapped types; this is a defensive
  /// invariant check, not a user-facing validation path.
  static ObjectCreateArgs toObjectCreateArgs(KnowledgeCandidate candidate, {required String sessionId, required String sessionAuthor}) {
    final category = candidate.type.foundationCategory;
    if (category == null) {
      throw ArgumentError(
        'Candidate ${candidate.id} has no Foundation object type mapping for ${candidate.type.name}.',
      );
    }
    return ObjectCreateArgs(
      category: category,
      name: candidate.name,
      description: _mergeDescriptionAndNotes(candidate.description, candidate.notes),
      author: candidate.author.trim().isEmpty ? sessionAuthor : candidate.author,
      tags: [
        ...candidate.tags,
        '$candidateTagPrefix${candidate.id}',
        '$sessionTagPrefix$sessionId',
      ],
    );
  }

  /// Foundation's Engineering Object model has no field distinct from
  /// `description` for [KnowledgeCandidate.notes] ("Preserve: ...
  /// Notes") — modifying Foundation to add one is out of scope ("Do not
  /// modify OEP Foundation"). Notes are appended to the description
  /// rather than dropped, the same lossless-within-existing-fields
  /// approach Work Package 012's Requirements imply by listing Notes
  /// alongside Author/Tags/Repository ownership as things to preserve
  /// without specifying a mechanism.
  static String _mergeDescriptionAndNotes(String description, String notes) {
    final trimmedNotes = notes.trim();
    if (trimmedNotes.isEmpty) return description;
    if (description.trim().isEmpty) return 'Notes: $trimmedNotes';
    return '$description\n\nNotes: $trimmedNotes';
  }

  /// Builds the [RelationshipCreateArgs] for [relationship]. [sourceObjectId]/
  /// [targetObjectId] are the Foundation object IDs its endpoints
  /// resolved to — computed by the caller (`CommitTransactionService`),
  /// since only it tracks which candidate became which object_id during
  /// a commit in progress. [RelationshipCandidate] carries no author
  /// field of its own (Work Package 008 never added one), so
  /// [sessionAuthor] is used directly.
  static RelationshipCreateArgs toRelationshipCreateArgs(
    RelationshipCandidate relationship, {
    required String sourceObjectId,
    required String targetObjectId,
    required String sessionAuthor,
  }) {
    return RelationshipCreateArgs(
      sourceObjectId: sourceObjectId,
      targetObjectId: targetObjectId,
      type: relationship.type,
      author: sessionAuthor,
      description: relationship.description,
    );
  }
}
