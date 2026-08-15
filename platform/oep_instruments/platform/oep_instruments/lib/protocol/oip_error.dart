/// OIP-SPEC-001 §23 — every protocol-level error's required shape:
/// Code, Severity, Description, Recoverable, Suggested Action.
enum OipErrorSeverity { info, warning, error, critical }

class OipError {
  const OipError({
    required this.code,
    required this.severity,
    required this.description,
    required this.recoverable,
    this.suggestedAction,
  });

  final String code;
  final OipErrorSeverity severity;
  final String description;
  final bool recoverable;
  final String? suggestedAction;

  Map<String, Object?> toJson() => {
        'code': code,
        'severity': severity.name,
        'description': description,
        'recoverable': recoverable,
        if (suggestedAction != null) 'suggestedAction': suggestedAction,
      };
}
