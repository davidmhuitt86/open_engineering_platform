import 'package:flutter/widgets.dart';

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
  /// All Surfaces currently available for the "+" / New Tab menu.
  static List<SurfaceDefinition> get all => _surfaces;

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
    return List.unmodifiable(result);
  }

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
