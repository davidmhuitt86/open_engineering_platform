import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../knowledge/models/engineering_entity.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/ocr_page_result.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../models/derived_artifact.dart';
import '../models/ingestion_provenance.dart';
import '../models/ingestion_stage.dart';
import '../models/normalized_document.dart';

/// Operationalizes the `DerivedArtifact` contract AP-INGEST-001 § 15
/// defines structurally and WP-INGEST-001 § 8 implemented as a model with
/// no producer (WP-INGEST-002 § 5 gap). One static factory method per
/// stage the WP-INGEST-002 § 12 product mapping selects; each returns a
/// real, populated [DerivedArtifact] with every field WP-INGEST-002 § 17
/// requires (`derivedArtifactId`, `runId`, `vaultObjectId`, `stage`,
/// `artifactType`, `contentHash`, `createdAt`, `processorId`,
/// `processorVersion`, `provenance`).
///
/// **Product mapping (WP-INGEST-002 § 12), and what is deliberately
/// excluded:**
///
/// ```text
/// CONTENT_EXTRACTION    -> normalized content artifact     (contentExtractionArtifact)
/// STRUCTURAL_ANALYSIS   -> normalized structural artifact  (structuralAnalysisArtifact)
/// OCR                   -> one OCR-derived artifact per successful OcrPageResult (ocrPageArtifact)
/// ENTITY_EXTRACTION     -> entity extraction artifact      (entityExtractionArtifact)
/// RELATIONSHIP_EXTRACTION -> relationship extraction artifact (relationshipExtractionArtifact)
/// CANDIDATE_GENERATION  -> candidate-generation artifact   (candidateGenerationArtifact)
/// ```
///
/// `IDENTIFY`, `PARSER_SELECTION`, and `METADATA_EXTRACTION` intentionally
/// produce no [DerivedArtifact]: `IDENTIFY`/`PARSER_SELECTION` are
/// orchestration *decisions* (which parser was chosen), not extracted
/// content, and normalized metadata (`NormalizedMetadata`) is not a
/// separate materialized product — it already travels as a field of the
/// same `NormalizedDocument` the content/structural artifacts below
/// represent, so wrapping it as its own `DerivedArtifact` would duplicate
/// rather than add traceability (WP-INGEST-002 § 17: "If a product cannot
/// legitimately satisfy those fields... document the reason" — here the
/// reason is redundancy, not a missing field). A failed OCR page likewise
/// produces no artifact: it produced no content, only a diagnostic
/// already carried on the OCR `StageResult`.
///
/// **Identity (WP-INGEST-002 § 7).** `derivedArtifactId` is a deterministic
/// digest of `runId + stage + processorId + processorVersion + contentHash
/// (+ page, where page-scoped)` — never a random UUID, so the exact same
/// processing identity reproducibly yields the exact same id
/// (WP-INGEST-002 § 21 "Tests must compare meaningful output, not
/// incidental runtime identity" / § 7 "Do not require random UUIDs for
/// reproducibility"). Because the id is derived from the *processing
/// identity* (which includes `runId`), a differently-identified run (new
/// `runId`, changed processor/parser version, or changed content) always
/// produces a different id rather than colliding with — and thus never
/// silently overwriting — a prior run's artifact (WP-INGEST-002 § 22/§ 23
/// Regeneration/Immutability). See this work package's AAR "Persistence
/// Decision" section for why no separate overwrite-prevention store is
/// needed: nothing in this codebase persists a keyed table of
/// `DerivedArtifact`s that a second run could overwrite in the first
/// place — every `IngestionOrchestrator.run` call returns its own fresh,
/// independent `IngestionResult`.
abstract final class DerivedArtifactFactory {
  static String _sha256Of(String content) => sha256.convert(utf8.encode(content)).toString();

  static String _derivedArtifactId({
    required IngestionStage stage,
    required String runId,
    required String processorId,
    required String processorVersion,
    required String contentHash,
    int? page,
  }) {
    final identity = '$runId|${stage.name}|$processorId|$processorVersion|$contentHash|${page ?? ''}';
    final digest = _sha256Of(identity).substring(0, 16);
    return page != null ? 'da-${stage.name}-p$page-$digest' : 'da-${stage.name}-$digest';
  }

  /// CONTENT_EXTRACTION -> normalized content artifact.
  ///
  /// [DerivedArtifact.contentHash] is a SHA-256 digest of every page's
  /// `NormalizedPage.embeddedText`, concatenated in page order — the
  /// actual normalized-content bytes this stage produced. For a
  /// purely-scanned source with no embedded text layer (e.g. TRX300),
  /// that content is the empty string; the resulting hash is still the
  /// real, honest hash of that (empty) content, not a fabricated one —
  /// the downstream OCR stage is what supplies extractable text for such
  /// a source, represented by [ocrPageArtifact] instead.
  static DerivedArtifact contentExtractionArtifact({
    required NormalizedDocument document,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
  }) {
    final content = document.pages.map((page) => page.embeddedText).join('\n');
    final contentHash = _sha256Of(content);
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.contentExtraction,
        runId: runId,
        processorId: parserId,
        processorVersion: parserVersion,
        contentHash: contentHash,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.contentExtraction,
      artifactType: 'normalized_content_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: parserId,
      processorVersion: parserVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.contentExtraction,
        processorId: parserId,
        processorVersion: parserVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
        sourceFingerprint: document.metadata.contentHash,
      ),
    );
  }

  /// STRUCTURAL_ANALYSIS -> normalized structural artifact.
  ///
  /// This is a metadata-only processing record: there is no separately
  /// materialized "structural document" byte artifact anywhere in this
  /// codebase (WP-INGEST-002 § 8: "For metadata-only processing records
  /// where there is no separate materialized byte artifact, explicitly
  /// document what the `contentHash` represents"). [DerivedArtifact.contentHash]
  /// here is a SHA-256 digest of a canonical, deterministic serialization
  /// of every page's own structural facts (`pageNumber|widthPt|heightPt|
  /// rotationDegrees`, one line per page) — i.e. it represents the
  /// structural findings themselves, not a rendered/materialized file.
  static DerivedArtifact structuralAnalysisArtifact({
    required NormalizedDocument document,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
  }) {
    final structuralSummary = document.pages
        .map((page) => '${page.pageNumber}|${page.widthPt}|${page.heightPt}|${page.rotationDegrees}')
        .join('\n');
    final contentHash = _sha256Of(structuralSummary);
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.structuralAnalysis,
        runId: runId,
        processorId: parserId,
        processorVersion: parserVersion,
        contentHash: contentHash,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.structuralAnalysis,
      artifactType: 'normalized_structural_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: parserId,
      processorVersion: parserVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.structuralAnalysis,
        processorId: parserId,
        processorVersion: parserVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
        sourceFingerprint: document.metadata.contentHash,
      ),
    );
  }

  /// OCR -> one OCR-derived artifact per successful [OcrPageResult]
  /// (WP-INGEST-002 § 13: "establish the association without creating a
  /// duplicate OCR result model" — this does not wrap/copy
  /// [OcrPageResult]; the artifact only *references* it by
  /// `sourceId`/`page` via [IngestionProvenance], and the real
  /// `OcrPageResult` remains the one already returned on
  /// `IngestionResult.ocrPageResults`). Only successful pages get an
  /// artifact — a failed page produced no content, only the diagnostic
  /// already recorded on the OCR `StageResult` (WP-INGEST-002 § 9
  /// partial-run preservation: the *successful* pages' artifacts must
  /// still surface even when the run overall is `PARTIAL`).
  ///
  /// [DerivedArtifact.contentHash] is a SHA-256 digest of
  /// [OcrPageResult.plainText] — the actual recognized-text content this
  /// stage produced for the page — deliberately distinct from
  /// [OcrPageResult.sourceFingerprint], which identifies the *source
  /// evidence* the OCR ran against, not the OCR *output*.
  static DerivedArtifact ocrPageArtifact({
    required OcrPageResult ocrResult,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
  }) {
    final contentHash = _sha256Of(ocrResult.plainText);
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.ocr,
        runId: runId,
        processorId: 'ocr',
        processorVersion: ocrResult.engineVersion,
        contentHash: contentHash,
        page: ocrResult.page,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.ocr,
      artifactType: 'ocr_page_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: 'ocr',
      processorVersion: ocrResult.engineVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.ocr,
        processorId: 'ocr',
        processorVersion: ocrResult.engineVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
        page: ocrResult.page,
        sourceFingerprint: ocrResult.sourceFingerprint,
      ),
    );
  }

  /// ENTITY_EXTRACTION -> entity extraction artifact. One artifact
  /// summarizing the whole stage's findings (not one per
  /// [EngineeringEntity] — the entities themselves remain the existing,
  /// unduplicated `EngineeringEntity` records on
  /// `IngestionResult.engineeringEntities`; WP-INGEST-002 § 14: "Reuse
  /// `EngineeringEntity`. Do not create `UifEngineeringEntity` or an
  /// equivalent duplicate."). Returns `null` when [entities] is empty —
  /// an empty extraction produced no content to represent
  /// (WP-INGEST-002 § 17: do not force an empty/non-existent product into
  /// the collection).
  ///
  /// [DerivedArtifact.contentHash] is a SHA-256 digest of every entity's
  /// `type|normalizedValue|page|extractedText`, one line per entity in
  /// extraction order — the actual extraction-result content.
  static DerivedArtifact? entityExtractionArtifact({
    required List<EngineeringEntity> entities,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
    required String processorVersion,
  }) {
    if (entities.isEmpty) return null;
    final summary = entities
        .map((entity) => '${entity.type.name}|${entity.normalizedValue}|${entity.page}|${entity.extractedText}')
        .join('\n');
    final contentHash = _sha256Of(summary);
    const processorId = 'entityExtraction';
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.entityExtraction,
        runId: runId,
        processorId: processorId,
        processorVersion: processorVersion,
        contentHash: contentHash,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.entityExtraction,
      artifactType: 'engineering_entity_extraction_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: processorId,
      processorVersion: processorVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.entityExtraction,
        processorId: processorId,
        processorVersion: processorVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
        sourceFingerprint: entities.first.sourceFingerprint,
      ),
    );
  }

  /// CANDIDATE_GENERATION -> candidate-generation artifact. One artifact
  /// summarizing the whole stage's output (individual
  /// [KnowledgeCandidate]s already carry their own per-candidate
  /// provenance via `IngestionResult.candidateProvenance` — this artifact
  /// exists to make the *stage itself* traceable via
  /// `StageResult.derivedArtifactIds`, not to duplicate that per-candidate
  /// record). Returns `null` when [candidates] is empty, matching the
  /// existing `StageExecutionStatus.skipped` the orchestrator already
  /// reports for that case.
  ///
  /// Uses the same `processorId`/`processorVersion`
  /// (`uif.candidate_generation_service` / `1.0.0`) that
  /// `CandidateGenerationService` already records on each candidate's own
  /// [IngestionProvenance] — one processor identity, not two competing
  /// ones, for the same stage.
  static DerivedArtifact? candidateGenerationArtifact({
    required List<KnowledgeCandidate> candidates,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
  }) {
    if (candidates.isEmpty) return null;
    final summary = candidates.map((candidate) => '${candidate.type.name}|${candidate.name}').join('\n');
    final contentHash = _sha256Of(summary);
    const processorId = 'uif.candidate_generation_service';
    const processorVersion = '1.0.0';
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.candidateGeneration,
        runId: runId,
        processorId: processorId,
        processorVersion: processorVersion,
        contentHash: contentHash,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.candidateGeneration,
      artifactType: 'candidate_generation_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: processorId,
      processorVersion: processorVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.candidateGeneration,
        processorId: processorId,
        processorVersion: processorVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
      ),
    );
  }

  /// RELATIONSHIP_EXTRACTION -> relationship extraction artifact. Returns
  /// `null` when [relationships] is empty. Preserves
  /// `RelationshipExtractionService`'s own documented limitation
  /// (WP-INGEST-002 § 16): this artifact represents the deterministic
  /// same-page-candidate heuristic's output, never a claim of actual
  /// schematic/wire topology.
  ///
  /// [DerivedArtifact.contentHash] deliberately hashes each relationship's
  /// *ordinal position* within [orderedCandidates] rather than
  /// `sourceCandidateId`/`targetCandidateId` directly:
  /// `KnowledgeSessionService.generateId` (which produced those ids,
  /// unchanged/reused here) incorporates wall-clock time and randomness
  /// by design — the same reason `ingestion_pipeline_test.dart`'s own
  /// TEST-013 already excludes candidate ids from its determinism
  /// comparison. Ordinal position is the actual deterministic content a
  /// same-page relationship represents ("the Nth and (N+1)th extracted
  /// findings on this page are co-located"), so hashing that instead
  /// keeps this artifact's identity reproducible across equivalent runs
  /// (WP-INGEST-002 § 21) without depending on incidental id generation.
  static DerivedArtifact? relationshipExtractionArtifact({
    required List<RelationshipCandidate> relationships,
    required List<KnowledgeCandidate> orderedCandidates,
    required String runId,
    required String vaultObjectId,
    required List<String> acquisitionRecordIds,
    required String pipelineVersion,
    required String parserId,
    required String parserVersion,
  }) {
    if (relationships.isEmpty) return null;
    final ordinalById = {for (var i = 0; i < orderedCandidates.length; i++) orderedCandidates[i].id: i};
    final summary = relationships
        .map(
          (relationship) =>
              '${ordinalById[relationship.sourceCandidateId]}|${ordinalById[relationship.targetCandidateId]}|${relationship.type.name}',
        )
        .join('\n');
    final contentHash = _sha256Of(summary);
    const processorId = 'uif.relationship_extraction_service';
    const processorVersion = '1.0.0';
    return DerivedArtifact(
      derivedArtifactId: _derivedArtifactId(
        stage: IngestionStage.relationshipExtraction,
        runId: runId,
        processorId: processorId,
        processorVersion: processorVersion,
        contentHash: contentHash,
      ),
      runId: runId,
      vaultObjectId: vaultObjectId,
      stage: IngestionStage.relationshipExtraction,
      artifactType: 'relationship_extraction_result',
      contentHash: contentHash,
      createdAt: DateTime.now(),
      processorId: processorId,
      processorVersion: processorVersion,
      provenance: IngestionProvenance(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: acquisitionRecordIds,
        runId: runId,
        stage: IngestionStage.relationshipExtraction,
        processorId: processorId,
        processorVersion: processorVersion,
        parserId: parserId,
        parserVersion: parserVersion,
        pipelineVersion: pipelineVersion,
      ),
    );
  }
}
