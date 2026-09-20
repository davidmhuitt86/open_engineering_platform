import '../../ingestion/models/derived_artifact.dart';
import '../../ingestion/models/ingestion_run.dart';
import '../../ingestion/models/normalized_ingestion_product.dart';
import 'ai_suggestion.dart';
import 'commit_report.dart';
import 'engineering_context.dart';
import 'engineering_entity.dart';
import 'evidence_link.dart';
import '../inference/inference_record.dart';
import 'evidence_region.dart';
import 'knowledge_candidate.dart';
import 'knowledge_session.dart';
import 'ocr_page_result.dart';
import 'page_selection.dart';
import 'procedure_step.dart';
import 'relationship_candidate.dart';
import 'review_decision.dart';
import 'source_material.dart';
import 'specification_details.dart';

/// The complete persisted unit for one Knowledge Curation Session —
/// what `session.json` holds (`docs/KNOWLEDGE_SESSION_FORMAT.md`) and
/// what `KnowledgeSessionStorage.load`/`save` round-trip. Also what the
/// Connection Manager holds in memory for the active session, spread
/// across `FoundationServiceState.knowledgeSession`/`candidates`/
/// `relationshipCandidates`/`sourceMaterials`/`reviewDecisions`/
/// `evidenceRegions`/`evidenceLinks`/`pageSelections` rather than as one
/// field — see `docs/CONNECTION_MANAGER.md`.
class KnowledgeSessionRecord {
  const KnowledgeSessionRecord({
    required this.session,
    this.candidates = const [],
    this.relationshipCandidates = const [],
    this.sources = const [],
    this.reviewDecisions = const [],
    this.evidenceRegions = const [],
    this.evidenceLinks = const [],
    this.pageSelections = const [],
    this.procedureSteps = const [],
    this.specificationDetails = const [],
    this.commitReports = const [],
    this.ocrPageResults = const [],
    this.engineeringEntities = const [],
    this.engineeringContexts = const [],
    this.aiSuggestions = const [],
    this.ingestionRuns = const [],
    this.derivedArtifacts = const [],
    this.normalizedProducts = const [],
    this.inferenceRecords = const [],
  });

  final KnowledgeSession session;
  final List<KnowledgeCandidate> candidates;
  final List<RelationshipCandidate> relationshipCandidates;
  final List<SourceMaterial> sources;
  final List<ReviewDecision> reviewDecisions;

  /// Manually-identified rectangular Evidence Regions (Work Package 009
  /// STUDIO-TASK-000020).
  final List<EvidenceRegion> evidenceRegions;

  /// Knowledge Candidate ↔ Evidence Region links (Work Package 009
  /// STUDIO-TASK-000021).
  final List<EvidenceLink> evidenceLinks;

  /// Whole-page evidence markers (Work Package 009 STUDIO-TASK-000019 §
  /// Selection).
  final List<PageSelection> pageSelections;

  /// Procedure Steps belonging to this session's Procedure Knowledge
  /// Candidates (Work Package 010 STUDIO-TASK-000023).
  final List<ProcedureStep> procedureSteps;

  /// Specification-type-fields for this session's Specification
  /// Knowledge Candidates, one entry per Specification candidate (Work
  /// Package 010 STUDIO-TASK-000024).
  final List<SpecificationDetails> specificationDetails;

  /// The append-only history of Repository Commit attempts against this
  /// session (Work Package 012 STUDIO-TASK-000033) — "Sessions become
  /// historical engineering records."
  final List<CommitReport> commitReports;

  /// OCR results for this session's Source Material (Work Package 013
  /// STUDIO-TASK-000037: "OCR results shall persist... Reopening a
  /// session shall not rerun OCR"). One entry per (source, page); see
  /// `docs/OCR_PIPELINE.md` § OCR Cache.
  final List<OcrPageResult> ocrPageResults;

  /// Engineering Entities extracted from this session's OCR results
  /// (Work Package 014 STUDIO-TASK-000038) — "Entities are suggestions
  /// only," persisted alongside their review status
  /// ([EngineeringEntityStatus]) so an engineer's Accept/Ignore
  /// decisions survive a restart the same way `ReviewDecision`s do.
  final List<EngineeringEntity> engineeringEntities;

  /// Engineering Contexts detected from this session's OCR results and
  /// entities (Work Package 015 STUDIO-TASK-000042) — persisted
  /// alongside their review status ([EngineeringContextStatus]) for
  /// the same reason `engineeringEntities` is.
  final List<EngineeringContext> engineeringContexts;

  /// AI Suggestions generated from this session's OCR/entity/context
  /// evidence (Work Package 016 STUDIO-TASK-000048) — persisted
  /// alongside their review status ([AiSuggestionStatus]), per SDD-022's
  /// own "AI Session Persistence: Persist... Provider, Model, Timestamp,
  /// Review Status." Does not include the `AiRequest`/`AiResponse`/
  /// `AiConversation` that produced them — those stay ephemeral (see
  /// `docs/AI_PROVIDER_ARCHITECTURE.md` § Persistence for why).
  final List<AiSuggestion> aiSuggestions;

  /// Durable ingestion execution history (WP-INGEST-006 § 7/§ 11):
  /// which ingestion run(s) produced this session's initial imported
  /// state, including processing identity, pipeline/parser/processor
  /// versions, processing configuration, and per-stage
  /// success/partial/failed/skipped status with diagnostics. Populated by
  /// `IngestionKnowledgeSessionBridge` from `IngestionResult.run`; a
  /// manually-created session (no ingestion involved) has an empty list.
  /// Reused unchanged, deliberately not duplicated into a second model —
  /// see `IngestionRun`'s own doc comment.
  final List<IngestionRun> ingestionRuns;

  /// Durable references/provenance metadata for every product an
  /// ingestion run produced (WP-INGEST-006 § 9) — `DerivedArtifact` has
  /// never carried the derived product's actual bytes, only identity and
  /// a content hash, so persisting these records is already
  /// metadata/reference persistence, not a claim that derived-artifact
  /// bytes are durable (see `DerivedArtifact.fromJson`'s own doc comment).
  final List<DerivedArtifact> derivedArtifacts;

  /// Durable, structured normalized ingestion products (WP-INGEST-008 §
  /// 1/§ 6) — the actual `NormalizedDocument` (vaultObjectId +
  /// `NormalizedMetadata` + `NormalizedPage[]`) UIF's content
  /// extraction/structural analysis produced, wrapped with the `runId`/
  /// `derivedArtifactId` that identify it (see
  /// [NormalizedIngestionProduct]'s own doc comment). Distinct from
  /// [derivedArtifacts]: that list stays provenance/identity metadata
  /// only, while this list is the structured content itself. Keyed by
  /// `runId` (a list, never a single overwritten field) so multiple
  /// ingestion attempts against the same session remain separately,
  /// historically represented — populated by
  /// `IngestionKnowledgeSessionBridge` exactly where [ingestionRuns]/
  /// [derivedArtifacts] are; a manually-created or pre-WP-INGEST-008
  /// session has an empty list.
  final List<NormalizedIngestionProduct> normalizedProducts;

  /// WP-INGEST-013: durable audit records of interpretation attempts (never
  /// engineering truth). Missing in older sessions => empty.
  final List<InferenceRecord> inferenceRecords;

  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'session': session.toJson(),
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
    'relationshipCandidates': relationshipCandidates.map((relationship) => relationship.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'reviewDecisions': reviewDecisions.map((decision) => decision.toJson()).toList(),
    'evidenceRegions': evidenceRegions.map((region) => region.toJson()).toList(),
    'evidenceLinks': evidenceLinks.map((link) => link.toJson()).toList(),
    'pageSelections': pageSelections.map((selection) => selection.toJson()).toList(),
    'procedureSteps': procedureSteps.map((step) => step.toJson()).toList(),
    'specificationDetails': specificationDetails.map((details) => details.toJson()).toList(),
    'commitReports': commitReports.map((report) => report.toJson()).toList(),
    'ocrPageResults': ocrPageResults.map((result) => result.toJson()).toList(),
    'engineeringEntities': engineeringEntities.map((entity) => entity.toJson()).toList(),
    'engineeringContexts': engineeringContexts.map((context) => context.toJson()).toList(),
    'aiSuggestions': aiSuggestions.map((suggestion) => suggestion.toJson()).toList(),
    'ingestionRuns': ingestionRuns.map((run) => run.toJson()).toList(),
    'derivedArtifacts': derivedArtifacts.map((artifact) => artifact.toJson()).toList(),
    'normalizedProducts': normalizedProducts.map((product) => product.toJson()).toList(),
    'inferenceRecords': inferenceRecords.map((record) => record.toJson()).toList(),
  };

  /// Throws [FormatException] on any structurally invalid input —
  /// callers (`KnowledgeSessionStorage.load`) translate that into
  /// Work Package 008's "Corrupted session files" error handling
  /// requirement rather than letting a raw parse error surface.
  factory KnowledgeSessionRecord.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>? ?? const [];
    final relationshipsJson = json['relationshipCandidates'] as List<dynamic>? ?? const [];
    final sourcesJson = json['sources'] as List<dynamic>? ?? const [];
    final decisionsJson = json['reviewDecisions'] as List<dynamic>? ?? const [];
    final evidenceRegionsJson = json['evidenceRegions'] as List<dynamic>? ?? const [];
    final evidenceLinksJson = json['evidenceLinks'] as List<dynamic>? ?? const [];
    final pageSelectionsJson = json['pageSelections'] as List<dynamic>? ?? const [];
    final procedureStepsJson = json['procedureSteps'] as List<dynamic>? ?? const [];
    final specificationDetailsJson = json['specificationDetails'] as List<dynamic>? ?? const [];
    final commitReportsJson = json['commitReports'] as List<dynamic>? ?? const [];
    final ocrPageResultsJson = json['ocrPageResults'] as List<dynamic>? ?? const [];
    final engineeringEntitiesJson = json['engineeringEntities'] as List<dynamic>? ?? const [];
    final engineeringContextsJson = json['engineeringContexts'] as List<dynamic>? ?? const [];
    final aiSuggestionsJson = json['aiSuggestions'] as List<dynamic>? ?? const [];
    final ingestionRunsJson = json['ingestionRuns'] as List<dynamic>? ?? const [];
    final derivedArtifactsJson = json['derivedArtifacts'] as List<dynamic>? ?? const [];
    final normalizedProductsJson = json['normalizedProducts'] as List<dynamic>? ?? const [];
    final inferenceRecordsJson = json['inferenceRecords'] as List<dynamic>? ?? const [];
    return KnowledgeSessionRecord(
      session: KnowledgeSession.fromJson(json['session'] as Map<String, dynamic>),
      candidates: [
        for (final entry in candidatesJson) KnowledgeCandidate.fromJson(entry as Map<String, dynamic>),
      ],
      relationshipCandidates: [
        for (final entry in relationshipsJson) RelationshipCandidate.fromJson(entry as Map<String, dynamic>),
      ],
      sources: [for (final entry in sourcesJson) SourceMaterial.fromJson(entry as Map<String, dynamic>)],
      reviewDecisions: [
        for (final entry in decisionsJson) ReviewDecision.fromJson(entry as Map<String, dynamic>),
      ],
      evidenceRegions: [
        for (final entry in evidenceRegionsJson) EvidenceRegion.fromJson(entry as Map<String, dynamic>),
      ],
      evidenceLinks: [
        for (final entry in evidenceLinksJson) EvidenceLink.fromJson(entry as Map<String, dynamic>),
      ],
      pageSelections: [
        for (final entry in pageSelectionsJson) PageSelection.fromJson(entry as Map<String, dynamic>),
      ],
      procedureSteps: [
        for (final entry in procedureStepsJson) ProcedureStep.fromJson(entry as Map<String, dynamic>),
      ],
      specificationDetails: [
        for (final entry in specificationDetailsJson) SpecificationDetails.fromJson(entry as Map<String, dynamic>),
      ],
      commitReports: [
        for (final entry in commitReportsJson) CommitReport.fromJson(entry as Map<String, dynamic>),
      ],
      ocrPageResults: [
        for (final entry in ocrPageResultsJson) OcrPageResult.fromJson(entry as Map<String, dynamic>),
      ],
      engineeringEntities: [
        for (final entry in engineeringEntitiesJson) EngineeringEntity.fromJson(entry as Map<String, dynamic>),
      ],
      engineeringContexts: [
        for (final entry in engineeringContextsJson) EngineeringContext.fromJson(entry as Map<String, dynamic>),
      ],
      aiSuggestions: [
        for (final entry in aiSuggestionsJson) AiSuggestion.fromJson(entry as Map<String, dynamic>),
      ],
      ingestionRuns: [
        for (final entry in ingestionRunsJson) IngestionRun.fromJson(entry as Map<String, dynamic>),
      ],
      derivedArtifacts: [
        for (final entry in derivedArtifactsJson) DerivedArtifact.fromJson(entry as Map<String, dynamic>),
      ],
      normalizedProducts: [
        for (final entry in normalizedProductsJson)
          NormalizedIngestionProduct.fromJson(entry as Map<String, dynamic>),
      ],
      inferenceRecords: [
        for (final entry in inferenceRecordsJson) InferenceRecord.fromJson(entry as Map<String, dynamic>),
      ],
    );
  }
}
