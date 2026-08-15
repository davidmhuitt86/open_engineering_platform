import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';
import '../perspective/perspective.dart';

/// Real sidebar sub-items for the Engineering Perspective — real
/// navigation to the already-existing Objects/Relationships/Validation
/// pages (separate `StudioDestination`s one level up in `StudioShell`),
/// not a new in-perspective object browser. Rebuilding Engineering
/// Object/Relationship browsing inside the Workbench would duplicate
/// already-shipped pages and is out of this phase's scope; jumping to
/// them from here is real, honest reuse.
List<PerspectiveSidebarItem> _engineeringSidebarItems(BuildContext context) => [
      PerspectiveSidebarItem(
        label: 'Engineering Objects',
        icon: Icons.category_outlined,
        onTap: () => context.go(StudioDestination.objects.path),
      ),
      PerspectiveSidebarItem(
        label: 'Relationships',
        icon: Icons.hub_outlined,
        onTap: () => context.go(StudioDestination.relationships.path),
      ),
      PerspectiveSidebarItem(
        label: 'Validation',
        icon: Icons.fact_check_outlined,
        onTap: () => context.go(StudioDestination.validation.path),
      ),
    ];

/// This Perspective's own center content is still an honest "not yet
/// built" placeholder (per WP-DS-006 Phase 1's "shell only" scope) — its
/// real value today is the sidebar submenu above, jumping to pages that
/// already exist.
Widget _engineeringCenter(BuildContext context) {
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

final engineeringPerspective = Perspective(
  id: 'engineering',
  title: 'Engineering',
  icon: Icons.engineering_outlined,
  centerBuilder: _engineeringCenter,
  sidebarSubItemsProvider: _engineeringSidebarItems,
);
