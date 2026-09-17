import 'ingestion_stage.dart';

/// The processing-chain half of AP-INGEST-001 § 16's provenance contract:
/// "Vault Object → Acquisition Record → Ingestion Run → Processing Stage →
/// Derived Artifact → Evidence Location." Answers the four required
/// questions (WP-INGEST-001 § 9): which source, which run, which stage,
/// which processor/version, and where in the source.
///
/// This is deliberately a separate, lightweight record rather than a new
/// field bolted onto [DerivedArtifact]/`KnowledgeCandidate`/`EngineeringEntity`
/// — those existing/UIF-owned models already carry their own evidence
/// coordinates (`EngineeringEntity.sourceId`/`page`/`boundingBox`,
/// `EvidenceRegion`), so [IngestionProvenance] carries only what they
/// don't: the *processing* identity (run/stage/processor/parser/pipeline
/// versions) that AP-INGEST-001 § 22 (Idempotency and Processing Identity)
/// requires be recorded alongside evidence coordinates, not the evidence
/// coordinates themselves.
class IngestionProvenance {
  const IngestionProvenance({
    required this.vaultObjectId,
    required this.acquisitionRecordIds,
    required this.runId,
    required this.stage,
    required this.processorId,
    required this.processorVersion,
    this.parserId,
    this.parserVersion,
    required this.pipelineVersion,
    this.page,
    this.sourceFingerprint,
  });

  final String vaultObjectId;
  final List<String> acquisitionRecordIds;
  final String runId;
  final IngestionStage stage;
  final String processorId;
  final String processorVersion;
  final String? parserId;
  final String? parserVersion;
  final String pipelineVersion;

  /// 1-based page number, when the finding is page-scoped.
  final int? page;

  /// The `OcrPageResult.sourceFingerprint`/`VaultObjectInput.contentHash`
  /// this finding was produced against, when applicable — lets a later
  /// re-run detect whether the underlying evidence has changed (the same
  /// convention `EngineeringEntity.sourceFingerprint` already uses one
  /// layer down).
  final String? sourceFingerprint;

  Map<String, dynamic> toJson() => {
    'vaultObjectId': vaultObjectId,
    'acquisitionRecordIds': acquisitionRecordIds,
    'runId': runId,
    'stage': stage.name,
    'processorId': processorId,
    'processorVersion': processorVersion,
    'parserId': parserId,
    'parserVersion': parserVersion,
    'pipelineVersion': pipelineVersion,
    'page': page,
    'sourceFingerprint': sourceFingerprint,
  };
}
