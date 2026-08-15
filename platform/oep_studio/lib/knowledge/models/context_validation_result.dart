import 'candidate_validation_result.dart';

/// The result of validating one Engineering Context (Work Package 015
/// STUDIO-TASK-000044: "Validate extracted contexts... Validation
/// remains informational only."). Reuses `ValidationSeverity` from
/// `candidate_validation_result.dart` — the same tri-level model
/// `CandidateValidationResult`/`EntityValidationResult` already use,
/// rather than inventing a third parallel severity enum.
class ContextValidationResult {
  const ContextValidationResult({required this.contextId, required this.severity, required this.issues});

  final String contextId;
  final ValidationSeverity severity;
  final List<String> issues;
}
