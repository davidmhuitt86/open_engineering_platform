import 'ingestion_run_status.dart';
import 'stage_result.dart';

/// One processing attempt against one immutable Vault Object
/// (AP-INGEST-001 § 6, WP-INGEST-001 § 6.2).
class IngestionRun {
  const IngestionRun({
    required this.runId,
    required this.vaultObjectId,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.pipelineVersion,
    required this.parserId,
    required this.parserVersion,
    required this.processorVersions,
    required this.processingConfiguration,
    required this.stageResults,
  });

  final String runId;
  final String vaultObjectId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final IngestionRunStatus status;

  /// Identifies this build of the UIF pipeline itself (AP-INGEST-001
  /// § 22 Idempotency and Processing Identity) — independent of
  /// [parserVersion]/[processorVersions], which identify the individual
  /// stage implementations invoked.
  final String pipelineVersion;

  final String parserId;
  final String parserVersion;

  /// Which version of each reused processor (OCR engine, entity
  /// extraction pattern library, ...) this run invoked — e.g.
  /// `{'ocr': 'Tesseract 5.4.0.20240606', 'entityExtraction': 'engineering_pattern_library-1'}`.
  final Map<String, String> processorVersions;

  /// The processing configuration in effect for this run (e.g. OCR render
  /// DPI) — part of AP-INGEST-001 § 22's processing-identity tuple.
  final Map<String, dynamic> processingConfiguration;

  final List<StageResult> stageResults;

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'vaultObjectId': vaultObjectId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'pipelineVersion': pipelineVersion,
    'parserId': parserId,
    'parserVersion': parserVersion,
    'processorVersions': processorVersions,
    'processingConfiguration': processingConfiguration,
    'stageResults': stageResults.map((result) => result.toJson()).toList(),
  };
}
