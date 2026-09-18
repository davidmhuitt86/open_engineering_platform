import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/knowledge_session_record.dart';
import '../../knowledge/models/source_material.dart';
import '../models/derived_artifact.dart';
import '../models/ingestion_result.dart';
import '../models/ingestion_run.dart';
import '../models/ingestion_stage.dart';
import '../models/normalized_ingestion_product.dart';

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
  /// [result.structuralData]'s corresponding [NormalizedIngestionProduct],
  /// if [result] actually produced a real `NormalizedDocument`
  /// (WP-INGEST-008 § 10) — an empty list otherwise.
  ///
  /// [IngestionOrchestrator] always populates `IngestionResult.structuralData`
  /// with *something*, even for a run that fails before parser output
  /// exists (a placeholder/unresolved document — see
  /// `IngestionOrchestrator._unresolvedDocument`'s own doc comment), so
  /// the field's mere presence can't distinguish a real product from a
  /// fabricated placeholder. The reliable signal is whether
  /// [result.derivedArtifacts] contains the STRUCTURAL_ANALYSIS artifact
  /// `IngestionOrchestrator` only ever creates once real parser output
  /// exists (alongside the CONTENT_EXTRACTION artifact, from the same
  /// `parserOutput.document`) — when it's absent, no meaningful
  /// normalized document exists for this run, so none is persisted
  /// (never a fabricated product for a failed run).
  ///
  /// References the STRUCTURAL_ANALYSIS artifact's id (rather than
  /// CONTENT_EXTRACTION's) as [NormalizedIngestionProduct.derivedArtifactId]:
  /// both are produced from the same `parserOutput.document` this product
  /// wraps, and structural analysis is the artifact whose own provenance
  /// (page geometry) most directly corresponds to the full document this
  /// wrapper carries, rather than duplicating both references.
  static List<NormalizedIngestionProduct> _normalizedProductsFor(IngestionResult result) {
    DerivedArtifact? structuralArtifact;
    for (final artifact in result.derivedArtifacts) {
      if (artifact.runId == result.run.runId && artifact.stage == IngestionStage.structuralAnalysis) {
        structuralArtifact = artifact;
        break;
      }
    }
    if (structuralArtifact == null) return const [];
    return [
      NormalizedIngestionProduct(
        runId: result.run.runId,
        derivedArtifactId: structuralArtifact.derivedArtifactId,
        document: result.structuralData,
      ),
    ];
  }


  /// Builds the minimal session record a run needs to exist *before*
  /// meaningful execution begins (WP-INGEST-007 § 7/§ 27/§ 28): a real
  /// session envelope plus exactly [queuedRun] (status QUEUED) in
  /// `ingestionRuns` -- every other list starts empty, since nothing
  /// else exists yet. The caller (`ReferenceVaultIngestionWorkflow`)
  /// persists this via `KnowledgeSessionStorage.save` immediately, so
  /// that if the application terminates before ingestion produces a
  /// result at all, this durable QUEUED/RUNNING record is what survives
  /// -- reconciled to FAILED on the next load by
  /// `IngestionRun.reconciledIfInterrupted`.
  static KnowledgeSessionRecord createQueuedSessionRecord({
    required String sessionId,
    required String sessionName,
    required String repositoryName,
    required String author,
    required IngestionRun queuedRun,
  }) {
    final now = DateTime.now();
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: sessionId,
        name: sessionName,
        repositoryName: repositoryName,
        author: author,
        description: 'Created by the Universal Ingestion Framework from run ${queuedRun.runId}.',
        createdTime: now,
        lastModified: now,
      ),
      ingestionRuns: [queuedRun],
    );
  }

  /// Replaces the entry in [record.ingestionRuns] whose `runId` matches
  /// [updatedRun] with [updatedRun] itself (WP-INGEST-007 § 6/§ 7) --
  /// used only to progress *the same execution attempt* through its own
  /// lifecycle (QUEUED -> RUNNING -> terminal), never to record a
  /// separate retry attempt (that is [mergeInto]'s job, which appends
  /// instead of replacing -- WP-INGEST-007 § 12/§ 23 historical
  /// immutability). If no entry with that `runId` exists yet (should not
  /// happen through the production workflow, but kept safe for direct
  /// callers/tests), [updatedRun] is appended instead of silently
  /// dropped.
  static KnowledgeSessionRecord withUpdatedRun(KnowledgeSessionRecord record, IngestionRun updatedRun) {
    final hasMatch = record.ingestionRuns.any((run) => run.runId == updatedRun.runId);
    return KnowledgeSessionRecord(
      session: record.session.copyWith(lastModified: DateTime.now()),
      candidates: record.candidates,
      relationshipCandidates: record.relationshipCandidates,
      sources: record.sources,
      reviewDecisions: record.reviewDecisions,
      evidenceRegions: record.evidenceRegions,
      evidenceLinks: record.evidenceLinks,
      pageSelections: record.pageSelections,
      procedureSteps: record.procedureSteps,
      specificationDetails: record.specificationDetails,
      commitReports: record.commitReports,
      ocrPageResults: record.ocrPageResults,
      engineeringEntities: record.engineeringEntities,
      engineeringContexts: record.engineeringContexts,
      aiSuggestions: record.aiSuggestions,
      ingestionRuns: hasMatch
          ? [for (final run in record.ingestionRuns) if (run.runId == updatedRun.runId) updatedRun else run]
          : [...record.ingestionRuns, updatedRun],
      derivedArtifacts: record.derivedArtifacts,
      normalizedProducts: record.normalizedProducts,
    );
  }

  /// Enriches [queuedRecord] (already persisted with [result]'s run in
  /// QUEUED/RUNNING state via [createQueuedSessionRecord]/
  /// [withUpdatedRun]) with [result]'s full products once execution
  /// reaches a terminal state -- same session identity/`createdTime`
  /// (unlike [toNewSessionRecord], which mints a brand-new session),
  /// with the in-progress run entry replaced by [result.run]'s terminal
  /// snapshot rather than appended as a second entry.
  static KnowledgeSessionRecord completeSessionRecord({
    required KnowledgeSessionRecord queuedRecord,
    required IngestionResult result,
  }) {
    return KnowledgeSessionRecord(
      session: queuedRecord.session.copyWith(lastModified: DateTime.now()),
      candidates: result.knowledgeCandidates,
      relationshipCandidates: result.relationshipCandidates,
      sources: [result.source],
      evidenceRegions: result.evidenceRegions,
      evidenceLinks: result.evidenceLinks,
      ocrPageResults: result.ocrPageResults,
      engineeringEntities: result.engineeringEntities,
      ingestionRuns: IngestionKnowledgeSessionBridge.withUpdatedRun(queuedRecord, result.run).ingestionRuns,
      derivedArtifacts: result.derivedArtifacts,
      normalizedProducts: _normalizedProductsFor(result),
    );
  }

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
      // WP-INGEST-006 § 7/§ 11: the durable link from this session to the
      // ingestion run/execution history that produced it.
      ingestionRuns: [result.run],
      derivedArtifacts: result.derivedArtifacts,
      normalizedProducts: _normalizedProductsFor(result),
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
      // WP-INGEST-006 § 7/§ 11: a second ingestion run contributing to an
      // already-existing session appends its own run/derived-artifact
      // history rather than replacing what is already there — the same
      // "append, never replace" discipline every other list above
      // already follows.
      ingestionRuns: [...session.ingestionRuns, result.run],
      derivedArtifacts: [...session.derivedArtifacts, ...result.derivedArtifacts],
      normalizedProducts: [...session.normalizedProducts, ..._normalizedProductsFor(result)],
    );
  }

  /// Returns [record] with its `sources` list replaced by exactly
  /// [sessionOwnedSource] (WP-INGEST-005) -- used by
  /// `ReferenceVaultIngestionWorkflow` once
  /// `SourceMaterialService.attachIngestedSource` has copied the ingested
  /// file into `KnowledgeSessionStorage`, so `KnowledgeSessionRecord.sources`
  /// never keeps referencing `ReferenceVaultAdapter`'s temporary ingestion
  /// path. [sessionOwnedSource] must carry the same `SourceMaterial.id` as
  /// the source it replaces -- callers get that for free from
  /// `attachIngestedSource`, which preserves the id exactly.
  ///
  /// Every other field is preserved unchanged, via the same explicit
  /// field-by-field reconstruction [mergeInto] already uses -- there is no
  /// `KnowledgeSessionRecord.copyWith` to reuse instead.
  static KnowledgeSessionRecord withReplacedSource(
    KnowledgeSessionRecord record,
    SourceMaterial sessionOwnedSource,
  ) {
    return KnowledgeSessionRecord(
      session: record.session,
      candidates: record.candidates,
      relationshipCandidates: record.relationshipCandidates,
      sources: [sessionOwnedSource],
      reviewDecisions: record.reviewDecisions,
      evidenceRegions: record.evidenceRegions,
      evidenceLinks: record.evidenceLinks,
      pageSelections: record.pageSelections,
      procedureSteps: record.procedureSteps,
      specificationDetails: record.specificationDetails,
      commitReports: record.commitReports,
      ocrPageResults: record.ocrPageResults,
      engineeringEntities: record.engineeringEntities,
      engineeringContexts: record.engineeringContexts,
      aiSuggestions: record.aiSuggestions,
      ingestionRuns: record.ingestionRuns,
      derivedArtifacts: record.derivedArtifacts,
      normalizedProducts: record.normalizedProducts,
    );
  }
}
