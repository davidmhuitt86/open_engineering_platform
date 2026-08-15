import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/knowledge_validation_exception.dart';
import '../widgets/knowledge_placeholder.dart';
import 'commit_report_dialog.dart';

/// The Commit Summary panel. Originally Work Package 008
/// STUDIO-TASK-000018 ("Display exactly what would be committed... no
/// repository modification occurs... Commit remains disabled") — now,
/// under Work Package 012, this shows the real `CommitPlan` and its
/// "Commit" button performs a real, one-shot, transactional write into
/// the open Foundation repository via `commitToFoundation()`. Kept the
/// original widget/file identity (`CommitPreviewPanel`) since it is the
/// same panel in the same place in the layout, now backed by a real
/// model instead of a simulated one.
class CommitPreviewPanel extends ConsumerStatefulWidget {
  const CommitPreviewPanel({super.key});

  @override
  ConsumerState<CommitPreviewPanel> createState() => _CommitPreviewPanelState();
}

class _CommitPreviewPanelState extends ConsumerState<CommitPreviewPanel> {
  bool _committing = false;

  Future<void> _confirmAndCommit(int newObjectCount, int newRelationshipCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Commit to Repository'),
        content: Text(
          'This will create $newObjectCount new Engineering Object(s) and '
          '$newRelationshipCount new Relationship(s) in the open Foundation '
          'repository. This cannot be undone from within OEP Studio. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Commit')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _committing = true);
    try {
      await ref.read(foundationRuntimeServiceProvider.notifier).commitToFoundation();
      if (!mounted) return;
      final report = ref.read(foundationRuntimeServiceProvider).latestCommitReport;
      if (report != null) {
        await showCommitReportDialog(context, report: report);
      }
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text('Couldn\'t Commit'),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(foundationRuntimeServiceProvider.select((state) => state.commitPlan));
    final latestReport = ref.watch(foundationRuntimeServiceProvider.select((state) => state.latestCommitReport));
    if (plan == null) {
      return const KnowledgePlaceholder(
        message: 'Create a Knowledge Curation Session to preview repository changes.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(label: 'New Objects', value: '${plan.newObjects.length}'),
                  _SummaryRow(label: 'New Relationships', value: '${plan.newRelationships.length}'),
                  _SummaryRow(label: 'Existing Objects', value: '${plan.existingObjectCount}'),
                  _SummaryRow(label: 'Merge Operations', value: '${plan.mergeOperationCount}'),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Repository Object Count',
                    value: plan.currentStatistics == null ? 'unavailable' : '${plan.currentStatistics!.totalObjectCount}',
                  ),
                  _SummaryRow(
                    label: 'Repository Relationship Count',
                    value: plan.currentStatistics == null ? 'unavailable' : '${plan.currentStatistics!.relationshipCount}',
                  ),
                  if (plan.validationErrors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Validation Errors',
                      style: TextStyle(color: StudioColors.error, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final error in plan.validationErrors)
                      _IssueLine(message: error, color: StudioColors.error, icon: Icons.error_outline),
                  ],
                  if (plan.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Warnings',
                      style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final warning in plan.warnings)
                      _IssueLine(message: warning, color: StudioColors.warning, icon: Icons.warning_amber_outlined),
                  ],
                  if (latestReport != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showCommitReportDialog(context, report: latestReport),
                        icon: Icon(
                          latestReport.success ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: latestReport.success ? StudioColors.success : StudioColors.error,
                        ),
                        label: const Text('View Last Commit Report'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: plan.canCommit
                  ? 'Create new Engineering Objects and Relationships in the open repository.'
                  : 'Resolve validation errors and ensure there is at least one new object or relationship to commit.',
              child: ElevatedButton(
                onPressed: plan.canCommit && !_committing
                    ? () => _confirmAndCommit(plan.newObjects.length, plan.newRelationships.length)
                    : null,
                child: _committing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: StudioColors.textPrimary),
                      )
                    : const Text('Commit'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          ),
          Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.message, required this.color, required this.icon});

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 11.5))),
        ],
      ),
    );
  }
}
