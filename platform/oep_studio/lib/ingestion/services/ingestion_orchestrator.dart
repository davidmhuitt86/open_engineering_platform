import '../../knowledge/models/engineering_entity.dart';
import '../../knowledge/models/evidence_link.dart';
import '../../knowledge/models/evidence_region.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/ocr_page_result.dart';
import '../../knowledge/models/ocr_processing_exception.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/models/source_material.dart';
import '../../knowledge/models/source_material_type.dart';
import '../../knowledge/services/engineering_entity_extraction_service.dart';
import '../../knowledge/services/knowledge_session_service.dart';
import '../../knowledge/services/ocr_pipeline_service.dart';
import '../models/derived_artifact.dart';
import '../models/ingestion_provenance.dart';
import '../models/ingestion_result.dart';
import '../models/ingestion_run.dart';
import '../models/ingestion_run_status.dart';
import '../models/ingestion_stage.dart';
import '../models/normalized_document.dart';
import '../models/normalized_metadata.dart';
import '../models/stage_execution_status.dart';
import '../models/stage_result.dart';
import '../models/vault_object_input.dart';
import 'candidate_generation_service.dart';
import 'derived_artifact_factory.dart';
import 'ingestion_cancellation_token.dart';
import 'ingestion_parser.dart';
import 'pdf_ingestion_parser.dart';
import 'relationship_extraction_service.dart';

/// The OCR entry point UIF's OCR stage calls — the exact signature of
/// [OcrPipelineService.processSource], so the default value below *is*
/// the real, existing OCR pipeline and a test can substitute a fake with
/// zero adapter code. AP-INGEST-001 § 35.3 / WP-INGEST-001 § 2.12: "No
/// second OCR implementation."
typedef OcrRunner = Future<List<OcrPageResult>> Function({
  required SourceMaterial source,
  required List<OcrPageResult> existingResults,
});

/// WP-INGEST-007 § 7/§ 27/§ 28: the orchestrator's own hook for making
/// each lifecycle checkpoint (QUEUED, then RUNNING) durable *before*
/// meaningful execution proceeds past it, without the orchestrator
/// itself knowing anything about Knowledge Sessions, files, or any
/// other persistence detail -- it stays the same Flutter/Riverpod-free,
/// Knowledge-Session-agnostic class it already was
/// (`IngestionOrchestrator` § doc comment: "Holds no state of its
/// own"). The caller supplies a callback that knows how to fold the
/// given [IngestionRun] snapshot into its own durable storage (see
/// `ReferenceVaultIngestionWorkflow.ingest`, which persists into the
/// existing `KnowledgeSessionStorage` path via
/// `IngestionKnowledgeSessionBridge`). Awaited synchronously, so the
/// orchestrator does not proceed to actual stage execution until the
/// RUNNING checkpoint this callback is responsible for has actually
/// been persisted.
typedef IngestionRunLifecycleCallback = Future<void> Function(IngestionRun run);

/// UIF's pipeline version identity (AP-INGEST-001 § 22).
const String uifPipelineVersion = 'uif-pipeline-1.0.0';

/// Orchestrates the first-vertical-slice UIF pipeline (AP-INGEST-001 § 2/
/// § 7, WP-INGEST-001 § 5): IDENTIFY → PARSER_SELECTION →
/// METADATA_EXTRACTION → CONTENT_EXTRACTION → STRUCTURAL_ANALYSIS → OCR →
/// ENTITY_EXTRACTION → RELATIONSHIP_EXTRACTION → CANDIDATE_GENERATION.
///
/// **Deliberate stage-execution-order note** (documented per
/// WP-INGEST-001 § 23's "if an implementation detail differs from the
/// approved architecture, do not silently update the architecture
/// document — report it"): AP-INGEST-001 § 7's canonical PDF pipeline
/// diagram lists RELATIONSHIP_EXTRACTION before CANDIDATE_GENERATION.
/// This implementation executes CANDIDATE_GENERATION first and derives
/// relationship candidates from the *resulting* `KnowledgeCandidate`s
/// second, because the existing `RelationshipCandidate` model (Work
/// Package 008, reused unchanged here) connects two `KnowledgeCandidate.id`s,
/// not two raw `EngineeringEntity.id`s — relationship candidates cannot
/// be constructed against candidates that do not exist yet. Both stages
/// still run, in the canonical stage *vocabulary*; only their internal
/// execution order (an implementation detail, not a contract) differs
/// from the diagram. See `RelationshipExtractionService`'s own doc
/// comment for the relationship-extraction method itself.
///
/// Holds no state of its own — every method takes a snapshot and returns
/// a value, the same "pure orchestration" discipline
/// `CommitPlanService`/`ProvenanceService` already establish elsewhere in
/// this codebase.
abstract final class IngestionOrchestrator {
  static Future<IngestionResult> run({
    required VaultObjectInput input,
    List<IngestionParser> parsers = const [PdfIngestionParser()],
    OcrRunner ocrRunner = OcrPipelineService.processSource,
    List<OcrPageResult> existingOcrResults = const [],
    List<EngineeringEntity> existingEntities = const [],
    String? runId,
    // WP-INGEST-007 § 20-22: an explicit, caller-owned cancellation
    // signal scoped to this one execution. Checked at stage boundaries
    // only -- never mid-stage -- so a stage that has already started
    // always finishes rather than being torn down partway through.
    IngestionCancellationToken? cancellationToken,
    // WP-INGEST-007 § 7/§ 27/§ 28: fired with the QUEUED snapshot before
    // any stage executes, then again with the RUNNING snapshot before
    // stage execution actually begins -- see
    // [IngestionRunLifecycleCallback]'s own doc comment. Not fired again
    // for the terminal snapshot; the returned [IngestionResult.run] *is*
    // that terminal snapshot, and the caller (already holding the
    // QUEUED/RUNNING durable record this callback built) persists it the
    // same way it persisted the earlier checkpoints.
    IngestionRunLifecycleCallback? onLifecycleUpdate,
  }) async {
    // INGEST-FOLLOWUP-004: `runId` identifies one *execution attempt* --
    // wholly independent of `IngestionRun.processingIdentity` (frozen by
    // INGEST-FOLLOWUP-003, see that getter's own doc comment), which
    // identifies the evidence + processing-definition combination and
    // deliberately excludes `runId` entirely. Identical evidence
    // processed repeatedly must receive a distinct `runId` per attempt,
    // so the default must not be derived from `input.contentHash` (or
    // any other input that repeats across attempts) -- reuses the same
    // `generateId` convention already established for every other
    // Knowledge-Session-adjacent id in this codebase (e.g.
    // `ReferenceVaultIngestionWorkflow.ingest`'s session id,
    // `CandidateGenerationService`'s candidate/region/link ids) rather
    // than introducing a second id-generation mechanism.
    final resolvedRunId = runId ?? KnowledgeSessionService.generateId('run');
    final stageResults = <StageResult>[];
    // WP-INGEST-002 § 17/§ 18: every DerivedArtifact this run actually
    // produces, populated inline below by the stage that produces it, and
    // linked from that stage's own StageResult.derivedArtifactIds.
    final derivedArtifacts = <DerivedArtifact>[];

    // --- WP-INGEST-007 § 7: the run must exist, in QUEUED, before any
    // meaningful execution occurs. ---
    var run = IngestionRun(
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      contentHash: input.contentHash,
      startedAt: DateTime.now(),
      completedAt: null,
      status: IngestionRunStatus.queued,
      pipelineVersion: uifPipelineVersion,
      parserId: 'none',
      parserVersion: 'none',
      processorVersions: const {},
      processingConfiguration: const {},
      stageResults: const [],
    );
    if (onLifecycleUpdate != null) await onLifecycleUpdate(run);

    if (cancellationToken?.isCancelled ?? false) {
      // WP-INGEST-007 § 21: QUEUED -> CANCELLED, before any stage runs.
      run = run.transitionTo(IngestionRunStatus.cancelled, completedAt: DateTime.now());
      return _terminalResult(input: input, run: run);
    }

    run = run.transitionTo(IngestionRunStatus.running);
    if (onLifecycleUpdate != null) await onLifecycleUpdate(run);

    // --- IDENTIFY ---
    final identifyStart = DateTime.now();
    final identifyDiagnostics = <String>[
      'artifactType=${input.artifactType.name}',
      'mimeType=${input.mimeType}',
    ];
    stageResults.add(
      StageResult(
        stage: IngestionStage.identify,
        status: StageExecutionStatus.succeeded,
        startedAt: identifyStart,
        completedAt: DateTime.now(),
        diagnostics: identifyDiagnostics,
      ),
    );

    // --- PARSER_SELECTION ---
    final parserSelectionStart = DateTime.now();
    IngestionParser? selectedParser;
    for (final parser in parsers) {
      if (parser.canParse(input)) {
        selectedParser = parser;
        break;
      }
    }
    if (selectedParser == null) {
      stageResults.add(
        StageResult(
          stage: IngestionStage.parserSelection,
          status: StageExecutionStatus.failed,
          startedAt: parserSelectionStart,
          completedAt: DateTime.now(),
          diagnostics: const ['No registered parser declares support for this artifact type/MIME type.'],
        ),
      );
      run = run.transitionTo(IngestionRunStatus.failed, completedAt: DateTime.now(), stageResults: stageResults);
      return _terminalResult(input: input, run: run);
    }
    stageResults.add(
      StageResult(
        stage: IngestionStage.parserSelection,
        status: StageExecutionStatus.succeeded,
        startedAt: parserSelectionStart,
        completedAt: DateTime.now(),
        diagnostics: ['Selected ${selectedParser.parserId}@${selectedParser.version}.'],
      ),
    );
    // WP-INGEST-007: enrich the still-RUNNING run snapshot with the
    // parser identity now that it is known, so a cancellation checkpoint
    // reached after this point (and the run's final terminal snapshot)
    // both carry the real parserId/parserVersion rather than the
    // 'none'/'none' placeholder the QUEUED/RUNNING checkpoints started
    // with.
    run = run.copyWith(parserId: selectedParser.parserId, parserVersion: selectedParser.version);

    // --- METADATA_EXTRACTION / CONTENT_EXTRACTION / STRUCTURAL_ANALYSIS ---
    // All three derive from one parser.parse() call — see this class's
    // own doc comment for why they are still reported as three distinct
    // StageResults (WP-INGEST-001 § 6.3 traceability).
    final parseStart = DateTime.now();
    ParserOutput parserOutput;
    try {
      parserOutput = await selectedParser.parse(input);
    } catch (error) {
      final failedAt = DateTime.now();
      stageResults.addAll([
        StageResult(
          stage: IngestionStage.metadataExtraction,
          status: StageExecutionStatus.failed,
          startedAt: parseStart,
          completedAt: failedAt,
          diagnostics: ['Parser failed: $error'],
        ),
        StageResult(
          stage: IngestionStage.contentExtraction,
          status: StageExecutionStatus.failed,
          startedAt: parseStart,
          completedAt: failedAt,
          diagnostics: ['Parser failed: $error'],
        ),
        StageResult(
          stage: IngestionStage.structuralAnalysis,
          status: StageExecutionStatus.failed,
          startedAt: parseStart,
          completedAt: failedAt,
          diagnostics: ['Parser failed: $error'],
        ),
      ]);
      run = run.transitionTo(IngestionRunStatus.failed, completedAt: DateTime.now(), stageResults: stageResults);
      return _terminalResult(input: input, run: run);
    }
    final parseEnd = DateTime.now();

    // WP-INGEST-002 § 12: CONTENT_EXTRACTION -> normalized content
    // artifact, STRUCTURAL_ANALYSIS -> normalized structural artifact.
    // METADATA_EXTRACTION deliberately produces no DerivedArtifact — see
    // DerivedArtifactFactory's own doc comment for why.
    final contentArtifact = DerivedArtifactFactory.contentExtractionArtifact(
      document: parserOutput.document,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
    );
    final structuralArtifact = DerivedArtifactFactory.structuralAnalysisArtifact(
      document: parserOutput.document,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
    );
    derivedArtifacts.addAll([contentArtifact, structuralArtifact]);

    stageResults.addAll([
      StageResult(
        stage: IngestionStage.metadataExtraction,
        status: StageExecutionStatus.succeeded,
        startedAt: parseStart,
        completedAt: parseEnd,
        diagnostics: ['pageCount=${parserOutput.document.metadata.pageCount}'],
      ),
      StageResult(
        stage: IngestionStage.contentExtraction,
        status: StageExecutionStatus.succeeded,
        startedAt: parseStart,
        completedAt: parseEnd,
        diagnostics: parserOutput.diagnostics,
        derivedArtifactIds: [contentArtifact.derivedArtifactId],
      ),
      StageResult(
        stage: IngestionStage.structuralAnalysis,
        status: StageExecutionStatus.succeeded,
        startedAt: parseStart,
        completedAt: parseEnd,
        diagnostics: ['pages=${parserOutput.document.pages.map((page) => page.pageNumber).toList()}'],
        derivedArtifactIds: [structuralArtifact.derivedArtifactId],
      ),
    ]);

    // WP-INGEST-007 § 20-22: the first safe cancellation point reached
    // once real, non-placeholder structural data/source exist -- stops
    // before the (potentially slow) OCR stage, preserving every stage
    // result already produced above.
    if (cancellationToken?.isCancelled ?? false) {
      run = run.transitionTo(IngestionRunStatus.cancelled, completedAt: DateTime.now(), stageResults: stageResults);
      return _terminalResult(
        input: input,
        run: run,
        structuralData: parserOutput.document,
        source: parserOutput.source,
        derivedArtifacts: derivedArtifacts,
      );
    }

    // --- OCR ---
    final ocrStart = DateTime.now();
    List<OcrPageResult> ocrResults;
    StageExecutionStatus ocrStatus;
    final ocrDiagnostics = <String>[];
    try {
      ocrResults = await ocrRunner(source: parserOutput.source, existingResults: existingOcrResults);
      final forThisSource = ocrResults.where((result) => result.sourceId == parserOutput.source.id).toList();
      final succeededPages = forThisSource.where((result) => result.success).length;
      final failedPages = forThisSource.where((result) => !result.success).toList();
      for (final failure in failedPages) {
        ocrDiagnostics.add('Page ${failure.page} OCR failed: ${failure.errorMessage}');
      }
      if (failedPages.isEmpty && forThisSource.isNotEmpty) {
        ocrStatus = StageExecutionStatus.succeeded;
      } else if (succeededPages > 0) {
        ocrStatus = StageExecutionStatus.partial;
      } else {
        ocrStatus = StageExecutionStatus.failed;
      }
    } on OcrProcessingException catch (error) {
      // Pipeline-wide OCR failure (e.g. the engine itself is unavailable)
      // — AP-INGEST-001 § 12: "the existing per-page failure behavior
      // supports the UIF PARTIAL run state," but an engine-unavailable
      // failure is not per-page; it is total for this run's OCR stage.
      // Every stage before this one still succeeded, so the *run* is
      // PARTIAL, not FAILED — "Partial processing preserves successful
      // intermediate results" (AP-INGEST-001 § 23).
      ocrResults = existingOcrResults;
      ocrStatus = StageExecutionStatus.failed;
      ocrDiagnostics.add('OCR engine unavailable: ${error.message}');
    }
    // WP-INGEST-002 § 12/§ 13: OCR -> one OCR-derived artifact per
    // successful OcrPageResult belonging to this run's source. A failed
    // page produces no artifact (see DerivedArtifactFactory doc comment)
    // — its diagnostic above is the record of that failure.
    final ocrArtifacts = [
      for (final result in ocrResults)
        if (result.sourceId == parserOutput.source.id && result.success)
          DerivedArtifactFactory.ocrPageArtifact(
            ocrResult: result,
            runId: resolvedRunId,
            vaultObjectId: input.vaultObjectId,
            acquisitionRecordIds: input.acquisitionRecordIds,
            pipelineVersion: uifPipelineVersion,
            parserId: selectedParser.parserId,
            parserVersion: selectedParser.version,
          ),
    ];
    derivedArtifacts.addAll(ocrArtifacts);
    stageResults.add(
      StageResult(
        stage: IngestionStage.ocr,
        status: ocrStatus,
        startedAt: ocrStart,
        completedAt: DateTime.now(),
        diagnostics: ocrDiagnostics,
        derivedArtifactIds: [for (final artifact in ocrArtifacts) artifact.derivedArtifactId],
      ),
    );

    // --- ENTITY_EXTRACTION ---
    final entityStart = DateTime.now();
    final hasUsableOcr = ocrResults.any(
      (result) => result.sourceId == parserOutput.source.id && result.success,
    );
    final entities = hasUsableOcr
        ? EngineeringEntityExtractionService.extractForSource(
            source: parserOutput.source,
            ocrResults: ocrResults,
            existingEntities: existingEntities,
          )
        : <EngineeringEntity>[];
    // WP-INGEST-002 § 12: ENTITY_EXTRACTION -> entity extraction artifact
    // (a single stage-summary artifact; the entities themselves stay the
    // existing, unduplicated EngineeringEntity records — see
    // DerivedArtifactFactory doc comment).
    final entityArtifact = DerivedArtifactFactory.entityExtractionArtifact(
      entities: entities,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
      processorVersion: 'engineering_pattern_library-1',
    );
    if (entityArtifact != null) derivedArtifacts.add(entityArtifact);
    stageResults.add(
      StageResult(
        stage: IngestionStage.entityExtraction,
        status: hasUsableOcr ? StageExecutionStatus.succeeded : StageExecutionStatus.skipped,
        startedAt: entityStart,
        completedAt: DateTime.now(),
        diagnostics: hasUsableOcr
            ? ['extracted=${entities.length}']
            : const ['Skipped: no successful OCR page results to extract entities from.'],
        derivedArtifactIds: entityArtifact == null ? const [] : [entityArtifact.derivedArtifactId],
      ),
    );

    // WP-INGEST-007 § 20-22: the second safe cancellation point, reached
    // after OCR/entity extraction -- stops before candidate/relationship
    // generation, preserving OCR results and extracted entities already
    // produced.
    if (cancellationToken?.isCancelled ?? false) {
      run = run.copyWith(
        processorVersions: {
          'entityExtraction': 'engineering_pattern_library-1',
          if (ocrResults.isNotEmpty) 'ocr': ocrResults.first.engineVersion,
        },
      );
      run = run.transitionTo(IngestionRunStatus.cancelled, completedAt: DateTime.now(), stageResults: stageResults);
      return _terminalResult(
        input: input,
        run: run,
        structuralData: parserOutput.document,
        source: parserOutput.source,
        derivedArtifacts: derivedArtifacts,
        ocrPageResults: ocrResults,
        engineeringEntities: entities,
      );
    }

    // --- CANDIDATE_GENERATION (executed before RELATIONSHIP_EXTRACTION;
    // see this class's own doc comment) ---
    final candidateStart = DateTime.now();
    final candidateOutput = CandidateGenerationService.generate(
      entities: entities,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
    );
    // WP-INGEST-002 § 12: CANDIDATE_GENERATION -> candidate-generation
    // artifact.
    final candidateArtifact = DerivedArtifactFactory.candidateGenerationArtifact(
      candidates: candidateOutput.candidates,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
    );
    if (candidateArtifact != null) derivedArtifacts.add(candidateArtifact);
    stageResults.add(
      StageResult(
        stage: IngestionStage.candidateGeneration,
        status: candidateOutput.candidates.isEmpty ? StageExecutionStatus.skipped : StageExecutionStatus.succeeded,
        startedAt: candidateStart,
        completedAt: DateTime.now(),
        diagnostics: ['candidates=${candidateOutput.candidates.length}'],
        derivedArtifactIds: candidateArtifact == null ? const [] : [candidateArtifact.derivedArtifactId],
      ),
    );

    // --- RELATIONSHIP_EXTRACTION ---
    final relationshipStart = DateTime.now();
    final relationships = RelationshipExtractionService.extract(
      orderedCandidates: candidateOutput.candidates,
      candidatePages: candidateOutput.candidatePages,
    );
    // WP-INGEST-002 § 12: RELATIONSHIP_EXTRACTION -> relationship
    // extraction artifact.
    final relationshipArtifact = DerivedArtifactFactory.relationshipExtractionArtifact(
      relationships: relationships,
      orderedCandidates: candidateOutput.candidates,
      runId: resolvedRunId,
      vaultObjectId: input.vaultObjectId,
      acquisitionRecordIds: input.acquisitionRecordIds,
      pipelineVersion: uifPipelineVersion,
      parserId: selectedParser.parserId,
      parserVersion: selectedParser.version,
    );
    if (relationshipArtifact != null) derivedArtifacts.add(relationshipArtifact);
    stageResults.add(
      StageResult(
        stage: IngestionStage.relationshipExtraction,
        status: relationships.isEmpty ? StageExecutionStatus.skipped : StageExecutionStatus.succeeded,
        startedAt: relationshipStart,
        completedAt: DateTime.now(),
        diagnostics: ['relationships=${relationships.length}'],
        derivedArtifactIds: relationshipArtifact == null ? const [] : [relationshipArtifact.derivedArtifactId],
      ),
    );

    final hasFailure = stageResults.any((result) => result.status == StageExecutionStatus.failed);
    final hasPartial = stageResults.any((result) => result.status == StageExecutionStatus.partial);
    final runStatus = (hasFailure || hasPartial) ? IngestionRunStatus.partial : IngestionRunStatus.completed;

    run = run.copyWith(
      processorVersions: {
        'entityExtraction': 'engineering_pattern_library-1',
        if (ocrResults.isNotEmpty) 'ocr': ocrResults.first.engineVersion,
      },
    );
    run = run.transitionTo(runStatus, completedAt: DateTime.now(), stageResults: stageResults);

    return _terminalResult(
      input: input,
      run: run,
      structuralData: parserOutput.document,
      source: parserOutput.source,
      derivedArtifacts: derivedArtifacts,
      ocrPageResults: ocrResults,
      engineeringEntities: entities,
      evidenceRegions: candidateOutput.evidenceRegions,
      evidenceLinks: candidateOutput.evidenceLinks,
      knowledgeCandidates: candidateOutput.candidates,
      relationshipCandidates: relationships,
      candidateProvenance: candidateOutput.candidateProvenance,
    );
  }

  /// Builds the [IngestionResult] for [run], which must already be in a
  /// terminal status (WP-INGEST-007 § 6) -- the single construction site
  /// every return path in [run] above (success, parser/parse failure,
  /// and every cancellation checkpoint) now funnels through, so a
  /// terminal run's [IngestionResult] is always built the same way
  /// regardless of *which* terminal status it reached.
  ///
  /// [structuralData]/[source] default to the same placeholder
  /// "unresolved" document/source the original `_failedResult` used --
  /// reached only when a run terminates before the real parser output
  /// exists at all (no registered parser, or the parser itself threw),
  /// exactly as before this work package.
  static IngestionResult _terminalResult({
    required VaultObjectInput input,
    required IngestionRun run,
    NormalizedDocument? structuralData,
    SourceMaterial? source,
    List<DerivedArtifact> derivedArtifacts = const [],
    List<OcrPageResult> ocrPageResults = const [],
    List<EngineeringEntity> engineeringEntities = const [],
    List<EvidenceRegion> evidenceRegions = const [],
    List<EvidenceLink> evidenceLinks = const [],
    List<KnowledgeCandidate> knowledgeCandidates = const [],
    List<RelationshipCandidate> relationshipCandidates = const [],
    Map<String, IngestionProvenance> candidateProvenance = const {},
  }) {
    return IngestionResult(
      run: run,
      structuralData: structuralData ?? _unresolvedDocument(input),
      source: source ?? _unresolvedSource(input),
      derivedArtifacts: derivedArtifacts,
      ocrPageResults: ocrPageResults,
      engineeringEntities: engineeringEntities,
      evidenceRegions: evidenceRegions,
      evidenceLinks: evidenceLinks,
      knowledgeCandidates: knowledgeCandidates,
      relationshipCandidates: relationshipCandidates,
      candidateProvenance: candidateProvenance,
    );
  }

  static NormalizedDocument _unresolvedDocument(VaultObjectInput input) => NormalizedDocument(
    vaultObjectId: input.vaultObjectId,
    metadata: NormalizedMetadata(
      pageCount: 0,
      sourceFileName: input.storageReference,
      sizeBytes: 0,
      mimeType: input.mimeType,
      contentHash: input.contentHash,
    ),
    pages: const [],
  );

  static SourceMaterial _unresolvedSource(VaultObjectInput input) => SourceMaterial(
    id: 'unresolved-${input.contentHash.substring(0, 16)}',
    originalFileName: input.storageReference,
    localPath: input.storageReference,
    type: SourceMaterialType.other,
    sizeBytes: 0,
    importDate: DateTime.fromMillisecondsSinceEpoch(0),
    addedBy: 'uif',
  );
}
