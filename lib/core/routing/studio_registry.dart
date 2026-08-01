import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../acquisition/services/acquisition_runtime_service.dart';
import '../../acquisition/settings/acquisition_settings_page.dart';
import '../../acquisition/workspaces/acquisition_studio_page.dart';
import '../../diagram_studio/settings/diagram_studio_settings_page.dart';
import '../../diagram_studio/workspaces/diagram_studio_page.dart';
import '../../engineering_intelligence/engineering_intelligence_page.dart';
import '../../exchange/services/exchange_runtime_service.dart';
import '../../exchange/settings/exchange_settings_page.dart';
import '../../exchange/workspaces/exchange_studio_page.dart';
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
import '../../settings/pages/knowledge_studio_settings_page.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/workspace/settings_workspace_page.dart';
import '../models/search_scope.dart';
import '../models/unified_search_result.dart';
import '../services/engineering_project_service.dart';
import '../services/foundation_runtime_service.dart';
import 'studio_destination.dart';

/// One Studio/search contributor's search hook, wired into the
/// [StudioRegistry] instead of being hand-called from
/// `UnifiedSearchService` (WP-STUDIO-021). [scope] is accepted
/// uniformly even though only the Knowledge contribution uses it today
/// — matching the pre-refactor code, where the Engine and Acquisition
/// search blocks likewise ignored it.
typedef StudioSearchProvider = List<UnifiedSearchResult> Function(
  WidgetRef ref,
  String query,
  SearchScope scope,
);

/// A single unit of already-existing Studio functionality, described
/// for the Platform to know about (WP-STUDIO-022 Studio Capability
/// Metadata Framework) — purely declarative metadata, not something
/// this Work Package makes callable. There is deliberately no Event Bus
/// entry point, no command-execution hook, and no registry of these
/// separate from [StudioDescriptor.capabilities]; a future Command
/// Palette or Capability Registry (Category C, WP-PLAT-020's
/// Outstanding Issues) would read this metadata, not the other way
/// around.
///
/// [id] must be unique across the whole [StudioRegistry] — see
/// [StudioRegistry.validateCapabilities] — so that a future consumer
/// can address one capability unambiguously without also needing to
/// know its owning Studio.
class CapabilityDescriptor {
  const CapabilityDescriptor({
    required this.id,
    required this.label,
    required this.description,
  });

  /// A stable, globally-unique identifier, conventionally
  /// `<studio>.<capability>` (e.g. `knowledge.review`) — a naming
  /// convention only; uniqueness is what [StudioRegistry.validateCapabilities]
  /// actually enforces.
  final String id;

  /// Short human-readable name, e.g. for a future settings/help surface.
  final String label;

  /// One sentence describing what the capability actually does today.
  final String description;
}

/// Everything one entry on the Navigation Rail needs, in one place
/// (WP-STUDIO-021 Studio Registry Framework): the stable identity
/// ([destination] — label/path/icon, unchanged from
/// `StudioDestination`, still the single source of truth for that
/// metadata), the route builder [app_router.dart] used to hand-list,
/// the two optional per-Studio contributions ([settingsProvider],
/// [searchProvider]) that `settings_registry.dart` and
/// `unified_search_service.dart` used to construct/call directly, and
/// (WP-STUDIO-022) the Studio's own [capabilities] metadata.
///
/// Not every destination is a "Studio" in the PAIS-001 sense (Dashboard,
/// Repository, Search, etc. are core Platform pages) — those simply
/// leave [settingsProvider]/[searchProvider]/[capabilities] empty,
/// which is exactly what happened implicitly before WP-STUDIO-021
/// (they were never referenced in `settings_registry.dart`/
/// `unified_search_service.dart` either).
class StudioDescriptor {
  const StudioDescriptor({
    required this.destination,
    required this.pageBuilder,
    this.settingsProvider,
    this.searchProvider,
    this.capabilities = const [],
  });

  final StudioDestination destination;
  final Widget Function(BuildContext context, GoRouterState state) pageBuilder;
  final SettingsProvider? settingsProvider;
  final StudioSearchProvider? searchProvider;

  /// This Studio's own capability metadata (WP-STUDIO-022) — belongs to
  /// this descriptor, not to any separate capability registry.
  final List<CapabilityDescriptor> capabilities;
}

/// The authoritative source for Navigation, Routing, Search Providers,
/// Settings Providers, Studio Metadata, and (WP-STUDIO-022) Capability
/// Metadata — replacing the four places [StudioDestination] used to be
/// paired, by hand, with a route (`app_router.dart`), a settings page
/// (`settings_registry.dart`), and a search contribution
/// (`unified_search_service.dart`), once each, in four separate files
/// that all had to be kept in sync manually.
///
/// This is a refactor, not a redesign: [defaultRegistry] is seeded with
/// exactly the same 13 destinations, in exactly the same order, pointing
/// at exactly the same widgets/providers/search logic that were already
/// hand-wired — see `docs/tasks/WP-STUDIO-021 Studio Registry Framework.md`
/// for the dependency map this replaces. No plugin system or dynamic
/// loading is introduced; [defaultRegistry] is still a plain, static,
/// compile-time list, exactly like `SettingsRegistry.defaultRegistry`
/// already was.
///
/// Capability metadata (WP-STUDIO-022, `docs/tasks/WP-STUDIO-022 Studio
/// Capability Metadata Framework.md`) is purely declarative and lives on
/// each Studio's own [StudioDescriptor.capabilities] — there is no
/// separate Capability Registry class, no Event Bus, and nothing here
/// is executable; a capability is a description of something a Studio
/// already does, not a callable command.
class StudioRegistry {
  StudioRegistry(List<StudioDescriptor> descriptors) : _descriptors = List.unmodifiable(descriptors);

  final List<StudioDescriptor> _descriptors;

  /// In registration order — the order the Navigation Rail renders and
  /// the router registers.
  List<StudioDescriptor> get descriptors => _descriptors;

  /// The [StudioDestination] for every registered descriptor, in order
  /// — what `StudioNavRail` now iterates instead of
  /// `StudioDestination.values` directly.
  List<StudioDestination> get destinations => [for (final descriptor in _descriptors) descriptor.destination];

  StudioDescriptor? descriptorFor(StudioDestination destination) {
    for (final descriptor in _descriptors) {
      if (descriptor.destination == destination) return descriptor;
    }
    return null;
  }

  /// One [GoRoute] per descriptor — what `app_router.dart` now builds
  /// its route table from, instead of hand-listing one `GoRoute` per
  /// [StudioDestination].
  List<GoRoute> buildRoutes() => [
        for (final descriptor in _descriptors)
          GoRoute(path: descriptor.destination.path, builder: descriptor.pageBuilder),
      ];

  /// Every registered [SettingsProvider], in registration order — what
  /// `SettingsRegistry.defaultRegistry` now splices in for the three
  /// Studios that have one, instead of constructing
  /// `KnowledgeStudioSettingsProvider`/`DiagramStudioSettingsProvider`/
  /// `AcquisitionSettingsProvider` directly.
  List<SettingsProvider> get settingsProviders =>
      [for (final descriptor in _descriptors) if (descriptor.settingsProvider != null) descriptor.settingsProvider!];

  /// Every registered [StudioSearchProvider], in registration order —
  /// what `UnifiedSearchService.search` now iterates instead of calling
  /// the Foundation/Engine/Acquisition search blocks by hand, in a
  /// fixed sequence.
  List<StudioSearchProvider> get searchProviders =>
      [for (final descriptor in _descriptors) if (descriptor.searchProvider != null) descriptor.searchProvider!];

  /// [destination]'s own capability metadata, in registration order —
  /// empty for any destination that isn't a "Studio" in the PAIS-001
  /// sense, or for an unregistered destination (WP-STUDIO-022).
  List<CapabilityDescriptor> capabilitiesFor(StudioDestination destination) =>
      descriptorFor(destination)?.capabilities ?? const [];

  /// Every registered [CapabilityDescriptor] across every Studio,
  /// flattened in registration order (WP-STUDIO-022).
  List<CapabilityDescriptor> get allCapabilities =>
      [for (final descriptor in _descriptors) ...descriptor.capabilities];

  /// The [CapabilityDescriptor] with the given [id], or `null` if no
  /// registered Studio has one by that id (WP-STUDIO-022).
  CapabilityDescriptor? findCapability(String id) {
    for (final capability in allCapabilities) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  /// The [StudioDestination] that owns the capability with the given
  /// [id], or `null` if no registered Studio has one by that id
  /// (WP-STUDIO-022).
  StudioDestination? ownerOf(String id) {
    for (final descriptor in _descriptors) {
      if (descriptor.capabilities.any((capability) => capability.id == id)) return descriptor.destination;
    }
    return null;
  }

  /// Checks every registered [CapabilityDescriptor] for internal
  /// consistency (WP-STUDIO-022): a blank [CapabilityDescriptor.id],
  /// [CapabilityDescriptor.label], or [CapabilityDescriptor.description]
  /// is always a mistake, and a duplicate [CapabilityDescriptor.id] —
  /// even across two different Studios — breaks the uniqueness
  /// [findCapability] and [ownerOf] depend on. Returns one human-readable
  /// message per problem found; an empty list means the registry is
  /// consistent. This never throws — callers (tests, a future startup
  /// check) decide what to do with a non-empty result.
  List<String> validateCapabilities() {
    final issues = <String>[];
    final seenIds = <String, StudioDestination>{};
    for (final descriptor in _descriptors) {
      for (final capability in descriptor.capabilities) {
        final owner = descriptor.destination;
        if (capability.id.trim().isEmpty) {
          issues.add('${owner.label}: a capability has a blank id.');
          continue;
        }
        if (capability.label.trim().isEmpty) {
          issues.add('${owner.label}: capability "${capability.id}" has a blank label.');
        }
        if (capability.description.trim().isEmpty) {
          issues.add('${owner.label}: capability "${capability.id}" has a blank description.');
        }
        final existingOwner = seenIds[capability.id];
        if (existingOwner != null) {
          issues.add(
            'Capability id "${capability.id}" is registered by both ${existingOwner.label} and ${owner.label} — '
            'capability ids must be globally unique.',
          );
        } else {
          seenIds[capability.id] = owner;
        }
      }
    }
    return issues;
  }

  static final StudioRegistry defaultRegistry = StudioRegistry([
    const StudioDescriptor(
      destination: StudioDestination.dashboard,
      pageBuilder: _dashboardBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.projectExplorer,
      pageBuilder: _projectExplorerBuilder,
    ),
    StudioDescriptor(
      destination: StudioDestination.knowledge,
      pageBuilder: _knowledgeBuilder,
      settingsProvider: const KnowledgeStudioSettingsProvider(),
      searchProvider: _searchKnowledge,
      capabilities: const [
        CapabilityDescriptor(
          id: 'knowledge.sourceIngestion',
          label: 'Source Material Ingestion',
          description: 'Import and OCR-process source documents (PDF) for evidence-backed knowledge capture.',
        ),
        CapabilityDescriptor(
          id: 'knowledge.aiAssistance',
          label: 'AI-Assisted Extraction',
          description:
              'Extract candidate entities, relationships, and specifications from source material using a '
              'configurable AI provider.',
        ),
        CapabilityDescriptor(
          id: 'knowledge.evidence',
          label: 'Evidence Linking',
          description: 'Link Knowledge Candidates to OCR-indexed source regions with full provenance tracking.',
        ),
        CapabilityDescriptor(
          id: 'knowledge.review',
          label: 'Knowledge Candidate Review',
          description:
              'Review and commit AI-suggested or manually created Knowledge Candidates into Engineering '
              'Objects and Relationships.',
        ),
      ],
    ),
    StudioDescriptor(
      destination: StudioDestination.diagram,
      pageBuilder: _diagramBuilder,
      settingsProvider: const DiagramStudioSettingsProvider(),
      searchProvider: _searchDiagram,
      capabilities: const [
        CapabilityDescriptor(
          id: 'diagram.editing',
          label: 'Diagram Editing',
          description: 'Create and edit engineering diagrams: nodes, relationships, ports, groups, and wire overrides.',
        ),
        CapabilityDescriptor(
          id: 'diagram.layersAndAnnotations',
          label: 'Layer & Annotation Management',
          description: 'Organize diagram content into layers and annotate diagrams with notes.',
        ),
        CapabilityDescriptor(
          id: 'diagram.validation',
          label: 'Diagram Validation',
          description: 'Run structural and engineering validation checks against the active diagram graph.',
        ),
        CapabilityDescriptor(
          id: 'diagram.aiAssistance',
          label: 'AI Diagram Assistance',
          description: 'Get AI-assisted suggestions while editing the active diagram.',
        ),
      ],
    ),
    StudioDescriptor(
      destination: StudioDestination.acquisition,
      pageBuilder: _acquisitionBuilder,
      settingsProvider: const AcquisitionSettingsProvider(),
      searchProvider: _searchAcquisition,
      capabilities: const [
        CapabilityDescriptor(
          id: 'acquisition.sourceManagement',
          label: 'Official Source Management',
          description: 'Register and manage trusted official engineering data sources.',
        ),
        CapabilityDescriptor(
          id: 'acquisition.jobOrchestration',
          label: 'Acquisition Job Orchestration',
          description: 'Create, execute, and cancel acquisition jobs against registered sources.',
        ),
        CapabilityDescriptor(
          id: 'acquisition.integrityPipeline',
          label: 'Download, Verification & Metadata Pipeline',
          description: 'Download artifacts, verify integrity by SHA-256, and extract artifact metadata.',
        ),
        CapabilityDescriptor(
          id: 'acquisition.vaultPublishing',
          label: 'Reference Vault Publishing',
          description: 'Publish verified artifacts with extracted metadata into the immutable Reference Vault.',
        ),
      ],
    ),
    const StudioDescriptor(
      destination: StudioDestination.repository,
      pageBuilder: _repositoryBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.objects,
      pageBuilder: _objectsBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.relationships,
      pageBuilder: _relationshipsBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.search,
      pageBuilder: _searchPageBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.graph,
      pageBuilder: _graphBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.validation,
      pageBuilder: _validationBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.packages,
      pageBuilder: _packagesBuilder,
    ),
    const StudioDescriptor(
      destination: StudioDestination.engineeringIntelligence,
      pageBuilder: _engineeringIntelligenceBuilder,
      capabilities: [
        CapabilityDescriptor(
          id: 'engineeringIntelligence.explorer',
          label: 'Engineering Explorer',
          description: 'Browse Engineering Objects, Relationships, Packages, and Knowledge Domains, and navigate semantic relationships.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.knowledgeGraph',
          label: 'Knowledge Graph Explorer',
          description: 'Read-only visualization of the Knowledge Graph: zoom, pan, expand/collapse, relationship highlighting, statistics.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.queryConsole',
          label: 'Query Console',
          description: 'Plan and execute Engineering Query Engine queries, and inspect execution plans, results, and statistics.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.validation',
          label: 'Validation Dashboard',
          description: 'Run Validation Sessions and review Validation Reports, Findings, and Rule Statistics.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.analysis',
          label: 'Analysis Dashboard',
          description: 'Dependency, Impact, Reachability, and Root Cause analysis plus overall Engineering Health.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.reasoning',
          label: 'Reasoning Dashboard',
          description: 'Run Reasoning Sessions and inspect Evidence Graphs, Engineering Conclusions, and confidence.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.recommendations',
          label: 'Recommendation Panel',
          description: 'Deterministic engineering recommendations with supporting evidence, referenced rules, validation, and objects.',
        ),
        CapabilityDescriptor(
          id: 'engineeringIntelligence.sessions',
          label: 'Knowledge Session Manager',
          description: 'Create, resume, clone, close, inspect, and export summaries of Engineering Intelligence Platform sessions.',
        ),
      ],
    ),
    StudioDescriptor(
      destination: StudioDestination.exchange,
      pageBuilder: _exchangeBuilder,
      settingsProvider: const ExchangeSettingsProvider(),
      searchProvider: _searchExchange,
      capabilities: const [
        CapabilityDescriptor(
          id: 'exchange.browse',
          label: 'Marketplace Browsing & Search',
          description: 'Browse Marketplace Home, search packages, and view Package Detail / Publisher Profiles.',
        ),
        CapabilityDescriptor(
          id: 'exchange.install',
          label: 'Package Installation',
          description: 'Install a published package version into the open Repository and track its status.',
        ),
        CapabilityDescriptor(
          id: 'exchange.library',
          label: 'Downloads & My Library',
          description: 'Download package artifacts and review locally-tracked download/installation history.',
        ),
      ],
    ),
    const StudioDescriptor(
      destination: StudioDestination.settings,
      pageBuilder: _settingsBuilder,
    ),
  ]);
}

Widget _dashboardBuilder(BuildContext context, GoRouterState state) => const DashboardPage();
Widget _projectExplorerBuilder(BuildContext context, GoRouterState state) => const ProjectExplorerPage();
Widget _knowledgeBuilder(BuildContext context, GoRouterState state) => const KnowledgeStudioPage();
Widget _diagramBuilder(BuildContext context, GoRouterState state) => const DiagramStudioPage();
Widget _acquisitionBuilder(BuildContext context, GoRouterState state) => const AcquisitionStudioPage();
Widget _repositoryBuilder(BuildContext context, GoRouterState state) => const RepositoryPage();
Widget _objectsBuilder(BuildContext context, GoRouterState state) => const ObjectsPage();
Widget _relationshipsBuilder(BuildContext context, GoRouterState state) => const RelationshipsPage();
Widget _searchPageBuilder(BuildContext context, GoRouterState state) => const SearchPage();
Widget _graphBuilder(BuildContext context, GoRouterState state) => const GraphPage();
Widget _validationBuilder(BuildContext context, GoRouterState state) => const ValidationPage();
Widget _packagesBuilder(BuildContext context, GoRouterState state) => const PackagesPage();
Widget _engineeringIntelligenceBuilder(BuildContext context, GoRouterState state) => const EngineeringIntelligencePage();
Widget _exchangeBuilder(BuildContext context, GoRouterState state) => const ExchangeStudioPage();
Widget _settingsBuilder(BuildContext context, GoRouterState state) =>
    SettingsWorkspacePage(initialPageId: state.uri.queryParameters['page']);

/// Moved from `UnifiedSearchService` unchanged (WP-STUDIO-021) — see
/// that class's own doc comment history for why this reads
/// `foundationRuntimeServiceProvider` directly rather than through any
/// new abstraction.
List<UnifiedSearchResult> _searchKnowledge(WidgetRef ref, String query, SearchScope scope) {
  final foundation = ref.read(foundationRuntimeServiceProvider);
  if (!foundation.isRepositoryOpen) return const [];
  final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
  notifier.search(query, scope: scope);
  final foundationResults = ref.read(foundationRuntimeServiceProvider).searchResults ?? const [];
  final repositoryName =
      ref.read(foundationRuntimeServiceProvider).repositoryStatus?.repositoryName ?? 'Open Repository';
  return [
    for (final result in foundationResults) UnifiedSearchResult.fromFoundation(result, repositoryLocation: repositoryName),
  ];
}

/// Moved from `UnifiedSearchService` unchanged (WP-STUDIO-021).
List<UnifiedSearchResult> _searchDiagram(WidgetRef ref, String query, SearchScope scope) {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  final session = projectState.session;
  if (engine == null || session == null) return const [];
  final engineResults = engine.registry.search.search(session.graph, session.layout, query);
  final documentLabel = projectState.documentPath?.split(RegExp(r'[\\/]')).last ?? 'Unsaved Diagram';
  return [
    for (final result in engineResults) UnifiedSearchResult.fromEngine(result, repositoryLocation: documentLabel),
  ];
}

/// Moved from `UnifiedSearchService` unchanged (WP-STUDIO-021, added
/// WP-PLAT-020) — still a best-effort, client-side, cache-only filter,
/// not a real index; see this Work Package's Outstanding Issues.
List<UnifiedSearchResult> _searchAcquisition(WidgetRef ref, String query, SearchScope scope) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final acquisition = ref.read(acquisitionRuntimeServiceProvider);
  final results = <UnifiedSearchResult>[];

  for (final source in acquisition.sources) {
    if (source.name.toLowerCase().contains(needle) || source.category.toLowerCase().contains(needle)) {
      results.add(UnifiedSearchResult.fromAcquisition(
        category: UnifiedSearchResultCategory.acquisitionSource,
        id: source.id,
        label: source.name,
        objectTypeLabel: 'Official Source',
      ));
    }
  }
  for (final job in acquisition.jobs) {
    if (job.name.toLowerCase().contains(needle) || job.status.toLowerCase().contains(needle)) {
      results.add(UnifiedSearchResult.fromAcquisition(
        category: UnifiedSearchResultCategory.acquisitionJob,
        id: job.id,
        label: job.name,
        objectTypeLabel: 'Acquisition Job',
      ));
    }
  }
  for (final entry in acquisition.vaultEntries) {
    if (entry.sha256Hash.toLowerCase().contains(needle) || entry.mimeType.toLowerCase().contains(needle)) {
      results.add(UnifiedSearchResult.fromAcquisition(
        category: UnifiedSearchResultCategory.acquisitionVaultEntry,
        id: entry.id,
        label: entry.sha256Hash.isEmpty ? entry.id : entry.sha256Hash.substring(0, 16),
        objectTypeLabel: 'Vault Entry',
      ));
    }
  }
  return results;
}

/// A best-effort, client-side, cache-only filter over whatever
/// Marketplace/Library data the Exchange Studio has already loaded
/// (WP-EXC-010) -- mirrors `_searchAcquisition`'s own reasoning exactly:
/// not a real index, just a filter over the currently cached
/// `ExchangeServiceState`, since a real index already exists server-side
/// (`GET /search`) but Unified Search's contract here is synchronous and
/// cache-only, the same constraint `_searchAcquisition` already works
/// under.
List<UnifiedSearchResult> _searchExchange(WidgetRef ref, String query, SearchScope scope) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final exchange = ref.read(exchangeRuntimeServiceProvider);
  final results = <UnifiedSearchResult>[];

  for (final package in exchange.packages) {
    if (package.displayName.toLowerCase().contains(needle) || package.packageId.toLowerCase().contains(needle)) {
      results.add(UnifiedSearchResult.fromExchange(
        category: UnifiedSearchResultCategory.exchangePackage,
        id: package.id,
        label: package.displayName,
        objectTypeLabel: 'Exchange Package',
      ));
    }
  }
  for (final publisher in exchange.publishers) {
    if (publisher.displayName.toLowerCase().contains(needle) || publisher.namespace.toLowerCase().contains(needle)) {
      results.add(UnifiedSearchResult.fromExchange(
        category: UnifiedSearchResultCategory.exchangePublisher,
        id: publisher.id,
        label: publisher.displayName,
        objectTypeLabel: 'Exchange Publisher',
      ));
    }
  }
  return results;
}
