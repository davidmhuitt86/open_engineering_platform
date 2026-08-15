import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/context/contextual_command_definitions.dart';
import '../../core/context/contextual_command_resolver.dart';
import '../../core/context/engineering_interaction_context.dart';
import '../../core/context/engineering_interaction_context_builder.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/models/engineering_inspectable.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../../shared/widgets/dockable_panel.dart';
import '../../shared/widgets/panel_dock_slot.dart';
import '../context_menu/diagram_context_menu.dart';
import '../controller/diagram_studio_controller.dart';
import '../host/diagram_document.dart';
import '../intelligence/diagram_intelligence_service.dart';
import '../panels/diagram_annotation_panel.dart';
import '../panels/diagram_explorer_panel.dart';
import '../panels/diagram_intelligence_overlay.dart';
import '../panels/diagram_layer_panel.dart';
import '../panels/diagram_mini_map.dart';
import '../panels/diagram_recent_commands_panel.dart';
import '../panels/diagram_search_panel.dart';
import '../panels/engineering_explorer_panel.dart';
import '../panels/knowledge_graph_panel.dart';
import '../panels/knowledge_sessions_panel.dart';
import '../panels/query_console_panel.dart';
import '../panels/recommendation_panel.dart';
import '../persistence/diagram_workspace_state.dart';
import '../persistence/workspace_state_storage.dart';
import '../publishing/publishing_center_dialog.dart';
import '../repository/diagram_repository_service.dart';
import '../instruments/core/engineering_instrument.dart';
import '../instruments/dock/instrument_dock.dart';
import '../instruments/dock/instrument_dock_controller.dart';
import '../instruments/multimeter/digital_multimeter_panel.dart';
import '../instruments/multimeter/multimeter_controller.dart';
import '../instruments/probe/probe_overlay.dart';
import '../simulation/diagram_simulation_service.dart';
import '../simulation/simulation_center_dialog.dart';
import '../simulation/simulation_state_overlay.dart';
import '../tabs/diagram_mode_switcher.dart';
import '../tabs/diagram_tab.dart';
import '../tabs/diagram_tab_bar.dart';
import '../tabs/diagram_tabs_controller.dart';
import '../toolbars/diagram_toolbars.dart';

const double _nodeSize = 100; // DiagramLayout.nodeSize, mirrored for hit-testing.
const double _nodeSpawnStep = 40;
const _diagramFileTypeGroup = XTypeGroup(label: 'Diagram', extensions: ['json']);

/// The Diagram Studio workspace (WORK_PACKAGE_024, ENGINE-TASK-000108) —
/// the production diagram-editing experience, registered as a Studio
/// workspace exactly like Knowledge Studio (same Navigation Rail,
/// Connection Manager, theme, window layout via `StudioShell`).
///
/// As of WORK_PACKAGE_025 (ENGINE-TASK-000118), this page no longer
/// *owns* the Engine instance — it *reads* it from the shared
/// `engineeringProjectServiceProvider`, which outlives this page's own
/// mount/unmount so Validation, Search, and Project Explorer can reach
/// the same live engine/session/selection/validation report. Every
/// editing/selection/routing/search/validation call is still a direct
/// call into the Engineering Engine's public API — this page only
/// orchestrates Studio-side chrome (toolbars, panels, Property
/// Inspector bridging) plus its own view-local gesture state (drag
/// deltas, box-select rect, panel widths), per "Studio orchestrates,
/// Engine executes."
class DiagramStudioPage extends ConsumerStatefulWidget {
  const DiagramStudioPage({super.key});

  @override
  ConsumerState<DiagramStudioPage> createState() => _DiagramStudioPageState();
}

class _DiagramStudioPageState extends ConsumerState<DiagramStudioPage> {
  /// The sole gateway to `engine.editing.execute` for this page (WAVE 1,
  /// AP-DIAGRAM-W1) — every mutating interaction handler below calls
  /// through this instead of the Engine directly. See
  /// `controller/diagram_studio_controller.dart`'s own doc comment for the
  /// governing boundary contract.
  DiagramStudioController? _controller;

  /// Test-only accessor (WAVE 1, AP-DIAGRAM-W1) — lets widget tests
  /// exercise `DiagramStudioController` directly against the same live
  /// engine instance this page uses, without depending on `_controller`'s
  /// privacy. No non-test code should read this.
  @visibleForTesting
  DiagramStudioController? get controllerForTest => _controller;

  final TransformationController _transformController = TransformationController();

  bool _loading = true;
  int _spawnCounter = 0;

  bool _showLayerPanel = true;
  bool _showSearchPanel = true;
  // OEP Diagram Studio -- Phase 6, Part 4/21: these three were
  // previously always rendered unconditionally (no toggle existed at
  // all) -- real clutter contributors in View mode. Now toggleable
  // like Layers/Search above, and all five default to hidden the
  // moment the active tab enters View mode (see `_applyModeDefaults`).
  bool _showObjectExplorerPanel = true;
  bool _showAnnotationsPanel = true;
  bool _showRecentCommandsPanel = true;

  // OEP Diagram Studio -- Phase 14 (UI Layout Ratification): bottom-left
  // category-color Legend, off by default (matches every other
  // toggleable panel's honest default, and the reference tool's own
  // toggle-driven `#legend`).
  bool _showLegendPanel = false;

  // (User-requested: "need to be...able to be toggle[d] on and off."
  // Defaults on -- the Minimap was always shown before this toggle
  // existed.) Also user-requested: the Minimap is the one panel that
  // stays a small, borderless, fixed-size floating overlay pinned to
  // the canvas's own bottom-right corner -- never a `DockablePanel`
  // (it must never take up more space than its own natural size the
  // way a dock slot, sized to fit the largest panel assigned to it,
  // could force it to).
  bool _showMiniMap = true;

  // OEP Diagram Studio -- Phase 14 (UI Layout Ratification): which tab
  // of the new, always-visible left Inspector/Meter sidebar is active
  // (modeled on `legacy_wiring_sim_v2`'s own permanent two-tab sidebar,
  // not one of the existing toggleable panels above).
  _ImmersiveSidebarTab _immersiveSidebarTab = _ImmersiveSidebarTab.inspector;

  // (User-requested: dockable panels -- "they shouldn't have ever been
  // able to free float. they just need a permanent place to sit in the
  // window with the ability to move that panel to another place as
  // well as resize.") Which [PanelDockSlot] each [DockablePanel]
  // currently occupies, by a stable per-panel id -- held here (not
  // inside `DockablePanel` itself) for the same reason `_explorerWidth`
  // etc. live here: a panel's slot must survive its own `if (visible)
  // ...` wrapper unmounting it. Runtime-only -- not yet persisted to
  // the document.
  // (Minimap is deliberately absent -- user-requested, it's the one
  // panel that stays a small, fixed-size floating overlay rather than
  // a dock-slot member; see `_showMiniMap`'s own doc comment.)
  final Map<String, PanelDockSlot> _panelSlot = {
    'inspector': PanelDockSlot.left,
    'key_states': PanelDockSlot.top,
    'legend': PanelDockSlot.bottom,
  };

  // One shared thickness per slot (every panel docked in the same slot
  // stacks within that one resizable band), matching how every other
  // fixed-dock panel on this page already sizes itself (`_explorerWidth`,
  // `_sidePanelsWidth`).
  final Map<PanelDockSlot, double> _slotSize = {
    PanelDockSlot.left: 260,
    PanelDockSlot.right: 240,
    PanelDockSlot.top: 96,
    PanelDockSlot.bottom: 160,
  };

  void _movePanel(String id, PanelDockSlot slot) => setState(() => _panelSlot[id] = slot);

  void _resizeSlot(PanelDockSlot slot, double delta) {
    setState(() {
      final current = _slotSize[slot] ?? 200;
      _slotSize[slot] = (current + delta).clamp(80, 640);
    });
  }

  // OEP Diagram Studio -- Phase 14: the last port a plain click (not a
  // connection-drag) actually landed on -- real, port-specific Inspector
  // detail (id/name/direction/connected wires) needs to know WHICH port
  // was clicked, not just which node it belongs to (a whole-node
  // selection alone can't distinguish "clicked the OIL pin" from
  // "clicked the REV pin" on the same component). Cleared by any other
  // selection-changing interaction so it never shows stale port detail
  // for a target that's no longer selected.
  PortReference? _lastPortTap;

  // OEP Diagram Studio -- Phase 14: the domain-profile source Phase 9
  // deferred (Part 22/9's own "no production domain-profile source"
  // finding). Runtime-only, page-local -- reloaded per app launch, same
  // scope as the rest of this page's session-local state. `null` is the
  // honest default: most diagrams have no profile, and the KEY/SWITCHES
  // row (see `_KeySwitchesRow`) correctly shows nothing rather than a
  // fabricated default until one is loaded.
  DomainProfile? _domainProfile;

  Future<void> _loadDomainProfile() async {
    final file = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'Operating Profile', extensions: ['json'])]);
    if (file == null) return;
    try {
      final raw = await file.readAsString();
      final profile = DomainProfile.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
      setState(() => _domainProfile = profile);
      // (Key States panel, user-requested: works in all 3 modes.) A
      // `SimulationSession` is what actually carries operating/input
      // state -- `SimulationEngine.setOperatingState`/`setInputState`
      // both require one (oep_engine's own session-management API,
      // mode-agnostic; the engine has no concept of View/Edit/Simulate
      // at all). Previously a session only ever came from the Simulate
      // toolbar's own "Start simulation" button, so the Key States row
      // -- gated to Simulate mode -- always had one by the time it
      // rendered. Making the row visible in View/Edit too means it
      // needs a live session immediately, not only once the user
      // separately presses Start in Simulate mode.
      if (_simulationService.hasSession) {
        await _simulationService.deleteSession(_simulationService.currentSession!.id);
      }
      await _simulationService.createSession(
        _session!.graph,
        availableOperatingStates: profile.operatingStates,
        availableInputStates: profile.inputStates,
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded operating profile "${profile.name}" (${profile.operatingStates.length} states, ${profile.inputStates.length} inputs).')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load operating profile: $error')));
      }
    }
  }

  // --- AP-DS-003: Engineering Intelligence Workspace ----------------------
  //
  // `DiagramIntelligenceService` is the ONLY point of contact with the
  // Engineering Intelligence Platform (see that class's own doc comment)
  // -- constructed once per open document alongside the engine/session
  // bootstrap below, disposed in `dispose()`. `null` until `_bootstrap`
  // finds a live `FoundationBridge` (mirrors every other Foundation-backed
  // feature in this file, which likewise tolerates a bridge that hasn't
  // started yet).
  DiagramIntelligenceService? _intelligence;
  ({OepWorkflowResult result, List<String> objectIds})? _validationOutcome;
  ({OepWorkflowResult result, List<String> objectIds})? _analysisOutcome;
  bool _showRecommendationPanel = false;
  bool _showEngineeringExplorerPanel = false;
  bool _showKnowledgeGraphPanel = false;
  bool _showQueryConsolePanel = false;
  bool _showSessionsPanel = false;

  // AP-DS-005: Engineering Verification & Simulation. `DiagramSimulationService`
  // is the sole point of contact with the Simulation Engine (see that
  // class's own doc comment) -- lazily created against the same
  // `EngineeringEngine.registry.simulationEngine` every other
  // `EngineRegistry`-provided capability in this file already reaches
  // through `engine.registry.*` (e.g. `engine.registry.selection`), never
  // a separately constructed `SimulationEngine` instance. Overlay state
  // is cached locally (never recomputed synchronously in `build()`) and
  // refreshed via `_refreshSimulationOverlay` whenever
  // `SimulationCenterDialog` reports a session-state change.
  // OEP Context & Capability Service -- Phase 2: `DiagramSimulationService`
  // and `MultimeterController` are no longer constructed or owned by
  // this page -- both now live behind `diagramSimulationServiceProvider`/
  // `multimeterRuntimeServiceProvider` (`diagram_simulation_service.dart`/
  // `multimeter_controller.dart`), so the Context & Capability Bridge
  // can reach the same authoritative runtime instances this page uses.
  // `ref.read` (not `watch`): every consumer below
  // (`DigitalMultimeterInstrument`/`AnimatedBuilder`, this page's own
  // overlay refresh) already listens to the `ChangeNotifier` directly:
  // watching the provider here too would additionally rebuild this
  // entire page on every `notifyListeners()` call (each measurement,
  // each probe placement) -- a real behavioral change this phase's own
  // "no visual UI refactor" boundary rules out. Both getters are safe
  // to call unconditionally only after `ensureEngineStarted()` has
  // completed (see `_bootstrap`), exactly like the `engine` getter
  // above.
  DiagramSimulationService get _simulationService => ref.read(diagramSimulationServiceProvider)!;
  bool _showSimulationOverlay = false;
  SimulationStateSnapshot? _simSnapshot;
  VerificationReport? _simVerification;
  Set<String> _simFaultNodeIds = const {};

  // WP-DS-005A: Engineering Instruments Framework + Digital Multimeter.
  // `_instruments`/`_dockController` are created once in `initState`
  // because the dock's persisted layout must load asynchronously
  // before first paint of the dock. `_multimeter` itself now comes from
  // the shared provider above, not a page-owned field. Slot `null`
  // means "not currently arming a probe for click-to-place"; set by the
  // Multimeter's probe-arm buttons (see `_ProbeArmToolbar`).
  InstrumentRegistry? _instruments;
  InstrumentDockController? _dockController;
  MultimeterController? get _multimeter => ref.read(multimeterRuntimeServiceProvider);
  ProbeSlot? _armedProbeSlot;

  Future<void> _initInstruments() async {
    final multimeter = _multimeter!;
    final registry = InstrumentRegistry()
      ..register(DigitalMultimeterInstrument(
        controller: multimeter,
        verificationReport: () => _simVerification,
      ));
    final dock = await InstrumentDockController.load();
    if (!mounted) return;
    setState(() {
      _instruments = registry;
      _dockController = dock;
    });
  }

  Future<void> _refreshSimulationOverlay() async {
    final simulation = ref.read(diagramSimulationServiceProvider);
    if (simulation == null || !simulation.hasSession) {
      if (mounted) {
        setState(() {
          _simSnapshot = null;
          _simVerification = null;
          _simFaultNodeIds = const {};
          _showSimulationOverlay = false;
        });
      }
      return;
    }
    final snapshot = simulation.currentSession!.state;
    final verification = await simulation.verify();
    final faults = simulation.currentSession!.activeFaults.active;
    final faultNodeIds = <String>{
      for (final fault in faults)
        if (!fault.isRelationship) fault.targetId,
    };
    if (!mounted) return;
    setState(() {
      _simSnapshot = snapshot;
      _simVerification = verification;
      _simFaultNodeIds = faultNodeIds;
      _showSimulationOverlay = true;
    });
  }

  void _openSimulationCenter() {
    unawaited(SimulationCenterDialog.show(
      context,
      simulation: _simulationService,
      graph: _session!.graph,
      onSelectNode: _selectAndFrameNode,
      onSessionStateChanged: () => unawaited(_refreshSimulationOverlay()),
    ).then((_) => _refreshSimulationOverlay()));
  }

  Rect2D? _boxSelectRect;
  Offset? _boxSelectStart;
  Point2D? _panStartPan;

  Set<String>? _dragNodeIds;
  Map<String, Point2D>? _dragStartPositions;
  Point2D _dragTotalDelta = const Point2D(0, 0);
  List<AlignmentGuide> _activeGuides = const [];

  // --- Resize (AP-DS-001A item 4) ---
  String? _resizingNodeId;
  ResizeHandleKind? _resizeHandle;
  Point2D? _resizeStartPosition;
  Size2D? _resizeStartSize;
  Point2D _resizeTotalDelta = const Point2D(0, 0);

  Point2D? _cursorScenePosition;

  PortReference? _connectFromPort;
  Point2D? _connectionCurrentPoint;
  bool _connectionValid = false;

  String? _reconnectRelationshipId;
  bool _reconnectIsSourceEnd = false;
  Point2D? _reconnectCurrentPoint;

  double _explorerWidth = 220;
  double _sidePanelsWidth = 300;

  /// A build-time snapshot of the shared provider's document
  /// path/ViewState, refreshed on every `build()` — `dispose()` uses
  /// these instead of the `ref.read`-based getters above, since Riverpod
  /// marks a `ConsumerStatefulElement` disposed before delegating to
  /// this widget's own `dispose()`, making `ref.read` unusable there
  /// (same constraint documented on `_foundationNotifier`).
  String? _cachedDocumentPath;
  ViewState _cachedViewState = ViewState.initial;

  String? _draggingAnnotationId;
  Point2D? _annotationDragStartPosition;
  Point2D _annotationDragTotalDelta = const Point2D(0, 0);

  bool _wireEditModeActive = false;
  List<Point2D>? _wireEditWorkingPoints;
  int? _wireEditSelectedVertex;
  int? _wireDragCornerIndex;

  // OEP Diagram Studio -- Phase 14 (UI Layout Ratification), § 5: "Wire"
  // was one of the six persistent Edit-mode controls the ratified spec
  // calls for, but had no visible affordance at all -- creating a wire
  // was only possible via an undiscoverable click-drag directly from
  // one port to another. This adds a real, explicit two-click
  // alternative (click a port to start, click a second port to finish)
  // -- reuses the exact same `_connectFromPort`/`ConnectionValidator`/
  // `CreateRelationshipCommand` machinery the drag path already uses,
  // never a second connection mechanism.
  bool _wireCreateModeActive = false;
  int? _wireDragSegmentIndex;
  List<Point2D>? _wireDragBasePoints;
  Point2D _wireDragTotalDelta = const Point2D(0, 0);

  /// Captured once (in [initState]) rather than via `ref.read` inside
  /// [dispose] — Riverpod's `ConsumerStatefulElement` marks itself
  /// disposed before delegating to the framework's own `dispose()`
  /// call, so `ref.read`/`ref.watch` throw `StateError` if used there.
  late final FoundationRuntimeNotifier _foundationNotifier;

  /// This page's own listener on the shared engine's selection stream
  /// (a broadcast stream — `EngineeringProjectNotifier` has its own,
  /// independent listener on the same stream, see
  /// `engineering_project_service.dart`). Exists only to trigger two
  /// page-local reactions that aren't part of the shared project state
  /// itself: re-seeding "Edit Route" mode's working points, and pushing
  /// the newly-selected item into the shared Property Inspector
  /// (ENGINE-TASK-000110/000122).
  StreamSubscription<GraphSelection>? _selectionSub;

  /// AP-DS-001A item 2: makes `ViewState` the single authoritative source
  /// for zoom/pan, instead of the `Matrix4`/`ViewState` dual source of
  /// truth that previously only reconciled one direction (transform ->
  /// ViewState, and only at `onInteractionEnd`). Chosen as the smaller,
  /// safer fix over rewriting `InteractiveViewer`'s pan/zoom handling:
  /// this listener mirrors every `ViewState` zoom/pan change — Fit All,
  /// Fit Selection, Center Selection, View Reset, Go Back/Forward, and
  /// the background space-drag pan (which previously updated
  /// `ViewState.pan` but never touched the `TransformationController`,
  /// so the canvas silently failed to move) — into
  /// `_transformController.value`. The existing transform -> ViewState
  /// direction (`_syncViewStateFromTransform`, on `onInteractionEnd`)
  /// stays as-is for live pinch/scroll-zoom gestures, which mutate the
  /// controller directly through `InteractiveViewer`'s own built-in
  /// handling; letting that continue to reconcile only at gesture-end
  /// (rather than every frame) avoids fighting the gesture recognizer
  /// mid-pinch. Round-trips exactly with `_syncViewStateFromTransform`:
  /// `translate(pan)..scale(zoom)` puts `pan` in the matrix's
  /// translation column and `zoom` as its uniform scale, which is
  /// exactly what `getTranslation()`/`getMaxScaleOnAxis()` read back.
  StreamSubscription<ViewState>? _viewStateSub;

  /// The current snapshot of the shared, longer-lived Engineering
  /// Project state (WORK_PACKAGE_025), reached via the Controller (WAVE
  /// 2, AP-DIAGRAM-W2) rather than a direct `ref.read` on the provider —
  /// every getter below reflects the live engine even though this page
  /// no longer owns it, but this page no longer talks to that provider
  /// directly either. `build()` separately calls `ref.watch` once so the
  /// page rebuilds when this state changes.
  EngineeringEngine get engine => _controller!.engine;
  DiagramDocument get _document => _controller!.document;
  EditingSession? get _session => _controller!.session;
  GraphSelection get _selection => _controller!.selection;
  ViewState get _viewState => _controller!.viewState;
  bool get _isDirty => _controller!.isDirty;

  /// (OEP Diagram Studio -- Phase 6, Part 21/29 -- "MODE DETERMINES
  /// WHAT IS VISIBLE".) Applied whenever the active tab's mode is
  /// established or changes. View mode collapses every secondary panel
  /// this file renders unconditionally-by-default -- Object Explorer,
  /// Layers, Search, Annotations, Recent Commands -- to a deliberately
  /// sparse workspace (Part 21's own explicit acceptance criterion);
  /// each remains individually toggleable via `PanelsToolbar`/
  /// `LayersToolbar`/`SearchToolbar`, so the user can still open any of
  /// them on purpose. Edit/Simulate both restore the exact defaults
  /// this file already used before Phase 6 -- neither mode's panel
  /// behavior is redesigned here (Part 26).
  /// (OEP Diagram Studio -- Phase 6, Part 21.) Whether the right-hand
  /// secondary-panel column has anything to show at all -- when every
  /// individual panel is toggled off (View mode's own default), the
  /// column itself (and its resize handle) are omitted entirely rather
  /// than rendering as an empty strip, keeping the diagram genuinely
  /// dominant.
  bool get _anySidePanelVisible =>
      _showLayerPanel ||
      _showSearchPanel ||
      _showAnnotationsPanel ||
      _showRecentCommandsPanel ||
      (_intelligence != null &&
          (_showRecommendationPanel ||
              _showEngineeringExplorerPanel ||
              _showKnowledgeGraphPanel ||
              _showQueryConsolePanel ||
              (_showSessionsPanel && _foundationNotifier.bridge != null)));

  void _applyModeDefaults(DiagramStudioMode mode) {
    final visible = mode != DiagramStudioMode.view;
    setState(() {
      _showObjectExplorerPanel = visible;
      _showLayerPanel = visible;
      _showSearchPanel = visible;
      _showAnnotationsPanel = visible;
      _showRecentCommandsPanel = visible;
    });
  }

  @override
  void initState() {
    super.initState();
    _foundationNotifier = ref.read(foundationRuntimeServiceProvider.notifier);
    unawaited(_bootstrap());
  }

  /// (WAVE 2, AP-DIAGRAM-W2 Step 3.) Engine startup, project/tab/document
  /// restoration, and Controller construction all now live behind
  /// `DiagramStudioController.bootstrap` — same steps, same order, moved
  /// verbatim (see that method's own doc comment). What remains here is
  /// what genuinely cannot move: `initState`/`unawaited` are Flutter
  /// lifecycle hooks only a `State` can provide, and everything below
  /// this point in `_bootstrap` either constructs Flutter-owned
  /// resources (`InstrumentDockController`, the selection/ViewState
  /// subscriptions feeding `setState`/`TransformationController`) or
  /// applies this page's own UI-only fields from the loaded workspace
  /// state (panel visibility/widths — this controller has no business
  /// owning those).
  Future<void> _bootstrap() async {
    final (controller, workspace) = await DiagramStudioController.bootstrap(ref: ref);
    _controller = controller;
    // WP-DS-005A: instruments must be reachable as soon as the diagram
    // itself is (see governing spec: "shall remain available regardless
    // of editing, verification, simulation, or inspection mode"), so this
    // is initialized here rather than deferred to a later toggle.
    unawaited(_initInstruments());

    // AP-DS-003 item 6: one `DiagramIntelligenceService` per open
    // document, sharing the same `FoundationBridge` the ambient
    // repository badge/other Foundation-backed panels already read via
    // `foundationRuntimeServiceProvider`. A `null` bridge (Foundation
    // Runtime not started) leaves `_intelligence` null -- every trigger
    // below already guards on that, matching this file's existing
    // "feature silently unavailable until its dependency is ready"
    // convention.
    final bridge = _foundationNotifier.bridge;
    if (bridge != null) {
      _intelligence = DiagramIntelligenceService(bridge: bridge, repository: DiagramRepositoryService(bridge));
      // WAVE 1: hands the Controller the same reference this page's own
      // `_validateNow`/`_analyzeSelectedNode`/widget bindings already use
      // -- lifecycle (construction/disposal) stays page-owned; the
      // Controller only needs it to drive the debounced sync it now
      // centralizes (see the controller's own doc comment).
      _controller!.intelligence = _intelligence;
    }

    // Panel visibility/width are Flutter-presentation fields the
    // Controller's `bootstrap` deliberately does not touch -- applied
    // here from the same loaded `DiagramWorkspaceState` it returned.
    _showLayerPanel = workspace.showLayerPanel;
    _showSearchPanel = workspace.showSearchPanel;
    _explorerWidth = workspace.explorerWidth;
    _sidePanelsWidth = workspace.sidePanelsWidth;

    // Applies the correct panel-visibility defaults for whichever mode
    // the active tab actually starts in (its own persisted mode, if
    // restored).
    _applyModeDefaults(ref.read(diagramTabsProvider).activeTab?.mode ?? DiagramStudioMode.edit);

    _selectionSub = engine.registry.selection.changes.listen((s) {
      if (_wireEditModeActive) _reseedWireEditPoints();
      _syncPropertyInspectorSelection();
    });
    _viewStateSub = _viewStateService.changes.listen(_applyTransformFromViewState);
    // Establishes the transform's initial position immediately, rather
    // than waiting for the first ViewState change.
    _applyTransformFromViewState(_viewState);
    // On a revisit, whatever the Property Inspector was last showing
    // (from another workspace visited in between) may not match this
    // page's own already-live selection — sync it once immediately.
    _syncPropertyInspectorSelection();

    setState(() => _loading = false);
  }

  /// [useCached] must be `true` from [dispose] — the ternaries below
  /// only evaluate one branch, so this is the one safe way to avoid the
  /// `_document`/`_viewState` getters (which need a live Controller)
  /// ever running there. A nullable "override" parameter defaulting via
  /// `??` would NOT be safe here: a brand-new unsaved document's cached
  /// path is legitimately `null`, which `??` cannot distinguish from "no
  /// override provided."
  Future<void> _persistWorkspaceState({bool useCached = false}) {
    final documentPath = useCached ? _cachedDocumentPath : _document.path;
    final viewState = useCached ? _cachedViewState : _viewState;
    return _controller!.persistWorkspaceState(DiagramWorkspaceState(
      lastDocumentPath: documentPath,
      showLayerPanel: _showLayerPanel,
      showSearchPanel: _showSearchPanel,
      explorerWidth: _explorerWidth,
      sidePanelsWidth: _sidePanelsWidth,
      viewState: viewState,
    ));
  }

  @override
  void dispose() {
    // The Engine now outlives this page (WORK_PACKAGE_025,
    // ENGINE-TASK-000118) — `engineeringProjectServiceProvider` itself
    // disposes the engine, only when the provider is torn down, not
    // when this page unmounts. Uses the cached (not `ref.read`-based)
    // document path/ViewState — see [_persistWorkspaceState]'s doc
    // comment for why.
    unawaited(_persistWorkspaceState(useCached: true));
    _selectionSub?.cancel();
    _viewStateSub?.cancel();
    _intelligence?.dispose();
    // `_multimeter` is no longer page-owned (see the getter's own doc
    // comment) -- its shared provider is `.autoDispose` and tears it
    // down (cancelling its live-mode timer) once nothing references it
    // anymore, exactly like `engineeringProjectServiceProvider` already
    // owns the Engine's own disposal independent of this page's
    // lifecycle.
    _instruments?.dispose();
    _dockController?.dispose();
    // The Instrument Bridge is now app-wide (`instrumentBridgeServiceProvider`,
    // controlled from Settings > Diagram Studio), not owned by this page --
    // it must keep running across a page unmount/remount, so it is
    // deliberately NOT stopped here.
    // Deferred: Riverpod forbids mutating a provider's state while the
    // widget tree is still finalizing, which this `dispose()` can run
    // during (e.g. a GoRouter navigation away from this page). The
    // clear itself is safe to run a microtask later — the provider
    // this notifier backs outlives this one page.
    final foundationNotifier = _foundationNotifier;
    scheduleMicrotask(foundationNotifier.clearEngineeringInspectableSelection);
    super.dispose();
  }

  // --- Property Inspector bridge (ENGINE-TASK-000110) -------------------

  void _syncPropertyInspectorSelection() {
    final notifier = _foundationNotifier;
    final session = _session;
    if (session == null || _selection.length != 1) {
      notifier.clearEngineeringInspectableSelection();
      return;
    }
    if (_selection.nodeIds.isNotEmpty) {
      final node = session.graph.nodes[_selection.nodeIds.first];
      if (node != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.node(node));
        return;
      }
    }
    if (_selection.relationshipIds.isNotEmpty) {
      final relationship = session.graph.relationships[_selection.relationshipIds.first];
      if (relationship != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.relationship(relationship));
        return;
      }
    }
    if (_selection.groupIds.isNotEmpty) {
      final group = session.graph.groups[_selection.groupIds.first];
      if (group != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.group(group));
        return;
      }
    }
    if (_selection.annotationIds.isNotEmpty) {
      final annotation = session.layout.annotationOf(_selection.annotationIds.first);
      if (annotation != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.annotation(annotation));
        return;
      }
    }
    notifier.clearEngineeringInspectableSelection();
  }

  void _selectLayerInInspector(DiagramLayer layer) {
    _foundationNotifier.selectEngineeringInspectable(EngineeringInspectable.layer(layer));
  }

  // --- Document (Open/Save/Save As/Close/Dirty State — ENGINE-TASK-000111)

  // WAVE 1 (AP-DIAGRAM-W1): dirty-marking and the debounced Intelligence
  // sync it triggers are now centralized in `DiagramStudioController`
  // (`_controller!.markDirty()`) -- every one of this page's former ~30
  // `_markDirty()` call sites was moved there alongside the
  // `engine.editing.execute` call it accompanied. `_reactToExternalEdit`
  // below is the one remaining page-local caller: contextual commands
  // (`_openContextualMenu`) execute through a separate, core-owned
  // command system (`core/context/contextual_command_definitions.dart`),
  // not through this page's own handlers, so the page still has to react
  // afterward -- but it now does so through the same centralized
  // Controller pathway instead of a page-local `_markDirty()`.
  void _reactToExternalEdit() => _controller!.markDirty();

  // --- AP-DS-003 item 4: Live Validation trigger wiring --------------------
  //
  // "Automatic validation after edits": every mutating Engine Command now
  // funnels through `DiagramStudioController.markDirty()`, which owns the
  // debounced Foundation sync itself (WAVE 1 -- moved verbatim from this
  // page's former `_scheduleIntelligenceSync()`; see the controller's own
  // doc comment). Nothing in this page schedules it directly any more.

  /// "Manual validation" (spec): bypasses [DiagramIntelligenceService]'s
  /// debounce with an immediate [DiagramIntelligenceService.sync] (so the
  /// diagram is guaranteed fresh even if edits just happened) followed by
  /// an immediate [DiagramIntelligenceService.validate].
  Future<void> _validateNow() async {
    final intelligence = _intelligence;
    final session = _session;
    if (intelligence == null || session == null) return;
    await intelligence.sync(
      title: _document.path ?? 'Untitled Diagram',
      graph: session.graph,
      layout: session.layout,
    );
    final outcome = await intelligence.validate();
    if (!mounted) return;
    setState(() => _validationOutcome = outcome);
  }

  /// Live Analysis (item 2) for the single selected node — no-op when
  /// zero or multiple nodes are selected (Analysis is inherently a
  /// single-object operation, per [DiagramIntelligenceService.analyzeNode]).
  Future<void> _analyzeSelectedNode() async {
    final intelligence = _intelligence;
    if (intelligence == null || _selection.nodeIds.length != 1) return;
    final nodeId = _selection.nodeIds.single;
    try {
      final outcome = await intelligence.analyzeNode(nodeId);
      if (!mounted) return;
      setState(() => _analysisOutcome = outcome);
    } on ArgumentError {
      // Node hasn't synced to the repository yet (added since the last
      // debounced sync) — sync now and retry once, rather than leaving
      // the user with a silently-ignored button press.
      await intelligence.sync(
        title: _document.path ?? 'Untitled Diagram',
        graph: _session!.graph,
        layout: _session!.layout,
      );
      final outcome = await intelligence.analyzeNode(nodeId);
      if (!mounted) return;
      setState(() => _analysisOutcome = outcome);
    }
  }

  /// Item 3 (Selection synchronization): the shared select+frame action
  /// every Intelligence panel's `onSelectNode` callback, and every canvas
  /// validation/analysis overlay's click-to-inspect, drives — same
  /// select-then-center pattern as [_goToSearchResult]'s node case,
  /// generalized to a bare node id.
  void _selectAndFrameNode(String nodeId) {
    engine.registry.selection.selectNode(nodeId);
    final position = _session!.layout.positionOf(nodeId);
    if (position != null) {
      _viewStateService.centerSelection(Rect2D(
        left: position.dx,
        top: position.dy,
        right: position.dx + _nodeSize,
        bottom: position.dy + _nodeSize,
      ));
    }
  }

  String? get _singleSelectedNodeId => _selection.nodeIds.length == 1 ? _selection.nodeIds.single : null;

  /// Validation Overlay marker set — canvas node ids translated from the
  /// last [_validationOutcome]'s Foundation object ids via
  /// [DiagramIntelligenceService.nodeIdFor]; an id that isn't a
  /// decomposed diagram node (the Diagram object itself, etc.) is simply
  /// not markable on the canvas and is dropped here.
  Set<String> get _validationMarkerNodeIds {
    final intelligence = _intelligence;
    final outcome = _validationOutcome;
    if (intelligence == null || outcome == null) return const {};
    return outcome.objectIds.map(intelligence.nodeIdFor).whereType<String>().toSet();
  }

  /// Analysis Overlay highlight set — same translation, for the last
  /// [_analysisOutcome].
  Set<String> get _analysisHighlightNodeIds {
    final intelligence = _intelligence;
    final outcome = _analysisOutcome;
    if (intelligence == null || outcome == null) return const {};
    return outcome.objectIds.map(intelligence.nodeIdFor).whereType<String>().toSet();
  }

  // WAVE 2 (AP-DIAGRAM-W2 Steps 6-7): every method below still owns the
  // one thing that must stay page-side -- the discard-confirmation
  // dialog, which needs a `BuildContext` that must never cross into the
  // Controller (spec §3.4) -- and now delegates the confirmed sequencing
  // of Engine/tab calls that follows to `DiagramStudioController`,
  // exactly matching each method's own original body. See
  // `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` for the full
  // classification.

  Future<void> _newDocument() async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    await _controller!.newDocument();
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text('This diagram has unsaved changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openDocument() async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    final file = await openFile(acceptedTypeGroups: [_diagramFileTypeGroup]);
    if (file == null) return;
    await _controller!.openDocument(file.path);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _saveDocument() async {
    if (_document.path == null) {
      await _saveAsDocument();
      return;
    }
    await _controller!.saveDocument();
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _saveAsDocument() async {
    final location = await getSaveLocation(acceptedTypeGroups: [_diagramFileTypeGroup], suggestedName: 'diagram.json');
    if (location == null) return;
    await _controller!.saveDocumentAs(location.path);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _closeDocument() async {
    final activeId = _controller!.activeTabId;
    if (activeId != null) {
      await _closeTab(activeId);
      return;
    }
    if (_isDirty && !await _confirmDiscardChanges()) return;
    await _controller!.closeDocument();
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  /// (OEP Diagram Studio -- Phase 5, Part 15.) Closes tab [id] --
  /// preserves the existing unsaved-change confirmation exactly as
  /// before tabs existed, only for the tab actually being closed
  /// (closing a *background* tab, whose content the single shared
  /// engine isn't currently holding, has nothing live to lose). If the
  /// closed tab was active, the newly-active tab's real document (if
  /// any) is reloaded through the same existing `openDocument`/
  /// `newDocument` pipeline -- never a second document model.
  Future<void> _closeTab(String id) async {
    final wasActive = _controller!.isActiveTab(id);
    if (wasActive && _isDirty && !await _confirmDiscardChanges()) return;
    await _controller!.closeTab(id, wasActive: wasActive);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  /// (OEP Diagram Studio -- Phase 5, Part 2/Part 20.) Switches the
  /// active tab -- since the single shared engine can only hold one
  /// document's content at a time (see `DiagramTab`'s own doc comment),
  /// switching away from a dirty tab uses the exact same
  /// discard-confirmation the existing New/Open/Close actions already
  /// use, then reloads the target tab's real document.
  Future<void> _activateTab(String id) async {
    if (_controller!.isActiveTab(id)) return;
    if (_isDirty && !await _confirmDiscardChanges()) return;
    final mode = await _controller!.activateTab(id);
    if (mode == null) return;
    // Panel visibility reflects the newly-active tab's OWN mode (Part
    // 20's "each open diagram remembers its current mode" applies to
    // the panels that mode controls too).
    _applyModeDefaults(mode);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  /// (OEP Diagram Studio -- Phase 5, Part 13.) Reopens a document from
  /// Recently Closed -- opens it through the exact same `openDocument`
  /// pipeline every other open path uses, then removes it from history.
  Future<void> _reopenRecentlyClosed(DiagramTab entry) async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    await _controller!.reopenRecentlyClosed(entry);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  /// (OEP Diagram Studio -- Phase 5, Part 13.) A lightweight Recently
  /// Closed surface -- reuses the same `showMenu` convention
  /// `diagram_context_menu.dart` already established rather than
  /// building a new history-browser component. Stays entirely page-side
  /// -- `context.findRenderObject()`/`showMenu` are `BuildContext`-bound
  /// UI, not application logic.
  Future<void> _showRecentlyClosedMenu(BuildContext context) async {
    final recentlyClosed = ref.read(diagramTabsProvider).recentlyClosed;
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset(renderBox.size.width - 40, 40));
    final selected = await showMenu<DiagramTab>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: recentlyClosed.isEmpty
          ? [const PopupMenuItem<DiagramTab>(enabled: false, child: Text('No recently closed diagrams'))]
          : [for (final entry in recentlyClosed) PopupMenuItem<DiagramTab>(value: entry, child: Text(entry.title))],
    );
    if (selected != null) await _reopenRecentlyClosed(selected);
  }

  // --- ViewState / viewport ---------------------------------------------

  ViewStateService get _viewStateService => engine.registry.viewState as ViewStateService;

  void _applyTransformFromViewState(ViewState state) {
    if (!mounted) return;
    final matrix = Matrix4.identity()
      ..translateByDouble(state.pan.dx, state.pan.dy, 0, 1)
      ..scaleByDouble(state.zoom, state.zoom, state.zoom, 1);
    if (_transformController.value != matrix) {
      _transformController.value = matrix;
    }
  }

  void _syncViewStateFromTransform() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    _viewStateService
      ..setZoom(scale)
      ..setPan(Point2D(translation.x, translation.y));
  }

  void _ensureViewportSize(double width, double height) {
    if (_viewState.viewportWidth == width && _viewState.viewportHeight == height) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewStateService.setViewportSize(width, height);
    });
  }

  Rect2D? _selectionBounds(DiagramScene scene) {
    final selected = scene.nodes.where((n) => _selection.containsNode(n.nodeId)).toList();
    if (selected.isEmpty) return null;
    var left = selected.first.position.dx;
    var top = selected.first.position.dy;
    var right = left + selected.first.width;
    var bottom = top + selected.first.height;
    for (final node in selected.skip(1)) {
      left = left < node.position.dx ? left : node.position.dx;
      top = top < node.position.dy ? top : node.position.dy;
      right = right > node.position.dx + node.width ? right : node.position.dx + node.width;
      bottom = bottom > node.position.dy + node.height ? bottom : node.position.dy + node.height;
    }
    return Rect2D(left: left, top: top, right: right, bottom: bottom);
  }

  void _fitAll(DiagramScene scene) => _viewStateService.fitAll(scene.contentWidth, scene.contentHeight);

  void _fitSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.fitSelection(bounds);
  }

  void _centerSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.centerSelection(bounds);
  }

  /// "View reset" (AP-DS-001A Canvas section) — public so a toolbar
  /// button (owned by the parallel toolbars/panels work) can call it;
  /// also reachable today via the Ctrl+0 shortcut registered in [build].
  void resetView() => _viewStateService.resetView();

  // --- Editing actions ----------------------------------------------------

  // WAVE 1 (AP-DIAGRAM-W1): every method in this section is now a thin
  // delegation to `DiagramStudioController` -- kept under their original
  // names (called elsewhere in this file, including from `build()`'s
  // toolbar/shortcut wiring, which is unchanged) so no other call site in
  // this page needed to move. Presentation-local computation that isn't
  // itself an Engine command (spawn-position bookkeeping) stays here; the
  // command construction/execution/selection/dirty-marking it used to do
  // directly now lives in the controller, verbatim.

  void _addNode(String symbolId) {
    _spawnCounter++;
    final position = Point2D(
      40 + (_spawnCounter % 6) * _nodeSpawnStep,
      40 + (_spawnCounter ~/ 6) * _nodeSpawnStep,
    );
    _controller!.addNode(symbolId, position);
  }

  void _deleteSelection() => _controller!.deleteSelection();

  void _groupSelection() => _controller!.groupSelection();

  void _ungroupSelection() => _controller!.ungroupSelection();

  void _undo() => _controller!.undo();

  void _redo() => _controller!.redo();

  void _copy() => _controller!.copy();

  void _cut() => _controller!.cut();

  Future<void> _paste() => _controller!.paste();

  void _duplicateSelection() => _controller!.duplicateSelection();

  // --- Selection interaction ----------------------------------------------

  bool get _additiveModifierPressed =>
      HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;
  bool get _toggleModifierPressed => HardwareKeyboard.instance.isControlPressed;
  bool get _spacePressed => HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);

  void _handleNodeTap(String nodeId) {
    // WP-DS-005A Probe System "click-to-place": when a probe is armed
    // (Multimeter panel's Probe A/B arm buttons), a node tap places that
    // probe instead of changing selection, reusing this exact handler's
    // own hit-testing rather than a second one on the canvas.
    final armedSlot = _armedProbeSlot;
    if (armedSlot != null && _multimeter != null) {
      ProbeOverlay.placeByNodeTap(_multimeter!, armedSlot, nodeId);
      setState(() => _armedProbeSlot = null);
      return;
    }
    setState(() => _lastPortTap = null);
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleNode(nodeId);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectNode(nodeId, additive: true);
    } else {
      engine.registry.selection.selectNode(nodeId);
    }
  }

  void _handleBackgroundTap(Offset localPosition, DiagramScene scene) {
    setState(() => _lastPortTap = null);
    if (_connectFromPort != null) {
      setState(() {
        _connectFromPort = null;
        _connectionCurrentPoint = null;
        _connectionValid = false;
      });
      return;
    }
    final relationshipId = DiagramHitTesting.relationshipAt(scene, offsetToPoint(localPosition));
    if (relationshipId != null) {
      if (_toggleModifierPressed) {
        engine.registry.selection.toggleRelationship(relationshipId);
      } else {
        engine.registry.selection.selectRelationship(relationshipId);
      }
      return;
    }
    if (!_additiveModifierPressed) engine.registry.selection.deselectAll();
  }

  /// The Diagram Studio right-click contextual menu (OEP Context &
  /// Capability Service — Phase 3): builds a real target-aware
  /// [CursorTarget] independent of the current left-click [_selection]
  /// (Contract spec § 7's own explicit reason this type exists), then
  /// hands off entirely to [EngineeringInteractionContextBuilder]/
  /// [ContextualCommandResolver] -- this method does not itself decide
  /// what is applicable, only what the user pointed at.
  ///
  /// Target detection reuses the same hit-testing already used for
  /// left-click (`_nodeAt`, `DiagramHitTesting.relationshipAt`) --
  /// **documented gap**: port- and annotation-at-point hit-testing has
  /// no existing standalone query anywhere in this codebase (ports/
  /// annotations are only ever reached through their own widgets' tap
  /// callbacks, never a page-level "what's at this point" function),
  /// so right-click on a port or annotation is not yet supported --
  /// deferred rather than approximated with new, unproven geometry.
  void _handleSecondaryTap(Offset localPosition, Offset globalPosition, DiagramScene scene) {
    final point = offsetToPoint(localPosition);
    final nodeId = _nodeAt(point);
    final relationshipId = nodeId == null ? DiagramHitTesting.relationshipAt(scene, point) : null;

    final CursorTarget cursorTarget;
    final String contextIdentity;
    if (nodeId != null) {
      final node = _session!.graph.nodes[nodeId];
      cursorTarget = CursorTarget(kind: CursorTargetKind.node, targetId: nodeId);
      contextIdentity = node?.displayName ?? nodeId;
    } else if (relationshipId != null) {
      final relationship = _session!.graph.relationships[relationshipId];
      cursorTarget = CursorTarget(kind: CursorTargetKind.relationship, targetId: relationshipId);
      contextIdentity = relationship == null
          ? relationshipId
          : '${relationship.relationshipType.name}: '
              '${_session!.graph.nodes[relationship.sourceNode]?.displayName ?? relationship.sourceNode} -> '
              '${_session!.graph.nodes[relationship.targetNode]?.displayName ?? relationship.targetNode}';
    } else {
      cursorTarget = const CursorTarget.none();
      contextIdentity = 'Canvas';
    }

    _openContextualMenu(cursorTarget, contextIdentity, globalPosition);
  }

  /// Handles a right-click landing directly on a node's body -- see
  /// `SymbolNodeWidget.onSecondaryTapUp`'s own doc comment for why this
  /// is a separate path from [_handleSecondaryTap]: that widget's own
  /// `GestureDetector` is `HitTestBehavior.opaque` and sits above
  /// `GraphViewPanel`'s background gesture detector in the `Stack`, so a
  /// right-click on a node never reaches the background-only handler.
  void _handleNodeSecondaryTap(String nodeId, Offset globalPosition) {
    final node = _session!.graph.nodes[nodeId];
    _openContextualMenu(
      CursorTarget(kind: CursorTargetKind.node, targetId: nodeId),
      node?.displayName ?? nodeId,
      globalPosition,
    );
  }

  /// Handles a right-click landing directly on a port marker (OEP
  /// Diagram Studio -- Phase 4, Part 4). [port] is the same
  /// [PortReference] (`nodeId`+`portId`) `_handlePortTap`/`_handlePortDragStart`
  /// already receive for left-click/drag -- this is the same real,
  /// already-established owning-node association, not a new lookup.
  void _handlePortSecondaryTap(PortReference port, Offset globalPosition) {
    final node = _session!.graph.nodes[port.nodeId];
    SymbolPort? symbolPort;
    if (node?.symbolId != null) {
      for (final candidate in engine.registry.symbols.resolve(node!.symbolId!).ports) {
        if (candidate.id == port.portId) {
          symbolPort = candidate;
          break;
        }
      }
    }
    final nodeName = node?.displayName ?? port.nodeId;
    final portName = symbolPort?.displayName ?? port.portId;
    _openContextualMenu(
      CursorTarget(kind: CursorTargetKind.port, targetId: port.portId, ownerNodeId: port.nodeId),
      '$nodeName / $portName',
      globalPosition,
    );
  }

  /// Handles a right-click landing directly on an annotation (OEP
  /// Diagram Studio -- Phase 4, Part 6). Reuses `AnnotationWidget`'s own
  /// real, already-rendered hit region (see that widget's own doc
  /// comment on why no separate geometry is computed here).
  void _handleAnnotationSecondaryTap(String annotationId, Offset globalPosition) {
    final annotation = _session!.layout.annotations[annotationId];
    final identity = annotation == null || annotation.text.isEmpty
        ? (annotation?.type.name ?? annotationId)
        : annotation.text;
    _openContextualMenu(
      CursorTarget(kind: CursorTargetKind.annotation, targetId: annotationId),
      identity,
      globalPosition,
    );
  }

  void _openContextualMenu(CursorTarget cursorTarget, String contextIdentity, Offset globalPosition) {
    // OEP Diagram Studio -- Phase 6: a real bug found while adding
    // View-mode widget tests -- `mode` was added to the context model
    // in Phase 5 but never actually threaded from the active tab into
    // the context this menu builds, so every contextual menu resolved
    // as if the document were always in Edit mode regardless of the
    // real active tab's mode. Fixed here at the one real construction
    // site, not by changing the builder/resolver again.
    EngineeringInteractionContext buildContext() => const EngineeringInteractionContextBuilder().build(
          ref,
          studioId: StudioDestination.diagram.path,
          route: StudioDestination.diagram.path,
          cursorTarget: cursorTarget,
          mode: ref.read(diagramTabsProvider).activeTab?.mode ?? DiagramStudioMode.edit,
        );

    final resolver = ContextualCommandResolver(commands: initialContextualCommands);
    final menu = resolver.buildMenu(buildContext(), title: contextIdentity, contextIdentity: contextIdentity);

    unawaited(() async {
      await showDiagramContextMenu(
        context: context,
        globalPosition: globalPosition,
        menu: menu,
        resolver: resolver,
        currentContext: buildContext,
      );
      // Contextual commands can now perform real document edits
      // (`diagram.port.addLabel`, `diagram.object.delete`,
      // `diagram.annotate.add` -- see `contextual_command_definitions.dart`),
      // executed straight against the shared engine rather than through
      // this page's own handlers, so the page has to re-render and mark
      // the document dirty afterward the same way its own edit paths do.
      if (!mounted) return;
      setState(() {});
      _reactToExternalEdit();
    }());
  }

  void _handleBackgroundPanStart(Offset localPosition) {
    if (_spacePressed) {
      _panStartPan = _viewState.pan;
      return;
    }
    _boxSelectStart = localPosition;
    setState(() => _boxSelectRect =
        Rect2D.fromPoints(offsetToPoint(localPosition), offsetToPoint(localPosition)));
  }

  void _handleBackgroundPanUpdate(Offset localPosition, Offset delta) {
    if (_panStartPan != null) {
      _viewStateService.setPan(_viewState.pan.translate(
        delta.dx * _viewState.zoom,
        delta.dy * _viewState.zoom,
      ));
      return;
    }
    final start = _boxSelectStart;
    if (start == null) return;
    setState(() => _boxSelectRect = rectFromOffsets(start, localPosition));
  }

  void _handleBackgroundPanEnd(DiagramScene scene) {
    if (_panStartPan != null) {
      _panStartPan = null;
      return;
    }
    final rect = _boxSelectRect;
    if (rect != null) {
      final ids = DiagramHitTesting.nodesInRect(scene, rect);
      if (ids.isNotEmpty) {
        engine.registry.selection.selectMany(nodeIds: ids, additive: _additiveModifierPressed);
      }
    }
    setState(() {
      _boxSelectRect = null;
      _boxSelectStart = null;
    });
  }

  void _handleHover(Offset localPosition) {
    _cursorScenePosition = offsetToPoint(localPosition);
    // Phase 14 § 5: the Wire-mode two-click flow has no drag gesture to
    // drive `_handlePortDragUpdate`'s own live preview update, so the
    // connection-preview line needs to follow the cursor here instead,
    // between the first and second click.
    if (_wireCreateModeActive && _connectFromPort != null) {
      setState(() => _connectionCurrentPoint = _cursorScenePosition);
      return;
    }
    if (_connectFromPort != null || _reconnectRelationshipId != null) return;
    setState(() {});
  }

  // --- Node dragging + smart guides ---------------------------------------

  /// Sibling node bounds for alignment-guide/snap comparison — every node
  /// not in [excludingNodeIds] with a tracked position. [excludingNodeIds]
  /// is normally the full set of nodes currently being dragged, not just
  /// one, so a multi-node drag doesn't spuriously "guide" against its own
  /// other members.
  List<Rect2D> _siblingBounds(Set<String> excludingNodeIds) {
    final layout = _session!.layout;
    return [
      for (final entry in _session!.graph.nodes.entries)
        if (!excludingNodeIds.contains(entry.key) && layout.positionOf(entry.key) != null)
          Rect2D(
            left: layout.positionOf(entry.key)!.dx,
            top: layout.positionOf(entry.key)!.dy,
            right: layout.positionOf(entry.key)!.dx + _nodeSize,
            bottom: layout.positionOf(entry.key)!.dy + _nodeSize,
          ),
    ];
  }

  /// Combined bounding box of the dragged node(s) at their current drag
  /// offset — used as the single "dragged rectangle" fed to
  /// [AlignmentGuideComputer], extending it from single- to multi-node
  /// drags without touching its algorithm (AP-DS-001A item 1): the whole
  /// selection is treated as one rigid rectangle, guides fire when *that*
  /// rectangle's edges/center line up with a sibling, and the resulting
  /// single snap delta is applied uniformly to every dragged node so
  /// relative spacing within the selection never changes mid-drag.
  Rect2D _draggedGroupBounds(Set<String> nodeIds, Map<String, Point2D> startPositions, Point2D totalDelta) {
    Rect2D? bounds;
    for (final id in nodeIds) {
      final candidate = startPositions[id]!.translate(totalDelta.dx, totalDelta.dy);
      final rect = Rect2D(
        left: candidate.dx,
        top: candidate.dy,
        right: candidate.dx + _nodeSize,
        bottom: candidate.dy + _nodeSize,
      );
      bounds = bounds == null
          ? rect
          : Rect2D(
              left: bounds.left < rect.left ? bounds.left : rect.left,
              top: bounds.top < rect.top ? bounds.top : rect.top,
              right: bounds.right > rect.right ? bounds.right : rect.right,
              bottom: bounds.bottom > rect.bottom ? bounds.bottom : rect.bottom,
            );
    }
    return bounds!;
  }

  void _handleNodeDragStart(String nodeId) {
    final current = _session;
    if (current == null) return;
    final targets = (_selection.nodeIds.contains(nodeId) && _selection.nodeIds.length > 1)
        ? _selection.nodeIds
        : {nodeId};
    if (!_selection.nodeIds.contains(nodeId)) engine.registry.selection.selectNode(nodeId);
    setState(() {
      _dragNodeIds = targets;
      _dragStartPositions = {
        for (final id in targets) id: current.layout.positionOf(id) ?? const Point2D(0, 0),
      };
      _dragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleNodeDragUpdate(Offset delta) {
    if (_dragNodeIds == null) return;
    setState(() {
      _dragTotalDelta = _dragTotalDelta.translate(delta.dx, delta.dy);
      if (_viewState.guidesVisible) {
        final groupBounds = _draggedGroupBounds(_dragNodeIds!, _dragStartPositions!, _dragTotalDelta);
        _activeGuides = AlignmentGuideComputer.computeGuides(
          draggedBounds: groupBounds,
          siblingBounds: _siblingBounds(_dragNodeIds!),
        );
      } else {
        _activeGuides = const [];
      }
    });
  }

  /// Snaps the whole dragged selection as one rigid group: computes a
  /// single guide-snap delta from the *combined* bounding box (so every
  /// dragged node moves by the same amount and relative spacing is
  /// preserved — see [_draggedGroupBounds]), then grid-snaps each node's
  /// resulting position independently (grid snap is inherently per-point,
  /// unlike alignment-guide snap which must act on the group as a whole).
  Map<String, Point2D> _snappedDragPositions(Set<String> nodeIds, Map<String, Point2D> startPositions, Point2D totalDelta) {
    var effectiveDelta = totalDelta;
    if (_viewState.guidesVisible) {
      final groupBounds = _draggedGroupBounds(nodeIds, startPositions, totalDelta);
      final snappedTopLeft = AlignmentGuideComputer.snapToGuides(
        candidatePosition: Point2D(groupBounds.left, groupBounds.top),
        width: groupBounds.right - groupBounds.left,
        height: groupBounds.bottom - groupBounds.top,
        siblingBounds: _siblingBounds(nodeIds),
      );
      effectiveDelta = Point2D(
        totalDelta.dx + (snappedTopLeft.dx - groupBounds.left),
        totalDelta.dy + (snappedTopLeft.dy - groupBounds.top),
      );
    }
    return {
      for (final id in nodeIds)
        id: GridComputer.snap(
          startPositions[id]!.translate(effectiveDelta.dx, effectiveDelta.dy),
          _viewState.grid,
        ),
    };
  }

  void _handleNodeDragEnd() {
    final nodeIds = _dragNodeIds;
    final startPositions = _dragStartPositions;
    if (nodeIds == null || startPositions == null) return;
    final newPositions = _snappedDragPositions(nodeIds, startPositions, _dragTotalDelta);
    _controller!.moveNodes(newPositions);
    setState(() {
      _dragNodeIds = null;
      _dragStartPositions = null;
      _dragTotalDelta = const Point2D(0, 0);
      _activeGuides = const [];
    });
  }

  DiagramLayoutState _effectiveLayout() {
    var layout = _session!.layout;
    if (_dragNodeIds != null && _dragStartPositions != null) {
      final preview = _snappedDragPositions(_dragNodeIds!, _dragStartPositions!, _dragTotalDelta);
      layout = layout.withPositions(preview);
    }
    if (_resizingNodeId != null) {
      final preview = _previewResize();
      if (preview != null) {
        layout = layout.withPosition(_resizingNodeId!, preview.$1).withSize(_resizingNodeId!, preview.$2);
      }
    }
    return layout;
  }

  // --- Resize (AP-DS-001A item 4: real resize with corner handles) --------
  //
  // Minimum node size enforced client-side to keep a node hit-testable
  // and its ports meaningfully spaced; mirrors the way wire editing
  // enforces `constraints.minimumWireLength` (see `_handleWireCornerDragUpdate`).
  static const double _minNodeSize = 24;

  void _handleNodeResizeStart(String nodeId, ResizeHandleKind handle) {
    if (!_selection.nodeIds.contains(nodeId) || _selection.nodeIds.length != 1) return;
    final layout = _session!.layout;
    setState(() {
      _resizingNodeId = nodeId;
      _resizeHandle = handle;
      _resizeStartPosition = layout.positionOf(nodeId) ?? DiagramLayout.compute(_session!.graph)[nodeId] ?? const Point2D(0, 0);
      _resizeStartSize = layout.sizeOf(nodeId) ?? const Size2D(_nodeSize, _nodeSize);
      _resizeTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleNodeResizeUpdate(Offset delta) {
    if (_resizingNodeId == null) return;
    setState(() => _resizeTotalDelta = _resizeTotalDelta.translate(delta.dx, delta.dy));
  }

  /// Computes the in-progress (position, size) for the node being
  /// resized, given which corner is being dragged — dragging a "top"/
  /// "left" handle moves the opposite edge to keep it fixed while the
  /// dragged corner tracks the pointer, same convention as most vector
  /// editors' corner-resize.
  (Point2D, Size2D)? _previewResize() {
    final handle = _resizeHandle;
    final startPosition = _resizeStartPosition;
    final startSize = _resizeStartSize;
    if (handle == null || startPosition == null || startSize == null) return null;

    var left = startPosition.dx;
    var top = startPosition.dy;
    var right = startPosition.dx + startSize.width;
    var bottom = startPosition.dy + startSize.height;

    switch (handle) {
      case ResizeHandleKind.topLeft:
        left += _resizeTotalDelta.dx;
        top += _resizeTotalDelta.dy;
      case ResizeHandleKind.topRight:
        right += _resizeTotalDelta.dx;
        top += _resizeTotalDelta.dy;
      case ResizeHandleKind.bottomLeft:
        left += _resizeTotalDelta.dx;
        bottom += _resizeTotalDelta.dy;
      case ResizeHandleKind.bottomRight:
        right += _resizeTotalDelta.dx;
        bottom += _resizeTotalDelta.dy;
    }
    if (right - left < _minNodeSize) {
      if (handle == ResizeHandleKind.topLeft || handle == ResizeHandleKind.bottomLeft) {
        left = right - _minNodeSize;
      } else {
        right = left + _minNodeSize;
      }
    }
    if (bottom - top < _minNodeSize) {
      if (handle == ResizeHandleKind.topLeft || handle == ResizeHandleKind.topRight) {
        top = bottom - _minNodeSize;
      } else {
        bottom = top + _minNodeSize;
      }
    }
    return (Point2D(left, top), Size2D(right - left, bottom - top));
  }

  void _handleNodeResizeEnd() {
    final nodeId = _resizingNodeId;
    final preview = _previewResize();
    if (nodeId != null && preview != null) {
      final (position, size) = preview;
      // top/left-handle drags move the node's top-left too — carried as
      // one atomic command (see `ResizeNodeCommand` doc comment) so a
      // single undo reverts the whole gesture.
      final movedPosition = position == _resizeStartPosition ? null : position;
      _controller!.resizeNode(nodeId, size, newPosition: movedPosition);
    }
    setState(() {
      _resizingNodeId = null;
      _resizeHandle = null;
      _resizeStartPosition = null;
      _resizeStartSize = null;
      _resizeTotalDelta = const Point2D(0, 0);
    });
  }

  // --- Port interaction / drag-to-connect ----------------------------------

  Point2D? _portAnchor(PortReference port) {
    final node = _session!.graph.nodes[port.nodeId];
    final position = _session!.layout.positionOf(port.nodeId);
    if (node == null || position == null) return null;
    // (Phase 14 -- UI Layout Ratification.) Prefers the visual Symbol's
    // own authored port geometry; otherwise falls back to `fallbackPorts`
    // -- the SAME real-port-derived geometry pin rendering
    // (`graph_view_panel.dart`) and wire-endpoint anchoring
    // (`diagram_view.dart`) both use, so a connection-drag starts from
    // exactly where the pin is actually drawn, not the node's center.
    final symbol = engine.registry.symbols.resolve(node.symbolId ?? '');
    final ports = symbol.ports.isNotEmpty ? symbol.ports : fallbackPorts(node.ports, exit: (node.metadata['exit'] as String?) ?? 'down');
    final match = ports.where((p) => p.id == port.portId);
    if (match.isEmpty) return position.translate(_nodeSize / 2, _nodeSize / 2);
    final p = match.first;
    return position.translate(p.x * _nodeSize, p.y * _nodeSize);
  }

  String? _nodeAt(Point2D point) {
    for (final entry in _session!.layout.positions.entries) {
      final within = point.dx >= entry.value.dx &&
          point.dx <= entry.value.dx + _nodeSize &&
          point.dy >= entry.value.dy &&
          point.dy <= entry.value.dy + _nodeSize;
      if (within) return entry.key;
    }
    return null;
  }

  void _handlePortHoverEnter(PortReference port) => _viewStateService.hoverPort(port);
  void _handlePortHoverExit() => _viewStateService.hoverPort(null);

  void _handlePortDragStart(PortReference port) {
    // WP-DS-005A Probe System "click-to-place": when a probe is armed,
    // pressing down on a port places that probe at the specific terminal
    // (e.g. a battery's `positive`/`negative`) instead of starting a wire
    // connection -- mirrors `_handleNodeTap`'s own armed-probe branch.
    // Also handled in `_handlePortTap` below (a plain click never reaches
    // `onPanStart`, which is what triggers this method -- see that
    // method's own doc comment), so an armed probe is placed correctly
    // whichever gesture the user's click happens to register as.
    final armedSlot = _armedProbeSlot;
    if (armedSlot != null && _multimeter != null) {
      ProbeOverlay.placeByPortTap(_multimeter!, armedSlot, port);
      setState(() => _armedProbeSlot = null);
      return;
    }
    setState(() {
      _connectFromPort = port;
      _connectionCurrentPoint = _portAnchor(port);
      _connectionValid = false;
    });
  }

  /// A plain, no-drag click on a port (`GraphViewPanel.onPortTap` ->
  /// `SymbolNodeWidget`'s own `onTapUp`) -- distinct from
  /// [_handlePortDragStart], which only fires once Flutter's pan
  /// recognizer has actually recognized a drag (i.e. the pointer moved
  /// past the touch-slop threshold). A precise click-and-release with
  /// zero movement -- exactly how a user places a probe on a specific
  /// terminal -- never reaches `onPanStart`, so without this handler the
  /// tap fell through to the node's own whole-node tap handler instead
  /// (`_handleNodeTap`), which is why probes always landed on the node's
  /// center regardless of which terminal was clicked.
  void _handlePortTap(PortReference port) {
    final armedSlot = _armedProbeSlot;
    if (armedSlot != null && _multimeter != null) {
      ProbeOverlay.placeByPortTap(_multimeter!, armedSlot, port);
      setState(() => _armedProbeSlot = null);
      return;
    }
    if (_wireCreateModeActive) {
      _handleWireCreateModePortTap(port);
      return;
    }
    _handleNodeTap(port.nodeId);
    setState(() => _lastPortTap = port);
  }

  /// Phase 14 § 5's explicit two-click Wire creation: the first port
  /// tap arms a pending connection (identical starting state to the
  /// drag path, `_handlePortDragStart`); the second tap -- on a
  /// DIFFERENT node -- completes it through the exact same
  /// `ConnectionValidator`/`CreateRelationshipCommand` the drag path
  /// uses. A second tap on the SAME node (can't wire a component to
  /// itself) is ignored, leaving the pending connection armed so the
  /// user can just click the intended target instead.
  void _handleWireCreateModePortTap(PortReference port) {
    final pending = _connectFromPort;
    if (pending == null) {
      setState(() {
        _connectFromPort = port;
        _connectionCurrentPoint = _portAnchor(port);
        _connectionValid = false;
      });
      return;
    }
    if (pending.nodeId == port.nodeId) return;
    if (ConnectionValidator.canConnect(_session!.graph, pending.nodeId, port.nodeId)) {
      _controller!.createRelationship(pending.nodeId, port.nodeId);
    }
    setState(() {
      _connectFromPort = null;
      _connectionCurrentPoint = null;
      _connectionValid = false;
    });
  }

  void _handlePortDragUpdate(Offset delta) {
    if (_connectionCurrentPoint == null) return;
    setState(() {
      _connectionCurrentPoint = _connectionCurrentPoint!.translate(delta.dx, delta.dy);
      final targetNodeId = _nodeAt(_connectionCurrentPoint!);
      _connectionValid = targetNodeId != null &&
          ConnectionValidator.canConnect(_session!.graph, _connectFromPort!.nodeId, targetNodeId);
    });
  }

  void _handlePortDragEnd() {
    final source = _connectFromPort;
    final point = _connectionCurrentPoint;
    if (source != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null &&
          ConnectionValidator.canConnect(_session!.graph, source.nodeId, targetNodeId)) {
        _controller!.createRelationship(source.nodeId, targetNodeId);
      }
    }
    setState(() {
      _connectFromPort = null;
      _connectionCurrentPoint = null;
      _connectionValid = false;
    });
  }

  // --- Drag-to-reconnect ----------------------------------------------------

  DiagramWireVisual? _reconnectingWire(DiagramScene scene) {
    if (_selection.relationshipIds.length != 1) return null;
    final id = _selection.relationshipIds.first;
    for (final wire in scene.wires) {
      if (wire.relationshipId == id) return wire;
    }
    return null;
  }

  void _handleReconnectDragStart(bool isSourceEnd) {
    final relationshipId = _selection.relationshipIds.single;
    final relationship = _session!.graph.relationships[relationshipId]!;
    final anchorNodeId = isSourceEnd ? relationship.sourceNode : relationship.targetNode;
    final position = _session!.layout.positionOf(anchorNodeId) ?? const Point2D(0, 0);
    setState(() {
      _reconnectRelationshipId = relationshipId;
      _reconnectIsSourceEnd = isSourceEnd;
      _reconnectCurrentPoint = position.translate(_nodeSize / 2, _nodeSize / 2);
    });
  }

  void _handleReconnectDragUpdate(Offset delta) {
    if (_reconnectCurrentPoint == null) return;
    setState(() => _reconnectCurrentPoint = _reconnectCurrentPoint!.translate(delta.dx, delta.dy));
  }

  void _handleReconnectDragEnd() {
    final relationshipId = _reconnectRelationshipId;
    final point = _reconnectCurrentPoint;
    if (relationshipId != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null) {
        _controller!.reconnectRelationship(
          relationshipId,
          newSourceNode: _reconnectIsSourceEnd ? targetNodeId : null,
          newTargetNode: _reconnectIsSourceEnd ? null : targetNodeId,
        );
      }
    }
    setState(() {
      _reconnectRelationshipId = null;
      _reconnectCurrentPoint = null;
    });
  }

  // --- Annotations ----------------------------------------------------------

  List<DiagramAnnotation> _effectiveAnnotations() {
    final annotations = _session!.layout.annotations.values.toList();
    final draggingId = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (draggingId == null || start == null) return annotations;
    return [
      for (final a in annotations)
        if (a.id == draggingId)
          a.copyWith(position: start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy))
        else
          a,
    ];
  }

  void _addAnnotation(AnnotationType type) {
    final position = _cursorScenePosition ?? const Point2D(40, 40);
    _controller!.addAnnotation(type, position);
  }

  void _handleAnnotationTap(String id) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleAnnotation(id);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectAnnotation(id, additive: true);
    } else {
      engine.registry.selection.selectAnnotation(id);
    }
  }

  void _handleAnnotationDragStart(String id) {
    final annotation = _session!.layout.annotationOf(id);
    if (annotation == null) return;
    if (!_selection.annotationIds.contains(id)) engine.registry.selection.selectAnnotation(id);
    setState(() {
      _draggingAnnotationId = id;
      _annotationDragStartPosition = annotation.position;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleAnnotationDragUpdate(Offset delta) {
    if (_draggingAnnotationId == null) return;
    setState(() => _annotationDragTotalDelta = _annotationDragTotalDelta.translate(delta.dx, delta.dy));
  }

  void _handleAnnotationDragEnd() {
    final id = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (id == null || start == null) return;
    final newPosition =
        GridComputer.snap(start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy), _viewState.grid);
    _controller!.moveAnnotation(id, newPosition);
    setState(() {
      _draggingAnnotationId = null;
      _annotationDragStartPosition = null;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  Future<void> _editAnnotationText(String id) async {
    final annotation = _session!.layout.annotationOf(id);
    if (annotation == null) return;
    final controller = TextEditingController(text: annotation.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit annotation'),
        content: TextField(controller: controller, autofocus: true, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newText != null) {
      _controller!.updateAnnotationText(id, newText);
    }
  }

  void _deleteAnnotation(String id) => _controller!.deleteAnnotation(id);

  // --- Wire editing / "Edit Route" mode -------------------------------------

  bool get _wireEditActive => _wireEditModeActive && _selection.relationshipIds.length == 1;

  void _reseedWireEditPoints() {
    if (_selection.relationshipIds.length != 1) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    final relationshipId = _selection.relationshipIds.single;
    final scene = engine.diagramView.render(
      _session!.graph,
      layout: _session!.layout,
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
    );
    final matches = scene.wires.where((w) => w.relationshipId == relationshipId).toList();
    if (matches.isEmpty) return;
    setState(() {
      _wireEditWorkingPoints = List.of(matches.first.points);
      _wireEditSelectedVertex = null;
    });
  }

  void _toggleWireEditMode() {
    if (_wireEditModeActive) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    if (_selection.relationshipIds.length != 1) return;
    setState(() => _wireEditModeActive = true);
    _reseedWireEditPoints();
  }

  void _handleWireVertexTap(int index) => setState(() => _wireEditSelectedVertex = index);

  void _insertWireVertex() {
    final points = _wireEditWorkingPoints;
    if (points == null || _selection.relationshipIds.length != 1 || points.length < 2) return;
    final relationshipId = _selection.relationshipIds.single;
    final afterIndex = (_wireEditSelectedVertex ?? 0).clamp(0, points.length - 2);
    final a = points[afterIndex];
    final b = points[afterIndex + 1];
    final midpoint = Point2D((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final updated = WireEditing.insertVertex(points, afterIndex, midpoint);
    _controller!.setWireRoute(relationshipId, updated);
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = afterIndex + 1;
    });
  }

  void _removeWireVertex() {
    final points = _wireEditWorkingPoints;
    final index = _wireEditSelectedVertex;
    if (points == null || index == null || _selection.relationshipIds.length != 1) return;
    final relationshipId = _selection.relationshipIds.single;
    final updated = WireEditing.removeVertex(points, index);
    _controller!.setWireRoute(relationshipId, updated);
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = null;
    });
  }

  void _restoreAutomaticRouting() {
    if (_selection.relationshipIds.length != 1) return;
    final relationshipId = _selection.relationshipIds.single;
    _controller!.setWireRoute(relationshipId, null);
    _reseedWireEditPoints();
  }

  void _handleWireCornerDragStart(int index) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragCornerIndex = index;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireCornerDragUpdate(Offset delta) {
    final index = _wireDragCornerIndex;
    final base = _wireDragBasePoints;
    if (index == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      final candidate = base[index].translate(_wireDragTotalDelta.dx, _wireDragTotalDelta.dy);
      _wireEditWorkingPoints =
          WireEditing.dragCorner(base, index, candidate, minimumWireLength: _viewState.constraints.minimumWireLength);
    });
  }

  void _handleWireCornerDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && _selection.relationshipIds.length == 1) {
      _controller!.setWireRoute(_selection.relationshipIds.single, points);
    }
    setState(() {
      _wireDragCornerIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragStart(int segmentIndex) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragSegmentIndex = segmentIndex;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragUpdate(Offset delta) {
    final segmentIndex = _wireDragSegmentIndex;
    final base = _wireDragBasePoints;
    if (segmentIndex == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      _wireEditWorkingPoints = WireEditing.dragSegment(base, segmentIndex, _wireDragTotalDelta,
          minimumWireLength: _viewState.constraints.minimumWireLength);
    });
  }

  void _handleWireSegmentDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && _selection.relationshipIds.length == 1) {
      _controller!.setWireRoute(_selection.relationshipIds.single, points);
    }
    setState(() {
      _wireDragSegmentIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  // --- Placement tools -------------------------------------------------------

  void _rotateSelection(double degrees) => _controller!.rotateSelection(degrees);

  void _mirrorSelection(MirrorAxis axis) => _controller!.mirrorSelection(axis);

  Future<void> _openArrayPlacement() async {
    if (_selection.nodeIds.isEmpty) return;
    final result = await showArrayPlacementDialog(context);
    if (result == null) return;
    _controller!.arrayPlace(
      countX: result.countX,
      countY: result.countY,
      spacingX: result.spacingX,
      spacingY: result.spacingY,
    );
  }

  void _replaceSymbol(String symbolId) => _controller!.replaceSymbol(symbolId);

  // --- Align / Distribute (AP-DS-001A: existed as `AlignNodesCommand`/
  // `DistributeNodesCommand` in oep_engine with no confirmed UI trigger —
  // these two public methods are that trigger. Named + exposed on
  // `_DiagramStudioPageState` so a toolbar button (owned by the parallel
  // toolbars/panels work) can call `alignSelection`/`distributeSelection`
  // directly; not wired to a button here since toolbar files are out of
  // this agent's scope. -----------------------------------------------

  /// Aligns the current multi-node selection to a common edge/center
  /// (no-op below 2 selected nodes — mirrors `AlignNodesCommand.apply`'s
  /// own no-op guard).
  void alignSelection(AlignmentMode mode) => _controller!.alignSelection(mode);

  /// Evenly distributes the current selection along one axis (no-op
  /// below 3 selected nodes — mirrors `DistributeNodesCommand.apply`'s
  /// own no-op guard).
  void distributeSelection(DistributionAxis axis) => _controller!.distributeSelection(axis);

  // --- Layers ------------------------------------------------------------------

  void _createLayer() => _controller!.createLayer();

  void _deleteLayer(String layerId) => _controller!.deleteLayer(layerId);

  void _toggleLayerVisible(String layerId) => _controller!.toggleLayerVisible(layerId);

  void _toggleLayerLocked(String layerId) => _controller!.toggleLayerLocked(layerId);

  // --- Search --------------------------------------------------------------

  List<SearchResult> _runSearch(String query) => engine.registry.search.search(_session!.graph, _session!.layout, query);

  void _goToSearchResult(SearchResult result) {
    switch (result.kind) {
      case SearchResultKind.node:
        engine.registry.selection.selectNode(result.id);
        final position = _session!.layout.positionOf(result.id);
        if (position != null) {
          _viewStateService.centerSelection(Rect2D(
            left: position.dx,
            top: position.dy,
            right: position.dx + _nodeSize,
            bottom: position.dy + _nodeSize,
          ));
        }
      case SearchResultKind.relationship:
        engine.registry.selection.selectRelationship(result.id);
      case SearchResultKind.annotation:
        engine.registry.selection.selectAnnotation(result.id);
        final annotation = _session!.layout.annotationOf(result.id);
        if (annotation != null) {
          _viewStateService.centerSelection(Rect2D(
            left: annotation.position.dx,
            top: annotation.position.dy,
            right: annotation.position.dx + 40,
            bottom: annotation.position.dy + 20,
          ));
        }
      case SearchResultKind.symbol:
        // A "symbol" search result identifies the *symbol library entry*
        // used by matching nodes, not a single node — the most useful
        // action is selecting every node placed with that symbol (mirrors
        // the node case's select+focus, generalized to a set) and framing
        // them all.
        final nodeIds = {
          for (final node in _session!.graph.nodes.values)
            if (node.symbolId == result.id) node.id,
        };
        if (nodeIds.isEmpty) return;
        engine.registry.selection.selectMany(nodeIds: nodeIds);
        final bounds = _boundsForNodes(nodeIds);
        if (bounds != null) _viewStateService.centerSelection(bounds);
      case SearchResultKind.layer:
        // A "layer" result selects every node/annotation assigned to
        // that layer and reveals it in the Layers panel (mirrors how the
        // Layers panel's own "select layer" already routes into the
        // Property Inspector via `_selectLayerInInspector`).
        final layer = _session!.layout.layerById(result.id);
        if (layer != null) _selectLayerInInspector(layer);
        final entityIds = _session!.layout.entitiesOnLayer(result.id);
        final nodeIds = entityIds.intersection(_session!.graph.nodes.keys.toSet());
        final annotationIds = entityIds.intersection(_session!.layout.annotations.keys.toSet());
        if (nodeIds.isEmpty && annotationIds.isEmpty) return;
        engine.registry.selection.selectMany(nodeIds: nodeIds, annotationIds: annotationIds);
        final bounds = _boundsForNodes(nodeIds);
        if (bounds != null) _viewStateService.centerSelection(bounds);
    }
  }

  /// Combined bounding box of [nodeIds], using each node's tracked (or
  /// resolved fallback) position/size — shared by the multi-node search
  /// result cases above.
  Rect2D? _boundsForNodes(Set<String> nodeIds) {
    if (nodeIds.isEmpty) return null;
    Rect2D? bounds;
    for (final id in nodeIds) {
      final position = _session!.layout.positionOf(id) ?? DiagramLayout.compute(_session!.graph)[id];
      if (position == null) continue;
      final size = _session!.layout.sizeOf(id) ?? const Size2D(_nodeSize, _nodeSize);
      final rect = Rect2D(
        left: position.dx,
        top: position.dy,
        right: position.dx + size.width,
        bottom: position.dy + size.height,
      );
      bounds = bounds == null
          ? rect
          : Rect2D(
              left: bounds.left < rect.left ? bounds.left : rect.left,
              top: bounds.top < rect.top ? bounds.top : rect.top,
              right: bounds.right > rect.right ? bounds.right : rect.right,
              bottom: bounds.bottom > rect.bottom ? bounds.bottom : rect.bottom,
            );
    }
    return bounds;
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Establishes the rebuild subscription — the getters above use
    // `ref.read` (safe from any callback), but `build()` itself needs
    // `ref.watch` so this page rebuilds whenever the shared engine's
    // session/selection/viewState/validation report changes, including
    // changes made from *other* routes now that the engine is shared.
    final watchedProjectState = ref.watch(engineeringProjectServiceProvider);
    _cachedDocumentPath = watchedProjectState.document.path;
    _cachedViewState = watchedProjectState.viewState;
    // OEP Diagram Studio -- Phase 5: rebuild subscription for the tab
    // bar/mode switcher.
    final tabsState = ref.watch(diagramTabsProvider);
    final activeMode = tabsState.activeTab?.mode ?? DiagramStudioMode.edit;

    if (_loading || _session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentGraph = _session!.graph;
    final scene = engine.diagramView.render(
      currentGraph,
      layout: _effectiveLayout(),
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
      selection: _selection,
    );
    final reconnectingWire = _reconnectingWire(scene);
    final symbolChoices = engine.registry.symbols.all.map((s) => s.identifier).toList();

    // (User-requested dockable panels: "they just need a permanent
    // place to sit in the window with the ability to move that panel
    // to another place as well as resize.") Every panel that can be
    // docked to a `PanelDockSlot`, keyed by the same stable id
    // `_panelSlot`/`_slotSize` use -- `panelsInSlot` below groups these
    // by each panel's CURRENT slot when the layout is actually built.
    final showKeyStates = _simulationService.currentSession != null &&
        (_simulationService.currentSession!.availableOperatingStates.isNotEmpty ||
            _simulationService.currentSession!.availableInputStates.isNotEmpty);
    final dockPanels = <String, Widget>{
      'inspector': DockablePanel(
        key: const ValueKey('panel-inspector'),
        title: _immersiveSidebarTab == _ImmersiveSidebarTab.inspector ? 'INSPECTOR' : 'METER',
        icon: Icons.list_alt,
        slot: _panelSlot['inspector']!,
        onSlotChanged: (slot) => _movePanel('inspector', slot),
        child: _ImmersiveInspectorSidebar(
          selection: _selection,
          graph: currentGraph,
          multimeter: _multimeter,
          lastPortTap: _lastPortTap,
          tab: _immersiveSidebarTab,
          onTabChanged: (tab) => setState(() => _immersiveSidebarTab = tab),
        ),
      ),
      // The panel frame itself is gated on real session states, not
      // just `_KeySwitchesRow`'s own internal empty check -- an empty
      // docked "KEY STATES" slot with nothing under it would violate
      // this codebase's own "no fabricated default" discipline just as
      // much as a fabricated value would.
      if (showKeyStates)
        'key_states': DockablePanel(
          key: const ValueKey('panel-key-states'),
          title: 'KEY STATES',
          icon: Icons.bolt,
          slot: _panelSlot['key_states']!,
          onSlotChanged: (slot) => _movePanel('key_states', slot),
          child: _KeySwitchesRow(simulation: _simulationService, onChanged: () => setState(() {})),
        ),
      if (_showLegendPanel)
        'legend': DockablePanel(
          key: const ValueKey('panel-legend'),
          title: 'LEGEND',
          icon: Icons.palette_outlined,
          slot: _panelSlot['legend']!,
          onSlotChanged: (slot) => _movePanel('legend', slot),
          onClose: () => setState(() => _showLegendPanel = false),
          child: _DiagramLegendPanel(categories: currentGraph.nodes.values.map((n) => n.category).toSet()),
        ),
    };
    List<Widget> panelsInSlot(PanelDockSlot slot) => [
          for (final entry in dockPanels.entries)
            if (_panelSlot[entry.key] == slot) entry.value,
        ];

    return Stack(
      children: [
        Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true): _cut,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelection,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveDocument,
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              engine.registry.selection.selectAll(currentGraph, layout: _session!.layout),
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_connectFromPort != null) {
              setState(() {
                _connectFromPort = null;
                _connectionCurrentPoint = null;
                _connectionValid = false;
              });
              return;
            }
            engine.registry.selection.deselectAll();
          },
          const SingleActivator(LogicalKeyboardKey.digit0, control: true): resetView,
          const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
            if (_dockController != null) _dockController!.toggleVisible('digital_multimeter');
          },
        },
        child: Column(
          children: [
            // Phase 14 (UI Layout Ratification) -- the immersive top
            // strip, styled after the `legacy_wiring_sim_v2` reference
            // tool's own two-row `#topbar-wrap` (dark surface, amber
            // bottom border) per explicit user direction to match it
            // closely. STRUCTURE/THEME ONLY this increment -- every
            // control below is the exact same widget/callback that was
            // already here, just regrouped and restyled; no toolbar
            // consolidation or KEY/SWITCHES-state wiring yet (that is
            // the next increment, once this frame is confirmed).
            Container(
              decoration: const BoxDecoration(
                color: _ImmersiveColors.surface0,
                border: Border(bottom: BorderSide(color: _ImmersiveColors.amber, width: 2)),
              ),
              child: Column(
                children: [
                  DiagramTabBar(
                    tabs: tabsState.tabs,
                    activeTabId: tabsState.activeTabId,
                    onSelect: (id) => unawaited(_activateTab(id)),
                    onClose: (id) => unawaited(_closeTab(id)),
                    onTogglePin: (id) => _controller!.togglePin(id),
                    onNewTab: () => unawaited(_newDocument()),
                    recentlyClosedCount: tabsState.recentlyClosed.length,
                    onShowHistory: () => unawaited(_showRecentlyClosedMenu(context)),
                  ),
                  Container(
                    color: _ImmersiveColors.surface1,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        DiagramModeSwitcher(
                          mode: activeMode,
                          onModeChanged: (mode) {
                            final id = tabsState.activeTabId;
                            if (id != null) _controller!.setTabMode(id, mode);
                            _applyModeDefaults(mode);
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DocumentActionsBar(
                            isDirty: _isDirty,
                            onNew: _newDocument,
                            onOpen: _openDocument,
                            onSave: _saveDocument,
                            onSaveAs: _saveAsDocument,
                            onClose: _closeDocument,
                            onPublish: () => PublishingCenterDialog.show(
                              context,
                              diagramKey: _document.path ?? 'untitled',
                              graph: currentGraph,
                              layout: _session!.layout,
                              intelligence: _intelligence,
                            ),
                            onSimulate: _openSimulationCenter,
                            onLoadProfile: _loadDomainProfile,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // (Key States panel now lives as a draggable floating
                  // panel in the canvas `Stack` below -- user-requested
                  // "works in all 3 modes" + "drag any panel anywhere,"
                  // so it's no longer pinned to this Simulate-only top
                  // strip.)
                ],
              ),
            ),
            Container(
              color: _ImmersiveColors.surface0,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              // Kept as `Wrap` (not a horizontal-scrolling single row) --
              // a real regression was caught here: several existing
              // interaction tests tap toolbar buttons directly without
              // scrolling, and a fixed-viewport horizontal scroll pushed
              // late buttons off-screen and unreachable. `Wrap`'s
              // multi-line fallback keeps every control reachable at any
              // width. Consolidating this toolbar into the reference's
              // single dense action row is deferred to the next
              // increment (needs real icon-set reduction, not just a
              // container swap).
              child: Wrap(children: [
                SelectionToolbar(
                  onSelectAll: () => engine.registry.selection.selectAll(currentGraph, layout: _session!.layout),
                  onDeselectAll: () => engine.registry.selection.deselectAll(),
                  // Group/Ungroup are structural edits (Part 17: "Do not
                  // expose Edit commands in View mode") -- Select
                  // All/Deselect stay available everywhere, they only
                  // affect selection, never diagram topology.
                  onGroup: activeMode != DiagramStudioMode.edit || _selection.nodeIds.length < 2 ? null : _groupSelection,
                  onUngroup: activeMode != DiagramStudioMode.edit || _selection.groupIds.isEmpty ? null : _ungroupSelection,
                ),
                // OEP Diagram Studio -- Phase 5, Part 5/Part 6/Part 22:
                // construction/editing tools are Edit-mode-only --
                // MODE DETERMINES WHAT IS VISIBLE. Selection/navigation/
                // view/search/DMM stay available in every mode (View
                // mode's own real purpose per Part 5: "Inspect,
                // Understand, Measure, Investigate").
                if (activeMode == DiagramStudioMode.edit)
                  EditActionsToolbar(
                    onUndo: _controller!.canUndo ? _undo : null,
                    onRedo: _controller!.canRedo ? _redo : null,
                    onCut: _selection.isEmpty ? null : _cut,
                    onCopy: _selection.isEmpty ? null : _copy,
                    onPaste: _controller!.hasClipboardContent ? _paste : null,
                    onDuplicate: _selection.isEmpty ? null : _duplicateSelection,
                    onDelete: _selection.isEmpty ? null : _deleteSelection,
                  ),
                DiagramNavigationToolbar(
                  onFitAll: () => _fitAll(scene),
                  onFitSelection: _selection.nodeIds.isEmpty ? null : () => _fitSelection(scene),
                  onCenterSelection: _selection.nodeIds.isEmpty ? null : () => _centerSelection(scene),
                  onGoBack: _viewStateService.canGoBack ? _viewStateService.goBack : null,
                  onGoForward: _viewStateService.canGoForward ? _viewStateService.goForward : null,
                  onResetView: resetView,
                ),
                if (activeMode == DiagramStudioMode.edit)
                  AlignDistributeToolbar(
                    onAlign: _selection.nodeIds.length < 2 ? null : (mode) => alignSelection(mode),
                    onDistribute: _selection.nodeIds.length < 3 ? null : (axis) => distributeSelection(axis),
                  ),
                if (activeMode == DiagramStudioMode.edit)
                  PlacementToolbar(
                    symbolChoices: symbolChoices,
                    resolveSymbolName: (id) => engine.registry.symbols.resolve(id).name,
                    onAddNode: _addNode,
                    onRotate90: _selection.nodeIds.isEmpty ? null : () => _rotateSelection(90),
                    onRotate180: _selection.nodeIds.isEmpty ? null : () => _rotateSelection(180),
                    onRotateArbitrary: _selection.nodeIds.isEmpty ? null : _rotateSelection,
                    onMirrorHorizontal: _selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.horizontal),
                    onMirrorVertical: _selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.vertical),
                    onArrayPlace: _selection.nodeIds.isEmpty ? null : _openArrayPlacement,
                    onReplaceSymbol: _selection.nodeIds.length == 1 ? _replaceSymbol : null,
                  ),
                if (activeMode == DiagramStudioMode.edit)
                  WireEditingToolbar(
                    wireEditModeActive: _wireEditActive,
                    onToggleWireEditMode: _selection.relationshipIds.length == 1 ? _toggleWireEditMode : null,
                    onInsertVertex: _wireEditActive ? _insertWireVertex : null,
                    onRemoveVertex: _wireEditActive && _wireEditSelectedVertex != null ? _removeWireVertex : null,
                    onRestoreAutomaticRouting: _wireEditActive ? _restoreAutomaticRouting : null,
                    wireCreateModeActive: _wireCreateModeActive,
                    onToggleWireCreateMode: () => setState(() {
                      _wireCreateModeActive = !_wireCreateModeActive;
                      _connectFromPort = null;
                      _connectionCurrentPoint = null;
                      _connectionValid = false;
                    }),
                  ),
                LayersToolbar(
                  onToggleLayerPanel: () {
                    setState(() => _showLayerPanel = !_showLayerPanel);
                    unawaited(_persistWorkspaceState());
                  },
                  onCreateLayer: _createLayer,
                ),
                if (activeMode == DiagramStudioMode.edit) AnnotationsToolbar(onAddAnnotation: _addAnnotation),
                ViewToolbar(
                  viewState: _viewState,
                  onToggleGrid: _viewStateService.toggleGrid,
                  onToggleSnap: _viewStateService.toggleSnap,
                  onToggleGuides: () => _viewStateService.setGuidesVisible(!_viewState.guidesVisible),
                  onOpenGridSettings: () => showGridSettingsDialog(context, _viewStateService),
                  onOpenNamedLayouts: () => showNamedLayoutsDialog(
                    context,
                    layoutProvider: engine.registry.layout,
                    graphId: _session!.graph.id,
                    currentLayout: () => _session!.layout,
                    onLoad: (layout) => _controller!.loadNamedLayout(layout),
                    onReset: () => _controller!.resetLayout(),
                  ),
                ),
                SearchToolbar(onToggleSearchPanel: () {
                  setState(() => _showSearchPanel = !_showSearchPanel);
                  unawaited(_persistWorkspaceState());
                }),
                PanelsToolbar(
                  onToggleObjectExplorer: () => setState(() => _showObjectExplorerPanel = !_showObjectExplorerPanel),
                  onToggleAnnotationsPanel: () => setState(() => _showAnnotationsPanel = !_showAnnotationsPanel),
                  onToggleRecentCommandsPanel: () => setState(() => _showRecentCommandsPanel = !_showRecentCommandsPanel),
                  onToggleLegend: () => setState(() => _showLegendPanel = !_showLegendPanel),
                  onToggleMiniMap: () => setState(() => _showMiniMap = !_showMiniMap),
                ),
                // Editing-drag constraints (orthogonal movement, axis
                // lock) have no meaning outside Edit mode.
                if (activeMode == DiagramStudioMode.edit)
                  ConstraintsToolbar(
                    constraints: _viewState.constraints,
                    onChanged: _viewStateService.setConstraints,
                  ),
                // OEP Diagram Studio -- Phase 8, Part 5/6/34: the
                // compact, immediately-discoverable Simulate-mode
                // runtime control strip. Simulate-only -- has no
                // meaning in View/Edit.
                if (activeMode == DiagramStudioMode.simulate)
                  SimulationControlsToolbar(
                    simulation: _simulationService,
                    graph: currentGraph,
                    onChanged: () => setState(() {}),
                    domainProfile: _domainProfile,
                  ),
                if (_intelligence != null)
                  _IntelligenceToolbar(
                    busy: _intelligence!.busy,
                    onValidateNow: _validateNow,
                    onAnalyzeSelected: _singleSelectedNodeId == null ? null : _analyzeSelectedNode,
                    showRecommendationPanel: _showRecommendationPanel,
                    onToggleRecommendationPanel: () => setState(() => _showRecommendationPanel = !_showRecommendationPanel),
                    showEngineeringExplorerPanel: _showEngineeringExplorerPanel,
                    onToggleEngineeringExplorerPanel: () =>
                        setState(() => _showEngineeringExplorerPanel = !_showEngineeringExplorerPanel),
                    showKnowledgeGraphPanel: _showKnowledgeGraphPanel,
                    onToggleKnowledgeGraphPanel: () => setState(() => _showKnowledgeGraphPanel = !_showKnowledgeGraphPanel),
                    showQueryConsolePanel: _showQueryConsolePanel,
                    onToggleQueryConsolePanel: () => setState(() => _showQueryConsolePanel = !_showQueryConsolePanel),
                    showSessionsPanel: _showSessionsPanel,
                    onToggleSessionsPanel: () => setState(() => _showSessionsPanel = !_showSessionsPanel),
                  ),
                // WP-DS-005A: Instrument Dock toggle + probe arm buttons.
                // A permanent toolbar entry (not gated on `_intelligence`
                // or a simulation session existing) since the governing
                // spec requires instruments "remain available regardless
                // of editing, verification, simulation, or inspection
                // mode."
                if (_instruments != null && _dockController != null && _multimeter != null)
                  _InstrumentToolbar(
                    dockVisible: _dockController!.state.visible,
                    onToggleDock: () => _dockController!.toggleVisible('digital_multimeter'),
                    armedSlot: _armedProbeSlot,
                    onArmProbeA: () => setState(() => _armedProbeSlot = _armedProbeSlot == ProbeSlot.a ? null : ProbeSlot.a),
                    onArmProbeB: () => setState(() => _armedProbeSlot = _armedProbeSlot == ProbeSlot.b ? null : ProbeSlot.b),
                  ),
              ]),
            ),
            Expanded(
              // Dockable panels (user-requested): a permanent-slot
              // layout around the canvas -- TOP/BOTTOM rows and
              // LEFT/RIGHT columns, each one shared, resizable band
              // (`_slotSize`) that every panel currently assigned to it
              // (`_panelSlot`, changed via each `DockablePanel`'s own
              // "Move panel" menu) stacks within. Never a freely
              // positioned overlay.
              child: Column(
                children: [
                  if (panelsInSlot(PanelDockSlot.top).isNotEmpty) ...[
                    SizedBox(
                      height: _slotSize[PanelDockSlot.top],
                      child: Row(children: [for (final panel in panelsInSlot(PanelDockSlot.top)) Expanded(child: panel)]),
                    ),
                    _VerticalResizeHandle(onDrag: (dy) => _resizeSlot(PanelDockSlot.top, dy)),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                  if (panelsInSlot(PanelDockSlot.left).isNotEmpty) ...[
                    SizedBox(
                      width: _slotSize[PanelDockSlot.left],
                      child: Column(children: [for (final panel in panelsInSlot(PanelDockSlot.left)) Expanded(child: panel)]),
                    ),
                    _ResizeHandle(onDrag: (dx) => _resizeSlot(PanelDockSlot.left, dx)),
                  ],
                  if (_showObjectExplorerPanel) ...[
                    SizedBox(
                      width: _explorerWidth,
                      child: KnowledgePanel(
                        title: 'Object Explorer',
                        icon: Icons.account_tree_outlined,
                        child: DiagramExplorerPanel(
                          graph: currentGraph,
                          selection: _selection,
                          onSelectNode: _handleNodeTap,
                        ),
                      ),
                    ),
                    _ResizeHandle(onDrag: (dx) => setState(() => _explorerWidth = (_explorerWidth + dx).clamp(150, 400))),
                  ],
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _ensureViewportSize(constraints.maxWidth, constraints.maxHeight);
                        return Stack(
                          children: [
                            GraphViewPanel(
                          scene: scene,
                          viewState: _viewState,
                          symbols: engine.registry.symbols,
                          guides: _activeGuides,
                          boxSelectRect: _boxSelectRect,
                          transformController: _transformController,
                          connectionPreviewFrom: _connectFromPort == null ? null : _portAnchor(_connectFromPort!),
                          connectionPreviewTo: _connectionCurrentPoint,
                          connectionPreviewValid: _connectionValid,
                          reconnectingWire: reconnectingWire,
                          annotations: _effectiveAnnotations(),
                          selectedAnnotationIds: _selection.annotationIds,
                          onAnnotationTap: _handleAnnotationTap,
                          onAnnotationDragStart: _handleAnnotationDragStart,
                          onAnnotationDragUpdate: _handleAnnotationDragUpdate,
                          onAnnotationDragEnd: _handleAnnotationDragEnd,
                          onAnnotationEditRequested: _editAnnotationText,
                          editingWirePoints: _wireEditActive ? _wireEditWorkingPoints : null,
                          editingWireSelectedVertex: _wireEditSelectedVertex,
                          onWireVertexTap: _handleWireVertexTap,
                          onWireCornerDragStart: _handleWireCornerDragStart,
                          onWireCornerDragUpdate: _handleWireCornerDragUpdate,
                          onWireCornerDragEnd: _handleWireCornerDragEnd,
                          onWireSegmentDragStart: _handleWireSegmentDragStart,
                          onWireSegmentDragUpdate: _handleWireSegmentDragUpdate,
                          onWireSegmentDragEnd: _handleWireSegmentDragEnd,
                          onNodeTap: _handleNodeTap,
                          onNodeDragStart: _handleNodeDragStart,
                          onNodeDragUpdate: _handleNodeDragUpdate,
                          onNodeDragEnd: _handleNodeDragEnd,
                          onBackgroundTap: (position) => _handleBackgroundTap(position, scene),
                          onSecondaryTapUp: (localPosition, globalPosition) =>
                              _handleSecondaryTap(localPosition, globalPosition, scene),
                          onNodeSecondaryTapUp: _handleNodeSecondaryTap,
                          onBackgroundPanStart: _handleBackgroundPanStart,
                          onBackgroundPanUpdate: _handleBackgroundPanUpdate,
                          onBackgroundPanEnd: () => _handleBackgroundPanEnd(scene),
                          onHover: _handleHover,
                          onPortHoverEnter: _handlePortHoverEnter,
                          onPortHoverExit: _handlePortHoverExit,
                          onPortDragStart: _handlePortDragStart,
                          onPortDragUpdate: _handlePortDragUpdate,
                          onPortDragEnd: _handlePortDragEnd,
                          onPortTap: _handlePortTap,
                          onPortSecondaryTapUp: _handlePortSecondaryTap,
                          onAnnotationSecondaryTapUp: _handleAnnotationSecondaryTap,
                          onReconnectDragStart: _handleReconnectDragStart,
                          onReconnectDragUpdate: _handleReconnectDragUpdate,
                          onReconnectDragEnd: _handleReconnectDragEnd,
                          onInteractionEnd: _syncViewStateFromTransform,
                          resizingNodeId: _selection.nodeIds.length == 1 ? _selection.nodeIds.single : null,
                          onNodeResizeStart: _handleNodeResizeStart,
                          onNodeResizeUpdate: _handleNodeResizeUpdate,
                          onNodeResizeEnd: _handleNodeResizeEnd,
                            ),
                            // AP-DS-003 items 1+2: Validation Overlay +
                            // Analysis Overlay -- a pure additive `Stack`
                            // layer positioned with the exact same
                            // pan/zoom transform `GraphViewPanel`'s own
                            // `InteractiveViewer` uses (see that widget's
                            // `_visibleSceneRect` doc comment), never a
                            // modification to `GraphViewPanel` itself
                            // (frozen, oep_engine). Empty sets render
                            // nothing, so this is a no-op until a
                            // Validate/Analyze trigger populates
                            // `_validationOutcome`/`_analysisOutcome`.
                            Positioned.fill(
                              child: DiagramIntelligenceOverlay(
                                layout: _effectiveLayout(),
                                pan: _viewState.pan,
                                zoom: _viewState.zoom,
                                validationNodeIds: _validationMarkerNodeIds,
                                analysisNodeIds: _analysisHighlightNodeIds,
                                validationSummary: _validationOutcome?.result.summary,
                                analysisSummary: _analysisOutcome?.result.summary,
                                onValidationMarkerTap: _selectAndFrameNode,
                              ),
                            ),
                            // AP-DS-005: Simulation State Overlay -- same
                            // additive `Positioned.fill` pattern as
                            // `DiagramIntelligenceOverlay` immediately
                            // above. Renders nothing until a simulation
                            // session exists and `_showSimulationOverlay`
                            // is toggled on (Simulation Center's own
                            // toggle, or the document-bar action opening
                            // it) -- a no-op otherwise, matching this
                            // file's existing "empty state renders
                            // nothing" convention for every optional
                            // overlay layer.
                            if (_showSimulationOverlay)
                              Positioned.fill(
                                child: SimulationStateOverlay(
                                  layout: _effectiveLayout(),
                                  pan: _viewState.pan,
                                  zoom: _viewState.zoom,
                                  snapshot: _simSnapshot,
                                  verification: _simVerification,
                                  activeFaultNodeIds: _simFaultNodeIds,
                                  onNodeTap: _selectAndFrameNode,
                                ),
                              ),
                            // WP-DS-005A Probe System — probe markers plus,
                            // for Continuity Mode, an automatic highlight
                            // of the last measured path (reuses
                            // `SimulationStateOverlay`'s own
                            // `propagationPathNodeIds` rendering, matching
                            // that widget's documented pattern, rather
                            // than a second path-drawing implementation).
                            if (_multimeter != null) ...[
                              if (_multimeter!.latestResult != null)
                                Positioned.fill(
                                  child: SimulationStateOverlay(
                                    layout: _effectiveLayout(),
                                    pan: _viewState.pan,
                                    zoom: _viewState.zoom,
                                    propagationPathNodeIds: _multimeter!.highlightedPathNodeIds,
                                  ),
                                ),
                              Positioned.fill(
                                child: ProbeOverlay(
                                  controller: _multimeter!,
                                  graph: currentGraph,
                                  layout: _effectiveLayout(),
                                  symbols: engine.registry.symbols,
                                  pan: _viewState.pan,
                                  zoom: _viewState.zoom,
                                  active: _armedProbeSlot != null,
                                  nodeSize: _nodeSize,
                                ),
                              ),
                            ],
                            // (Legend / Key States render as
                            // `DockablePanel`s in a permanent window
                            // slot -- see `dockPanels`/`panelsInSlot`
                            // above this method's own `Stack`.)
                            // Mini Map (Phase 3, ODS-C015 § 5 "Minimap
                            // integration") -- user-requested exception
                            // to the dock-slot system: a small,
                            // borderless, FIXED-size (`DiagramMiniMap`'s
                            // own natural 180x120, never stretched by a
                            // dock slot sized for some other panel)
                            // floating overlay pinned to the canvas's
                            // own bottom-right corner, toggleable
                            // on/off, passive/click-through exactly as
                            // before.
                            if (_showMiniMap)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: IgnorePointer(
                                  child: DiagramMiniMap(
                                    scene: scene,
                                    pan: _viewState.pan,
                                    zoom: _viewState.zoom,
                                    viewportWidth: constraints.maxWidth,
                                    viewportHeight: constraints.maxHeight,
                                  ),
                                ),
                              ),
                            // "Coordinate display" (AP-DS-001A Canvas section)
                            // — a minimal status-bar-style label rather than
                            // new panel infrastructure (that's the parallel
                            // toolbars/panels work's territory).
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: StudioColors.surfaceRaised.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: StudioColors.borderSubtle),
                                  ),
                                  child: Text(
                                    _cursorScenePosition == null
                                        ? 'x: —, y: —   ${(_viewState.zoom * 100).round()}%'
                                        : 'x: ${_cursorScenePosition!.dx.toStringAsFixed(0)}, '
                                            'y: ${_cursorScenePosition!.dy.toStringAsFixed(0)}   '
                                            '${(_viewState.zoom * 100).round()}%',
                                    style: const TextStyle(
                                      color: StudioColors.textSecondary,
                                      fontSize: 11,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_anySidePanelVisible) ...[
                  _ResizeHandle(onDrag: (dx) => setState(() => _sidePanelsWidth = (_sidePanelsWidth - dx).clamp(240, 480))),
                  SizedBox(
                    width: _sidePanelsWidth,
                    child: Column(
                      children: [
                        if (_showLayerPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Layers',
                              icon: Icons.layers_outlined,
                              child: DiagramLayerPanel(
                                layers: _session!.layout.layers.values.toList(),
                                onSelectLayer: _selectLayerInInspector,
                                onToggleVisible: _toggleLayerVisible,
                                onToggleLocked: _toggleLayerLocked,
                                onCreateLayer: _createLayer,
                                onDeleteLayer: _deleteLayer,
                              ),
                            ),
                          ),
                        if (_showSearchPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Search',
                              icon: Icons.search,
                              child: DiagramSearchPanel(search: _runSearch, onGoToResult: _goToSearchResult),
                            ),
                          ),
                        // The Validation panel that lived here was removed
                        // (Phase 3, Objective 6): it read the exact same
                        // `ValidationReport` the shared Output Panel's own
                        // "Validation" tab already shows app-wide (see
                        // `output_panel.dart`'s `_ValidationTab`) --
                        // duplicating the shell rather than integrating
                        // with it. "Revalidate" remains reachable from the
                        // Ribbon's `diagram.revalidate` command and the
                        // Analyze toolbar group.
                        if (_showAnnotationsPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Annotations',
                              icon: Icons.sticky_note_2_outlined,
                              child: DiagramAnnotationPanel(
                                annotations: _session!.layout.annotations.values.toList(),
                                selectedAnnotationIds: _selection.annotationIds,
                                onSelectAnnotation: _handleAnnotationTap,
                                onEditAnnotation: _editAnnotationText,
                                onDeleteAnnotation: _deleteAnnotation,
                              ),
                            ),
                          ),
                        if (_showRecentCommandsPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Recent Commands',
                              icon: Icons.history,
                              child: DiagramRecentCommandsPanel(descriptions: engine.editing.recentDescriptions),
                            ),
                          ),
                        // AP-DS-003 item 5: Recommendation / Engineering
                        // Explorer / Knowledge Graph / Query Console /
                        // Knowledge Sessions panels -- same conditional-
                        // `Expanded(KnowledgePanel(...))` toggle pattern
                        // as Layers/Search above, gated on `_intelligence`
                        // being ready (mirrors every other Foundation-
                        // backed feature in this file).
                        if (_intelligence != null && _showRecommendationPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Recommendations',
                              icon: Icons.lightbulb_outline,
                              child: RecommendationPanel(
                                intelligence: _intelligence!,
                                onSelectNode: _selectAndFrameNode,
                                selectedNodeId: _singleSelectedNodeId,
                              ),
                            ),
                          ),
                        if (_intelligence != null && _showEngineeringExplorerPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Engineering Explorer',
                              icon: Icons.travel_explore_outlined,
                              child: EngineeringExplorerPanel(
                                intelligence: _intelligence!,
                                onSelectNode: _selectAndFrameNode,
                                selectedNodeId: _singleSelectedNodeId,
                              ),
                            ),
                          ),
                        if (_intelligence != null && _showKnowledgeGraphPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Knowledge Graph',
                              icon: Icons.hub_outlined,
                              child: KnowledgeGraphPanel(
                                intelligence: _intelligence!,
                                onSelectNode: _selectAndFrameNode,
                                selectedNodeId: _singleSelectedNodeId,
                              ),
                            ),
                          ),
                        if (_intelligence != null && _showQueryConsolePanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Query Console',
                              icon: Icons.terminal,
                              child: QueryConsolePanel(
                                intelligence: _intelligence!,
                                onSelectNode: _selectAndFrameNode,
                                selectedNodeId: _singleSelectedNodeId,
                              ),
                            ),
                          ),
                        if (_intelligence != null && _showSessionsPanel && _foundationNotifier.bridge != null)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Engineering Sessions',
                              icon: Icons.history_edu_outlined,
                              child: KnowledgeSessionsPanel(
                                intelligence: _intelligence!,
                                onSelectNode: _selectAndFrameNode,
                                bridge: _foundationNotifier.bridge!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ],
                  if (panelsInSlot(PanelDockSlot.right).isNotEmpty) ...[
                    _ResizeHandle(onDrag: (dx) => _resizeSlot(PanelDockSlot.right, -dx)),
                    SizedBox(
                      width: _slotSize[PanelDockSlot.right],
                      child: Column(children: [for (final panel in panelsInSlot(PanelDockSlot.right)) Expanded(child: panel)]),
                    ),
                  ],
                      ],
                    ),
                  ),
                  if (panelsInSlot(PanelDockSlot.bottom).isNotEmpty) ...[
                    _VerticalResizeHandle(onDrag: (dy) => _resizeSlot(PanelDockSlot.bottom, -dy)),
                    SizedBox(
                      height: _slotSize[PanelDockSlot.bottom],
                      child: Row(children: [for (final panel in panelsInSlot(PanelDockSlot.bottom)) Expanded(child: panel)]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
        ),
        // WP-DS-005A Instrument Dock — permanent, layered above the whole
        // page (not just the canvas) so it is reachable regardless of
        // which side panels are open, matching the spec's "shall become a
        // permanent subsystem of Diagram Studio."
        if (_instruments != null && _dockController != null)
          InstrumentDock(controller: _dockController!, registry: _instruments!),
      ],
    );
  }
}

/// A slim bar for document identity + Open/Save/Save As/Close/New
/// (WORK_PACKAGE_024, ENGINE-TASK-000111) — not one of the plan's nine
/// editing-toolbar groups, since Repository Integration is a document
/// lifecycle concern, not an editing one.
/// Phase 3, Objective 2: the title this bar used to show is removed --
/// it duplicated the Breadcrumb Bar's own Document-level segment
/// (`studio_breadcrumb_bar.dart`).
///
/// New/Save/Close are **kept**, not moved to the Ribbon, despite
/// `diagram.newDocument`/`diagram.saveDocument`/`diagram.closeDocument`
/// already existing as real Ribbon commands (`command_registry.dart`,
/// surfaced by `studio_ribbon.dart`) -- inspection found those shell-level
/// commands are a thinner implementation than this page's own
/// `_newDocument`/`_saveDocument`/`_closeDocument`: the page's versions
/// additionally run the unsaved-changes confirmation dialog
/// (`_confirmDiscardChanges`) and persist workspace state
/// (`_persistWorkspaceState`), neither of which the Ribbon's thin
/// `EngineeringProjectServiceProvider` calls do. Removing these buttons
/// in favor of the Ribbon would have been a silent functionality
/// regression, not de-duplication -- flagged in this phase's report as
/// a Command Framework gap rather than resolved unilaterally.
/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): color
/// tokens modeled directly on `legacy_wiring_sim_v2`'s own dark-theme
/// CSS custom properties (`css/main.css:6-49`, `--surf-0`/`--surf-1`,
/// `--amber` accent border) -- deliberately a small, standalone token
/// set scoped to Diagram Studio's own immersive chrome, not a change to
/// the shared `StudioColors` every other Studio still uses (Phase 14
/// Section 21: "studio-by-studio," not a shell-wide theme change).
class _ImmersiveColors {
  const _ImmersiveColors._();
  static const Color surface0 = Color(0xFF0A0A0A);
  static const Color surface1 = Color(0xFF171717);
  static const Color amber = Color(0xFFF59E0B);
}

enum _ImmersiveSidebarTab { inspector, meter }

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification), § 4/13: the
/// always-visible, fixed-width left sidebar modeled directly on
/// `legacy_wiring_sim_v2`'s own permanent `#left-sidebar`
/// (Inspector/Meter tabs, `css/main.css:512`) -- distinct from the
/// existing toggleable panels (Object Explorer/Layers/Search/etc.),
/// which remain unchanged this increment. Reads only real, already-live
/// state ([selection]/[graph]/[multimeter]) -- never fabricated field
/// values.
class _ImmersiveInspectorSidebar extends StatelessWidget {
  const _ImmersiveInspectorSidebar({
    required this.selection,
    required this.graph,
    required this.multimeter,
    required this.lastPortTap,
    required this.tab,
    required this.onTabChanged,
  });

  final GraphSelection selection;
  final EngineeringGraph graph;
  final MultimeterController? multimeter;
  final PortReference? lastPortTap;
  final _ImmersiveSidebarTab tab;
  final ValueChanged<_ImmersiveSidebarTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: _ImmersiveColors.surface1,
        border: Border(right: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ImmersiveSidebarTabButton(
                  label: 'INSPECTOR',
                  selected: tab == _ImmersiveSidebarTab.inspector,
                  onTap: () => onTabChanged(_ImmersiveSidebarTab.inspector),
                ),
              ),
              Expanded(
                child: _ImmersiveSidebarTabButton(
                  label: 'METER',
                  selected: tab == _ImmersiveSidebarTab.meter,
                  onTap: () => onTabChanged(_ImmersiveSidebarTab.meter),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: StudioColors.borderSubtle),
          Expanded(
            child: tab == _ImmersiveSidebarTab.inspector
                ? _ImmersiveInspectorPane(selection: selection, graph: graph, lastPortTap: lastPortTap)
                : _ImmersiveMeterPane(multimeter: multimeter),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveSidebarTabButton extends StatelessWidget {
  const _ImmersiveSidebarTabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? _ImmersiveColors.amber : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: selected ? _ImmersiveColors.amber : StudioColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Wire Inspector / Module Inspector -- shows real detail for exactly
/// one selected relationship or node, sourced directly from [graph]
/// (never a fabricated description/label). A multi-selection or empty
/// selection shows the same honest placeholder
/// `legacy_wiring_sim_v2`'s own Wire Inspector shows before any wire is
/// clicked.
class _ImmersiveInspectorPane extends StatelessWidget {
  const _ImmersiveInspectorPane({required this.selection, required this.graph, this.lastPortTap});

  final GraphSelection selection;
  final EngineeringGraph graph;

  /// (Phase 14.) The specific port a plain click last landed on, if
  /// any -- checked before the whole-node Module Inspector so clicking
  /// a pin shows real detail about THAT pin (id/name/direction/
  /// connected wires), not just generic info about the node it belongs
  /// to. Only honored while it still matches the current single-node
  /// selection (`_handleNodeTap`/background/relationship clicks all
  /// clear it) so it can never show stale port detail for a target
  /// that's no longer selected.
  final PortReference? lastPortTap;

  @override
  Widget build(BuildContext context) {
    if (selection.relationshipIds.length == 1 && selection.nodeIds.isEmpty) {
      final relationship = graph.relationships[selection.relationshipIds.single];
      if (relationship != null) return _wireInspector(relationship);
    }
    if (selection.nodeIds.length == 1 && selection.relationshipIds.isEmpty) {
      final node = graph.nodes[selection.nodeIds.single];
      if (node != null) {
        final port = lastPortTap;
        if (port != null && port.nodeId == node.id) {
          final matchingPort = node.ports.where((p) => p.id == port.portId);
          if (matchingPort.isNotEmpty) return _portInspector(node, matchingPort.first);
        }
        return _moduleInspector(node);
      }
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Click a wire or component\nto inspect it',
          textAlign: TextAlign.center,
          style: TextStyle(color: StudioColors.textDisabled, fontSize: 12),
        ),
      ),
    );
  }

  Widget _wireInspector(EngineeringRelationship relationship) {
    final source = graph.nodes[relationship.sourceNode]?.displayName ?? relationship.sourceNode;
    final target = graph.nodes[relationship.targetNode]?.displayName ?? relationship.targetNode;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('WIRE INSPECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: StudioColors.textDisabled)),
        const SizedBox(height: 10),
        _inspectorField('ID', relationship.id),
        _inspectorField('Type', relationship.relationshipType.name),
        _inspectorField('From', source),
        _inspectorField('To', target),
      ],
    );
  }

  Widget _portInspector(EngineeringNode node, Port port) {
    // (Phase 14.) Port-to-relationship association reuses the exact
    // same `metadata['sourcePort']`/`['targetPort']` convention
    // `StateConditionResolver`'s component/port targeting (Phase 12)
    // and `VerificationEngine`'s connector check already established --
    // never a second, invented port-reference mechanism.
    final connected = graph.relationships.values
        .where((r) => (r.sourceNode == node.id || r.targetNode == node.id) && (r.metadata['sourcePort'] == port.id || r.metadata['targetPort'] == port.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('PORT INSPECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: StudioColors.textDisabled)),
        const SizedBox(height: 10),
        _inspectorField('Pin', port.name),
        _inspectorField('Component', node.displayName),
        _inspectorField('Direction', port.direction.name),
        _inspectorField('Type', port.type),
        const SizedBox(height: 6),
        Text('CONNECTED WIRES (${connected.length})', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: StudioColors.textDisabled)),
        const SizedBox(height: 4),
        if (connected.isEmpty)
          const Text('None', style: TextStyle(fontSize: 12, color: StudioColors.textDisabled))
        else
          for (final relationship in connected)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                (relationship.metadata['label'] as String?) ?? relationship.id,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
              ),
            ),
      ],
    );
  }

  Widget _moduleInspector(EngineeringNode node) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('MODULE INSPECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: StudioColors.textDisabled)),
        const SizedBox(height: 10),
        _inspectorField('Label', node.displayName),
        _inspectorField('Category', node.category.name),
        if (node.ports.isNotEmpty) _inspectorField('Ports', node.ports.map((p) => p.name).join(', ')),
      ],
    );
  }

  Widget _inspectorField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: StudioColors.textDisabled)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Meter tab -- real probe placement + [MultimeterController.latestResult]
/// state, no second/fabricated meter concept. Full instrument
/// interaction (mode selection, lead placement) remains in the existing
/// `InstrumentDock`/`_InstrumentToolbar` this increment; this tab is a
/// compact, always-visible summary alongside it.
class _ImmersiveMeterPane extends StatelessWidget {
  const _ImmersiveMeterPane({required this.multimeter});

  final MultimeterController? multimeter;

  @override
  Widget build(BuildContext context) {
    final meter = multimeter;
    if (meter == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No instrument runtime available yet.', textAlign: TextAlign.center, style: TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
        ),
      );
    }
    return AnimatedBuilder(
      animation: meter,
      builder: (context, _) {
        final result = meter.latestResult;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('METER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: StudioColors.textDisabled)),
            const SizedBox(height: 10),
            Text('Probe +: ${meter.probeA?.nodeId ?? 'not placed'}', style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Probe -: ${meter.probeB?.nodeId ?? 'not placed'}', style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary)),
            const SizedBox(height: 12),
            if (result != null) ...[
              Text(result.type.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: StudioColors.textDisabled)),
              const SizedBox(height: 4),
              Text(
                result.reachable ? '${result.measuredValue ?? '--'} ${result.unit}' : 'OL',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ImmersiveColors.amber),
              ),
            ] else
              const Text('No measurement yet.', style: TextStyle(fontSize: 12, color: StudioColors.textDisabled)),
          ],
        );
      },
    );
  }
}

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): the
/// KEY/SWITCHES row, modeled directly on `legacy_wiring_sim_v2`'s own
/// topbar row (`index.html:21-53`) -- one button group per real
/// `SimulationSession.availableOperatingStates` (KEY, single-select via
/// [DiagramSimulationService.setOperatingState]) plus one group per
/// real `availableInputStates` entry (SWITCHES, via
/// [DiagramSimulationService.setInputState]). Renders nothing at all
/// when the session has no real states -- the same "no fabricated
/// default" discipline every prior state-architecture phase (9-13)
/// established; this is a presentation of that same real session, never
/// a second source of truth.
class _KeySwitchesRow extends StatelessWidget {
  const _KeySwitchesRow({required this.simulation, required this.onChanged});

  final DiagramSimulationService simulation;
  final VoidCallback onChanged;

  /// Picks a recognizable icon from a group's own real label/id --
  /// keyword matching against whatever the domain profile actually
  /// named it (never a hard-coded automotive vocabulary in the engine
  /// layer itself, per Phase 9's "no domain terminology in oep_engine"
  /// rule -- this mapping lives entirely in Studio presentation code).
  /// Falls back to a generic toggle glyph for anything unrecognized, so
  /// an unfamiliar profile still renders sensibly rather than badly.
  static IconData _iconFor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('ignition') || lower.contains('key')) return Icons.bolt;
    if (lower.contains('crank') || lower.contains('start')) return Icons.settings_backup_restore;
    if (lower.contains('headlight') || lower.contains('light') || lower.contains('lamp')) return Icons.wb_incandescent;
    if (lower.contains('fan')) return Icons.air;
    if (lower.contains('fuel') || lower.contains('pump')) return Icons.local_gas_station;
    if (lower.contains('horn')) return Icons.campaign;
    if (lower.contains('wiper')) return Icons.water_drop;
    if (lower.contains('brake')) return Icons.warning_amber;
    if (lower.contains('turn') || lower.contains('signal') || lower.contains('blink') || lower.contains('hazard')) {
      return Icons.turn_right;
    }
    return Icons.toggle_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final session = simulation.currentSession;
    if (session == null || (session.availableOperatingStates.isEmpty && session.availableInputStates.isEmpty)) {
      return const SizedBox.shrink();
    }

    Future<void> run(Future<void> Function() action) async {
      await action();
      onChanged();
    }

    return Container(
      color: _ImmersiveColors.surface1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 8,
        children: [
          if (session.availableOperatingStates.isNotEmpty)
            _KeySwitchGroup(
              // No `overline` here -- the enclosing `DockablePanel`'s
              // own title bar already reads "KEY STATES"; repeating it
              // on the Ignition group specifically would duplicate it.
              label: 'IGNITION',
              icon: _iconFor('ignition'),
              active: session.activeOperatingStateId != null,
              children: [
                for (final state in session.availableOperatingStates)
                  _KeySwitchButton(
                    label: state.name,
                    active: session.activeOperatingStateId == state.id,
                    onTap: () => run(() => simulation.setOperatingState(state.id)),
                  ),
              ],
            ),
          for (final input in session.availableInputStates)
            _KeySwitchGroup(
              label: input.label.toUpperCase(),
              icon: _iconFor(input.label),
              active: input.valueType == InputValueType.boolean
                  ? session.activeInputStates[input.id] == false
                  : session.activeInputStates.containsKey(input.id),
              children: input.valueType == InputValueType.boolean
                  ? [
                      _KeySwitchButton(
                        label: 'OFF',
                        active: session.activeInputStates[input.id] == false,
                        onTap: () => run(() => simulation.setInputState(input.id, false)),
                      ),
                      _KeySwitchButton(
                        label: 'ON',
                        active: session.activeInputStates[input.id] == true,
                        onTap: () => run(() => simulation.setInputState(input.id, true)),
                      ),
                    ]
                  : [
                      for (final position in input.topologyEffects.keys)
                        _KeySwitchButton(
                          label: position,
                          active: session.activeInputStates[input.id]?.toString() == position,
                          onTap: () => run(() => simulation.setInputState(input.id, position)),
                        ),
                    ],
            ),
        ],
      ),
    );
  }
}

/// One KEY STATES group -- an icon (amber when the group's own value
/// reads "off"/inactive, matching the reference screenshot's glowing
/// icon-on-OFF look) above a small caps label, and a row of pill
/// buttons for its real values. No group-level "KEY STATES" overline --
/// the enclosing `DockablePanel`'s own title bar already reads that.
class _KeySwitchGroup extends StatelessWidget {
  const _KeySwitchGroup({
    required this.label,
    required this.icon,
    required this.active,
    required this.children,
  });

  final String label;
  final IconData icon;
  final bool active;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? _ImmersiveColors.amber : StudioColors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: StudioColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(spacing: 4, children: children),
      ],
    );
  }
}

class _KeySwitchButton extends StatelessWidget {
  const _KeySwitchButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _ImmersiveColors.amber : StudioColors.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? _ImmersiveColors.amber : StudioColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.black : StudioColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): the bottom-
/// left category-color Legend, modeled on
/// `legacy_wiring_sim_v2`'s own `#legend`. Uses the exact same
/// [categoryStripeColor] mapping the component cards themselves render
/// with (`SymbolNodeWidget`, oep_engine) -- never a second, independent
/// color table that could drift out of sync with what's actually on
/// canvas.
class _DiagramLegendPanel extends StatelessWidget {
  const _DiagramLegendPanel({required this.categories});

  final Set<NodeCategory> categories;

  @override
  Widget build(BuildContext context) {
    final sorted = categories.toList()..sort((a, b) => a.name.compareTo(b.name));
    // No own title/border/radius here -- this is now the content of a
    // `DockablePanel`, which already supplies a "LEGEND" title bar and
    // the frame (border/rounded corners/shadow) around it; repeating
    // either here would double them up.
    return Container(
      padding: const EdgeInsets.all(10),
      color: StudioColors.surfaceRaised.withValues(alpha: 0.95),
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sorted.isEmpty)
            const Text('No components on canvas.', style: TextStyle(fontSize: 11, color: StudioColors.textDisabled))
          else
            for (final category in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: categoryStripeColor(category), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text(category.name, style: const TextStyle(fontSize: 11, color: StudioColors.textPrimary)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DocumentActionsBar extends StatelessWidget {
  const _DocumentActionsBar({
    required this.isDirty,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onClose,
    required this.onPublish,
    required this.onSimulate,
    required this.onLoadProfile,
  });

  final bool isDirty;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onClose;
  final VoidCallback onPublish;
  final VoidCallback onSimulate;
  final VoidCallback onLoadProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          if (isDirty) ...[
            const Icon(Icons.circle, size: 8, color: StudioColors.warning),
            const SizedBox(width: 6),
            const Text('Unsaved changes', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          ],
          const Spacer(),
          IconButton(iconSize: 15, tooltip: 'New', onPressed: onNew, icon: const Icon(Icons.note_add_outlined)),
          IconButton(iconSize: 15, tooltip: 'Open…', onPressed: onOpen, icon: const Icon(Icons.folder_open_outlined)),
          IconButton(iconSize: 15, tooltip: 'Save (Ctrl+S)', onPressed: onSave, icon: const Icon(Icons.save_outlined)),
          IconButton(iconSize: 15, tooltip: 'Save As…', onPressed: onSaveAs, icon: const Icon(Icons.save_as_outlined)),
          IconButton(
            iconSize: 15,
            tooltip: 'Load Operating Profile…',
            onPressed: onLoadProfile,
            icon: const Icon(Icons.key_outlined),
          ),
          IconButton(iconSize: 15, tooltip: 'Publishing…', onPressed: onPublish, icon: const Icon(Icons.print_outlined)),
          IconButton(
            iconSize: 15,
            tooltip: 'Simulation…',
            onPressed: onSimulate,
            icon: const Icon(Icons.play_circle_outline),
          ),
          IconButton(iconSize: 15, tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

/// A thin draggable divider between side panels — matches the
/// Demonstration Host's own "basic implementation only, do NOT
/// implement a docking framework" precedent (WORK_PACKAGE_022,
/// ENGINE-TASK-000097).
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(width: 6, child: VerticalDivider(width: 6, color: StudioColors.borderSubtle)),
      ),
    );
  }
}

/// Same as [_ResizeHandle], for a TOP/BOTTOM dock slot's height instead
/// of a LEFT/RIGHT slot's width (dockable panels, user-requested).
class _VerticalResizeHandle extends StatelessWidget {
  const _VerticalResizeHandle({required this.onDrag});

  final void Function(double dy) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta.dy),
        child: const SizedBox(height: 6, child: Divider(height: 6, color: StudioColors.borderSubtle)),
      ),
    );
  }
}

/// AP-DS-003 item 4/5: a compact toolbar group for the Engineering
/// Intelligence Workspace — mirrors this file's existing
/// `LayersToolbar`/`SearchToolbar` "one icon-button-row toggling a
/// boolean panel-visibility flag" pattern (see `diagram_toolbars.dart`),
/// kept as a private widget local to this file (like `_DocumentBar`)
/// rather than added to `diagram_toolbars.dart`, since this phase's
/// scope is additive wiring into `diagram_studio_page.dart` specifically.
/// [onValidateNow] is the "Manual validation" trigger (spec); "Automatic
/// validation after edits" happens separately, unconditionally, from
/// every `DiagramStudioController.markDirty()` call — this button exists
/// purely to bypass its debounce on demand.
/// WP-DS-005A toolbar entry: toggles the Instrument Dock and arms a probe
/// for click-to-place. Deliberately small/standalone (not folded into
/// `_IntelligenceToolbar`) — instruments are a permanent subsystem, not
/// part of the Engineering Intelligence Platform toolbar group.
class _InstrumentToolbar extends StatelessWidget {
  const _InstrumentToolbar({
    required this.dockVisible,
    required this.onToggleDock,
    required this.armedSlot,
    required this.onArmProbeA,
    required this.onArmProbeB,
  });

  final bool dockVisible;
  final VoidCallback onToggleDock;
  final ProbeSlot? armedSlot;
  final VoidCallback onArmProbeA;
  final VoidCallback onArmProbeB;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.speed_outlined, color: dockVisible ? StudioColors.selection : StudioColors.textSecondary),
          tooltip: 'Toggle Instrument Dock (Ctrl+M)',
          onPressed: onToggleDock,
        ),
        IconButton(
          icon: Icon(Icons.circle, size: 14, color: armedSlot == ProbeSlot.a ? StudioColors.selection : StudioColors.textPrimary),
          tooltip: 'Arm Probe A (black) — click a node to place',
          onPressed: onArmProbeA,
        ),
        IconButton(
          icon: Icon(Icons.circle, size: 14, color: armedSlot == ProbeSlot.b ? StudioColors.selection : StudioColors.error),
          tooltip: 'Arm Probe B (red) — click a node to place',
          onPressed: onArmProbeB,
        ),
      ],
    );
  }
}

class _IntelligenceToolbar extends StatelessWidget {
  const _IntelligenceToolbar({
    required this.busy,
    required this.onValidateNow,
    required this.onAnalyzeSelected,
    required this.showRecommendationPanel,
    required this.onToggleRecommendationPanel,
    required this.showEngineeringExplorerPanel,
    required this.onToggleEngineeringExplorerPanel,
    required this.showKnowledgeGraphPanel,
    required this.onToggleKnowledgeGraphPanel,
    required this.showQueryConsolePanel,
    required this.onToggleQueryConsolePanel,
    required this.showSessionsPanel,
    required this.onToggleSessionsPanel,
  });

  final bool busy;
  final VoidCallback onValidateNow;
  final VoidCallback? onAnalyzeSelected;
  final bool showRecommendationPanel;
  final VoidCallback onToggleRecommendationPanel;
  final bool showEngineeringExplorerPanel;
  final VoidCallback onToggleEngineeringExplorerPanel;
  final bool showKnowledgeGraphPanel;
  final VoidCallback onToggleKnowledgeGraphPanel;
  final bool showQueryConsolePanel;
  final VoidCallback onToggleQueryConsolePanel;
  final bool showSessionsPanel;
  final VoidCallback onToggleSessionsPanel;

  Widget _toggle(String tooltip, IconData icon, bool active, VoidCallback onPressed) {
    return IconButton(
      iconSize: 18,
      tooltip: tooltip,
      isSelected: active,
      selectedIcon: Icon(icon, color: StudioColors.selection),
      icon: Icon(icon, color: StudioColors.textSecondary),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 18,
          tooltip: busy ? 'Validating…' : 'Validate Now (manual, immediate)',
          onPressed: busy ? null : onValidateNow,
          icon: busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.fact_check_outlined, color: StudioColors.textSecondary),
        ),
        IconButton(
          iconSize: 18,
          tooltip: 'Analyze Selected Node',
          onPressed: onAnalyzeSelected,
          icon: const Icon(Icons.insights_outlined),
        ),
        _toggle('Recommendations', Icons.lightbulb_outline, showRecommendationPanel, onToggleRecommendationPanel),
        _toggle('Engineering Explorer', Icons.travel_explore_outlined, showEngineeringExplorerPanel,
            onToggleEngineeringExplorerPanel),
        _toggle('Knowledge Graph', Icons.hub_outlined, showKnowledgeGraphPanel, onToggleKnowledgeGraphPanel),
        _toggle('Query Console', Icons.terminal, showQueryConsolePanel, onToggleQueryConsolePanel),
        _toggle('Engineering Sessions', Icons.history_edu_outlined, showSessionsPanel, onToggleSessionsPanel),
      ],
    );
  }
}
