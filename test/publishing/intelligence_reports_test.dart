import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/diagram_studio/publishing/intelligence_reports.dart';

/// AP-DS-004 constraint check: Validation/Reasoning report rendering
/// takes an already-produced `OepWorkflowResult` (synthetic here, since
/// a real one requires `DiagramIntelligenceService`/`FoundationBridge` —
/// see `test/intelligence_panels_test.dart`'s own doc comment for why
/// that's untestable in this environment) and must never invent
/// structured findings/severity/evidence/confidence fields the API
/// didn't return.
void main() {
  const result = OepWorkflowResult(kind: WorkflowKind.validate, success: true, summary: 'All checks passed.', executionTimeMs: 12.5);

  test('renderValidationMarkdown includes status, summary, and affected objects', () {
    final markdown = IntelligenceReportRenderer.renderValidationMarkdown(result: result, objectIds: ['obj-1', 'obj-2']);

    expect(markdown, contains('Validation Report'));
    expect(markdown, contains('PASS'));
    expect(markdown, contains('All checks passed.'));
    expect(markdown, contains('obj-1'));
    expect(markdown, contains('obj-2'));
  });

  test('renderValidationMarkdown discloses unsupported structured fields rather than fabricating them', () {
    final markdown = IntelligenceReportRenderer.renderValidationMarkdown(result: result, objectIds: const []);
    expect(markdown, contains('does not expose'));
    expect(markdown, contains('None reported'));
  });

  test('renderReasoningMarkdown includes conclusions and evidence sections', () {
    final markdown = IntelligenceReportRenderer.renderReasoningMarkdown(result: result, objectIds: ['obj-9']);

    expect(markdown, contains('Reasoning Report'));
    expect(markdown, contains('Engineering Conclusions'));
    expect(markdown, contains('obj-9'));
    expect(markdown, contains('does not expose'));
  });

  test('failed result renders FAIL/Failed status', () {
    const failed = OepWorkflowResult(kind: WorkflowKind.validate, success: false, summary: 'Two isolated objects found.', executionTimeMs: 3.1);
    final markdown = IntelligenceReportRenderer.renderValidationMarkdown(result: failed, objectIds: const []);
    expect(markdown, contains('FAIL'));
  });
}
