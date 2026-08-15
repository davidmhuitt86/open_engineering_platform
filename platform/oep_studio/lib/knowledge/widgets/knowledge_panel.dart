import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// A titled, bordered panel container shared by every Knowledge Studio
/// panel (SDD-016's seven-panel workspace layout) — consistent chrome
/// so each panel (Import Queue, Source Viewer, AI Suggestions,
/// Repository Matches, Engineering Review, Commit Summary) reads as
/// part of one workspace rather than unrelated widgets.
class KnowledgePanel extends StatelessWidget {
  const KnowledgePanel({required this.title, required this.icon, required this.child, super.key});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: StudioColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: StudioColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
