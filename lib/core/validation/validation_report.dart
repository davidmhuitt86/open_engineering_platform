import 'validation_finding.dart';

/// The result of running validation against an [EngineeringGraph]
/// (SDD-025/026). Immutable — validation never mutates the graph.
class ValidationReport {
  final List<ValidationFinding> findings;
  final DateTime generatedAt;

  ValidationReport({required this.findings, DateTime? generatedAt})
      : generatedAt = generatedAt ?? DateTime.now();

  factory ValidationReport.clean() => ValidationReport(findings: const []);

  bool get isClean => findings.isEmpty;

  bool get hasErrors =>
      findings.any((f) => f.severity == ValidationSeverity.error);

  List<ValidationFinding> get errors =>
      findings.where((f) => f.severity == ValidationSeverity.error).toList();

  List<ValidationFinding> get warnings =>
      findings.where((f) => f.severity == ValidationSeverity.warning).toList();

  Map<String, Object?> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'findings': findings.map((f) => f.toJson()).toList(),
      };
}
