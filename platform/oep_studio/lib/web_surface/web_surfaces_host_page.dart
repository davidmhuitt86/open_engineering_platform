import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../acquisition/workspaces/acquisition_studio_page.dart';
import '../core/routing/studio_destination.dart';
import '../core/services/engineering_project_service.dart';
import '../core/theme/studio_colors.dart';
import '../diagram_studio/controller/diagram_studio_controller_provider.dart';
import '../diagram_studio/webview/legacy_v2_webview.dart';
import '../engineering_intelligence/engineering_intelligence_page.dart';
import '../exchange/workspaces/exchange_studio_page.dart';
import '../features/copilot/copilot_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/graph/graph_page.dart';
import '../features/objects/objects_page.dart';
import '../features/packages/packages_page.dart';
import '../features/project_explorer/project_explorer_page.dart';
import '../features/relationships/relationships_page.dart';
import '../features/repository/repository_page.dart';
import '../features/search/search_page.dart';
import '../features/validation/validation_page.dart';
import '../knowledge/workspaces/knowledge_studio_page.dart';
import '../settings/workspace/settings_workspace_page.dart';
import 'web_surface.dart';
import 'web_surface_tabs_controller.dart';
import 'web_surface_tabs_storage.dart';
import 'web_surface_view.dart';

/// AP-STUDIO-WEB-SURFACE-002 — the real Studio "Web Surfaces"
/// destination (`StudioDestination.webSurfaces`, `/web-surfaces`),
/// registered in `core/routing/studio_registry.dart` and reached through
/// the same persistent Navigation Rail every other Studio uses — this
/// promotes AP-STUDIO-WEB-SURFACE-001's dev-button POC into a real Studio
/// surface. No own `Scaffold`/`AppBar`: like every other
/// `StudioDescriptor.pageBuilder` target (`DashboardPage`,
/// `EngineeringWorkbenchPage`, etc.), this widget renders as body content
/// inside the single persistent `StudioShell`, not as its own page frame.
///
/// Three tab kinds:
///
///  1. **Diagram Studio** — the existing, unmodified [LegacyV2WebViewPage]
///     embedded directly. The only [WebSurface] whose
///     `application == WebSurfaceApplication.legacyV2`, and therefore
///     the only one with `bridgeAuthorized == true` (structurally
///     enforced — see `WebSurface.bridgeAuthorized`'s own doc comment).
///     Its tab label is bound live to the open document's title (see
///     `build`'s `documentTitle`/`titleOverrides`), not a fixed string —
///     "Legacy V2" is this Studio's internal bridge/presentation-
///     technology name (see `docs/OEP_STUDIO_ARCHITECTURE.md`'s STUDIO
///     vs. PRESENTATION TECHNOLOGY split), never surfaced as
///     product-facing UI text. "New Diagram" (the "+" menu) calls
///     `EngineeringProjectServiceNotifier.newDocument()` and focuses
///     this tab — it replaces the single current document rather than
///     opening a second, independent one, because Diagram Studio has
///     exactly one `EditingSession` today (confirmed: no multi-document
///     API exists on `EngineeringProjectService`). Real multi-document
///     support (an independent session per tab) is a separate,
///     Engine-level undertaking, not attempted here (AP-OEP-DIAGRAM-UX-003).
///  2. **Generic Web Surfaces** — [WebSurfaceView] instances. The globe
///     button opens one immediately, blank (`about:blank`), with its own
///     address bar — no upfront "enter a URL" dialog, matching a
///     browser's own new-tab behavior.
///  3. **Native OEP destination tabs** ([_NativeTab]) — the real, live
///     Flutter page for another OEP destination (Repository, Settings,
///     Knowledge Studio, etc.), embedded directly as tab content via
///     the "+" dropdown. Deliberately a separate, lightweight list
///     (`_nativeTabs`) rather than folded into [WebSurface] — a native
///     page has no URL/`WebviewController`, so shoehorning it into that
///     URL-centric model would be a category error, not a simplification
///     (mirrors the reasoning [WebSurface]'s own doc comment already
///     gives for keeping Legacy V2 and generic surfaces as the two
///     things that model actually covers). Session-only: not persisted
///     across restarts (unlike [WebSurface] tabs) — a smaller, accepted
///     scope gap, not an oversight.
///
/// All open tabs are kept in an `IndexedStack` (never rebuilt out of the
/// tree on switch) — see [WebSurfaceView]'s own doc comment for why this
/// is what preserves each surface's state across tab switches. The open
/// [WebSurface] tab list and active tab id are persisted
/// (`WebSurfaceTabsStorage`) and restored on next launch, with the
/// Diagram Studio tab always guaranteed present even if it wasn't the
/// last thing saved (so the Studio never opens to nothing) —
/// AP-OEP-DIAGRAM-UX-001. A leading "back to OEP" button (navigates to
/// `/`) is always present in the tab strip — Diagram Studio's own
/// chrome-bypass carve-out (`StudioShell.build`) means the Navigation
/// Rail is not reachable from here any other way (AP-OEP-DIAGRAM-UX-003).
class WebSurfacesHostPage extends ConsumerStatefulWidget {
  const WebSurfacesHostPage({super.key, this.autoOpenLegacyV2 = false});

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 2 — `true` for the production
  /// `/diagram` route (`Studio → Diagram Studio → Web Surface Host →
  /// Legacy V2`, opened automatically, matching the target flow) —
  /// `false` for any other host of this widget (none exist today; kept
  /// as a constructor flag rather than hard-coded so a future non-
  /// Diagram-Studio host of this same widget isn't forced to open V2).
  /// Only affects the very first launch (no persisted tabs yet) — once a
  /// session has been persisted, restoration (§ class doc comment) is
  /// authoritative and this flag no longer matters.
  final bool autoOpenLegacyV2;

  static const String nativeTabId = 'native-oep';
  static const String legacyV2TabId = 'legacy-v2';

  @override
  ConsumerState<WebSurfacesHostPage> createState() => _WebSurfacesHostPageState();
}

/// A native OEP destination embedded as tab content (§ class doc
/// comment, kind 3). Deliberately not a [WebSurface] — see there for why.
class _NativeTab {
  _NativeTab({required this.id, required this.destination});

  final String id;
  final StudioDestination destination;
}

class _WebSurfacesHostPageState extends ConsumerState<WebSurfacesHostPage> {
  final WebSurfaceTabsController _tabs = WebSurfaceTabsController();
  final List<_NativeTab> _nativeTabs = [];
  bool _restored = false;

  /// Unified across [WebSurface] tabs and [_NativeTab]s — `activeId` is
  /// no longer sourced from `_tabs.activeId` alone, since a native tab
  /// id would never be found in `_tabs.surfaces` (see `_activate`).
  String? _activeTabId;

  static WebSurface _diagramStudioSurface() => WebSurface(
        id: WebSurfacesHostPage.legacyV2TabId,
        title: 'Diagram Studio',
        initialUrl: 'file://legacy-v2', // placeholder, see class doc comment
        application: WebSurfaceApplication.legacyV2,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_restoreTabs());
  }

  /// AP-OEP-DIAGRAM-UX-001 — restores whatever [WebSurface] tabs were
  /// open last session, guaranteeing the Diagram Studio tab is always
  /// among them even if it wasn't (e.g. the user closed it right before
  /// exiting) — "always load at least the diagram, plus whatever else
  /// was still open." On a genuinely first launch (nothing persisted
  /// yet), falls back to today's [widget.autoOpenLegacyV2]-gated
  /// default. Native tabs are never restored (session-only, § class doc
  /// comment).
  Future<void> _restoreTabs() async {
    final loaded = await WebSurfaceTabsStorage.load();
    final restoredSurfaces = List<WebSurface>.of(loaded.surfaces);
    final hasDiagramStudio = restoredSurfaces.any((s) => s.id == WebSurfacesHostPage.legacyV2TabId);
    if (!hasDiagramStudio) {
      restoredSurfaces.insert(0, _diagramStudioSurface());
    }
    if (restoredSurfaces.isEmpty && widget.autoOpenLegacyV2) {
      restoredSurfaces.add(_diagramStudioSurface());
    }
    if (!mounted) return;
    setState(() {
      for (final surface in restoredSurfaces) {
        _tabs.add(surface, activate: false);
      }
      _activeTabId = loaded.activeId ?? (restoredSurfaces.isEmpty ? null : restoredSurfaces.first.id);
      _restored = true;
    });
  }

  Future<void> _persistTabs() =>
      WebSurfaceTabsStorage.save(surfaces: _tabs.surfaces, activeId: _activeTabId);

  /// "+" menu — "New Diagram": replaces the single current document
  /// (§ class doc comment on why this isn't a second independent
  /// session) and focuses/opens the Diagram Studio tab.
  void _newDiagram() {
    unawaited(ref.read(engineeringProjectServiceProvider.notifier).newDocument());
    _openLegacyV2();
  }

  /// Opens (or focuses, if already open) the Diagram Studio tab. Reuses
  /// the tab if already open (matches `DiagramTabsNotifier.openTab`'s
  /// own "don't duplicate an already-open reference" behavior) rather
  /// than allowing two.
  void _openLegacyV2() {
    if (_tabs.surfaces.any((s) => s.id == WebSurfacesHostPage.legacyV2TabId)) {
      setState(() => _activeTabId = WebSurfacesHostPage.legacyV2TabId);
      unawaited(_persistTabs());
      return;
    }
    setState(() {
      _tabs.add(_diagramStudioSurface());
      _activeTabId = WebSurfacesHostPage.legacyV2TabId;
    });
    unawaited(_persistTabs());
  }

  /// "+" menu — opens (or focuses, if already open) a native tab for
  /// [destination].
  void _openNativeTab(StudioDestination destination) {
    final existing = _nativeTabs.where((t) => t.destination == destination).firstOrNull;
    if (existing != null) {
      setState(() => _activeTabId = existing.id);
      return;
    }
    final tab = _NativeTab(id: 'native-${destination.name}', destination: destination);
    setState(() {
      _nativeTabs.add(tab);
      _activeTabId = tab.id;
    });
  }

  /// Globe button — opens a new, blank Web Surface tab immediately (no
  /// upfront URL prompt), with its own address bar
  /// ([WebSurfaceView]'s existing `showChrome` row) — a browser's own
  /// new-tab behavior, not a dialog-first flow.
  void _openBlankWebTab() {
    final id = 'web-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _tabs.add(WebSurface(id: id, title: 'New Tab', initialUrl: 'about:blank'));
      _activeTabId = id;
    });
    unawaited(_persistTabs());
  }

  void _activate(String id) {
    setState(() => _activeTabId = id);
    if (_tabs.surfaces.any((s) => s.id == id)) unawaited(_persistTabs());
  }

  void _close(String id) {
    final isNative = _nativeTabs.any((t) => t.id == id);
    setState(() {
      if (isNative) {
        _nativeTabs.removeWhere((t) => t.id == id);
        if (_activeTabId == id) {
          _activeTabId = _nativeTabs.isNotEmpty ? _nativeTabs.last.id : _tabs.surfaces.lastOrNull?.id;
        }
      } else {
        final wasActive = _activeTabId == id;
        _tabs.close(id);
        if (wasActive) _activeTabId = _tabs.activeId ?? _nativeTabs.lastOrNull?.id;
      }
    });
    if (!isNative) unawaited(_persistTabs());
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _tabs.surfaces;
    // AP-OEP-DIAGRAM-UX-001 — the Diagram Studio tab's label is bound to
    // the live open document's title, not a fixed "Legacy V2" string
    // (that name is this Studio's internal presentation-technology
    // detail, never product-facing UI text — see the class doc comment).
    final documentTitle = ref.watch(diagramStudioControllerProvider).valueOrNull?.document.metadata.title;

    return Container(
      color: StudioColors.background,
      child: Column(
        children: [
          _TabStrip(
            surfaces: surfaces,
            nativeTabs: _nativeTabs,
            activeId: _activeTabId,
            onActivate: _activate,
            onClose: _close,
            onNewDiagram: _newDiagram,
            onOpenNativeTab: _openNativeTab,
            onOpenWebUrl: _openBlankWebTab,
            onBackToOep: () => context.go('/'),
            titleOverrides: {
              if (documentTitle != null) WebSurfacesHostPage.legacyV2TabId: documentTitle,
            },
          ),
          Expanded(
            child: !_restored
                ? const SizedBox.shrink()
                : (surfaces.isEmpty && _nativeTabs.isEmpty)
                    ? const Center(
                        child: Text('No Web Surfaces open', style: TextStyle(color: StudioColors.textDisabled)),
                      )
                    : IndexedStack(
                        index: _stackIndex(surfaces),
                        children: [
                          for (final surface in surfaces) _buildSurfaceContent(surface),
                          for (final tab in _nativeTabs) _buildNativeContent(tab),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  int _stackIndex(List<WebSurface> surfaces) {
    final combinedIds = [...surfaces.map((s) => s.id), ..._nativeTabs.map((t) => t.id)];
    if (combinedIds.isEmpty) return 0;
    final index = combinedIds.indexOf(_activeTabId ?? '');
    return index.clamp(0, combinedIds.length - 1);
  }

  Widget _buildSurfaceContent(WebSurface surface) {
    if (surface.application == WebSurfaceApplication.legacyV2) {
      // The existing, unmodified bridged widget — embedded directly, not
      // reconstructed through the generic WebSurface model.
      return const LegacyV2WebViewPage();
    }
    if (surface.id == WebSurfacesHostPage.nativeTabId) {
      return _NativeOepPanel(key: ValueKey(surface.id));
    }
    return WebSurfaceView(key: ValueKey(surface.id), surface: surface);
  }

  Widget _buildNativeContent(_NativeTab tab) {
    return KeyedSubtree(key: ValueKey(tab.id), child: _nativeDestinationPage(tab.destination));
  }

  /// Directly constructs the real page widget for [destination] — not
  /// via `StudioDescriptor.pageBuilder` (`studio_registry.dart`), which
  /// takes a `GoRouterState` this embedded-tab context doesn't have.
  /// Every builder that matters here ignores `state` already (confirmed
  /// by reading each one) except Settings, whose `initialPageId` query
  /// param a plain tab has no equivalent for — `null` (its own default)
  /// is used instead.
  Widget _nativeDestinationPage(StudioDestination destination) {
    return switch (destination) {
      StudioDestination.dashboard => const DashboardPage(),
      StudioDestination.projectExplorer => const ProjectExplorerPage(),
      StudioDestination.knowledge => const KnowledgeStudioPage(),
      StudioDestination.acquisition => const AcquisitionStudioPage(),
      StudioDestination.repository => const RepositoryPage(),
      StudioDestination.objects => const ObjectsPage(),
      StudioDestination.relationships => const RelationshipsPage(),
      StudioDestination.search => const SearchPage(),
      StudioDestination.graph => const GraphPage(),
      StudioDestination.validation => const ValidationPage(),
      StudioDestination.packages => const PackagesPage(),
      StudioDestination.engineeringIntelligence => const EngineeringIntelligencePage(),
      StudioDestination.exchange => const ExchangeStudioPage(),
      StudioDestination.copilot => const CopilotPage(),
      StudioDestination.settings => const SettingsWorkspacePage(initialPageId: null),
      // Diagram/diagramClassic are not offered in the "+" menu (see
      // `_TabStrip`'s own menu-building code) — Diagram Studio is this
      // page itself, and Classic hosts Perspectives unrelated to tabs.
      StudioDestination.diagram || StudioDestination.diagramClassic => const SizedBox.shrink(),
    };
  }
}

extension _WebSurfaceListX on List<WebSurface> {
  WebSurface? get lastOrNull => isEmpty ? null : last;
}

extension _NativeTabListX on List<_NativeTab> {
  _NativeTab? get lastOrNull => isEmpty ? null : last;
}

extension _NativeTabWhereX on Iterable<_NativeTab> {
  _NativeTab? get firstOrNull => isEmpty ? null : first;
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.surfaces,
    required this.nativeTabs,
    required this.activeId,
    required this.onActivate,
    required this.onClose,
    required this.onNewDiagram,
    required this.onOpenNativeTab,
    required this.onOpenWebUrl,
    required this.onBackToOep,
    this.titleOverrides = const {},
  });

  final List<WebSurface> surfaces;
  final List<_NativeTab> nativeTabs;
  final String? activeId;
  final void Function(String id) onActivate;
  final void Function(String id) onClose;
  final VoidCallback onNewDiagram;
  final void Function(StudioDestination) onOpenNativeTab;
  final VoidCallback onOpenWebUrl;
  final VoidCallback onBackToOep;
  final Map<String, String> titleOverrides;

  /// Every destination offered in the "+" dropdown besides Diagram
  /// Studio itself (covered by its own "New Diagram" item) and Classic
  /// (Perspectives shell, not a tab-shaped destination).
  static const _nativeDestinations = [
    StudioDestination.dashboard,
    StudioDestination.projectExplorer,
    StudioDestination.knowledge,
    StudioDestination.acquisition,
    StudioDestination.repository,
    StudioDestination.objects,
    StudioDestination.relationships,
    StudioDestination.search,
    StudioDestination.graph,
    StudioDestination.validation,
    StudioDestination.packages,
    StudioDestination.engineeringIntelligence,
    StudioDestination.exchange,
    StudioDestination.copilot,
    StudioDestination.settings,
  ];

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
          // AP-OEP-DIAGRAM-UX-003 — Diagram Studio's chrome-bypass
          // carve-out (`StudioShell.build`) means the Navigation Rail is
          // not reachable from here any other way; this is the only path
          // back to the rest of OEP while a Web Surface tab is showing.
          IconButton(
            tooltip: 'Back to OEP',
            icon: const Icon(Icons.home_outlined, size: 16),
            color: StudioColors.textSecondary,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            splashRadius: 15,
            onPressed: onBackToOep,
          ),
          Container(width: 1, height: 18, color: StudioColors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
          // AP-OEP-DIAGRAM-UX-002 — `Flexible`/loose (not `Expanded`), so
          // this only takes as much width as the actual open tabs need
          // (scrolling internally past that), letting the "+"/globe sit
          // snug against the last tab exactly like Chrome's own new-tab
          // button — `Expanded` here previously pinned them to the far
          // right edge of the whole strip instead, with a large gap.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final surface in surfaces)
                    _TabChip(
                      id: surface.id,
                      displayTitle: titleOverrides[surface.id] ?? surface.title,
                      icon: surface.application == WebSurfaceApplication.legacyV2
                          ? Icons.polyline
                          : surface.kind == WebSurfaceKind.local
                              ? Icons.insert_drive_file
                              : Icons.public,
                      iconColor: surface.bridgeAuthorized ? StudioColors.success : StudioColors.textSecondary,
                      active: surface.id == activeId,
                      onTap: () => onActivate(surface.id),
                      onClose: () => onClose(surface.id),
                    ),
                  for (final tab in nativeTabs)
                    _TabChip(
                      id: tab.id,
                      displayTitle: tab.destination.label,
                      icon: tab.destination.icon,
                      iconColor: StudioColors.textSecondary,
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
                onTap: onNewDiagram,
                child: const _MenuRow(icon: Icons.polyline, label: 'New Diagram'),
              ),
              const PopupMenuDivider(),
              for (final destination in _nativeDestinations)
                PopupMenuItem<void>(
                  onTap: () => onOpenNativeTab(destination),
                  child: _MenuRow(icon: destination.icon, label: destination.label),
                ),
            ],
          ),
          IconButton(
            tooltip: 'New Web Tab',
            icon: const Icon(Icons.public, size: 16),
            color: StudioColors.textSecondary,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            splashRadius: 15,
            onPressed: onOpenWebUrl,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: StudioColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary)),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.id,
    required this.displayTitle,
    required this.icon,
    required this.iconColor,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final String id;
  final String displayTitle;
  final IconData icon;
  final Color iconColor;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 14, color: iconColor),
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

/// Proves native Studio content can sit alongside Web Surfaces in the
/// same tab strip without either side knowing about the other — reads
/// live Engine state through the existing, unmodified
/// `diagramStudioControllerProvider`, the same provider
/// `LegacyV2WebViewPage`'s own status bar already reads.
///
/// Superseded for real use by `_NativeTab` (§ class doc comment kind 3,
/// which embeds any OEP destination, not just this one demo panel) but
/// kept, unreachable via `WebSurcesHostPage.nativeTabId`, rather than
/// deleted (AP-OEP-DIAGRAM-UX-001's own reasoning, unchanged).
class _NativeOepPanel extends ConsumerWidget {
  const _NativeOepPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerAsync = ref.watch(diagramStudioControllerProvider);
    return Container(
      color: StudioColors.background,
      alignment: Alignment.center,
      child: controllerAsync.when(
        data: (controller) {
          final graph = controller.session?.graph;
          return Text(
            'Native OEP Studio surface\n\n'
            '${graph?.nodes.length ?? 0} node(s), ${graph?.relationships.length ?? 0} relationship(s)\n'
            'Document: "${controller.document.metadata.title}"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: StudioColors.textSecondary, fontFamily: 'Consolas'),
          );
        },
        loading: () => const CircularProgressIndicator(color: StudioColors.selection),
        error: (_, __) => const Text('Engine unavailable', style: TextStyle(color: StudioColors.error)),
      ),
    );
  }
}
