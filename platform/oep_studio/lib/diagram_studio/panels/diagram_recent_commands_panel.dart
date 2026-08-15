import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// Recent Commands panel — the undo stack's descriptions, most recent
/// first (WORK_PACKAGE_024, ENGINE-TASK-000114; mirrors the Demonstration
/// Host's own "Editing Productivity" affordance, `CommandHistory.
/// recentDescriptions`). Reflects what CAN currently be undone, not a
/// historical log — a command that has been undone no longer appears.
class DiagramRecentCommandsPanel extends StatelessWidget {
  const DiagramRecentCommandsPanel({required this.descriptions, super.key});

  final List<String> descriptions;

  @override
  Widget build(BuildContext context) {
    if (descriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No commands yet.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: descriptions.length,
      itemBuilder: (context, index) {
        return ListTile(
          dense: true,
          leading: Text(
            '${index + 1}',
            style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11),
          ),
          title: Text(
            descriptions[index],
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
          ),
        );
      },
    );
  }
}
