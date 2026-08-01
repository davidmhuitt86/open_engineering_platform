import 'package:flutter/material.dart';

/// The primary navigation items of the left Navigation Rail (SDD-003).
///
/// This is the single source of truth for navigation: the rail, the
/// router, and the command palette (future) all read from this list
/// rather than duplicating it.
enum StudioDestination {
  dashboard('Dashboard', '/', Icons.dashboard_outlined, Icons.dashboard),
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
