import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../perspective/perspective.dart';

/// WP-DS-006 Engineering Workbench — the shell's own Status Bar region,
/// distinct from `StudioStatusBar` (the app-wide status bar `StudioShell`
/// already owns) — shows which Perspective is active, nothing engineering-
/// specific (no engineering logic belongs in the Workbench shell).
class WorkbenchStatusBar extends StatelessWidget {
  const WorkbenchStatusBar({super.key, required this.perspective});

  final Perspective perspective;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      color: StudioColors.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(perspective.icon, size: 12, color: StudioColors.textDisabled),
          const SizedBox(width: 6),
          Text(
            '${perspective.title} Perspective',
            style: const TextStyle(fontSize: 11, color: StudioColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
