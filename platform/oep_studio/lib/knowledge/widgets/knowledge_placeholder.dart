import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// A compact placeholder for a Knowledge Studio panel that has no
/// functionality yet (Work Package 007 STUDIO-TASK-000013: "All
/// remaining panels shall initially use placeholder content"). Smaller
/// than `PlaceholderWorkspace` — sized for a panel cell, not a full
/// Primary Workspace.
class KnowledgePlaceholder extends StatelessWidget {
  const KnowledgePlaceholder({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: StudioColors.textDisabled, fontSize: 12),
        ),
      ),
    );
  }
}
