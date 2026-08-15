import '../../core/foundation/oep_api_types.dart';
import '../../core/models/object_category.dart';
import '../../core/models/relationship_type.dart';

/// One Engineering Object created by a Repository Commit (Work Package
/// 012 STUDIO-TASK-000033's "Objects Created"), pairing the originating
/// Knowledge Candidate with the Foundation object it became.
class CommittedObjectRecord {
  const CommittedObjectRecord({
    required this.candidateId,
    required this.objectId,
    required this.name,
    required this.category,
  });

  final String candidateId;
  final String objectId;
  final String name;
  final ObjectCategory category;

  Map<String, dynamic> toJson() => {
    'candidateId': candidateId,
    'objectId': objectId,
    'name': name,
    'category': category.name,
  };

  factory CommittedObjectRecord.fromJson(Map<String, dynamic> json) {
    return CommittedObjectRecord(
      candidateId: json['candidateId'] as String,
      objectId: json['objectId'] as String,
      name: json['name'] as String,
      category: ObjectCategory.values.byName(json['category'] as String),
    );
  }
}

/// One Relationship created by a Repository Commit ("Relationships
/// Created"), pairing the originating Relationship Candidate with the
/// Foundation relationship it became.
class CommittedRelationshipRecord {
  const CommittedRelationshipRecord({
    required this.relationshipCandidateId,
    required this.relationshipId,
    required this.sourceObjectId,
    required this.targetObjectId,
    required this.type,
  });

  final String relationshipCandidateId;
  final String relationshipId;
  final String sourceObjectId;
  final String targetObjectId;
  final RelationshipType type;

  Map<String, dynamic> toJson() => {
    'relationshipCandidateId': relationshipCandidateId,
    'relationshipId': relationshipId,
    'sourceObjectId': sourceObjectId,
    'targetObjectId': targetObjectId,
    'type': type.name,
  };

  factory CommittedRelationshipRecord.fromJson(Map<String, dynamic> json) {
    return CommittedRelationshipRecord(
      relationshipCandidateId: json['relationshipCandidateId'] as String,
      relationshipId: json['relationshipId'] as String,
      sourceObjectId: json['sourceObjectId'] as String,
      targetObjectId: json['targetObjectId'] as String,
      type: RelationshipType.values.byName(json['type'] as String),
    );
  }
}

/// The outcome of one Repository Commit attempt (Work Package 012
/// STUDIO-TASK-000033) — "Display the outcome of Repository Commit."
/// Unlike `CommitPlan` (recomputed fresh on every read), a
/// `CommitReport` is the record of something that actually happened
/// (or was attempted and failed); the Connection Manager holds a
/// growing, append-only list of these
/// (`FoundationServiceState.commitReports`, mirroring `ReviewDecision`'s
/// append-only audit-log pattern from Work Package 008) rather than
/// recomputing it, and it is persisted with the session — "Sessions
/// become historical engineering records" (this work package's own
/// text) requires the record of what was actually committed to survive
/// a restart, not just what the *next* commit would do.
///
/// [success] is `false` for a failed/rolled-back commit attempt — the
/// report still exists ("Report the error") but [objectsCreated]/
/// [relationshipsCreated] are always empty in that case (the
/// transaction left the repository unchanged) and [errors] explains
/// why.
class CommitReport {
  const CommitReport({
    required this.id,
    required this.success,
    required this.objectsCreated,
    required this.relationshipsCreated,
    required this.objectsMergedCount,
    required this.warnings,
    required this.errors,
    required this.durationMs,
    required this.statisticsBefore,
    required this.statisticsAfter,
    required this.timestamp,
  });

  final String id;
  final bool success;
  final List<CommittedObjectRecord> objectsCreated;
  final List<CommittedRelationshipRecord> relationshipsCreated;

  /// Always `0` — see `CommitPlan.mergeOperationCount`.
  final int objectsMergedCount;
  final List<String> warnings;

  /// Empty on success; one or more professional, non-technical messages
  /// on failure (never a raw native `technicalDetail` — see
  /// `FoundationBridgeException`'s own translation rule, which this
  /// report's errors always go through first).
  final List<String> errors;

  final int durationMs;
  final RepositoryStatistics? statisticsBefore;
  final RepositoryStatistics? statisticsAfter;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'success': success,
    'objectsCreated': objectsCreated.map((record) => record.toJson()).toList(),
    'relationshipsCreated': relationshipsCreated.map((record) => record.toJson()).toList(),
    'objectsMergedCount': objectsMergedCount,
    'warnings': warnings,
    'errors': errors,
    'durationMs': durationMs,
    'statisticsBefore': statisticsBefore?.toJson(),
    'statisticsAfter': statisticsAfter?.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory CommitReport.fromJson(Map<String, dynamic> json) {
    final objectsJson = json['objectsCreated'] as List<dynamic>? ?? const [];
    final relationshipsJson = json['relationshipsCreated'] as List<dynamic>? ?? const [];
    return CommitReport(
      id: json['id'] as String,
      success: json['success'] as bool,
      objectsCreated: [
        for (final entry in objectsJson) CommittedObjectRecord.fromJson(entry as Map<String, dynamic>),
      ],
      relationshipsCreated: [
        for (final entry in relationshipsJson) CommittedRelationshipRecord.fromJson(entry as Map<String, dynamic>),
      ],
      objectsMergedCount: json['objectsMergedCount'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>?)?.map((entry) => entry as String).toList() ?? const [],
      errors: (json['errors'] as List<dynamic>?)?.map((entry) => entry as String).toList() ?? const [],
      durationMs: json['durationMs'] as int,
      statisticsBefore: json['statisticsBefore'] == null
          ? null
          : RepositoryStatistics.fromJson(json['statisticsBefore'] as Map<String, dynamic>),
      statisticsAfter: json['statisticsAfter'] == null
          ? null
          : RepositoryStatistics.fromJson(json['statisticsAfter'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
