import '../../knowledge/models/engineering_entity.dart';
import '../../knowledge/models/evidence_link.dart';
import '../../knowledge/models/evidence_region.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/ocr_page_result.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/models/source_material.dart';
import 'derived_artifact.dart';
import 'ingestion_provenance.dart';
import 'ingestion_run.dart';
import 'normalized_document.dart';

/// UIF's output (AP-INGEST-001 § 18, WP-INGEST-001 § 14). Chunk and
/// embedding fields are intentionally absent — AP-INGEST-001 § 18: "The
/// first TRX300 implementation may omit chunk and embedding products
/// while preserving the extensible result contract" (the contract stays
/// extensible because nothing here prevents adding `chunks`/`embeddings`
/// fields later; this work package simply does not populate them).
///
/// Deliberately reuses existing Knowledge Studio models
/// ([SourceMaterial], [OcrPageResult], [EngineeringEntity],
/// [KnowledgeCandidate], [RelationshipCandidate], [EvidenceRegion],
/// [EvidenceLink]) rather than inventing UIF-specific equivalents — this
/// is what lets [IngestionResult] feed the existing Knowledge Curation
/// Session model (AP-INGEST-001 § 19/§ 29) without a translation layer
/// that could silently drop provenance. See
/// `IngestionKnowledgeSessionBridge` for how these become a
/// `KnowledgeSessionRecord`.
class IngestionResult {
  const IngestionResult({
    required this.run,
    required this.structuralData,
    required this.source,
    this.derivedArtifacts = const [],
    this.ocrPageResults = const [],
    this.engineeringEntities = const [],
    this.evidenceRegions = const [],
    this.evidenceLinks = const [],
    this.knowledgeCandidates = const [],
    this.relationshipCandidates = const [],
    this.candidateProvenance = const {},
  });

  final IngestionRun run;

  /// [NormalizedDocument.metadata] is this result's normalized metadata —
  /// kept on [structuralData] rather than duplicated as a sibling field,
  /// since AP-INGEST-001 § 18 lists them as a pair
  /// (`metadata`/`structuralData`) that a `NormalizedDocument` already
  /// represents together.
  final NormalizedDocument structuralData;

  /// The Source Material this run's evidence became, for reuse by
  /// [OcrPipelineService]/[EngineeringEntityExtractionService] and, later,
  /// a Knowledge Studio session's own `sources` list.
  final SourceMaterial source;

  final List<DerivedArtifact> derivedArtifacts;
  final List<OcrPageResult> ocrPageResults;
  final List<EngineeringEntity> engineeringEntities;

  /// Evidence Regions UIF derived from [engineeringEntities]' own bounding
  /// boxes — reusing the existing Evidence Region model so a UIF-produced
  /// candidate's provenance is inspectable by the *existing*
  /// `ProvenanceService`/Provenance Explorer exactly like a
  /// manually-created candidate's, with no separate UIF-only provenance
  /// viewer required.
  final List<EvidenceRegion> evidenceRegions;

  /// Links connecting each [knowledgeCandidates] entry to its supporting
  /// [evidenceRegions] entry/entries.
  final List<EvidenceLink> evidenceLinks;

  /// Engineering Knowledge Candidates (AP-INGEST-001 § 17) — `EXTRACTED`
  /// findings represented as `KnowledgeCandidateStatus.pending`
  /// [KnowledgeCandidate]s, never `accepted`/committed by UIF itself
  /// (AP-INGEST-001 § 20/§ 35.1).
  final List<KnowledgeCandidate> knowledgeCandidates;

  /// Relationship candidates (AP-INGEST-001 § 14) connecting
  /// [knowledgeCandidates] entries.
  final List<RelationshipCandidate> relationshipCandidates;

  /// Processing-chain provenance for every entry in [knowledgeCandidates],
  /// keyed by `KnowledgeCandidate.id` — see [IngestionProvenance]'s own
  /// doc comment for why this is separate from the evidence-chain
  /// provenance [evidenceRegions]/[evidenceLinks] already carry.
  final Map<String, IngestionProvenance> candidateProvenance;
}
