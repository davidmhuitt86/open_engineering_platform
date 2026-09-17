import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/studio_destination.dart';
import '../core/surfaces/surface_registry.dart';
import '../core/theme/oep_tokens.dart';
import '../workspace/engineering_workspace_page.dart' show openDiagramTab;
import '../workspace/workspace_tab.dart';
import '../workspace/workspace_tabs_controller.dart';

/// WP-UI-DS-001 Section 03 correction — the seven ratified Studio Bar
/// destinations (AP-UX-004 §5/§9, AP-UX-006 §11), as an application-level
/// navigation concept **independent of any workspace tab**.
///
/// This is the fix for the bug the previous Section 03 pass introduced:
/// clicking a Studio in [OepGlobalStudioBar] must select which Studio is
/// active — it must NOT call [WorkspaceTabsController.openSurface] or
/// [openDiagramTab] (both of which create/reuse a *workspace tab* in the
/// single shared, flat [WorkspaceTabsController] list). Those two concepts
/// are architecturally different (`AP-UX-006` §10, §16): a Studio is an
/// application destination; a workspace is a unit of work inside a Studio.
///
/// Engineering Intelligence is deliberately absent from this enum — it is
/// not a Studio Bar destination (AP-UX-004 §5, AP-UX-005 §5).
enum ActiveStudio { home, diagram, eam, knowledge, exchange, instruments, settings }

extension ActiveStudioMapping on ActiveStudio {
  /// The [WorkspaceTab.surfaceId] value that identifies a tab as belonging
  /// to this Studio — `SurfaceRegistry`'s own `id`s for every Studio except
  /// Diagram (which `SurfaceRegistry` deliberately excludes; it uses the
  /// reserved [WorkspaceTab.diagramSurfaceId] sentinel instead, exactly as
  /// the rest of this codebase already does).
  String get surfaceId => switch (this) {
        ActiveStudio.home => SurfaceRegistry.homeSurfaceId,
        ActiveStudio.diagram => WorkspaceTab.diagramSurfaceId,
        ActiveStudio.eam => StudioDestination.acquisition.name,
        ActiveStudio.knowledge => StudioDestination.knowledge.name,
        ActiveStudio.exchange => StudioDestination.exchange.name,
        ActiveStudio.instruments => StudioDestination.instrumentsWorkbench.name,
        ActiveStudio.settings => StudioDestination.settings.name,
      };
}

/// Shared display identity for a Studio — label, icon, and the per-Studio
/// identity color (`OEP-DESIGN-TOKENS.md` §2A). Used by BOTH
/// [OepGlobalStudioBar] (Section 03) and the Workspace Bar (Section 04, the
/// leading Studio-identity chip and per-Studio tab coloring), so the two
/// regions never carry two independent copies of the same Studio metadata
/// (`OEP-UI-RULES.md` — avoid duplicated navigation code).
class ActiveStudioMeta {
  const ActiveStudioMeta({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

extension ActiveStudioPresentation on ActiveStudio {
  ActiveStudioMeta get meta => switch (this) {
        ActiveStudio.home =>
          const ActiveStudioMeta(label: 'Home', icon: Icons.home_outlined, color: OepColors.studioHome),
        ActiveStudio.diagram => ActiveStudioMeta(
            label: 'Diagram Studio', icon: StudioDestination.diagram.icon, color: OepColors.studioDiagram),
        ActiveStudio.eam => ActiveStudioMeta(
            label: 'EAM', icon: StudioDestination.acquisition.icon, color: OepColors.studioEam),
        ActiveStudio.knowledge => ActiveStudioMeta(
            label: 'Knowledge Studio', icon: StudioDestination.knowledge.icon, color: OepColors.studioKnowledge),
        ActiveStudio.exchange => ActiveStudioMeta(
            label: 'Engineering Exchange', icon: StudioDestination.exchange.icon, color: OepColors.studioExchange),
        ActiveStudio.instruments => ActiveStudioMeta(
            label: 'Instruments',
            icon: StudioDestination.instrumentsWorkbench.icon,
            color: OepColors.studioInstruments),
        ActiveStudio.settings => ActiveStudioMeta(
            label: 'Settings', icon: StudioDestination.settings.icon, color: OepColors.studioSettings),
      };
}

extension ActiveStudioCommandSource on ActiveStudio {
  /// The [StudioDestination] whose registered commands
  /// (`CommandRegistry.commandsForStudio`) belong to this Studio — used by
  /// the Global Toolbar (Section 07) to select contextual actions. `null`
  /// for Home, which has no `StudioDestination`/command source of its own
  /// (it is reached via `SurfaceRegistry.homeSurfaceId`, not a
  /// `StudioDestination` — see [ActiveStudioMapping.surfaceId]).
  StudioDestination? get studioDestination => switch (this) {
        ActiveStudio.home => null,
        ActiveStudio.diagram => StudioDestination.diagram,
        ActiveStudio.eam => StudioDestination.acquisition,
        ActiveStudio.knowledge => StudioDestination.knowledge,
        ActiveStudio.exchange => StudioDestination.exchange,
        ActiveStudio.instruments => StudioDestination.instrumentsWorkbench,
        ActiveStudio.settings => StudioDestination.settings,
      };
}

/// The inverse of [ActiveStudioMapping.surfaceId] — which of the seven
/// ratified Studios (if any) a given [WorkspaceTab.surfaceId] belongs to.
/// `null` for every surface not yet reconciled onto the seven-Studio model
/// (Repository, Objects, Relationships, Graph, Validation, Packages,
/// Search, Dashboard, Project Explorer, Copilot, Engineering Workbench,
/// Engineering Intelligence, Browser — AP-UX-006 §11 explicitly defers
/// reconciling these; this correction does not resolve that separately
/// open question). A `null`-mapped tab is treated as Studio-unscoped and
/// remains visible under whichever Studio's Workspace Bar is active,
/// rather than becoming unreachable — see [tabsForStudio]'s own doc
/// comment.
ActiveStudio? activeStudioForSurfaceId(String surfaceId) {
  for (final studio in ActiveStudio.values) {
    if (studio.surfaceId == surfaceId) return studio;
  }
  return null;
}

/// The active Studio. Defaults to Home. Selecting a Studio
/// ([OepGlobalStudioBar]'s `onTap`) only ever assigns this — it never
/// calls `openSurface`/`openDiagramTab`. **Known, disclosed limitation**:
/// unlike the underlying workspace-tab list (which persists across
/// restarts via `WorkspaceTabsStorage`, unchanged by this correction), this
/// selection itself is in-memory only for this pass — the smallest clean
/// state addition per `AP-UX-006` §5/§16, not a new persistence schema.
/// After a restart the active Studio resets to Home; each Studio's own
/// workspace tabs are unaffected and still restore correctly.
final activeStudioProvider = StateProvider<ActiveStudio>((ref) => ActiveStudio.home);

/// Per-Studio "which workspace was last active" memory, so switching
/// Studios and back restores the same workspace (AP-UX-006 §7's own worked
/// example) without a single global `activeId` being sufficient (it can
/// only ever name one tab across the whole app). In-memory only, same
/// disclosed limitation as [activeStudioProvider].
final lastActiveTabPerStudioProvider = StateProvider<Map<ActiveStudio, String>>((ref) => {});

/// Filters the shared, flat tab list down to the tabs belonging to
/// [studio], **plus** any tab whose surface has not yet been reconciled
/// onto the seven-Studio model (`activeStudioForSurfaceId` returns `null`
/// for those) — such a tab has no Studio Bar button of its own yet, so it
/// remains reachable regardless of which Studio is active rather than
/// becoming invisible. This does not apply to Home: callers render Home
/// directly (`HomeDashboardPage`) and never call this for
/// [ActiveStudio.home] — Home is not workspace-tab-based at all (AP-UX-006
/// §9: "do not invent Home workspace tabs").
List<WorkspaceTab> tabsForStudio(List<WorkspaceTab> allTabs, ActiveStudio studio) {
  return allTabs.where((tab) {
    final owner = activeStudioForSurfaceId(tab.surfaceId);
    return owner == studio || owner == null;
  }).toList();
}

/// Opens/creates a workspace inside [studio] — the ONLY place a Studio Bar
/// selection is allowed to also create a tab, and even then only via an
/// explicit call from a "+"-style action, never from [OepGlobalStudioBar]
/// itself (AP-UX-006 §16). Reuses the exact existing mechanism each Studio
/// already had: [openDiagramTab] for Diagram Studio (preserving its
/// existing multi-instance decision), [WorkspaceTabsController.openSurface]
/// (existing singleton reuse-if-open semantics) for every other Studio.
/// Returns `null` for Home, which has no workspaces to open.
String? openWorkspaceForStudio(ActiveStudio studio, WorkspaceTabsController tabsController) {
  if (studio == ActiveStudio.home) return null;
  if (studio == ActiveStudio.diagram) return openDiagramTab(tabsController);
  return tabsController.openSurface(studio.surfaceId);
}

/// Records that [tabId] is now the last-active workspace for whichever
/// Studio it belongs to (a no-op for a Studio-unscoped tab) — called from
/// every workspace-activate/open call site, never from
/// [OepGlobalStudioBar]'s Studio-selection handler.
void rememberActiveTabForItsStudio(WidgetRef ref, List<WorkspaceTab> allTabs, String tabId) {
  final tab = allTabs.where((t) => t.id == tabId).firstOrNull;
  if (tab == null) return;
  final studio = activeStudioForSurfaceId(tab.surfaceId);
  if (studio == null) return;
  final next = Map<ActiveStudio, String>.from(ref.read(lastActiveTabPerStudioProvider))..[studio] = tabId;
  ref.read(lastActiveTabPerStudioProvider.notifier).state = next;
}

/// WP-UI-DS-008 — read-only helper for the Global Status Bar: which of
/// [studio]'s own tabs is the one currently displayed, using the exact same
/// resolution order `EngineeringWorkspacePage.build()` already computes
/// inline (global `activeId` if it belongs to this Studio, else the
/// remembered per-Studio tab, else the first of this Studio's tabs, else
/// `null`). Extracted here so the Status Bar can report the same "active
/// workspace" the Workspace Bar shows, without a second resolution
/// mechanism and without duplicating the algorithm by hand. Read-only: it
/// does not call `activate`/`openSurface` and does not mutate
/// [lastActiveTabPerStudioProvider].
WorkspaceTab? resolveActiveTabForStudio(
  WidgetRef ref,
  List<WorkspaceTab> allTabs,
  ActiveStudio studio,
  String? globalActiveId,
) {
  final tabs = tabsForStudio(allTabs, studio);
  final remembered = ref.watch(lastActiveTabPerStudioProvider)[studio];
  final id = tabs.any((t) => t.id == globalActiveId)
      ? globalActiveId
      : (remembered != null && tabs.any((t) => t.id == remembered))
          ? remembered
          : (tabs.isNotEmpty ? tabs.first.id : null);
  if (id == null) return null;
  return tabs.where((t) => t.id == id).firstOrNull;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
