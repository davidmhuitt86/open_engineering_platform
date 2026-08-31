import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Consumer;

import '../../acquisition/workspaces/acquisition_studio_page.dart';
import '../../engineering_intelligence/engineering_intelligence_page.dart';
import '../../exchange/workspaces/exchange_studio_page.dart';
import '../../features/copilot/copilot_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/graph/graph_page.dart';
import '../../features/objects/objects_page.dart';
import '../../features/packages/packages_page.dart';
import '../../features/project_explorer/project_explorer_page.dart';
import '../../features/relationships/relationships_page.dart';
import '../../features/repository/repository_page.dart';
import '../../features/search/search_page.dart';
import '../../features/validation/validation_page.dart';
import '../../knowledge/workspaces/knowledge_studio_page.dart';
import '../../settings/workspace/settings_workspace_page.dart';
import '../../workbench/perspectives/engineering_perspective.dart';
import '../../workbench/perspectives/instruments_perspective.dart';
import '../../web_surface/web_browser_settings_provider.dart';
import '../../web_surface/web_surface.dart';
import '../../web_surface/web_surface_view.dart';
import '../routing/studio_destination.dart';
import '../routing/studio_registry.dart';
import 'surface_definition.dart';

/// AP-OEP-SURFACE-ARCHITECTURE-002 — Migration Steps 1–2 of
/// `docs/OEP_SURFACE_ARCHITECTURE.md` §19: the canonical
/// [SurfaceDefinition] source, replacing `WebSurfacesHostPage`'s former
/// hand-maintained `_nativeDestinations` list (§7/§14 of that document's
/// own audit — a real, observed duplication, not a hypothetical one).
///
/// **Additive, not a replacement.** `StudioRegistry.defaultRegistry`
/// remains the sole authority for routing (`pageBuilder`,
/// `settingsProvider`, `searchProvider`) — this registry only derives
/// `id`/`title`/`icon` identity from it (never duplicating those values
/// by hand) and supplies the one thing `StudioDescriptor` cannot: a
/// widget factory that does not require a `GoRouterState`
/// (`SurfaceDefinition.build`'s own doc comment explains why that
/// requirement is real, not a convenience).
///
/// **Diagram Studio is deliberately excluded** (§ Phase 5 of this task,
/// and §2/§5 of the architecture audit): Diagram Studio has its own
/// dedicated "New Diagram" menu entry and the existing, unmodified
/// Legacy V2 embedding (`WebSurfacesHostPage._openLegacyV2`/
/// `_diagramStudioSurface`) — its reference-style `DiagramTab` semantics
/// are explicitly *not* generalized into this model (the audit's own
/// finding: they are a different, legitimate kind of tab, not a gap to
/// unify away). `/diagram-classic` (the former temporary compatibility
/// route this comment used to also mention) was retired entirely by
/// AP-OEP-WORKBENCH-RETIREMENT-001 and no longer exists.
///
/// **Why a per-destination widget-builder map still exists, rather than
/// this being fully derived from `StudioRegistry` alone**: every
/// `StudioDescriptor.pageBuilder` requires a real `GoRouterState`,
/// which cannot be constructed outside actual router navigation (its
/// only constructor takes a private `RouteConfiguration` — confirmed by
/// reading `package:go_router`'s own source). This is the one place
/// values are supplied by hand rather than derived — documented here
/// per the audit's own "if a particular destination cannot be derived
/// cleanly, document the specific reason" instruction. Every widget
/// constructed below is the *exact same* class each `StudioDescriptor.
/// pageBuilder` already builds (confirmed against
/// `core/routing/studio_registry.dart` at the time of writing) — no new
/// page implementation, no fork.
abstract final class SurfaceRegistry {
  /// AP-OEP-WORKSPACE-BROWSER-001 — the generic Browser Surface's stable
  /// id, appended to [_surfaces] below directly (not derived from
  /// `StudioRegistry`, since Browser has no `StudioDestination`/route of
  /// its own — it exists only as a Workspace tab, the same shape
  /// Diagram's own reserved sentinel already established for a Surface
  /// that has no meaningful standalone route). Unlike Diagram, Browser
  /// *is* a real, ordinary [SurfaceDefinition] — its independent
  /// per-instance state ([WebviewController], URL, navigation history)
  /// lives entirely inside [WebSurfaceView]'s own local `State`, never in
  /// an external Riverpod family provider the way Diagram's engine state
  /// does, so [SurfaceDefinition.build]'s plain `Widget Function
  /// (BuildContext)` signature (no instance id parameter) is already
  /// sufficient: `EngineeringWorkspacePage._buildTabContent`'s existing
  /// `KeyedSubtree(key: ValueKey(tab.id), child: surface.build(context))`
  /// gives each Browser tab its own `Element`/`State` (and therefore its
  /// own `WebviewController`) purely from `WorkspaceTab.id` already being
  /// distinct per instance — exactly like every other ordinary Surface,
  /// no special-casing needed anywhere in the Workspace rendering path.
  static const String browserSurfaceId = 'browser';

  /// All Surfaces currently available for a generic, `openSurface`-based
  /// "+" / New Tab menu — deliberately **excludes** Browser: every
  /// existing consumer of this list (this shell's own "+" menu,
  /// `WebSurfacesHostPage`'s own native-tab picker) assumes reuse-if-open
  /// singleton semantics, which Browser explicitly must never have (every
  /// selection creates a new instance, § `browserSurfaceId`'s own doc
  /// comment and `EngineeringWorkspacePage`'s dedicated "🌐 Browser" menu
  /// entry). Excluding it here, once, means no consumer of this list can
  /// accidentally wire it into the wrong (singleton) open path — the
  /// alternative, filtering it out at every call site individually, would
  /// only be as safe as the least careful future caller. [forId] below is
  /// unaffected (it searches the full internal list), so rendering an
  /// already-open Browser tab still resolves correctly.
  static List<SurfaceDefinition> get all => List.unmodifiable(_surfaces.where((s) => s.id != browserSurfaceId));

  /// Looks up a Surface by its `id` (a `StudioDestination.name`, for
  /// every Surface this registry currently produces). `null` if not
  /// found.
  static SurfaceDefinition? forId(String id) {
    for (final surface in _surfaces) {
      if (surface.id == id) return surface;
    }
    return null;
  }

  static final List<SurfaceDefinition> _surfaces = _build();

  static List<SurfaceDefinition> _build() {
    final result = <SurfaceDefinition>[];
    for (final descriptor in StudioRegistry.defaultRegistry.descriptors) {
      final destination = descriptor.destination;
      // AP-OEP-WORKSPACE-SHELL-001 — `workspace` (the new OEP-wide tabbed
      // shell this Surface list itself feeds) is excluded for the same
      // reason `diagram` already was: opening a Surface as a tab inside
      // the very shell that renders that tab strip would be
      // self-referential, not a real Surface a user needs to reach this
      // way (it's already the page they're on).
      if (destination == StudioDestination.diagram || destination == StudioDestination.workspace) {
        continue;
      }
      final builder = _nativeWidgetBuilders[destination];
      if (builder == null) continue;
      result.add(SurfaceDefinition(
        id: destination.name,
        title: destination.label,
        icon: destination.icon,
        presentationTechnology: SurfacePresentationTechnology.native,
        build: builder,
      ));
    }
    result.add(_browserSurface());
    return List.unmodifiable(result);
  }

  /// AP-OEP-WORKSPACE-BROWSER-001 — a brand-new, independent
  /// [WebSurfaceView] every time this is built (i.e. every time a new
  /// Browser Workspace tab is opened — [SurfaceDefinition.build] is
  /// called once per tab, at the moment `EngineeringWorkspacePage` first
  /// renders it). `initialUrl` reads the *current* configured homepage
  /// (`WebBrowserSettings.homepageUrl`) via a [Consumer] — `build` itself
  /// only receives a `BuildContext`, not a `WidgetRef` — using
  /// `ref.read`, not `watch`: [WebSurfaceView.initState] reads
  /// `widget.surface.initialUrl` exactly once to seed its first
  /// navigation, so nothing would react to a later homepage-setting
  /// change on an already-open tab even with `watch`, but `read` avoids
  /// pointless rebuilds of this `Consumer` from ambient Workspace
  /// activity (tab open/close/split) it has no reason to react to. The
  /// inner [WebSurface.id] is never used for Workspace-level identity —
  /// only [WorkspaceTab.id] is (§ [browserSurfaceId]'s own doc comment) —
  /// so a fixed placeholder is fine; it's local-only to
  /// [WebSurfaceView]'s internal bookkeeping.
  static SurfaceDefinition _browserSurface() => SurfaceDefinition(
        id: browserSurfaceId,
        title: 'New Tab',
        icon: Icons.public,
        presentationTechnology: SurfacePresentationTechnology.genericWeb,
        allowsMultipleInstances: true,
        build: (context) => Consumer(
          builder: (context, ref, _) => WebSurfaceView(
            surface: WebSurface(
              id: 'browser-tab',
              title: 'New Tab',
              initialUrl: ref.read(webBrowserSettingsProvider).homepageUrl,
            ),
          ),
        ),
      );

  /// One entry per `StudioDestination` this registry can offer as a
  /// Surface — the identity (`id`/`title`/`icon`) is still derived from
  /// `StudioRegistry.defaultRegistry` above; only the widget factory
  /// itself is necessarily hand-written per destination (§ class doc
  /// comment for why).
  static final Map<StudioDestination, Widget Function(BuildContext)> _nativeWidgetBuilders = {
    StudioDestination.dashboard: (context) => const DashboardPage(),
    StudioDestination.projectExplorer: (context) => const ProjectExplorerPage(),
    StudioDestination.knowledge: (context) => const KnowledgeStudioPage(),
    StudioDestination.acquisition: (context) => const AcquisitionStudioPage(),
    StudioDestination.repository: (context) => const RepositoryPage(),
    StudioDestination.objects: (context) => const ObjectsPage(),
    StudioDestination.relationships: (context) => const RelationshipsPage(),
    StudioDestination.search: (context) => const SearchPage(),
    StudioDestination.graph: (context) => const GraphPage(),
    StudioDestination.validation: (context) => const ValidationPage(),
    StudioDestination.packages: (context) => const PackagesPage(),
    StudioDestination.engineeringIntelligence: (context) => const EngineeringIntelligencePage(),
    StudioDestination.exchange: (context) => const ExchangeStudioPage(),
    StudioDestination.copilot: (context) => const CopilotPage(),
    // AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001 — the exact same
    // widgets `StudioRegistry`'s `_engineeringWorkbenchBuilder`/
    // `_instrumentsWorkbenchBuilder` construct.
    StudioDestination.engineeringWorkbench: (context) => const EngineeringSurfacePage(),
    StudioDestination.instrumentsWorkbench: (context) => const InstrumentsSurfacePage(),
    StudioDestination.settings: (context) => const SettingsWorkspacePage(initialPageId: null),
  };
}
