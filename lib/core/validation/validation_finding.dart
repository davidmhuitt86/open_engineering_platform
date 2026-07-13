/// Severity of a single [ValidationFinding].
enum ValidationSeverity { info, warning, error }

/// One deterministic validation result (SDD-025/026: "Validation reports
/// findings only" — never mutates the graph).
class ValidationFinding {
  final String code;
  final ValidationSeverity severity;
  final String message;

  /// Node, relationship, port, or symbol id this finding concerns, if any.
  final String? subjectId;

  const ValidationFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.subjectId,
  });

  Map<String, Object?> toJson() => {
        'code': code,
        'severity': severity.name,
        'message': message,
        'subjectId': subjectId,
      };

  @override
  String toString() => '[${severity.name.toUpperCase()}] $code: $message';
}
