import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';

/// AP-DS-005: the single point of contact between Diagram Studio and the
/// Simulation Engine — mirrors `DiagramIntelligenceService`'s own role for
/// the Engineering Intelligence Platform (AP-DS-003), but for a much
/// simpler dependency: [SimulationEngine] is pure Dart (no FFI, no
/// Foundation runtime, no native handle), already registered on every
/// `EngineeringEngine.create()`'s [EngineRegistry] (see
/// `oep_engine/lib/core/engineering_engine.dart`'s `..register<SimulationEngine>(SimulationEngine())`)
/// exactly like `EngineRegistry.selection`/`.viewState` are reached
/// elsewhere in this codebase (`engineering_project_service.dart`). This
/// class does NOT construct its own [SimulationEngine] — it is handed the
/// one the host page's [EngineeringEngine] already owns, so every
/// Diagram Studio surface (overlay, playback, faults, diagnostics,
/// sessions) shares one engine instance, matching the "one Engine per
/// diagram" pattern [DiagramIntelligenceService] already established for
/// its own Knowledge Session.
///
/// Zero engineering logic lives here: every method is a thin,
/// async-wrapped pass-through to [SimulationEngine] — this class only
/// tracks which session id is "current" for the diagram, exactly as
/// [DiagramIntelligenceService] tracks the current Knowledge Session id.
///
/// **Asynchrony**: every public method returns a `Future`, matching
/// [DiagramIntelligenceService]'s own documented convention — callers
/// (the playback controls, fault injection panel, diagnostics panel)
/// `await` inside handlers/FutureBuilders, never call synchronously
/// inside `build()`. The underlying [SimulationEngine] itself is
/// synchronous Dart (no isolate dispatch), so this is the same honest
/// "wrapped in `Future(() => ...)` for a consistent async contract, not
/// actual background execution" disclosure `DiagramIntelligenceService`
/// already makes.
class DiagramSimulationService {
  DiagramSimulationService({required SimulationEngine engine}) : _engine = engine;

  final SimulationEngine _engine;

  String? _currentSessionId;

  /// The session id this diagram's simulation UI is currently scoped to,
  /// or `null` before the first [createSession]/[importSession] call.
  String? get currentSessionId => _currentSessionId;

  SimulationSession? get currentSession => _currentSessionId == null ? null : _engine.getSession(_currentSessionId!);

  bool get hasSession => _currentSessionId != null && _engine.getSession(_currentSessionId!) != null;

  // ---- Session Management --------------------------------------------

  Future<SimulationSession> createSession(
    EngineeringGraph graph, {
    String? name,
    List<OperatingStateDefinition> availableOperatingStates = const [],
    List<InputStateDefinition> availableInputStates = const [],
  }) async {
    final session = _engine.createSession(
      graph,
      name: name,
      availableOperatingStates: availableOperatingStates,
      availableInputStates: availableInputStates,
    );
    _currentSessionId = session.id;
    _trackSession(session.id);
    return session;
  }

  Future<SimulationSession> duplicateSession({String? name}) async {
    final duplicate = _engine.duplicateSession(_requireSessionId, name: name);
    _currentSessionId = duplicate.id;
    _trackSession(duplicate.id);
    return duplicate;
  }

  Future<void> resumeSession(String sessionId) async {
    if (_engine.getSession(sessionId) == null) {
      throw StateError('No simulation session registered for id "$sessionId".');
    }
    _currentSessionId = sessionId;
    _trackSession(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    _engine.deleteSession(sessionId);
    _knownSessionIds.remove(sessionId);
    if (_currentSessionId == sessionId) _currentSessionId = null;
  }

  Future<Map<String, Object?>> exportSession() async => _engine.exportSession(_requireSessionId);

  Future<SimulationSession> importSession(Map<String, Object?> json, EngineeringGraph graph) async {
    final session = _engine.importSession(json, graph);
    _currentSessionId = session.id;
    _trackSession(session.id);
    return session;
  }

  Future<SimulationCompareResult> compareSessions(String sessionIdA, String sessionIdB) async =>
      _engine.compareSessions(sessionIdA, sessionIdB);

  List<String> get allSessionIds => _knownSessionIds;

  /// [SimulationEngine] exposes no "list all sessions" method (its own
  /// facade only supports lookup by id) — this tracks every session id
  /// this service has ever seen created/duplicated/imported/resumed, a
  /// Studio-side bookkeeping list only (never consulted by any
  /// engineering computation), so the Sessions panel has something to
  /// list. A session removed via [deleteSession] is removed from this
  /// list too.
  final List<String> _knownSessionIds = [];

  void _trackSession(String id) {
    if (!_knownSessionIds.contains(id)) _knownSessionIds.add(id);
  }

  // ---- Deterministic execution / playback ------------------------------

  Future<SimulationStateSnapshot> run() async => _engine.run(_requireSessionId);

  Future<void> step() async => _engine.step(_requireSessionId);

  Future<void> reset() async => _engine.reset(_requireSessionId);

  Future<void> pause() async => _engine.pause(_requireSessionId);

  Future<void> resume() async => _engine.resume(_requireSessionId);

  Stream<SimulationStateSnapshot> play({Duration stepDelay = Duration.zero}) =>
      _engine.play(_requireSessionId, stepDelay: stepDelay);

  // ---- Timeline / bookmarks / replay -----------------------------------

  Future<List<SimulationEvent>> timeline() async => _engine.timeline(_requireSessionId);

  Future<void> addBookmark(String label) async => _engine.addBookmark(_requireSessionId, label);

  Future<void> jumpToBookmark(String label) async => _engine.jumpToBookmark(_requireSessionId, label);

  Future<void> replay({String? fromBookmark}) async => _engine.replay(_requireSessionId, fromBookmark: fromBookmark);

  // ---- Fault injection ---------------------------------------------------

  Future<void> injectFault(SimulationFault fault) async => _engine.injectFault(_requireSessionId, fault);

  Future<void> clearFault(String faultId) async => _engine.clearFault(_requireSessionId, faultId);

  Future<void> restoreNormal() async => _engine.restoreNormal(_requireSessionId);

  // ---- Operating / input state (Phase 9) --------------------------------

  /// Sets the current session's active operating state. Zero engineering
  /// logic here -- a thin pass-through to
  /// [SimulationEngine.setOperatingState], matching every other method on
  /// this class.
  Future<void> setOperatingState(String stateId) async => _engine.setOperatingState(_requireSessionId, stateId);

  /// Sets a single input's value on the current session.
  Future<void> setInputState(String inputId, Object? value) async =>
      _engine.setInputState(_requireSessionId, inputId, value);

  // ---- Verification / diagnostics (read-only queries) --------------------

  Future<VerificationReport> verify() async => _engine.verify(_requireSessionId);

  Future<FaultReport> faultReport() async => _engine.faultReport(_requireSessionId);

  Future<PropagationReport> propagationReport(String targetNodeId) async =>
      _engine.propagationReport(_requireSessionId, targetNodeId);

  Future<PowerReport> powerReport() async => _engine.powerReport(_requireSessionId);

  Future<GroundReport> groundReport() async => _engine.groundReport(_requireSessionId);

  Future<SimulationReport> simulationReport() async => _engine.simulationReport(_requireSessionId);

  /// Power Distribution visualization data — sourced directly from
  /// [PowerDistributionCalculator], never recomputed here.
  Future<PowerDistributionView> powerDistribution() async {
    final session = currentSession;
    if (session == null) {
      throw StateError('DiagramSimulationService: no active simulation session — call createSession() first.');
    }
    return const PowerDistributionCalculator()
        .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
  }

  // ---- Measurement (WP-DS-005A Engineering Instruments) ----------------

  /// Requests a measurement from the real [SimulationEngine.measure] — the
  /// Instruments Framework (dock, Digital Multimeter, probes) calls only
  /// this to obtain a reading; it never computes one itself. Wrapped in the
  /// same async pass-through convention as every other method on this
  /// class.
  Future<MeasurementResult> measure({
    required ProbePoint probeA,
    required ProbePoint probeB,
    required MeasurementType type,
    MeasurementMode mode = MeasurementMode.manual,
  }) async =>
      _engine.measure(_requireSessionId, probeA: probeA, probeB: probeB, type: type, mode: mode);

  String get _requireSessionId {
    final id = _currentSessionId;
    if (id == null) {
      throw StateError('DiagramSimulationService: no active simulation session — call createSession() first.');
    }
    return id;
  }
}

/// The Context & Capability Service's Phase 2 extraction (OEP Context &
/// Capability Service — Phase 2, Part 2/Part 3): promotes what was
/// previously a page-private instance
/// (`DiagramStudioPage._simulationService`, `??=`-lazily constructed
/// from `engine.registry.simulationEngine`) into one shared,
/// authoritative provider — exactly the same construction call, just
/// reachable outside `DiagramStudioPage` now.
///
/// Mirrors `instrument_bridge_provider.dart`'s own
/// `instrumentBridgeServiceProvider` precedent: a plain `Provider`
/// sourcing the live [SimulationEngine] through
/// [engineeringProjectServiceProvider]'s shared [EngineeringEngine] --
/// never a second, independently-constructed engine.
///
/// **Nullable by necessity, not caution for its own sake**: the shared
/// engine is only bootstrapped on demand
/// (`EngineeringProjectNotifier.ensureEngineStarted`, called today only
/// from `DiagramStudioPage.initState`) -- it is genuinely `null` until
/// some diagram-editing action has happened. `null` here means exactly
/// that, never a placeholder for "not implemented."
///
/// **No `ref.onDispose` is registered**: [DiagramSimulationService] has
/// no `dispose()` method (confirmed by inspection) and holds no timers
/// or stream subscriptions of its own -- there is nothing to clean up
/// beyond what the shared engine's own provider already tears down.
final diagramSimulationServiceProvider = Provider<DiagramSimulationService?>((ref) {
  // `.select` rather than a plain `watch`: `EngineeringProjectState`
  // changes on every selection/validation/view-state update, but the
  // `engine` reference itself only changes when the engine is actually
  // (re)bootstrapped. Watching the whole state would reconstruct a new
  // `DiagramSimulationService` -- and silently lose its `_currentSessionId`
  // -- on every unrelated state change; this keeps identity stable
  // across all of that.
  final engine = ref.watch(engineeringProjectServiceProvider.select((state) => state.engine));
  if (engine == null) return null;
  return DiagramSimulationService(engine: engine.registry.simulationEngine);
});
