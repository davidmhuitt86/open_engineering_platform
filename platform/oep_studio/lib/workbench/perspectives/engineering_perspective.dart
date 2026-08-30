import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';

/// This content's own placeholder center (per WP-DS-006 Phase 1's "shell
/// only" scope, historically) — its real value is the button row in
/// [EngineeringSurfacePage] below, jumping to pages that already exist.
///
/// AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001 — made public (was
/// `_engineeringCenter`) so [EngineeringSurfacePage] can reuse the exact
/// same content instead of forking it. AP-OEP-WORKBENCH-RETIREMENT-001 —
/// the Workbench `Perspective` this content used to back (`engineeringPerspective`)
/// was retired along with `PerspectiveManager`/`EngineeringWorkbenchPage`;
/// [EngineeringSurfacePage] (`StudioDestination.engineeringWorkbench`) is
/// now this content's sole home.
Widget engineeringPerspectiveCenter(BuildContext context) {
  return Container(
    color: StudioColors.background,
    alignment: Alignment.center,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.engineering_outlined, size: 40, color: StudioColors.textDisabled),
        SizedBox(height: 12),
        Text('Engineering', style: TextStyle(fontSize: 16, color: StudioColors.textSecondary)),
        SizedBox(height: 4),
        Text(
          'Use the sidebar to jump to Engineering Objects, Relationships, or Validation.',
          style: TextStyle(fontSize: 12, color: StudioColors.textDisabled),
        ),
      ],
    ),
  );
}

/// AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001 — the Engineering
/// Perspective's real functionality (per [engineeringPerspectiveCenter]'s
/// own doc comment: jumping to Engineering Objects/Relationships/
/// Validation) exposed as an ordinary Workspace Surface
/// (`StudioDestination.engineeringWorkbench`) — same three navigation
/// targets, same reasoning (real reuse of already-shipped pages, not a
/// new in-Surface browser), no second implementation of those pages.
///
/// The center placeholder's visuals are intentionally *not* reused
/// verbatim from [engineeringPerspectiveCenter]: that widget's caption
/// ("Use the sidebar to jump to...") described the retired Workbench
/// sidebar's per-Perspective submenu chrome, which has no equivalent
/// inside a plain Surface page — repeating that caption here would point
/// at UI that no longer exists. The three shortcuts are rendered as
/// inline buttons instead, using
/// [openOrActivateDestination] (the current, general Workspace-aware
/// navigation primitive every other cross-Surface navigation function
/// already goes through) rather than the Perspective sidebar items' own
/// raw `context.go`: the correct behavior for a Surface opened as a
/// Workspace tab is to activate the target Surface's own tab, not leave
/// Workspace entirely.
class EngineeringSurfacePage extends ConsumerWidget {
  const EngineeringSurfacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: StudioColors.background,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.engineering_outlined, size: 40, color: StudioColors.textDisabled),
                SizedBox(height: 12),
                Text('Engineering', style: TextStyle(fontSize: 16, color: StudioColors.textSecondary)),
                SizedBox(height: 4),
                Text(
                  'Jump to Engineering Objects, Relationships, or Validation.',
                  style: TextStyle(fontSize: 12, color: StudioColors.textDisabled),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('engineering-surface-objects'),
                onPressed: () => openOrActivateDestination(context, ref, StudioDestination.objects),
                icon: const Icon(Icons.category_outlined, size: 16),
                label: const Text('Engineering Objects'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('engineering-surface-relationships'),
                onPressed: () => openOrActivateDestination(context, ref, StudioDestination.relationships),
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('Relationships'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('engineering-surface-validation'),
                onPressed: () => openOrActivateDestination(context, ref, StudioDestination.validation),
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('Validation'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
