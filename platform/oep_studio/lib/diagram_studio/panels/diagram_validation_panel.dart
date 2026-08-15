import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/validation_findings_list.dart';

/// Validation panel — shows `ValidationReport` findings for the current
/// graph, with a manual revalidate action (WORK_PACKAGE_024,
/// ENGINE-TASK-000114). A Studio-styled port of the Demonstration
/// Host's `ValidationPanel`. As of WORK_PACKAGE_025 (ENGINE-TASK-000125),
/// row rendering itself is shared with the global Validation page via
/// `ValidationFindingsList`, so "Suggested Fixes" and Click-to-navigate
/// behave identically in both places.
class DiagramValidationPanel extends StatelessWidget {
  const DiagramValidationPanel({
    required this.report,
    required this.onRevalidate,
    this.onFindingTap,
    super.key,
  });

  final ValidationReport? report;
  final VoidCallback onRevalidate;
  final void Function(ValidationFinding finding)? onFindingTap;

  @override
  Widget build(BuildContext context) {
    final findings = report?.findings ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            children: [
              Text(
                findings.isEmpty ? 'Clean — no findings' : '${findings.length} finding(s)',
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
              ),
              const Spacer(),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Revalidate',
                icon: const Icon(Icons.refresh, color: StudioColors.textSecondary),
                onPressed: onRevalidate,
              ),
            ],
          ),
        ),
        Expanded(child: ValidationFindingsList(report: report, onFindingTap: onFindingTap)),
      ],
    );
  }
}
