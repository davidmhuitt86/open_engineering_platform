import '../../knowledge/models/engineering_entity.dart';
import '../../knowledge/models/ocr_page_result.dart';
import '../../knowledge/models/ocr_processing_exception.dart';
import '../../knowledge/models/source_material.dart';
import '../../knowledge/models/source_material_type.dart';
import '../../knowledge/services/engineering_entity_extraction_service.dart';
import '../../knowledge/services/ocr_pipeline_service.dart';
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
  }) async {
    final resolvedRunId = runId ?? 'run-${input.contentHash.substring(0, 16)}';
    final stageResults = <StageResult>[];

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
      return _failedResult(input: input, runId: resolvedRunId, stageResults: stageResults);
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
      return _failedResult(input: input, runId: resolvedRunId, stageResults: stageResults);
    }
    final parseEnd = DateTime.now();
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
      ),
      StageResult(
        stage: IngestionStage.structuralAnalysis,
        status: StageExecutionStatus.succeeded,
        startedAt: parseStart,
        completedAt: parseEnd,
        diagnostics: ['pages=${parserOutput.document.pages.map((page) => page.pageNumber).toList()}'],
      ),
    ]);

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
    stageResults.add(
      StageResult(
        stage: IngestionStage.ocr,
        status: ocrStatus,
        startedAt: ocrStart,
        completedAt: DateTime.now(),
        diagnostics: ocrDiagnostics,
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
    stageResults.add(
      StageResult(
        stage: IngestionStage.entityExtraction,
        status: hasUsableOcr ? StageExecutionStatus.succeeded : StageExecutionStatus.skipped,
        startedAt: entityStart,
        completedAt: DateTime.now(),
        diagnostics: hasUsableOcr
            ? ['extracted=${entities.length}']
            : const ['Skipped: no successful OCR page results to extract entities from.'],
      ),
    );

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
    stageResults.add(
      StageResult(
        stage: IngestionStage.candidateGeneration,
        status: candidateOutput.candidates.isEmpty ? StageExecutionStatus.skipped : StageExecutionStatus.succeeded,
        startedAt: candidateStart,
        completedAt: DateTime.now(),
        diagnostics: ['candidates=${candidateOutput.candidates.length}'],
      ),
    );

    // --- RELATIONSHIP_EXTRACTION ---
    final relationshipStart = DateTime.now();
    final relationships = RelationshipExtractionService.extract(
      orderedCandidates: candidateOutput.candidates,
      candidatePages: candidateOutput.candidatePages,
    );
    stageResults.add(
      StageResult(
        stage: IngestionStage.relationshipExtraction,
        status: relationships.isEmpty ? StageExecutionStatus.skipped : StageExecutionStatus.succeeded,
        startedAt: relationshipStart,
        completedAt: DateTime.now(),
        diagnostics: ['relationships=${relationships.length}'],
      ),
    );

    final hasFailure = stageResults.any((result) => result.status == StageExecutionStatus.failed);
    final hasPartial = stageResults.any((result) => result.status == StageExecutionStatus.partial);
    final runStatus = (hasFailure || hasPartial) ? IngestionRunStatus.partial : IngestionRunStatus.completed;

    return IngestionResult(
      run: IngestionRun(
        runId: resolvedRunId,
        vaultObjectId: input.vaultObjectId,
        startedAt: identifyStart,
        completedAt: DateTime.now(),
        status: runStatus,
        pipelineVersion: uifPipelineVersion,
        parserId: selectedParser.parserId,
        parserVersion: selectedParser.version,
        processorVersions: {
          'entityExtraction': 'engineering_pattern_library-1',
          if (ocrResults.isNotEmpty) 'ocr': ocrResults.first.engineVersion,
        },
        processingConfiguration: const {},
        stageResults: stageResults,
      ),
      structuralData: parserOutput.document,
      source: parserOutput.source,
      ocrPageResults: ocrResults,
      engineeringEntities: entities,
      evidenceRegions: candidateOutput.evidenceRegions,
      evidenceLinks: candidateOutput.evidenceLinks,
      knowledgeCandidates: candidateOutput.candidates,
      relationshipCandidates: relationships,
      candidateProvenance: candidateOutput.candidateProvenance,
    );
  }

  static IngestionResult _failedResult({
    required VaultObjectInput input,
    required String runId,
    required List<StageResult> stageResults,
  }) {
    return IngestionResult(
      run: IngestionRun(
        runId: runId,
        vaultObjectId: input.vaultObjectId,
        startedAt: stageResults.first.startedAt,
        completedAt: DateTime.now(),
        status: IngestionRunStatus.failed,
        pipelineVersion: uifPipelineVersion,
        parserId: 'none',
        parserVersion: 'none',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: stageResults,
      ),
      structuralData: NormalizedDocument(
        vaultObjectId: input.vaultObjectId,
        metadata: NormalizedMetadata(
          pageCount: 0,
          sourceFileName: input.storageReference,
          sizeBytes: 0,
          mimeType: input.mimeType,
          contentHash: input.contentHash,
        ),
        pages: const [],
      ),
      source: SourceMaterial(
        id: 'unresolved-${input.contentHash.substring(0, 16)}',
        originalFileName: input.storageReference,
        localPath: input.storageReference,
        type: SourceMaterialType.other,
        sizeBytes: 0,
        importDate: DateTime.fromMillisecondsSinceEpoch(0),
        addedBy: 'uif',
      ),
    );
  }
}
