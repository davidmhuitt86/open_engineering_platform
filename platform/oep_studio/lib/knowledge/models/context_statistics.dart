import 'engineering_entity_type.dart';

/// Summary statistics for one Engineering Context's child entities
/// (Work Package 015 Property Inspector: "Extend support for: ...
/// Context Statistics"). Computed on demand, never persisted — the
/// same derived-not-stored discipline `SessionHealthMetrics`/
/// `CandidateDependencyInfo` already established.
class ContextStatistics {
  const ContextStatistics({
    required this.childEntityCount,
    required this.averageChildConfidence,
    required this.entityCountByType,
  });

  final int childEntityCount;

  /// `0.0` if there are no child entities — the same honest-zero
  /// convention `OcrPageResult.averageConfidence` already uses for
  /// "nothing to average."
  final double averageChildConfidence;

  final Map<EngineeringEntityType, int> entityCountByType;
}
