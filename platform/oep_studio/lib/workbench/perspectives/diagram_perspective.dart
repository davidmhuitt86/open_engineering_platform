import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/workspace/workspace_manager.dart';
import '../../diagram_studio/workspaces/diagram_studio_page.dart';
import '../perspective/perspective.dart';

const _diagramFileTypeGroup = XTypeGroup(label: 'Diagram', extensions: ['json']);

/// Real sidebar sub-items for the Diagram Perspective: the currently open
/// document, and recent documents from `WorkspaceManager` (WP-STUDIO-029,
/// already the single source of truth for recent-workspace tracking — not
/// duplicated here). Opening a recent document calls
/// `EngineeringProjectNotifier.openDocument` directly, the same call
/// `CommandRegistry`'s own already-shipped `diagram.openDocument` command
/// makes (WP-STUDIO-023) — that path does not run
/// `DiagramStudioPage`'s local unsaved-changes confirmation dialog either,
/// so this sidebar introduces no new data-loss risk beyond what the
/// Command Palette already exposes.
List<PerspectiveSidebarItem> _diagramSidebarItems(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final projectState = container.read(engineeringProjectServiceProvider);
  final activeName = projectState.documentPath?.split(RegExp(r'[\\/]')).last ?? 'Untitled Diagram';

  Future<void> open(String path) => container.read(engineeringProjectServiceProvider.notifier).openDocument(path);

  final items = <PerspectiveSidebarItem>[
    PerspectiveSidebarItem(label: activeName, active: true, icon: Icons.description_outlined, onTap: () {}),
    PerspectiveSidebarItem(
      label: 'Open Diagram…',
      icon: Icons.folder_open_outlined,
      onTap: () async {
        final file = await openFile(acceptedTypeGroups: [_diagramFileTypeGroup]);
        if (file != null) await open(file.path);
      },
    ),
    PerspectiveSidebarItem(
      label: 'New Diagram',
      icon: Icons.add_outlined,
      onTap: () => container.read(engineeringProjectServiceProvider.notifier).newDocument(),
    ),
  ];

  final recent = WorkspaceManager.instance.recentWorkspaces;
  for (final path in recent.take(5)) {
    items.add(PerspectiveSidebarItem(label: path.split(RegExp(r'[\\/]')).last, onTap: () => open(path)));
  }
  return items;
}

/// WP-DS-006 Migration: "Current Diagram Studio becomes the first
/// Perspective... Simply host the existing Diagram Studio inside the new
/// shell. No engineering functionality shall regress."
///
/// [DiagramStudioPage] is embedded completely unchanged — it already owns
/// its own toolbar, panels, and Instrument Dock internally (AP-DS-001
/// through WP-DS-005A), so this Perspective deliberately supplies no
/// [Perspective.toolbarProvider]/panel providers of its own: doing so
/// would either duplicate `DiagramStudioPage`'s existing chrome or require
/// redesigning it, both explicitly out of scope for this phase ("Do NOT
/// redesign Diagram UI yet").
final diagramPerspective = Perspective(
  id: 'diagram',
  title: 'Diagram',
  icon: Icons.polyline_outlined,
  centerBuilder: (context) => const DiagramStudioPage(),
  // DiagramStudioPage already sits under StudioShell's own StudioStatusBar
  // and supplies its own toolbar/panel chrome — a second, shell-level
  // Workbench status bar stacked on top is redundant and, at typical test/
  // small-window sizes, was measured to overflow DiagramStudioPage's own
  // already-tight internal panels by ~10px. See `Perspective
  // .suppressWorkbenchStatusBar`'s own doc comment.
  suppressWorkbenchStatusBar: true,
  sidebarSubItemsProvider: _diagramSidebarItems,
);
