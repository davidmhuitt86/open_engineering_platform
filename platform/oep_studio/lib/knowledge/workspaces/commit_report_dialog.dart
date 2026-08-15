import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../models/commit_report.dart';

/// The Commit Report (Work Package 012 STUDIO-TASK-000033): "Display
/// the outcome of Repository Commit." Shown immediately after a commit
/// attempt (success or failure), and re-openable afterward from the
/// Commit Summary panel / Property Inspector's Session mode ("Last
/// Commit Report").
Future<void> showCommitReportDialog(BuildContext context, {required CommitReport report}) {
  return showDialog<void>(context: context, builder: (context) => _CommitReportDialog(report: report));
}

class _CommitReportDialog extends StatelessWidget {
  const _CommitReportDialog({required this.report});

  final CommitReport report;

  Future<void> _export(BuildContext context) async {
    final location = await getSaveLocation(
      suggestedName: 'commit-report-${report.id}.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;
    final encoder = const JsonEncoder.withIndent('  ');
    await File(location.path).writeAsString(encoder.convert(report.toJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commit report exported.')));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = report.success ? StudioColors.success : StudioColors.error;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Row(
        children: [
          Icon(report.success ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Text(report.success ? 'Commit Succeeded' : 'Commit Failed'),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 480,
        child: ListView(
          children: [
            _Row(label: 'Objects Created', value: '${report.objectsCreated.length}'),
            _Row(label: 'Relationships Created', value: '${report.relationshipsCreated.length}'),
            _Row(label: 'Objects Merged', value: '${report.objectsMergedCount}'),
            _Row(label: 'Commit Duration', value: '${report.durationMs} ms'),
            _Row(
              label: 'Repository Object Count (before → after)',
              value: report.statisticsBefore == null || report.statisticsAfter == null
                  ? 'unavailable'
                  : '${report.statisticsBefore!.totalObjectCount} → ${report.statisticsAfter!.totalObjectCount}',
            ),
            _Row(
              label: 'Repository Relationship Count (before → after)',
              value: report.statisticsBefore == null || report.statisticsAfter == null
                  ? 'unavailable'
                  : '${report.statisticsBefore!.relationshipCount} → ${report.statisticsAfter!.relationshipCount}',
            ),
            _Row(label: 'Timestamp', value: formatDateTime(report.timestamp)),
            if (report.objectsCreated.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionTitle('Objects Created'),
              for (final object in report.objectsCreated)
                _ListItem('${object.name} — ${object.category.label} (${object.objectId})'),
            ],
            if (report.relationshipsCreated.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionTitle('Relationships Created'),
              for (final relationship in report.relationshipsCreated)
                _ListItem(
                  '${relationship.sourceObjectId} —${relationship.type.label}→ ${relationship.targetObjectId}',
                ),
            ],
            if (report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionTitle('Warnings', color: StudioColors.warning),
              for (final warning in report.warnings) _ListItem(warning, color: StudioColors.warning),
            ],
            if (report.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionTitle('Errors', color: StudioColors.error),
              for (final error in report.errors) _ListItem(error, color: StudioColors.error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _export(context), child: const Text('Export as JSON')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))),
          Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.color = StudioColors.textPrimary});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem(this.text, {this.color = StudioColors.textPrimary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5), overflow: TextOverflow.ellipsis),
    );
  }
}
