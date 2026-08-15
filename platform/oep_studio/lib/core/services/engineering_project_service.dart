import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../diagram_studio/host/diagram_document.dart';
import '../../diagram_studio/host/engine_host.dart';
import '../../diagram_studio/settings/diagram_studio_settings_provider.dart';
import '../models/engineering_project.dart';
import '../models/recent_history_entry.dart';

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

    final host = await EngineHost.create();
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
