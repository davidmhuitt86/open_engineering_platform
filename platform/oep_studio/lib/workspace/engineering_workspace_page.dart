import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/engineering_project_service.dart';
import '../core/surfaces/surface_definition.dart';
import '../core/surfaces/surface_registry.dart';
import '../core/theme/studio_colors.dart';
import '../diagram_studio/compare/compare_legacy_v2_webview.dart';
import '../diagram_studio/compare/diagram_with_compare_pane.dart';
import '../diagram_studio/controller/diagram_studio_controller_provider.dart';
import '../diagram_studio/tabs/diagram_tabs_controller.dart';
import '../diagram_studio/webview/legacy_v2_webview.dart';
import 'workspace_tab.dart';
import 'workspace_tabs_controller.dart';

/// AP-OEP-WORKSPACE-SHELL-001 — the first OEP-wide tabbed workspace
/// shell, generalizing the proven `WebSurfacesHostPage` tab pattern
/// (Diagram Studio's own "+"/tab-strip/`IndexedStack` system) from one
/// Studio to the whole app, built entirely on the canonical
/// `SurfaceRegistry` (AP-OEP-SURFACE-ARCHITECTURE-002/003) — no second
/// Surface list, no second identity source.
///
/// **Where this sits in the shell** (Phase 1's own question): this is a
/// perfectly ordinary `StudioDescriptor.pageBuilder` target
/// (`StudioDestination.workspace`, `/workspace`) — it renders inside
/// `StudioShell`'s existing, unmodified content slot, sidebar and all
/// (`StudioShell` was not touched by this package). `WebSurfacesHostPage`
/// itself was deliberately **not** repurposed as this shell (per the
/// task's own Phase 1 instruction) — it remains Diagram Studio's own,
/// smaller, Web-Surface-specific tab host; this is a new, separate,
/// app-wide shell that happens to *embed* Diagram Studio's real content
/// (`LegacyV2WebViewPage`, not `WebSurfacesHostPage`) as one of its own
/// tabs, avoiding a confusing tab-strip-inside-a-tab-strip nesting.
///
/// **Sidebar coexistence** (Phase 8): the sidebar is untouched and
/// remains the primary way to *reach* every Studio, including this one
/// — `WorkbenchSidebar` gained one new row (`workspace`, listed first)
/// pointing here, per `docs/OEP_SURFACE_ARCHITECTURE.md`'s own framing:
/// TAB WORKSPACE = PRIMARY (once here), SIDEBAR = FALLBACK/LEGACY
/// NAVIGATION (always available to leave here or reach anything this
/// shell doesn't yet expose independently, e.g. Project Explorer's own
/// internal state).
///
/// **No tab persistence** (explicitly out of scope, Phase 3/11): every
/// launch starts with zero open tabs — the user re-opens what they need
/// via "+", exactly as this task's own constraints require.
///
/// **AP-OEP-WORKSPACE-UX-001** — no longer owns a page-local
/// `WorkspaceTabsController`; it reads the single shared instance from
/// [workspaceTabsControllerProvider] instead, so a sidebar click (wired
/// up in `StudioShell`, § that provider's own doc comment) can open or
/// activate a tab here without this widget needing to exist yet or stay
/// mounted across navigation.
class EngineeringWorkspacePage extends ConsumerWidget {
  const EngineeringWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsController = ref.watch(workspaceTabsControllerProvider);
    final tabs = tabsController.tabs;
    final activeId = tabsController.activeId;

    return Container(
      color: StudioColors.background,
      child: Column(
        children: [
          _WorkspaceTabStrip(
            tabs: tabs,
            activeId: activeId,
            onActivate: tabsController.activate,
            onClose: tabsController.close,
            onOpenDiagram: () => tabsController.openSurface(WorkspaceTab.diagramSurfaceId),
            onOpenDiagram2: () => tabsController.openSurface(WorkspaceTab.diagram2SurfaceId),
            onOpenSurface: (surface) => tabsController.openSurface(surface.id),
          ),
          Expanded(
            child: tabs.isEmpty
                ? const Center(
                    child: Text('No tabs open — press "+" to open a Surface', style: TextStyle(color: StudioColors.textDisabled)),
                  )
                : IndexedStack(
                    index: activeId == null ? 0 : tabs.indexWhere((t) => t.id == activeId).clamp(0, tabs.length - 1),
                    children: [
                      for (final tab in tabs) _buildTabContent(context, tab),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// `KeyedSubtree` per tab, kept in one `IndexedStack` — the same
  /// state-retention mechanism `WebSurfacesHostPage` already proved
  /// (non-visible `IndexedStack` children stay mounted, so a switched-
  /// away-from tab's `State` survives until the tab is actually closed).
  Widget _buildTabContent(BuildContext context, WorkspaceTab tab) {
    if (tab.isDiagram) {
      // AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — `tab.id`
      // (not merely `tab.isDiagram`/`surfaceId`) decides which Diagram
      // instance this tab renders, per the approved design's Part 6/9:
      // the *primary* instance (this Workspace's original, single
      // Diagram tab, id == `primaryDiagramInstanceId`) keeps its exact
      // existing widget tree (`DiagramWithComparePane`, Compare toggle
      // included) — zero behavior change. Any other `tab.id` (created
      // via `WorkspaceTabsController.openNewInstance`, not yet exposed
      // by any UI in this package) is a genuinely new, independent
      // Diagram instance and must never resolve to the primary alias —
      // it renders the same real `LegacyV2WebViewPage`, parameterized
      // with its own `instanceId`, with no Compare pane (Compare is
      // explicitly primary-only stopgap infrastructure per the design's
      // Part 14/21, out of scope to generalize here).
      if (tab.id == primaryDiagramInstanceId) {
        // The existing, unmodified bridged widget — the same one
        // `WebSurfacesHostPage` embeds for its own Diagram tab. Embedding
        // the whole `WebSurfacesHostPage` here instead would nest one tab
        // strip inside another (it has its own Web-Surface/native-tab
        // strip) — embedding `LegacyV2WebViewPage` directly keeps exactly
        // one tab strip, this shell's own, with zero V2/bridge changes.
        //
        // AP-OEP-DIAGRAM-COMPARE-001 — wrapped in the shared
        // `DiagramWithComparePane`, which optionally splits this content
        // area to also show the Compare pane (the same widget
        // `WebSurfacesHostPage`'s own Diagram Studio tab uses, so Compare
        // works regardless of which route reaches Diagram Studio's real
        // content). `WorkspaceTab`/`WorkspaceTabsController`/
        // `SurfaceRegistry` are untouched by this — it remains exactly one
        // Workspace tab; the split is purely a rendering decision inside
        // this tab's own content area.
        return const KeyedSubtree(key: ValueKey('workspace-tab-diagram'), child: DiagramWithComparePane());
      }
      return _DiagramInstanceTab(key: ValueKey(tab.id), instanceId: tab.id);
    }
    if (tab.isDiagram2) {
      // AP-OEP-DIAGRAM-COMPARE-002 — the same second, independent
      // engine the Primary's split-pane "Compare Diagrams" pane already
      // drives (`compareDiagramControllerProvider`), given its own
      // full-width tab so it can be opened and edited side by side with
      // the Primary diagram as two ordinary Workspace tabs, not just as
      // a split within one tab.
      return const KeyedSubtree(key: ValueKey('workspace-tab-diagram-2'), child: CompareLegacyV2WebViewPage());
    }
    final surface = SurfaceRegistry.forId(tab.surfaceId);
    if (surface == null) {
      // Not expected in practice (Surfaces are a static list) — an
      // honest empty state rather than a crash if it ever happens.
      return KeyedSubtree(key: ValueKey(tab.id), child: const SizedBox.shrink());
    }
    return KeyedSubtree(key: ValueKey(tab.id), child: surface.build(context));
  }
}

/// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — the one
/// place a non-primary Diagram instance's three family-provider entries
/// (`engineeringProjectServiceFamily`/`diagramStudioControllerFamily`/
/// `diagramTabsFamily`, all keyed by [instanceId]) are explicitly
/// invalidated, per the approved design's Part 10 "critical disposal
/// rule" — **not** `autoDispose`, and not tied to this widget merely
/// scrolling offstage inside the `IndexedStack` (which keeps every open
/// tab's widget mounted regardless of which is visually active, exactly
/// as `WebSurfacesHostPage`'s own tab host already established). This
/// `State.dispose()` only runs when Flutter actually removes this
/// `Element` from the tree, which only happens because
/// `EngineeringWorkspacePage.build()` stops including it in
/// `IndexedStack.children` — which only happens because
/// `WorkspaceTabsController.close(tab.id)` removed the tab from
/// `tabs`. Never constructed for the primary instance (§
/// `_buildTabContent`'s own branch) — the primary alias is deliberately
/// never invalidated here, preserving its existing "outlives any single
/// route/tab" lifetime untouched.
class _DiagramInstanceTab extends ConsumerStatefulWidget {
  const _DiagramInstanceTab({super.key, required this.instanceId});

  final String instanceId;

  @override
  ConsumerState<_DiagramInstanceTab> createState() => _DiagramInstanceTabState();
}

class _DiagramInstanceTabState extends ConsumerState<_DiagramInstanceTab> {
  @override
  void dispose() {
    ref.invalidate(engineeringProjectServiceFamily(widget.instanceId));
    ref.invalidate(diagramStudioControllerFamily(widget.instanceId));
    ref.invalidate(diagramTabsFamily(widget.instanceId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LegacyV2WebViewPage(instanceId: widget.instanceId);
}

class _WorkspaceTabStrip extends StatelessWidget {
  const _WorkspaceTabStrip({
    required this.tabs,
    required this.activeId,
    required this.onActivate,
    required this.onClose,
    required this.onOpenDiagram,
    required this.onOpenDiagram2,
    required this.onOpenSurface,
  });

  final List<WorkspaceTab> tabs;
  final String? activeId;
  final void Function(String id) onActivate;
  final void Function(String id) onClose;
  final VoidCallback onOpenDiagram;
  final VoidCallback onOpenDiagram2;
  final void Function(SurfaceDefinition) onOpenSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      child: Row(
        children: [
          // AP-OEP-WORKSPACE-SHELL-001 — same `Flexible`/loose layout
          // `WebSurfacesHostPage`'s own tab strip already established
          // (AP-OEP-DIAGRAM-UX-002), so "+" sits snug against the last
          // open tab rather than pinned to the far right edge.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs)
                    _WorkspaceTabChip(
                      tab: tab,
                      active: tab.id == activeId,
                      onTap: () => onActivate(tab.id),
                      onClose: () => onClose(tab.id),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<void>(
            tooltip: 'New tab',
            splashRadius: 15,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 16, color: StudioColors.textSecondary),
            iconSize: 16,
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: onOpenDiagram,
                child: const _MenuRow(icon: Icons.polyline, label: 'Diagram Studio'),
              ),
              PopupMenuItem<void>(
                onTap: onOpenDiagram2,
                child: const _MenuRow(icon: Icons.polyline, label: 'Diagram Studio (2)'),
              ),
              const PopupMenuDivider(),
              // AP-OEP-SURFACE-ARCHITECTURE-002/003 — the canonical
              // Surface source, not a second hand-written list.
              for (final surface in SurfaceRegistry.all)
                PopupMenuItem<void>(
                  onTap: () => onOpenSurface(surface),
                  child: _MenuRow(icon: surface.icon, label: surface.title),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: StudioColors.textSecondary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceTabChip extends ConsumerWidget {
  const _WorkspaceTabChip({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final WorkspaceTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — each
    // Diagram tab's own live document title, resolved from *this tab's*
    // own instance (`tab.id`), never the primary alias — the previous
    // single, page-level `diagramTitleOverride` was correct only while
    // exactly one Diagram tab could ever exist; it would have shown
    // instance A's title on instance B's chip once a second instance
    // exists.
    final displayTitle = tab.isDiagram
        ? (ref.watch(diagramStudioControllerFamily(tab.id)).valueOrNull?.document.metadata.title ?? tab.title)
        : tab.title;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? StudioColors.selectedRowBackground : Colors.transparent,
          border: Border(
            right: const BorderSide(color: StudioColors.border),
            bottom: BorderSide(color: active ? StudioColors.selection : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 14, color: StudioColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              displayTitle,
              style: TextStyle(
                color: active ? StudioColors.textPrimary : StudioColors.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onClose,
              child: const Icon(Icons.close, size: 14, color: StudioColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }
}
