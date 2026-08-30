import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../diagram_studio/bridge/studio_foundation_bridge_port.dart';
import '../../diagram_studio/host/diagram_document.dart';
import '../../diagram_studio/host/engine_host.dart';
import '../../diagram_studio/settings/diagram_studio_settings_provider.dart';
import '../models/engineering_project.dart';
import '../models/recent_history_entry.dart';
import 'foundation_runtime_service.dart';

const int _maxRecentHistory = 50;

/// Everything an Engineering Project coordinates, as one immutable
/// snapshot (WORK_PACKAGE_025, ENGINE-TASK-000118/000119).
///
/// [engineHost]/[session]/[selection]/[viewState]/[validationReport]
/// mirror the Engineering Engine's own live state — the *same* engine
/// instance Diagram Studio edits, now reachable from any route (a
/// global Validation page, the unified Search page, Project Explorer),
/// not just from `DiagramStudioPage`'s own private `State`. [document]
/// is the single shared `DiagramDocument` (open/save/close/dirty-state)
/// — previously a `DiagramStudioPage`-private field.
class EngineeringProjectState {
  const EngineeringProjectState({
    this.activeProject,
    this.engineHost,
    required this.document,
    this.session,
    this.selection = GraphSelection.empty,
    this.viewState = ViewState.initial,
    this.validationReport,
    this.recentHistory = const [],
  });

  final EngineeringProject? activeProject;
  final EngineHost? engineHost;
  final DiagramDocument document;
  final EditingSession? session;
  final GraphSelection selection;
  final ViewState viewState;
  final ValidationReport? validationReport;
  final List<RecentHistoryEntry> recentHistory;

  EngineeringEngine? get engine => engineHost?.engine;

  bool get isDirty => document.isDirty;
  String? get documentPath => document.path;

  EngineeringProjectState copyWith({
    EngineeringProject? activeProject,
    EngineHost? engineHost,
    DiagramDocument? document,
    EditingSession? session,
    GraphSelection? selection,
    ViewState? viewState,
    ValidationReport? validationReport,
    List<RecentHistoryEntry>? recentHistory,
  }) {
    return EngineeringProjectState(
      activeProject: activeProject ?? this.activeProject,
      engineHost: engineHost ?? this.engineHost,
      document: document ?? this.document,
      session: session ?? this.session,
      selection: selection ?? this.selection,
      viewState: viewState ?? this.viewState,
      validationReport: validationReport ?? this.validationReport,
      recentHistory: recentHistory ?? this.recentHistory,
    );
  }
}

/// Owns the Engineering Engine instance Diagram Studio (and every other
/// consumer described below) reads from — the WORK_PACKAGE_025
/// resolution to `DiagramStudioPage` previously creating and destroying
/// its own private `EngineHost` per mount/unmount, which made the
/// engine unreachable from anywhere except that one page. This
/// `Notifier` outlives any single route: [ensureEngineStarted] is
/// idempotent (safe to call every time `DiagramStudioPage` mounts) and
/// the engine keeps running when the user navigates away to Knowledge
/// Studio, Validation, Search, or Project Explorer — which is exactly
/// what lets those routes show live validation/search/selection data
/// without Diagram Studio being the active workspace.
///
/// This class is Studio-side orchestration only — it never implements
/// engineering behavior itself, only relays the Engine's own streams
/// into Riverpod state (`docs/ENGINEERING_PROJECT.md`).
class EngineeringProjectNotifier extends Notifier<EngineeringProjectState> {
  StreamSubscription<EditingSession>? _sessionSub;
  StreamSubscription<GraphSelection>? _selectionSub;
  StreamSubscription<ViewState>? _viewStateSub;

  @override
  EngineeringProjectState build() {
    ref.onDispose(() {
      _sessionSub?.cancel();
      _selectionSub?.cancel();
      _viewStateSub?.cancel();
      final host = state.engineHost;
      if (host != null) unawaited(host.dispose());
    });
    return EngineeringProjectState(document: DiagramDocument());
  }

  /// Creates and subscribes to the shared `EngineHost` on first call;
  /// every later call returns the same instance without recreating
  /// anything. Begins a blank editing session if none exists yet.
  Future<EngineHost> ensureEngineStarted() async {
    final existing = state.engineHost;
    if (existing != null) return existing;

    // AP-OEP-FOUNDATION-BRIDGE-001 — resolved via a closure, not read
    // once here, so the registered bridge always reaches whichever
    // `FoundationBridge` is live *at commit time* (e.g. a repository
    // opened after this engine already started), matching
    // `LegacyV2StateAdapter.simulationServiceResolver`'s own established
    // "resolve fresh per call" reasoning in this codebase.
    final host = await EngineHost.create(
      foundationBridge: StudioFoundationBridgePort.fromBridgeResolver(
        () => ref.read(foundationRuntimeServiceProvider.notifier).bridge,
      ),
    );
    _sessionSub = host.engine.editing.sessionChanges.listen((s) {
      state = state.copyWith(session: s, validationReport: host.engine.validate(s.graph));
    });
    _selectionSub = host.engine.registry.selection.changes.listen((s) {
      state = state.copyWith(selection: s);
    });
    _viewStateSub = host.engine.registry.viewState.changes.listen((v) {
      state = state.copyWith(viewState: v);
    });

    host.engine.beginEditingSession(EngineeringGraph.empty(host.engine.graph.generateId('graph')));
    _applyNewDocumentViewStateDefaults(host);

    state = state.copyWith(
      engineHost: host,
      session: host.engine.editing.session,
      viewState: host.engine.registry.viewState.current,
      validationReport: host.engine.validate(host.engine.editing.session.graph),
    );
    return host;
  }

  void _applyNewDocumentViewStateDefaults(EngineHost host) {
    final settings = ref.read(diagramStudioSettingsProvider);
    final service = host.engine.registry.viewState as ViewStateService;
    if (service.current.grid.visible != settings.defaultGridVisible) service.toggleGrid();
    if (service.current.grid.snapEnabled != settings.defaultSnapEnabled) service.toggleSnap();
    service.setGuidesVisible(settings.defaultGuidesVisible);
  }

  // --- Document lifecycle (moved from DiagramStudioPage, ENGINE-TASK-000111/118) --

  Future<void> newDocument() async {
    final host = await ensureEngineStarted();
    state.document.close();
    host.engine.beginEditingSession(EngineeringGraph.empty(host.engine.graph.generateId('graph')));
    _applyNewDocumentViewStateDefaults(host);
    state = state.copyWith();
  }

  Future<void> openDocument(String path) async {
    final host = await ensureEngineStarted();
    final opened = await state.document.open(path);
    host.engine.editing.resetSession(EditingSession.initial(opened.graph).copyWith(layout: opened.layout));
    state = state.copyWith();
    await _reconnectToFoundationDiagram(host, opened.graph);
  }

  /// AP-OEP-DIAGRAM-PERSISTENCE-001 — if the just-restored graph already
  /// carries a Foundation diagram identity (`diagramRepositoryId`,
  /// established by a prior `EngineGraphCommitService.commit()` and
  /// round-tripped for free through `DiagramDocument`'s existing
  /// `graph.toJson()`/`fromJson()` envelope), verify it against the
  /// currently open Foundation Repository through the existing scoped
  /// `StudioFoundationBridgePort.loadCommittedGraph` path — never a
  /// whole-Repository enumeration.
  ///
  /// Deliberately does not use the load's *result* to replace the
  /// restored graph: the local file already carries this diagram's own
  /// layout, groups, and richer `NodeCategory`/`RelationshipType` detail
  /// that Foundation's committed representation can't reconstruct (see
  /// `loadCommittedGraph`'s own doc comment) — overwriting the just-
  /// restored session with that would be a regression, not a reconnect.
  /// No Foundation repository open, or an id that no longer resolves, is
  /// treated exactly like "nothing to reconnect to": the restored graph
  /// is left exactly as loaded — never replaced with an empty/default
  /// graph, never re-committed, and no new Foundation diagram or new
  /// error-reporting mechanism is created for this case (this Notifier
  /// has no `BuildContext` to surface one through, and none of this
  /// package's existing seams reach here).
  Future<void> _reconnectToFoundationDiagram(EngineHost host, EngineeringGraph graph) async {
    final diagramId = graph.diagramRepositoryId;
    if (diagramId == null || diagramId.isEmpty) return;
    final bridge = host.engine.registry.foundationBridge;
    if (bridge == null) return;
    try {
      await bridge.loadCommittedGraph(diagramId);
    } catch (_) {
      // No repository open, or `diagramId` no longer resolves in it —
      // preserve the restored graph exactly as loaded (see doc comment).
    }
  }

  Future<void> saveDocument() async {
    final session = state.session;
    if (session == null) return;
    await state.document.save(session.graph, session.layout);
    state = state.copyWith();
  }

  Future<void> saveDocumentAs(String path) async {
    final session = state.session;
    if (session == null) return;
    await state.document.saveAs(path, session.graph, session.layout);
    state = state.copyWith();
  }

  /// AP-OEP-DIAGRAM-REPOSITORY-001 — persists [graph] (the graph a
  /// Foundation Repository commit just updated with `repositoryObjectId`/
  /// `repositoryRelationshipId`/`diagramRepositoryId`, already applied
  /// onto the live session by the caller via `EditingService.
  /// applyExternalGraphUpdate`) through the same existing save path
  /// [saveDocument] uses — but only when the document already has a
  /// path: a commit must never implicitly trigger a first-time "Save As"
  /// the user never asked for. An unsaved document's committed
  /// identities still live on the in-memory session and will be written
  /// out whenever the user does save/save-as, same as any other edit.
  ///
  /// Takes [graph] explicitly rather than reading `state.session.graph`
  /// (as [saveDocument] does): `applyExternalGraphUpdate` delivers onto
  /// `EditingService.sessionChanges`, a broadcast stream whose listener
  /// (subscribed in [ensureEngineStarted]) updates `state.session`
  /// asynchronously — reading `state.session` here, in the same
  /// synchronous continuation the caller applied that update in, could
  /// still observe the pre-commit graph. `session.layout` has no such
  /// race (`applyExternalGraphUpdate` never touches layout), so it's
  /// still read from `state.session` as usual.
  Future<void> persistCommittedGraph(EngineeringGraph graph) async {
    final session = state.session;
    if (session == null || state.document.path == null) return;
    await state.document.save(graph, session.layout);
    state = state.copyWith();
  }

  Future<void> closeDocument() async {
    final host = await ensureEngineStarted();
    state.document.close();
    host.engine.beginEditingSession(EngineeringGraph.empty(host.engine.graph.generateId('graph')));
    _applyNewDocumentViewStateDefaults(host);
    state = state.copyWith();
  }

  void markDocumentDirty() {
    if (!state.document.isDirty) {
      state.document.markDirty();
      state = state.copyWith();
    }
  }

  /// Forces a fresh validation pass over the current graph. Validation
  /// already recomputes automatically on every session change (see the
  /// `sessionChanges` listener in [ensureEngineStarted]) — this exists
  /// only so a "Revalidate" button has something concrete to call,
  /// matching the affordance's pre-WORK_PACKAGE_025 behavior.
  void revalidate() {
    final host = state.engineHost;
    final session = state.session;
    if (host == null || session == null) return;
    state = state.copyWith(validationReport: host.engine.validate(session.graph));
  }

  // --- Recent history (ENGINE-TASK-000119) ---------------------------------

  void recordHistory(RecentHistoryEntry entry) {
    final updated = [entry, ...state.recentHistory].take(_maxRecentHistory).toList();
    state = state.copyWith(recentHistory: updated);
  }

  // --- Active project (ENGINE-TASK-000118) ---------------------------------

  void setActiveProject(EngineeringProject? project) {
    state = state.copyWith(activeProject: project);
  }
}

final engineeringProjectServiceProvider =
    NotifierProvider<EngineeringProjectNotifier, EngineeringProjectState>(
  EngineeringProjectNotifier.new,
);
