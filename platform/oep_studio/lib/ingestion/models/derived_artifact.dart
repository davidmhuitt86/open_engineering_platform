import 'ingestion_provenance.dart';
import 'ingestion_stage.dart';

/// A first-class ingestion product (AP-INGEST-001 § 15, WP-INGEST-001
/// § 8). This first vertical slice produces the "useful products"
/// § 8 lists as expected: normalized structural/content results, OCR page
/// results (already represented by the reused `OcrPageResult`, so not
/// re-wrapped here), engineering entity extraction results, and candidate
/// results.
class DerivedArtifact {
  const DerivedArtifact({
    required this.derivedArtifactId,
    required this.runId,
    required this.vaultObjectId,
    required this.stage,
    required this.artifactType,
    required this.contentHash,
    required this.createdAt,
    required this.processorId,
    required this.processorVersion,
    required this.provenance,
  });

  final String derivedArtifactId;
  final String runId;
  final String vaultObjectId;
  final IngestionStage stage;

  /// A short label describing what this derived artifact is (e.g.
  /// `"normalized_structural_result"`, `"engineering_entity_extraction_result"`)
  /// — descriptive only, not a parsed/typed taxonomy; AP-INGEST-001 § 15
  /// does not mandate one for the first slice.
  final String artifactType;

  final String contentHash;
  final DateTime createdAt;
  final String processorId;
  final String processorVersion;
  final IngestionProvenance provenance;

  Map<String, dynamic> toJson() => {
    'derivedArtifactId': derivedArtifactId,
    'runId': runId,
    'vaultObjectId': vaultObjectId,
    'stage': stage.name,
    'artifactType': artifactType,
    'contentHash': contentHash,
    'createdAt': createdAt.toIso8601String(),
    'processorId': processorId,
    'processorVersion': processorVersion,
    'provenance': provenance.toJson(),
  };
}
