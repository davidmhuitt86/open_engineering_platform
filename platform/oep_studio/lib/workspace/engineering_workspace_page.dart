import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/active_studio.dart';
import '../app/widgets/global_context_navigation.dart';
import '../app/widgets/global_inspector.dart';
import '../app/widgets/global_toolbar.dart';
import '../core/services/engineering_project_service.dart';
import '../core/surfaces/surface_definition.dart';
import '../core/surfaces/surface_registry.dart';
import '../core/theme/oep_tokens.dart';
import '../core/theme/studio_colors.dart';
import '../diagram_studio/compare/diagram_with_compare_pane.dart';
import '../diagram_studio/controller/diagram_studio_controller_provider.dart';
import '../diagram_studio/tabs/diagram_tabs_controller.dart';
import '../diagram_studio/webview/legacy_v2_webview.dart';
import 'home/home_dashboard_page.dart';
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
/// **Tab persistence** (`AP-OEP-WORKSPACE-PERSISTENCE-001`,
/// `WorkspaceTabsController`/`WorkspaceTabsStorage`): the open tab list,
/// active tab, and split-view second tab are restored across restarts.
/// A launch with nothing persisted yet (or a session that last closed
/// with zero tabs open) boots to Home instead of an empty Workspace —
/// see `WorkspaceTabsController._ensureHomeIfEmpty` (PRODUCT-READINESS-013).
///
/// **AP-OEP-WORKSPACE-UX-001** — no longer owns a page-local
/// `WorkspaceTabsController`; it reads the single shared instance from
/// [workspaceTabsControllerProvider] instead, so a sidebar click (wired
/// up in `StudioShell`, § that provider's own doc comment) can open or
/// activate a tab here without this widget needing to exist yet or stay
/// mounted across navigation.
/// AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001 — the "+" menu's single
/// "Diagram Studio" entry: opens the first (primary) Diagram tab via the
/// existing singleton [WorkspaceTabsController.openSurface] path exactly
/// as before (so `WorkspaceTab.diagramSurfaceId`'s deterministic id keeps
/// landing on `primaryDiagramInstanceId`, untouched), but once any
/// Diagram tab is already open, selecting it again opens a genuinely
/// new, independent instance via [WorkspaceTabsController.openNewInstance]
/// instead of merely refocusing the existing one — replacing the old,
/// separate "Diagram Studio (2)" menu entry/`diagram2SurfaceId` sentinel
/// (a single second identity) with the real, already-implemented per-tab
/// instancing (§ [WorkspaceTab.diagramAllowsMultipleInstances]).
/// [WorkspaceTabsController.openSurface]'s own generic
/// one-tab-per-surfaceId contract is untouched — this only decides
/// *which* of its two existing methods to call, exactly the caller-side
/// decision `SurfaceDefinition.allowsMultipleInstances`'s own doc comment
/// already anticipated ("a future caller ... is what decides whether to
/// call `openSurface` or `openNewInstance`").
///
/// A top-level function, not a private method on
/// [EngineeringWorkspacePage] — the exact decision a real WebView2-backed
/// Diagram tab makes is otherwise untestable without mounting one (§
/// `engineering_workspace_page_test.dart`'s own doc comment on why that's
/// unreliable under `flutter test`); as a plain function over a
/// [WorkspaceTabsController], it is exercised directly, the same way
/// every other `openSurface`/`openNewInstance` call in this file's tests
/// already is. Returns the opened (or newly created) tab's id.
String openDiagramTab(WorkspaceTabsController tabsController) {
  final alreadyOpen = tabsController.tabs.any((t) => t.isDiagram);
  return (alreadyOpen && WorkspaceTab.diagramAllowsMultipleInstances)
      ? tabsController.openNewInstance(WorkspaceTab.diagramSurfaceId)
      : tabsController.openSurface(WorkspaceTab.diagramSurfaceId);
}

/// AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001 — this [tabs]`[index]`'s 1-based
/// position among only the Diagram tabs at or before it (`0` for a
/// non-Diagram tab), used by [_WorkspaceTabChip] to disambiguate two
/// still-untitled Diagram tabs ("Diagram Studio 2", "Diagram Studio 3",
/// ...) without persisting a presentation label anywhere — recomputed
/// fresh from live tab order on every call. A top-level pure function for
/// the same testability reason as [openDiagramTab]: a plain
/// `List<WorkspaceTab>` in, an `int` out, no widget tree required.
int diagramOrdinalFor(List<WorkspaceTab> tabs, int index) =>
    tabs[index].isDiagram
        ? tabs.take(index + 1).where((t) => t.isDiagram).length
        : 0;

/// AP-OEP-DIAGRAM-PRIMARY-TAB-CLOSE-001 — closing the primary Diagram
/// tab (`id == primaryDiagramInstanceId`) does not tear down its
/// document the way closing a *secondary* Diagram tab does
/// (`_DiagramInstanceTabState.dispose`'s own doc comment: the primary
/// instance is deliberately never invalidated, since it is meant to
/// outlive any single tab/route for the whole app session). Left as-is,
/// that meant reopening a fresh Diagram tab after closing the primary
/// one silently showed whatever document the primary instance still had
/// live in memory — reading as "the tab remembers the diagram I just
/// closed" from the user's side, since the tab strip itself gives no
/// visual cue that it's the same underlying document. Explicitly
/// requested fix: closing the primary Diagram tab now also resets its
/// document to a blank Untitled one (the exact same reset
/// [DiagramStudioController.newDocument] already performs for the
/// toolbar/Command-Palette "New Diagram" action — no new reset
/// mechanism), so the *next* time a Diagram tab is opened, it is
/// genuinely blank. The primary instance's family-provider entries
/// themselves are still never invalidated (that part of the design is
/// unchanged) — only its document content is reset.
void _closeTab(
    WidgetRef ref, WorkspaceTabsController tabsController, String id) {
  tabsController.close(id);
  if (id != primaryDiagramInstanceId) return;
  final controller = ref
      .read(diagramStudioControllerFamily(primaryDiagramInstanceId))
      .valueOrNull;
  if (controller == null) return;
  unawaited(controller.newDocument());
}

class EngineeringWorkspacePage extends ConsumerWidget {
  const EngineeringWorkspacePage({super.key});

  /// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — wraps [_buildTabContent]'s output
  /// in a [GlobalObjectKey] (equality by `tab.id`, not object identity —
  /// a fresh instance created on every build compares equal to the one
  /// from the previous build for the same tab), rather than the plain
  /// [ValueKey] `_buildTabContent`'s own callers used before this
  /// package. This is the one addition that makes split view safe:
  /// `_DiagramInstanceTabState.dispose()` invalidates that instance's
  /// family providers (tearing down its real `EngineHost`) whenever its
  /// `Element` is actually removed from the tree — which, with a plain
  /// key, is exactly what happens when a tab moves between structurally
  /// different parents (e.g. `IndexedStack.children` in single mode vs.
  /// a `Row` pane in split mode, or into/out of the hidden holder below):
  /// Flutter's reconciliation only reuses an `Element` across a parent
  /// change for a `GlobalKey`. Without this, merely opening or closing a
  /// split would falsely dispose a still-open Diagram instance's engine
  /// state — a real correctness bug, not a cosmetic one, discovered
  /// while implementing this package (the approved audit's Part 4 did
  /// not analyze Flutter element-identity mechanics at this level).
  /// `_buildTabContent` itself is untouched, per this package's own
  /// scope boundary.
  Widget _keyedTabContent(BuildContext context, WorkspaceTab tab) =>
      KeyedSubtree(
          key: GlobalObjectKey(tab.id), child: _buildTabContent(context, tab));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsController = ref.watch(workspaceTabsControllerProvider);
    final allTabs = tabsController.tabs;
    final activeStudio = ref.watch(activeStudioProvider);

    // WP-UI-DS-001 Section 02 — the OEP header used to render here, scoped
    // to Diagram tabs only. It is now hosted once, application-globally, by
    // `StudioShell` (`OepApplicationHeader`) above this whole page, so it no
    // longer needs to be conditionally rendered per-tab here. `OepStudioHeader`
    // itself (Diagram/Simulation identity + `_ViewSwapControl`) still exists
    // for Diagram Studio's own use — see that file's doc comment — it is
    // simply no longer invoked from this call site.
    //
    // WP-UI-DS-001 Section 03 correction — Home is not workspace-tab-based
    // at all (AP-UX-006 §9): when Home is the active Studio, this page
    // renders `HomeDashboardPage` directly and shows no Workspace Bar,
    // rather than treating Home as (or auto-creating) a workspace tab.
    // WP-UI-DS-007 — the Global Toolbar is persistent shell chrome, placed
    // per the design-owner-designated pixel wireframe ("Start With this
    // Exact Wireframe and its Pixel Measurments.png", AP-UX-002 C2): a
    // full-width row BELOW the Context-Nav/Surface/Inspector content, not
    // above it. Home has no Workspace Bar (above) or Context Nav/Inspector
    // of its own, but the Toolbar still renders below its content — it is
    // Studio-scoped, not workspace/tab-scoped, and Home is a Studio.
    // WP-UI-DS-009 — the Global Inspector is a right-side structural
    // sibling of the main content (Section 05/06's Context-Nav/Surface
    // split does not exist yet — this is the smallest non-destructive host
    // for the Inspector region until that lands). Present for every
    // Studio, Home included.
    if (activeStudio == ActiveStudio.home) {
      return Container(
        color: StudioColors.background,
        child: const Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  GlobalContextNavigation(),
                  Expanded(child: HomeDashboardPage()),
                  GlobalInspector(),
                ],
              ),
            ),
            GlobalToolbar(),
          ],
        ),
      );
    }

    // Every other Studio: only the tabs that belong to it (plus any tab
    // whose surface isn't yet reconciled onto the seven-Studio model —
    // `tabsForStudio`'s own doc comment) are shown. Clicking a different
    // Studio in `OepGlobalStudioBar` never adds/removes anything from this
    // list — it only changes which subset of the SAME shared tab list is
    // displayed here.
    final tabs = tabsForStudio(allTabs, activeStudio);
    // Bug fix (direct product feedback): a tab whose Surface has not
    // been reconciled onto the seven-Studio model is visible under
    // EVERY Studio (`tabsForStudio`'s own doc comment — deliberate, so
    // it is never lost), but that must not let it silently become the
    // resolved "active" content of an unrelated Studio just because
    // it's the app-wide `activeId` from having been viewed elsewhere.
    // Only a tab this Studio actually OWNS may satisfy that check; an
    // unscoped tab can still be resolved via `remembered` below, since
    // that is only ever set by an explicit interaction while this exact
    // Studio was active (see `rememberActiveTabForItsStudio`).
    final ownedTabs = tabs.where((t) => activeStudioForSurfaceId(t.surfaceId) == activeStudio).toList();
    final globalActiveId = tabsController.activeId;
    final remembered = ref.watch(lastActiveTabPerStudioProvider)[activeStudio];
    final activeId = ownedTabs.any((t) => t.id == globalActiveId)
        ? globalActiveId
        : (remembered != null && tabs.any((t) => t.id == remembered))
            ? remembered
            : (ownedTabs.isNotEmpty ? ownedTabs.first.id : null);
    // Same leak this Studio's `activeId` resolution above guards
    // against: the persisted split partner is a single, app-wide field,
    // not Studio-scoped, so it must only be honored here when it names
    // a tab this Studio actually owns — otherwise a split entered while
    // browsing a DIFFERENT Studio would render its second pane here too.
    final rawSecondTabId = tabsController.secondTabId;
    final secondTabId =
        (rawSecondTabId != null && ownedTabs.any((t) => t.id == rawSecondTabId)) ? rawSecondTabId : null;

    void activate(String id) {
      tabsController.activate(id);
      rememberActiveTabForItsStudio(ref, activeStudio, id);
    }

    void openAndRemember(String Function() open) {
      final id = open();
      rememberActiveTabForItsStudio(ref, activeStudio, id);
    }

    return Container(
      color: StudioColors.background,
      child: Column(
        children: [
          _WorkspaceTabStrip(
            activeStudio: activeStudio,
            tabs: tabs,
            activeId: activeId,
            onActivate: activate,
            onClose: (id) => _closeTab(ref, tabsController, id),
            onOpenDiagram: () =>
                openAndRemember(() => openDiagramTab(tabsController)),
            onOpenBrowser: () => openAndRemember(() => tabsController
                .openNewInstance(SurfaceRegistry.browserSurfaceId)),
            onOpenSurface: (surface) =>
                openAndRemember(() => tabsController.openSurface(surface.id)),
            onSplitWith: tabsController.splitWith,
          ),
          Expanded(
            child: Row(
              children: [
                // WP-UI-DS-002 (Section 06) — Global Context Navigation, a
                // left-side structural sibling of the content, first
                // position in the Row per AP-UX-006/010's established
                // insertion point.
                const GlobalContextNavigation(),
                Expanded(
                  child: tabs.isEmpty
                      ? const Center(
                          child: Text(
                              'No workspaces open — press "+" to open one',
                              style:
                                  TextStyle(color: StudioColors.textDisabled)),
                        )
                      : _WorkspaceContent(
                          // WP-UI-DS-001 Section 03 correction — deliberately
                          // the FULL, unfiltered tab list here, not the
                          // Studio-scoped `tabs` above: every open tab across
                          // every Studio must stay mounted in the shared
                          // IndexedStack exactly as it did before this
                          // correction (a Diagram tab's
                          // `LegacyV2WebViewPage`/`WebviewController` would
                          // otherwise be torn down and recreated — losing its
                          // live WebView state — every time the user switches
                          // to a different Studio and back). Only `activeId`
                          // (which Studio-scoped tab is painted) changes;
                          // which tabs exist in the tree does not.
                          tabs: allTabs,
                          activeId: activeId,
                          secondTabId: secondTabId,
                          buildTabContent: _keyedTabContent,
                        ),
                ),
                // WP-UI-DS-009 — Global Inspector, a right-side structural
                // sibling of the content above, not embedded in it.
                const GlobalInspector(),
              ],
            ),
          ),
          // WP-UI-DS-007 — Global Toolbar, a full-width row BELOW the main
          // content (Context Nav/Surface/Inspector, owned inside each tab's
          // own content), per the design-owner-designated pixel wireframe —
          // not nested between the Workspace Bar and the content. Its
          // content is Studio-scoped (via activeStudioProvider), not
          // workspace/tab-scoped — it does not change when the active tab
          // changes within the same Studio.
          const GlobalToolbar(),
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
        return const KeyedSubtree(
            key: ValueKey('workspace-tab-diagram'),
            child: DiagramWithComparePane());
      }
      return _DiagramInstanceTab(key: ValueKey(tab.id), instanceId: tab.id);
    }
    final surface = SurfaceRegistry.forId(tab.surfaceId);
    if (surface == null) {
      // Not expected in practice (Surfaces are a static list) — an
      // honest empty state rather than a crash if it ever happens.
      return KeyedSubtree(
          key: ValueKey(tab.id), child: const SizedBox.shrink());
    }
    return KeyedSubtree(key: ValueKey(tab.id), child: surface.build(context));
  }
}

/// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — the one place the audit's "single
/// visible content area" assumption ([IndexedStack]'s single `index`) is
/// generalized to two. Single mode is the exact, unmodified
/// [IndexedStack] behavior that shipped before this package; split mode
/// renders [activeId]'s and [secondTabId]'s content side by side in a
/// [Row], while every *other* open tab (neither pane) stays mounted,
/// unpainted, in a hidden holder — so no open tab is ever torn down
/// merely because the Workspace switched between single and split
/// layout (§ [EngineeringWorkspacePage._keyedTabContent]'s own doc
/// comment on why that requires a [GlobalObjectKey], not a plain one).
///
/// **Falls back to single mode** if [secondTabId] doesn't name a
/// currently open tab (stale/invalid reference — never fabricated),
/// [activeId] doesn't either, or [secondTabId] equals [activeId]. That
/// last case is a real contradiction the approved audit's Part 6 did not
/// fully resolve at the Flutter-widget level: showing the *same*
/// `WorkspaceTab.id` in two panes simultaneously would require two
/// independent `Element`s sharing one [GlobalObjectKey], which Flutter
/// hard-rejects (a `GlobalKey` names *one* live `Element`, not "the
/// Nth occurrence of this key"), and manufacturing a second key for just
/// this case would itself be the "new identity merely to distinguish the
/// panes" this package is explicitly forbidden from introducing. The
/// audit's own conclusion — that showing one tab in both panes should
/// not be *prohibited* at the state level — is preserved:
/// [WorkspaceTabsController.splitWith] still happily sets `secondTabId`
/// to `activeId`; only *this rendering layer* deterministically falls
/// back to showing that one tab full-width rather than attempting an
/// unsafe duplicate mount.
class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.tabs,
    required this.activeId,
    required this.secondTabId,
    required this.buildTabContent,
  });

  final List<WorkspaceTab> tabs;
  final String? activeId;
  final String? secondTabId;
  final Widget Function(BuildContext context, WorkspaceTab tab) buildTabContent;

  @override
  Widget build(BuildContext context) {
    final activeTab = activeId == null
        ? null
        : tabs.where((t) => t.id == activeId).firstOrNull;
    final secondTab = (secondTabId == null || secondTabId == activeId)
        ? null
        : tabs.where((t) => t.id == secondTabId).firstOrNull;

    if (activeTab != null && secondTab != null) {
      final paneIds = {activeTab.id, secondTab.id};
      final hiddenTabs = [
        for (final tab in tabs)
          if (!paneIds.contains(tab.id)) tab
      ];
      return LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(child: buildTabContent(context, activeTab)),
            const VerticalDivider(width: 1, color: StudioColors.border),
            Expanded(child: buildTabContent(context, secondTab)),
            if (hiddenTabs.isNotEmpty)
              Offstage(
                child: SizedBox.fromSize(
                  size: constraints.biggest,
                  child: IndexedStack(children: [
                    for (final tab in hiddenTabs) buildTabContent(context, tab)
                  ]),
                ),
              ),
          ],
        ),
      );
    }

    return IndexedStack(
      index: activeId == null
          ? 0
          : tabs.indexWhere((t) => t.id == activeId).clamp(0, tabs.length - 1),
      children: [for (final tab in tabs) buildTabContent(context, tab)],
    );
  }
}

extension _FirstOrNullTab on Iterable<WorkspaceTab> {
  WorkspaceTab? get firstOrNull => isEmpty ? null : first;
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
  ConsumerState<_DiagramInstanceTab> createState() =>
      _DiagramInstanceTabState();
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
  Widget build(BuildContext context) =>
      LegacyV2WebViewPage(instanceId: widget.instanceId);
}

/// WP-UI-DS-001 Section 04 — the target Workspace Bar
/// (`docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §4;
/// canonical reference `docs/architecture/ux/renders/oep-shell/workspace-bar.svg`).
/// Height corrected from 36px to the ratified 42px
/// (`OepGeometry.workspaceBarHeight`, AP-UX-002 C2). Adds the leading
/// Studio-identity chip and recolors the active tab using [activeStudio]'s
/// identity color (`OEP-DESIGN-TOKENS.md` §2A: "Workspace tabs inherit
/// their parent Studio's identity color") instead of the generic
/// `StudioColors.selection` blue every Studio previously shared. The tab
/// list itself ([tabs]) is already Studio-scoped by
/// `EngineeringWorkspacePage.build()` (Section 03, frozen) — this widget
/// only renders whatever list it is given; it does not filter or own that
/// decision.
class _WorkspaceTabStrip extends StatelessWidget {
  const _WorkspaceTabStrip({
    required this.activeStudio,
    required this.tabs,
    required this.activeId,
    required this.onActivate,
    required this.onClose,
    required this.onOpenDiagram,
    required this.onOpenBrowser,
    required this.onOpenSurface,
    required this.onSplitWith,
  });

  final ActiveStudio activeStudio;
  final List<WorkspaceTab> tabs;
  final String? activeId;
  final void Function(String id) onActivate;
  final void Function(String id) onClose;
  final VoidCallback onOpenDiagram;
  final VoidCallback onOpenBrowser;
  final void Function(SurfaceDefinition) onOpenSurface;
  final void Function(String id) onSplitWith;

  @override
  Widget build(BuildContext context) {
    final identityColor = activeStudio.meta.color;
    return Container(
      height: OepGeometry.workspaceBarHeight,
      decoration: const BoxDecoration(
        color: OepColors.surface1,
        border: Border(bottom: BorderSide(color: OepColors.border)),
      ),
      child: Row(
        children: [
          _StudioIdentityChip(meta: activeStudio.meta),
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
                  for (final (index, tab) in tabs.indexed)
                    _WorkspaceTabChip(
                      tab: tab,
                      active: tab.id == activeId,
                      identityColor: identityColor,
                      diagramOrdinal: diagramOrdinalFor(tabs, index),
                      onTap: () => onActivate(tab.id),
                      onClose: () => onClose(tab.id),
                      onSplit: () => onSplitWith(tab.id),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<void>(
            tooltip: 'New tab',
            splashRadius: 15,
            padding: EdgeInsets.zero,
            icon:
                const Icon(Icons.add, size: 16, color: OepColors.textSecondary),
            iconSize: 16,
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: onOpenDiagram,
                child: const _MenuRow(
                    icon: Icons.polyline, label: 'Diagram Studio'),
              ),
              // AP-OEP-WORKSPACE-BROWSER-001 — a dedicated entry, not
              // folded into the generic `SurfaceRegistry.all` loop below:
              // every selection must call `openNewInstance` (a brand-new
              // Browser tab, every time — there is no "focus the existing
              // Browser tab" concept the way singleton Surfaces have),
              // never `openSurface`'s reuse-if-open semantics. Mirrors
              // "Diagram Studio"'s own dedicated entry immediately above,
              // just without that one's extra "first click reuses the
              // primary" branch — Browser has no primary/singleton
              // instance at all (§ `SurfaceRegistry.browserSurfaceId`'s
              // own doc comment).
              PopupMenuItem<void>(
                onTap: onOpenBrowser,
                child: const _MenuRow(icon: Icons.public, label: '🌐 Browser'),
              ),
              const PopupMenuDivider(),
              // AP-OEP-SURFACE-ARCHITECTURE-002/003 — the canonical
              // Surface source, not a second hand-written list.
              // `SurfaceRegistry.all` itself already excludes Browser (§
              // its own doc comment) — it has its own dedicated entry
              // above instead, since every other Surface here uses
              // `openSurface`'s singleton reuse-if-open semantics, which
              // Browser must never have.
              //
              // WP-UI-DS-001 Section 04 note: this list is deliberately NOT
              // scoped to `activeStudio` — re-scoping which Surfaces can be
              // opened from which Studio's "+" menu is a further
              // reconciliation of the 12 not-yet-ratified `StudioDestination`
              // entries (AP-UX-006 §11), out of this section's scope. Opening
              // one of them here simply surfaces it later, under whichever
              // Studio it's mapped to (or unscoped) — see `tabsForStudio`.
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

/// The leading Studio-identity chip (canonical reference: leftmost element
/// of `workspace-bar.svg`, e.g. "Diagram Studio ⌄"). Read-only identity
/// display — the dropdown chevron is decorative for this section: no
/// specification defines behavior for it (`OEP-UI-RULES.md` Rule 3 — do not
/// invent behavior for a control the specification does not define), so it
/// is not wired to anything rather than guessed at.
class _StudioIdentityChip extends StatelessWidget {
  const _StudioIdentityChip({required this.meta});

  final ActiveStudioMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: OepGeometry.workspaceBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: meta.color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            meta.label,
            style: TextStyle(
              color: Colors.white,
              fontFamily: OepTypography.fontFamily,
              fontSize: OepTypography.workspaceLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
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
            style:
                const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
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
    required this.identityColor,
    required this.diagramOrdinal,
    required this.onTap,
    required this.onClose,
    required this.onSplit,
  });

  final WorkspaceTab tab;
  final bool active;

  /// The active Studio's identity color (`OEP-DESIGN-TOKENS.md` §2A) — used
  /// for this tab's active-state indicator only when active is true, per
  /// "Workspace tabs inherit their parent Studio's identity color."
  final Color identityColor;

  /// This tab's 1-based position among currently-open Diagram tabs
  /// (`0`/unused for every non-Diagram tab) — see
  /// [_WorkspaceTabStrip.build]'s own doc comment for how it's computed.
  final int diagramOrdinal;
  final VoidCallback onTap;
  final VoidCallback onClose;

  /// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — the approved audit's Part 8
  /// minimal split-creation mechanism: a right-click context menu on any
  /// open tab chip, one action, "Open in Split," calling
  /// `WorkspaceTabsController.splitWith(tab.id)` directly. No drag-and-
  /// drop, no keyboard shortcut, no chrome-level split button — see that
  /// method's own doc comment for why a context menu was chosen.
  final VoidCallback onSplit;

  Future<void> _showContextMenu(
      BuildContext context, Offset globalPosition) async {
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
          globalPosition.dx, globalPosition.dy),
      items: [
        PopupMenuItem<void>(
          onTap: onSplit,
          child: const _MenuRow(
              icon: Icons.vertical_split, label: 'Open in Split'),
        ),
      ],
    );
  }

  /// [DiagramDocumentMetadata.newDocument]'s own default title — the one
  /// value that means "this document has never been given a real title,"
  /// used below to decide when an ordinal label is more useful than the
  /// (otherwise ambiguous, identical-across-every-untitled-instance) live
  /// document title.
  static const _untitledDiagramTitle = 'Untitled Diagram';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — each
    // Diagram tab's own live document title, resolved from *this tab's*
    // own instance (`tab.id`), never the primary alias — the previous
    // single, page-level `diagramTitleOverride` was correct only while
    // exactly one Diagram tab could ever exist; it would have shown
    // instance A's title on instance B's chip once a second instance
    // exists.
    //
    // AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001 — a live title is only shown
    // once it's a *real* one: while a Diagram tab's document is still at
    // its default "Untitled Diagram" placeholder, every open Diagram tab
    // would otherwise display that exact same ambiguous label. In that
    // case this falls back to a deterministic, instance-aware label
    // instead ("Diagram Studio" for the first open Diagram tab, "Diagram
    // Studio 2"/"3"/... for each one after, by open order) — computed
    // fresh from live tab order and provider state every build, per the
    // task's own "do not persist presentation titles" requirement.
    final liveTitle = tab.isDiagram
        ? ref
            .watch(diagramStudioControllerFamily(tab.id))
            .valueOrNull
            ?.document
            .metadata
            .title
        : null;
    final displayTitle = !tab.isDiagram
        ? tab.title
        : (liveTitle != null && liveTitle != _untitledDiagramTitle)
            ? liveTitle
            : (diagramOrdinal <= 1
                ? 'Diagram Studio'
                : 'Diagram Studio $diagramOrdinal');
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? identityColor.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border(
              right: const BorderSide(color: OepColors.border),
              bottom: BorderSide(
                  color: active ? identityColor : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon,
                  size: 14,
                  color: active ? identityColor : OepColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                displayTitle,
                style: TextStyle(
                  color:
                      active ? OepColors.textPrimary : OepColors.textSecondary,
                  fontFamily: OepTypography.fontFamily,
                  fontSize: OepTypography.workspaceLabel,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onClose,
                child: const Icon(Icons.close,
                    size: 14, color: OepColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
