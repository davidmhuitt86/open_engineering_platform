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

  /// Throws [FormatException]/[TypeError] on structurally invalid input —
  /// see [IngestionRun.fromJson]'s own doc comment for why.
  factory StageResult.fromJson(Map<String, dynamic> json) => StageResult(
    stage: IngestionStage.values.byName(json['stage'] as String),
    status: StageExecutionStatus.values.byName(json['status'] as String),
    startedAt: DateTime.parse(json['startedAt'] as String),
    completedAt: DateTime.parse(json['completedAt'] as String),
    diagnostics: List<String>.from(json['diagnostics'] as List? ?? const []),
    derivedArtifactIds: List<String>.from(json['derivedArtifactIds'] as List? ?? const []),
  );
}
