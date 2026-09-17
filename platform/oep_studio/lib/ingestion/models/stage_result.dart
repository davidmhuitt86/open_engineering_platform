import 'ingestion_stage.dart';
import 'stage_execution_status.dart';

/// One processing stage's report within an [IngestionRun]
/// (AP-INGEST-001 § 6.3, WP-INGEST-001 § 6.3): "Each processing stage
/// must be able to report at least: stage, status, startedAt, completedAt,
/// diagnostics, derivedArtifactIds[]."
class StageResult {
  const StageResult({
    required this.stage,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    this.diagnostics = const [],
    this.derivedArtifactIds = const [],
  });

  final IngestionStage stage;
  final StageExecutionStatus status;
  final DateTime startedAt;
  final DateTime completedAt;

  /// Human-readable notes explaining what happened during this stage —
  /// always populated on [StageExecutionStatus.failed]/[StageExecutionStatus.partial]
  /// (AP-INGEST-001 § 23: "The system must preserve diagnostics sufficient
  /// to determine which stage failed and why"), optionally populated
  /// otherwise.
  final List<String> diagnostics;

  final List<String> derivedArtifactIds;

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'diagnostics': diagnostics,
    'derivedArtifactIds': derivedArtifactIds,
  };
}
