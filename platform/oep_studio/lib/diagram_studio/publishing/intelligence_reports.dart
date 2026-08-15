import '../../core/foundation/oep_api_types.dart';

/// AP-DS-004: Validation Report / Reasoning Report rendering.
///
/// **Constraint honored**: neither function computes findings, evidence,
/// severity, or conclusions — both take an already-produced
/// [OepWorkflowResult] (from [DiagramIntelligenceService.validate]/
/// `.reason`, the ONLY caller of these) and format it. Per this phase's
/// own "Publishing shall never duplicate engineering logic" rule and
/// `RecommendationPanel`'s AP-DS-003 precedent (see its own doc comment):
/// `OepWorkflowResult` is a coarse `{success, summary, executionTimeMs}`
/// shape, not a structured findings/evidence/severity/rules object. The
/// spec names "Findings / Severity / Evidence / Rules / Recommendations /
/// Resolution Status" (Validation) and "Conclusions / Evidence /
/// Confidence / Traceability / Knowledge References" (Reasoning) as
/// headings this report SHOULD organize under — this renderer creates
/// those section headings honestly labeled, but populates them from
/// [OepWorkflowResult.summary] (free text) and [objectIds] (the affected
/// Foundation objects), NOT from fabricated structured fields the API
/// does not return. Where the API doesn't give us a field, the section
/// says so rather than inventing content.
class IntelligenceReportRenderer {
  static String renderValidationMarkdown({
    required OepWorkflowResult result,
    required List<String> objectIds,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# Validation Report');
    buffer.writeln();
    buffer.writeln('_Generated ${DateTime.now().toIso8601String()}_');
    buffer.writeln();
    buffer.writeln('**Status:** ${result.success ? "PASS" : "FAIL"}');
    buffer.writeln();
    buffer.writeln('**Execution time:** ${result.executionTimeMs.toStringAsFixed(2)} ms');
    buffer.writeln();
    buffer.writeln('## Findings / Summary');
    buffer.writeln();
    buffer.writeln(result.summary.isEmpty ? '_No summary returned._' : result.summary);
    buffer.writeln();
    buffer.writeln('## Affected Objects (${objectIds.length})');
    buffer.writeln();
    if (objectIds.isEmpty) {
      buffer.writeln('_None reported._');
    } else {
      for (final id in objectIds) {
        buffer.writeln('- `$id`');
      }
    }
    buffer.writeln();
    buffer.writeln('## Severity / Evidence / Rules / Recommendations / Resolution Status');
    buffer.writeln();
    buffer.writeln(
      '_The Engineering Intelligence Platform\'s current validation workflow result does not expose '
      'per-finding severity, evidence, rule identifiers, discrete recommendations, or a resolution-status '
      'field as separate structured data — only the pass/fail status and the free-text summary above. '
      'This section is disclosed as unpopulated rather than fabricated, matching this platform\'s '
      '"do not overclaim structure the API doesn\'t provide" precedent (`RecommendationPanel`, AP-DS-003)._',
    );
    return buffer.toString();
  }

  static String renderReasoningMarkdown({
    required OepWorkflowResult result,
    required List<String> objectIds,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# Reasoning Report');
    buffer.writeln();
    buffer.writeln('_Generated ${DateTime.now().toIso8601String()}_');
    buffer.writeln();
    buffer.writeln('**Status:** ${result.success ? "Completed" : "Failed"}');
    buffer.writeln();
    buffer.writeln('**Execution time:** ${result.executionTimeMs.toStringAsFixed(2)} ms');
    buffer.writeln();
    buffer.writeln('## Engineering Conclusions');
    buffer.writeln();
    buffer.writeln(result.summary.isEmpty ? '_No summary returned._' : result.summary);
    buffer.writeln();
    buffer.writeln('## Supporting Evidence — Referenced Objects (${objectIds.length})');
    buffer.writeln();
    if (objectIds.isEmpty) {
      buffer.writeln('_None reported._');
    } else {
      for (final id in objectIds) {
        buffer.writeln('- `$id`');
      }
    }
    buffer.writeln();
    buffer.writeln('## Confidence / Recommendation Traceability / Knowledge References');
    buffer.writeln();
    buffer.writeln(
      '_The reasoning workflow result does not expose a numeric confidence score, per-recommendation '
      'traceability links, or discrete knowledge-reference identifiers as separate structured data — '
      'only the free-text summary above and the affected object list. Disclosed as unpopulated rather '
      'than fabricated._',
    );
    return buffer.toString();
  }
}
