import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../features/validation/suggested_fixes.dart';

/// The findings list itself — extracted (WORK_PACKAGE_025,
/// ENGINE-TASK-000125) so both the global Validation page and Diagram
/// Studio's own `DiagramValidationPanel` (WORK_PACKAGE_024, since
/// retired along with the native renderer) render `ValidationReport`
/// findings identically instead of maintaining two copies. Each row
/// shows a Suggested Fix when `ValidationFinding.code` has one
/// (`SuggestedFixes`) and, when [onFindingTap] is given, becomes
/// tappable ("Click-to-navigate").
class ValidationFindingsList extends StatelessWidget {
  const ValidationFindingsList({required this.report, this.onFindingTap, super.key});

  final ValidationReport? report;
  final void Function(ValidationFinding finding)? onFindingTap;

  @override
  Widget build(BuildContext context) {
    final findings = report?.findings ?? const [];
    if (findings.isEmpty) {
      return const Center(
        child: Icon(Icons.check_circle_outline, color: StudioColors.success, size: 28),
      );
    }
    return ListView.builder(
      itemCount: findings.length,
      itemBuilder: (context, index) => ValidationFindingTile(
        finding: findings[index],
        onTap: onFindingTap == null ? null : () => onFindingTap!(findings[index]),
      ),
    );
  }
}

/// AP-OEP-DIAGRAM-VALIDATION-001 — the single-finding presentation unit
/// [ValidationFindingsList] itself renders per row, extracted so the
/// Diagram Property Inspector's own, much smaller "Validation Findings"
/// section (`EngineeringNodeProperties`/`EngineeringRelationshipProperties`)
/// can show the same severity color, message, and Suggested Fix
/// treatment without embedding a second `ListView` inside the
/// Inspector's own `ListView`, and without a second copy of this
/// presentation logic.
class ValidationFindingTile extends StatelessWidget {
  const ValidationFindingTile({required this.finding, this.onTap, super.key});

  final ValidationFinding finding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.severity) {
      ValidationSeverity.error => StudioColors.error,
      ValidationSeverity.warning => StudioColors.warning,
      ValidationSeverity.info => StudioColors.info,
    };
    final fix = SuggestedFixes.forCode(finding.code);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.circle, size: 8, color: color),
        title: Text(
          finding.message,
          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
        ),
        subtitle: fix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  fix,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                ),
              ),
        isThreeLine: fix != null,
        onTap: onTap,
      ),
    );
  }
}
