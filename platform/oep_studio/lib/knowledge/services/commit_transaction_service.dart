import '../../core/foundation/foundation_bridge.dart';
import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import 'commit_conversion_service.dart';
import '../models/commit_plan.dart';
import '../models/commit_report.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_session.dart';
import 'knowledge_session_service.dart';

/// Commit Transaction orchestration (Work Package 012 STUDIO-TASK-000032):
/// "Repository Commit shall execute as one logical transaction. If any
/// operation fails: Stop Commit, Report the error, Leave the repository
/// unchanged." Unlike `CommitPlanService`/`CommitConversionService`,
/// this service is not pure — executing a commit *is* Foundation I/O —
/// but it is still a service, not the Connection Manager: only
/// `FoundationRuntimeNotifier` calls it, and it is the only place in
/// Studio (besides `FoundationBridge` itself) that calls
/// `oep_transaction_*`/`oep_object_create`/`oep_relationship_create`.
abstract final class CommitTransactionService {
  /// Executes [plan] against [bridge] inside one Foundation transaction
  /// and returns the resulting [CommitReport]. [allCandidates] is the
  /// session's *complete* candidate list (not just [plan.newObjects]) —
  /// needed to resolve the Foundation object id of a Relationship
  /// Candidate endpoint that was committed in an *earlier* commit of
  /// this same session, not this one.
  ///
  /// On any failure — a Foundation mutation failing (which
  /// automatically rolls back and deactivates the transaction per
  /// `oep_api.h`'s own documented contract) or any other exception —
  /// this method still returns a (failed) [CommitReport] rather than
  /// throwing; the caller does not need its own try/catch to keep the
  /// Knowledge Session open. [CommitReport.errors] never contains a raw
  /// native error string — every Foundation failure is translated by
  /// [FoundationBridgeException] first, the same rule every other
  /// Foundation-facing call in Studio follows.
  static CommitReport execute({
    required FoundationBridge bridge,
    required CommitPlan plan,
    required KnowledgeSession session,
    required List<KnowledgeCandidate> allCandidates,
  }) {
    final reportId = KnowledgeSessionService.generateId('commit');
    final stopwatch = Stopwatch()..start();

    RepositoryStatistics? statisticsBefore;
    try {
      statisticsBefore = bridge.getRepositoryStatistics();
    } on FoundationBridgeException {
      statisticsBefore = null;
    }

    // Pre-seed with candidates already committed by an earlier commit of
    // this session, so a relationship connecting to one of them (not
    // itself part of `plan.newObjects`) can still resolve its endpoint.
    final objectIdByCandidateId = <String, String>{
      for (final candidate in allCandidates)
        if (candidate.committedObjectId != null) candidate.id: candidate.committedObjectId!,
    };
    final objectNameById = <String, String>{
      for (final candidate in allCandidates)
        if (candidate.committedObjectId != null) candidate.committedObjectId!: candidate.name,
    };
    final objectsCreated = <CommittedObjectRecord>[];
    final relationshipsCreated = <CommittedRelationshipRecord>[];

    try {
      bridge.beginTransaction();

      for (final candidate in plan.newObjects) {
        final args = CommitConversionService.toObjectCreateArgs(
          candidate,
          sessionId: session.id,
          sessionAuthor: session.author,
        );
        final created = bridge.createObject(
          category: args.category,
          name: args.name,
          description: args.description,
          author: args.author,
          tags: args.tags,
        );
        objectIdByCandidateId[candidate.id] = created.objectId;
        objectNameById[created.objectId] = created.name;
        objectsCreated.add(
          CommittedObjectRecord(
            candidateId: candidate.id,
            objectId: created.objectId,
            name: created.name,
            category: created.category,
          ),
        );
      }

      for (final relationship in plan.newRelationships) {
        final sourceObjectId = objectIdByCandidateId[relationship.sourceCandidateId];
        final targetObjectId = objectIdByCandidateId[relationship.targetCandidateId];
        if (sourceObjectId == null || targetObjectId == null) {
          // Defensive only — CommitPlanService already restricts
          // plan.newRelationships to endpoints it confirmed are
          // resolvable. Treated as a commit failure (not skipped)
          // since silently omitting a relationship the plan promised
          // would violate "The Commit Plan represents exactly what
          // Foundation will receive."
          throw StateError('Relationship candidate ${relationship.id} has an unresolved endpoint.');
        }
        final args = CommitConversionService.toRelationshipCreateArgs(
          relationship,
          sourceObjectId: sourceObjectId,
          targetObjectId: targetObjectId,
          sessionAuthor: session.author,
        );
        final created = bridge.createRelationship(
          sourceObjectId: args.sourceObjectId,
          targetObjectId: args.targetObjectId,
          type: args.type,
          author: args.author,
          description: args.description,
          objectNamesById: objectNameById,
        );
        relationshipsCreated.add(
          CommittedRelationshipRecord(
            relationshipCandidateId: relationship.id,
            relationshipId: created.relationshipId,
            sourceObjectId: sourceObjectId,
            targetObjectId: targetObjectId,
            type: relationship.type,
          ),
        );
      }

      bridge.commitTransaction();
      stopwatch.stop();

      RepositoryStatistics? statisticsAfter;
      try {
        statisticsAfter = bridge.getRepositoryStatistics();
      } on FoundationBridgeException {
        statisticsAfter = statisticsBefore;
      }

      return CommitReport(
        id: reportId,
        success: true,
        objectsCreated: objectsCreated,
        relationshipsCreated: relationshipsCreated,
        objectsMergedCount: 0,
        warnings: plan.warnings,
        errors: const [],
        durationMs: stopwatch.elapsedMilliseconds,
        statisticsBefore: statisticsBefore,
        statisticsAfter: statisticsAfter,
        timestamp: DateTime.now(),
      );
    } on FoundationBridgeException catch (error) {
      stopwatch.stop();
      _safeRollback(bridge);
      return CommitReport(
        id: reportId,
        success: false,
        objectsCreated: const [],
        relationshipsCreated: const [],
        objectsMergedCount: 0,
        warnings: plan.warnings,
        errors: [error.message],
        durationMs: stopwatch.elapsedMilliseconds,
        statisticsBefore: statisticsBefore,
        statisticsAfter: statisticsBefore,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      _safeRollback(bridge);
      return CommitReport(
        id: reportId,
        success: false,
        objectsCreated: const [],
        relationshipsCreated: const [],
        objectsMergedCount: 0,
        warnings: plan.warnings,
        errors: const ['Something went wrong while committing to OEP Foundation. Please try again.'],
        durationMs: stopwatch.elapsedMilliseconds,
        statisticsBefore: statisticsBefore,
        statisticsAfter: statisticsBefore,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Best-effort rollback for a failure that did *not* go through a
  /// Foundation mutation function (which already auto-rolls-back per
  /// `oep_api.h`'s documented contract) — e.g. the defensive
  /// [StateError] above. Swallows any [FoundationBridgeException] from
  /// the rollback call itself: the repository is torn down or the
  /// transaction already inactive either way, and the original failure
  /// is what the caller needs reported, not a secondary one from
  /// cleanup.
  static void _safeRollback(FoundationBridge bridge) {
    try {
      if (bridge.isTransactionActive) {
        bridge.rollbackTransaction();
      }
    } on FoundationBridgeException {
      // Best-effort only.
    }
  }
}
