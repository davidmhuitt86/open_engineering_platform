import 'package:flutter/material.dart';

/// The primary navigation items of the left Navigation Rail (SDD-003).
///
/// This is the single source of truth for navigation: the rail, the
/// router, and the command palette (future) all read from this list
/// rather than duplicating it.
enum StudioDestination {
  dashboard('Dashboard', '/', Icons.dashboard_outlined, Icons.dashboard),
  // AP-OEP-WORKSPACE-SHELL-001 — the first OEP-wide tabbed workspace
  // (`EngineeringWorkspacePage`), built on the canonical `SurfaceRegistry`
  // (AP-OEP-SURFACE-ARCHITECTURE-002/003). Deliberately a new,
  // additional destination, not a replacement of any existing one —
  // the sidebar and every existing route remain fully functional and
  // reachable exactly as before.
  workspace(
    'Engineering Workspace',
    '/workspace',
    Icons.tab_outlined,
    Icons.tab,
  ),
  projectExplorer(
    'Project Explorer',
    '/project',
    Icons.workspaces_outlined,
    Icons.workspaces,
  ),
  knowledge(
    'Knowledge Studio',
    '/knowledge',
    Icons.auto_awesome_outlined,
    Icons.auto_awesome,
  ),
  diagram(
    'Diagram Studio',
    '/diagram',
    Icons.polyline_outlined,
    Icons.polyline,
  ),
  acquisition(
    'Engineering Acquisition',
    '/acquisition',
    Icons.cloud_download_outlined,
    Icons.cloud_download,
  ),
  repository('Repository', '/repository', Icons.folder_outlined, Icons.folder),
  objects('Objects', '/objects', Icons.category_outlined, Icons.category),
  relationships(
    'Relationships',
    '/relationships',
    Icons.hub_outlined,
    Icons.hub,
  ),
  search('Search', '/search', Icons.search_outlined, Icons.search),
  graph('Graph', '/graph', Icons.account_tree_outlined, Icons.account_tree),
  validation(
    'Validation',
    '/validation',
    Icons.fact_check_outlined,
    Icons.fact_check,
  ),
  packages(
    'Packages',
    '/packages',
    Icons.inventory_2_outlined,
    Icons.inventory_2,
  ),
  engineeringIntelligence(
    'Engineering Intelligence',
    '/engineering-intelligence',
    Icons.psychology_outlined,
    Icons.psychology,
  ),
  exchange(
    'Engineering Exchange',
    '/exchange',
    Icons.storefront_outlined,
    Icons.storefront,
  ),
  copilot(
    'AI Engineering Copilot',
    '/copilot',
    Icons.auto_awesome_outlined,
    Icons.auto_awesome,
  ),
  // AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001 — the Engineering and
  // Instruments Perspectives' real functionality (§ `workbench/
  // perspectives/engineering_perspective.dart`/`instruments_perspective.dart`),
  // migrated to these ordinary Workspace Surfaces.
  // AP-OEP-WORKBENCH-RETIREMENT-001 — `/diagram-classic` and the
  // Workbench Perspective framework these two destinations were
  // originally added alongside have since been retired; these two
  // Surfaces are now the sole home for this content.
  engineeringWorkbench(
    'Engineering',
    '/engineering',
    Icons.engineering_outlined,
    Icons.engineering,
  ),
  instrumentsWorkbench(
    'Instruments',
    '/instruments',
    Icons.speed_outlined,
    Icons.speed,
  ),
  settings('Settings', '/settings', Icons.settings_outlined, Icons.settings);

  const StudioDestination(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  static StudioDestination fromPath(String path) {
    return StudioDestination.values.firstWhere(
      (destination) => destination.path == path,
      orElse: () => StudioDestination.dashboard,
    );
  }
}
