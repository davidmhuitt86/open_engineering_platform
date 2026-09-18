import 'normalized_document.dart';

/// Wraps UIF's [NormalizedDocument] with the identifiers needed to place
/// it durably within the Knowledge Session persistence domain
/// (WP-INGEST-008 § 4): which execution ([runId]) produced this document,
/// and which [DerivedArtifact] provenance record ([derivedArtifactId])
/// documents its processing identity/content hash. This wrapper — never
/// `DerivedArtifact` itself — is the structured *content* persisted;
/// `DerivedArtifact` stays provenance/identity metadata only, exactly as
/// it already was before this work package (WP-INGEST-008 § 3: "Do not
/// reinterpret `DerivedArtifact` as the actual persisted content").
///
/// A list of these, keyed by [runId], is what `KnowledgeSessionRecord`
/// persists (never a single overwritten `latestDocument` field) — two
/// executions of the same session, even with identical processing
/// identity, each keep their own separately-persisted product
/// (WP-INGEST-008 § 7/§ 11).
class NormalizedIngestionProduct {
  const NormalizedIngestionProduct({required this.runId, required this.derivedArtifactId, required this.document});

  /// The `IngestionRun.runId` of the execution that produced [document] —
  /// matches an entry in `KnowledgeSessionRecord.ingestionRuns`.
  final String runId;

  /// The `DerivedArtifact.derivedArtifactId` of the provenance record
  /// documenting this document's processing identity/content hash (the
  /// structural-analysis artifact — see `IngestionKnowledgeSessionBridge`
  /// for why that stage, rather than content-extraction, is what this
  /// references). Not duplicated further: callers that need the full
  /// `DerivedArtifact` look it up in `KnowledgeSessionRecord.derivedArtifacts`
  /// by this id.
  final String derivedArtifactId;

  /// The complete normalized product itself.
  final NormalizedDocument document;

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'derivedArtifactId': derivedArtifactId,
    'document': document.toJson(),
  };

  /// Throws [FormatException]/[TypeError] on structurally invalid input —
  /// matching every other `fromJson` in this codebase.
  factory NormalizedIngestionProduct.fromJson(Map<String, dynamic> json) => NormalizedIngestionProduct(
    runId: json['runId'] as String,
    derivedArtifactId: json['derivedArtifactId'] as String,
    document: NormalizedDocument.fromJson(json['document'] as Map<String, dynamic>),
  );
}
