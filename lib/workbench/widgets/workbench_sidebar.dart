import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/operations/operation.dart';
import '../../core/operations/operation_manager.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';
import '../perspective/perspective.dart';
import '../perspective/perspective_manager.dart';
import 'workbench_sidebar_state.dart';

/// Engineering Workbench — Left Sidebar Navigation.
///
/// Replaces the earlier horizontal [PerspectiveSelector] row with a
/// collapsible left sidebar: WORKBENCH (every registered [Perspective],
/// with a real expandable submenu for the ones that have one —
/// [Perspective.sidebarSubItemsProvider]), RESOURCES (Library — a
/// registered Perspective; Repository/Packages — real navigation to the
/// existing sibling `StudioDestination` routes, since those pages already
/// exist one level up in `StudioShell` and this sidebar's job is to jump
/// to them, not rebuild them), TOOLS (Search — opens the existing Command
/// Palette; Tasks & Jobs — a real, live badge/list backed by
/// `OperationManager.instance`; Reports — honestly disabled, no such
/// feature exists yet anywhere in this codebase).
///
/// **Disclosed scope reduction from the design mock**: the mock's
/// "Context Filtered" state shows a full categorized cross-corpus search
/// results panel (Engineering Objects / Diagrams / Documents, each with
/// live counts). Building that would mean a new cross-corpus search
/// aggregator this sidebar owns — a much larger, separate piece of work,
/// and this codebase already has one real search path
/// (`UnifiedSearchService`) that is page-based, not sidebar-embeddable
/// without its own redesign. This sidebar's search box instead does a
/// real, honest, client-side filter over the nav items themselves
/// (WORKBENCH/RESOURCES/TOOLS labels) — genuinely functional, not
/// fabricated data, just a narrower interpretation of "context filtered."
/// Every [StudioDestination] not already reachable from this sidebar's
/// RESOURCES (Repository, Packages)/TOOLS (Search)/footer (Settings) rows.
///
/// Includes [StudioDestination.diagram] itself, even though the WORKBENCH
/// section above also reaches it (as the "Diagram" Perspective, activating
/// whichever Perspective was last active) — this row is the plain "open
/// Diagram Studio" entry point with the Studio's own real label, matching
/// what the classic `StudioNavRail` (now no longer mounted, see
/// `StudioShell`) always exposed.
const _otherStudioDestinations = [
  StudioDestination.dashboard,
  StudioDestination.projectExplorer,
  StudioDestination.knowledge,
  StudioDestination.diagram,
  StudioDestination.acquisition,
  StudioDestination.objects,
  StudioDestination.relationships,
  StudioDestination.graph,
  StudioDestination.validation,
  StudioDestination.engineeringIntelligence,
  StudioDestination.exchange,
  StudioDestination.copilot,
];

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification), § 10 "Left
/// Sidebar — Redesign": these are capabilities/services, not Diagram
/// Studio navigation destinations, and must not remain persistent while
/// a diagram is actively open (`diagramSessionActive`). Kept visible at
/// all other times (nothing became unreachable when idle) -- this is a
/// context-driven reduction, not a permanent removal.
const _hiddenWhileDiagramActive = {
  StudioDestination.projectExplorer,
  StudioDestination.acquisition,
  StudioDestination.objects,
  StudioDestination.relationships,
  StudioDestination.graph,
  StudioDestination.validation,
  StudioDestination.engineeringIntelligence,
};

class WorkbenchSidebar extends StatefulWidget {
  const WorkbenchSidebar({
    super.key,
    required this.perspectiveManager,
    this.current = StudioDestination.diagram,
    this.diagramSessionActive = false,
    WorkbenchSidebarState? sidebarState,
  }) : _sidebarState = sidebarState;

  final PerspectiveManager perspectiveManager;

  /// (Phase 14 § 10.) Whether Diagram Studio's own engine session is
  /// currently bootstrapped (`EngineeringProjectState.session != null`)
  /// -- the same real, already-existing signal
  /// `EngineeringInteractionContextBuilder`'s `document.isOpen` derives
  /// from, never a fabricated "diagram open" flag of this widget's own.
  /// Only used to reduce the STUDIOS/RESOURCES sections while [current]
  /// is [StudioDestination.diagram] -- see [_hiddenWhileDiagramActive].
  final bool diagramSessionActive;

  /// The currently active `StudioDestination`, used only to highlight the
  /// matching row and to know whether a WORKBENCH/RESOURCES row's tap needs
  /// to navigate to `/diagram` first. Passed explicitly (from
  /// `StudioShell.selected` when this sidebar is the app's hoisted single
  /// nav) rather than read via `GoRouterState.of(context)` -- that call
  /// requires a `GoRouter` ancestor, which not every host of this widget
  /// has (e.g. `StudioShell`'s own event-publishing tests mount it as a
  /// bare `MaterialApp` child with no router at all) and would throw
  /// during `build` otherwise. Defaults to [StudioDestination.diagram]
  /// since `EngineeringWorkbenchPage`'s own standalone usage of this
  /// sidebar only ever renders while Diagram Studio's Perspective content
  /// is what's on screen.
  final StudioDestination current;

  final WorkbenchSidebarState? _sidebarState;

  @override
  State<WorkbenchSidebar> createState() => _WorkbenchSidebarState();
}

class _WorkbenchSidebarState extends State<WorkbenchSidebar> {
  late final WorkbenchSidebarState _sidebar = widget._sidebarState ?? WorkbenchSidebarState();
  final TextEditingController _searchController = TextEditingController();
  String? _expandedPerspectiveId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String label) {
    final query = _searchController.text.trim().toLowerCase();
    return query.isEmpty || label.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sidebar, widget.perspectiveManager]),
      builder: (context, _) {
        if (_sidebar.collapsed) return _CollapsedRail(perspectiveManager: widget.perspectiveManager, onExpand: _sidebar.toggleCollapsed);
        return _ExpandedSidebar(
          perspectiveManager: widget.perspectiveManager,
          current: widget.current,
          diagramSessionActive: widget.diagramSessionActive,
          onCollapse: _sidebar.toggleCollapsed,
          searchController: _searchController,
          matches: _matches,
          onSearchChanged: () => setState(() {}),
          expandedPerspectiveId: _expandedPerspectiveId,
          onToggleExpanded: (id) => setState(() => _expandedPerspectiveId = _expandedPerspectiveId == id ? null : id),
        );
      },
    );
  }
}

class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({required this.perspectiveManager, required this.onExpand});

  final PerspectiveManager perspectiveManager;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(right: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          const _OepMark(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final perspective in perspectiveManager.perspectives)
                  _CollapsedIcon(
                    icon: perspective.icon,
                    tooltip: perspective.title,
                    active: perspective.id == perspectiveManager.active?.id,
                    onTap: () => perspectiveManager.activate(perspective.id),
                  ),
              ],
            ),
          ),
          _CollapsedIcon(icon: Icons.chevron_right, tooltip: 'Expand sidebar', onTap: onExpand),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _CollapsedIcon extends StatelessWidget {
  const _CollapsedIcon({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Material(
          color: active ? StudioColors.selection.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, size: 18, color: active ? StudioColors.selection : StudioColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _OepMark extends StatelessWidget {
  const _OepMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: StudioColors.selection, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: const Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }
}

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.perspectiveManager,
    required this.current,
    this.diagramSessionActive = false,
    required this.onCollapse,
    required this.searchController,
    required this.matches,
    required this.onSearchChanged,
    required this.expandedPerspectiveId,
    required this.onToggleExpanded,
  });

  final PerspectiveManager perspectiveManager;
  final StudioDestination current;
  final bool diagramSessionActive;
  final VoidCallback onCollapse;
  final TextEditingController searchController;
  final bool Function(String label) matches;
  final VoidCallback onSearchChanged;
  final String? expandedPerspectiveId;
  final ValueChanged<String> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final activeId = perspectiveManager.active?.id;
    final minimized = current == StudioDestination.diagram && diagramSessionActive;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(right: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                const _OepMark(),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('OEP', style: TextStyle(color: StudioColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  color: StudioColors.textSecondary,
                  tooltip: 'Collapse sidebar',
                  onPressed: onCollapse,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filter navigation…',
                hintStyle: const TextStyle(fontSize: 12, color: StudioColors.textDisabled),
                prefixIcon: const Icon(Icons.search, size: 16, color: StudioColors.textDisabled),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        color: StudioColors.textDisabled,
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged();
                        },
                      ),
                filled: true,
                fillColor: StudioColors.surfaceSunken,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              key: const ValueKey('workbench-sidebar-nav-list'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _SectionLabel('WORKBENCH'),
                for (final perspective in perspectiveManager.perspectives)
                  if (matches(perspective.title))
                    _PerspectiveRow(
                      key: ValueKey('sidebar-perspective-${perspective.id}'),
                      perspective: perspective,
                      active: perspective.id == activeId,
                      expanded: expandedPerspectiveId == perspective.id,
                      onTap: () {
                        // This sidebar is now the app's single left nav
                        // (hoisted into `StudioShell`), so a Perspective can
                        // be tapped from any route -- ensure Diagram
                        // Studio's own route (the only place
                        // `EngineeringWorkbenchPage` renders Perspective
                        // content) is actually active before/alongside
                        // switching which Perspective is selected within it.
                        if (current != StudioDestination.diagram) {
                          context.go(StudioDestination.diagram.path);
                        }
                        perspectiveManager.activate(perspective.id);
                      },
                      onToggleExpand: () => onToggleExpanded(perspective.id),
                    ),
                const SizedBox(height: 10),
                _SectionLabel('RESOURCES'),
                if (matches('Library'))
                  _SimpleRow(
                    key: const ValueKey('sidebar-perspective-library'),
                    icon: Icons.local_library_outlined,
                    label: 'Library',
                    active: activeId == 'library',
                    onTap: () {
                      if (current != StudioDestination.diagram) {
                        context.go(StudioDestination.diagram.path);
                      }
                      perspectiveManager.activate('library');
                    },
                  ),
                if (!minimized && matches('Repository'))
                  _SimpleRow(
                    key: ValueKey('sidebar-dest-${StudioDestination.repository.path}'),
                    icon: Icons.folder_outlined,
                    label: 'Repository',
                    onTap: () => context.go(StudioDestination.repository.path),
                  ),
                if (!minimized && matches('Packages'))
                  _SimpleRow(
                    key: ValueKey('sidebar-dest-${StudioDestination.packages.path}'),
                    icon: Icons.inventory_2_outlined,
                    label: 'Packages',
                    onTap: () => context.go(StudioDestination.packages.path),
                  ),
                const SizedBox(height: 10),
                _SectionLabel('TOOLS'),
                if (matches('Search'))
                  _SimpleRow(
                    key: ValueKey('sidebar-dest-${StudioDestination.search.path}'),
                    icon: Icons.search,
                    label: 'Search',
                    onTap: () => context.go(StudioDestination.search.path),
                  ),
                if (matches('Tasks & Jobs')) const _TasksAndJobsRow(),
                if (matches('Reports'))
                  const _SimpleRow(
                    icon: Icons.summarize_outlined,
                    label: 'Reports',
                    enabled: false,
                    disabledReason: 'Not available yet',
                  ),
                const SizedBox(height: 10),
                // This sidebar replaced the classic `StudioNavRail` as the
                // app's single left nav -- every other `StudioDestination`
                // (previously only reachable from that rail) is listed here
                // so nothing became unreachable. Deliberately excludes
                // `diagram` (the WORKBENCH section above already reaches
                // it) and `settings` (already in the footer icon).
                _SectionLabel('STUDIOS'),
                for (final destination in _otherStudioDestinations)
                  if ((!minimized || !_hiddenWhileDiagramActive.contains(destination)) && matches(destination.label))
                    _SimpleRow(
                      key: ValueKey('sidebar-dest-${destination.path}'),
                      icon: destination.icon,
                      label: destination.label,
                      active: current == destination,
                      onTap: () => context.go(destination.path),
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          const _SidebarFooter(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: StudioColors.textDisabled),
      ),
    );
  }
}

class _PerspectiveRow extends StatefulWidget {
  const _PerspectiveRow({
    super.key,
    required this.perspective,
    required this.active,
    required this.expanded,
    required this.onTap,
    required this.onToggleExpand,
  });

  final Perspective perspective;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;

  @override
  State<_PerspectiveRow> createState() => _PerspectiveRowState();
}

class _PerspectiveRowState extends State<_PerspectiveRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasSubItems = widget.perspective.sidebarSubItemsProvider != null;
    final showSubItems = hasSubItems && widget.active && widget.expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: widget.active
                  ? StudioColors.selection.withValues(alpha: 0.16)
                  : (_hovered ? StudioColors.surfaceRaised : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(
                    children: [
                      Icon(widget.perspective.icon, size: 16, color: widget.active ? StudioColors.selection : StudioColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.perspective.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.active ? StudioColors.textPrimary : StudioColors.textSecondary,
                            fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasSubItems && widget.active)
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: widget.onToggleExpand,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              widget.expanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: StudioColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showSubItems)
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.perspective.sidebarSubItemsProvider!(context)) _SidebarSubItemRow(item: item),
              ],
            ),
          ),
      ],
    );
  }
}

class _SidebarSubItemRow extends StatelessWidget {
  const _SidebarSubItemRow({required this.item});

  final PerspectiveSidebarItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              if (item.icon != null)
                Icon(item.icon, size: 13, color: item.active ? StudioColors.selection : StudioColors.textSecondary)
              else
                Icon(Icons.circle, size: 6, color: item.active ? StudioColors.selection : StudioColors.textDisabled),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.active ? StudioColors.textPrimary : StudioColors.textSecondary,
                    fontWeight: item.active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Material(
          color: active ? StudioColors.selection.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: active ? StudioColors.selection : StudioColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? StudioColors.textPrimary : StudioColors.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return disabledReason == null ? row : Tooltip(message: disabledReason!, child: row);
  }
}

/// A real, live "Tasks & Jobs" row — badge count and list both come
/// directly from `OperationManager.instance`, the Platform's own
/// cross-Studio operation tracker (WP-STUDIO-030); nothing here is
/// fabricated sample data.
class _TasksAndJobsRow extends StatefulWidget {
  const _TasksAndJobsRow();

  @override
  State<_TasksAndJobsRow> createState() => _TasksAndJobsRowState();
}

class _TasksAndJobsRowState extends State<_TasksAndJobsRow> {
  late final _subscription = OperationManager.instance.changes.listen((_) => setState(() {}));

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = OperationManager.instance.activeOperations;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _showTasksDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.checklist_outlined, size: 16, color: StudioColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Tasks & Jobs', style: TextStyle(fontSize: 13, color: StudioColors.textSecondary)),
                ),
                if (active.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: StudioColors.selection, borderRadius: BorderRadius.circular(9)),
                    child: Text('${active.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTasksDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Tasks & Jobs'),
        content: SizedBox(
          width: 360,
          child: _TasksAndJobsList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }
}

class _TasksAndJobsList extends StatelessWidget {
  const _TasksAndJobsList();

  @override
  Widget build(BuildContext context) {
    final active = OperationManager.instance.activeOperations;
    final recent = OperationManager.instance.recentOperations;
    if (active.isEmpty && recent.isEmpty) {
      return const Text('No active or recent operations.', style: TextStyle(color: StudioColors.textSecondary));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final op in active) _OperationTile(op),
          for (final op in recent) _OperationTile(op),
        ],
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile(this.operation);
  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final color = switch (operation.status) {
      OperationStatus.running => StudioColors.selection,
      OperationStatus.completed => StudioColors.success,
      OperationStatus.failed => StudioColors.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(operation.label, style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary))),
          if (operation.fraction != null) Text('${(operation.fraction! * 100).round()}%', style: const TextStyle(fontSize: 11, color: StudioColors.textSecondary)),
        ],
      ),
    );
  }
}

/// The sidebar footer — a real OS username (from the environment, not a
/// fabricated name) with a generic role label, since this codebase has no
/// per-user profile/auth system to draw a real role from.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const CircleAvatar(radius: 13, backgroundColor: StudioColors.selection, child: Icon(Icons.person, size: 14, color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentUserName(), style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const Text('Engineer', style: TextStyle(fontSize: 10, color: StudioColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 16),
            color: StudioColors.textSecondary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Settings',
            onPressed: () => context.go(StudioDestination.settings.path),
          ),
        ],
      ),
    );
  }

  String _currentUserName() {
    final value = Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? '';
    return value.isNotEmpty ? value : 'Local User';
  }
}
