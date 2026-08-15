import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-004 §6 (Engineering Exchange Integration — preparation only).
///
/// **No networking, no upload** — this file (and every UI built on top of
/// it) never calls `FoundationBridge` methods that publish/upload; it only
/// reads already-computed local state (Title Block, whether a validation
/// pass has been run this session, whether tabular reports have rows) to
/// render a Publishing Checklist / Exchange Readiness summary. Package-
/// level validation itself is `PackageValidationDialog` /
/// `FoundationBridge.verifyPackage` (AP-DS-002 work, reused here, not
/// duplicated) — this class does not reimplement Foundation package
/// validation, it only asks "has [validationPassed] already been supplied
/// by the caller" (the caller ran `DiagramIntelligenceService.validate()`
/// itself; this class never calls it).
class ExchangeChecklistItem {
  final String label;
  final bool complete;
  final String detail;

  const ExchangeChecklistItem({required this.label, required this.complete, required this.detail});
}

class ExchangeChecklist {
  static List<ExchangeChecklistItem> build({
    required TitleBlock titleBlock,
    required bool validationPassed,
    required bool validationRun,
    required int bomRowCount,
    required int nodeCount,
  }) {
    return [
      ExchangeChecklistItem(
        label: 'Title block complete',
        complete: titleBlock.company.isNotEmpty && titleBlock.drawingNumber.isNotEmpty && titleBlock.revision.isNotEmpty,
        detail: titleBlock.drawingNumber.isEmpty ? 'Drawing Number is not set.' : 'Drawing ${titleBlock.drawingNumber} rev ${titleBlock.revision}.',
      ),
      ExchangeChecklistItem(
        label: 'Validation passing',
        complete: validationRun && validationPassed,
        detail: !validationRun ? 'Validation has not been run this session.' : (validationPassed ? 'Last validation passed.' : 'Last validation reported failures.'),
      ),
      ExchangeChecklistItem(
        label: 'Bill of Materials generated',
        complete: bomRowCount > 0,
        detail: bomRowCount > 0 ? '$bomRowCount BOM line(s).' : 'No orderable components found.',
      ),
      ExchangeChecklistItem(
        label: 'Diagram is non-empty',
        complete: nodeCount > 0,
        detail: '$nodeCount Engineering Object(s).',
      ),
    ];
  }

  static bool ready(List<ExchangeChecklistItem> items) => items.every((i) => i.complete);
}
