import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/knowledge_session_record.dart';
import '../models/ingestion_result.dart';

/// The UIF ↔ Knowledge Studio boundary (AP-INGEST-001 § 19, WP-INGEST-001
/// § 15): "The ingestion result should be capable of becoming/feeding a
/// Knowledge Studio session without losing provenance." "Do not create a
/// new review application. Use the existing Knowledge Curation Session
/// architecture."
///
/// This is the *entire* integration surface — a pure function from an
/// [IngestionResult] (plus the [KnowledgeSession] envelope a real session
/// needs: id/name/repository/author) to an ordinary
/// [KnowledgeSessionRecord], the exact same type
/// `KnowledgeSessionStorage.save`/`.load` already persist and every
/// existing Knowledge Studio UI (Candidate List, Evidence Browser,
/// Provenance Explorer, Commit Preview) already renders. Nothing here
/// creates a parallel review/session subsystem (AP-INGEST-001 § 35.4);
/// nothing here calls `CommitTransactionService`/`CommitPlanService`/
/// `FoundationBridge` (AP-INGEST-001 § 35.1) — nothing in this file even
/// imports them.
abstract final class IngestionKnowledgeSessionBridge {
  /// Builds a brand-new session record from [result] alone.
  static KnowledgeSessionRecord toNewSessionRecord({
    required IngestionResult result,
    required String sessionId,
    required String sessionName,
    required String repositoryName,
    required String author,
  }) {
    final now = DateTime.now();
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: sessionId,
        name: sessionName,
        repositoryName: repositoryName,
        author: author,
        description: 'Created by the Universal Ingestion Framework from run ${result.run.runId}.',
        createdTime: now,
        lastModified: now,
      ),
      candidates: result.knowledgeCandidates,
      relationshipCandidates: result.relationshipCandidates,
      sources: [result.source],
      evidenceRegions: result.evidenceRegions,
      evidenceLinks: result.evidenceLinks,
      ocrPageResults: result.ocrPageResults,
      engineeringEntities: result.engineeringEntities,
    );
  }

  /// Merges [result] into an already-existing [session] record — e.g. a
  /// second ingestion run contributing more candidates to a session an
  /// engineer is already reviewing. Every list is appended to, never
  /// replaced, so nothing already under human review is silently
  /// discarded.
  static KnowledgeSessionRecord mergeInto(KnowledgeSessionRecord session, IngestionResult result) {
    final alreadyHasSource = session.sources.any((source) => source.id == result.source.id);
    return KnowledgeSessionRecord(
      session: session.session.copyWith(lastModified: DateTime.now()),
      candidates: [...session.candidates, ...result.knowledgeCandidates],
      relationshipCandidates: [...session.relationshipCandidates, ...result.relationshipCandidates],
      sources: alreadyHasSource ? session.sources : [...session.sources, result.source],
      reviewDecisions: session.reviewDecisions,
      evidenceRegions: [...session.evidenceRegions, ...result.evidenceRegions],
      evidenceLinks: [...session.evidenceLinks, ...result.evidenceLinks],
      pageSelections: session.pageSelections,
      procedureSteps: session.procedureSteps,
      specificationDetails: session.specificationDetails,
      commitReports: session.commitReports,
      ocrPageResults: [...session.ocrPageResults, ...result.ocrPageResults],
      engineeringEntities: [...session.engineeringEntities, ...result.engineeringEntities],
      engineeringContexts: session.engineeringContexts,
      aiSuggestions: session.aiSuggestions,
    );
  }
}
