import 'candidate_validation_result.dart';

/// The result of validating one Engineering Entity (Work Package 014
/// STUDIO-TASK-000041). Reuses `ValidationSeverity`
/// (`candidate_validation_result.dart`, Work Package 010) rather than
/// inventing a parallel ok/warning/error taxonomy — the same three
/// severities mean the same thing here: `ok` (no findings), `warning`
/// (worth a second look — a duplicate, low OCR confidence), `error`
/// (a structurally invalid detection — an impossible value, a
/// malformed specification). Always computed fresh by
/// `EntityValidationService.computeValidation` — never stored, never
/// persisted, the same derived-not-stored discipline
/// `CandidateValidationResult` already established ("No automatic
/// correction" — this work package's own text — extends naturally to
/// "no automatic *anything*," including caching a result that could
/// silently go stale).
class EntityValidationResult {
  const EntityValidationResult({required this.entityId, required this.severity, required this.issues});

  final String entityId;
  final ValidationSeverity severity;

  /// Human-readable findings, worst-first — empty only when [severity]
  /// is [ValidationSeverity.ok].
  final List<String> issues;
}
