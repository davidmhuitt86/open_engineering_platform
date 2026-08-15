import '../graph/models/engineering_graph.dart';
import '../shared/ids.dart';
import 'diagnostics/diagnostics_engine.dart';
import 'diagnostics/diagnostics_models.dart';
import 'measurement/measurement_engine.dart';
import 'measurement/measurement_result.dart';
import 'measurement/measurement_types.dart';
import 'models/signal_types.dart';
import 'models/simulation_fault.dart';
import 'session/simulation_compare_result.dart';
import 'session/simulation_event.dart';
import 'session/simulation_session.dart';
import 'state/operating_state.dart';
import 'verification/verification_engine.dart';
import 'verification/verification_finding.dart';

/// AP-DS-005 top-level Simulation Engine facade — composes Sessions,
/// Playback, Fault Injection, Verification, and Diagnostics into the one
/// class Diagram Studio (and any other caller) depends on.
///
/// **Async execution deviation from the pre-specified facade contract**:
/// `run`/`step` return `Future<...>` here, not bare values. This is a
/// deliberate, disclosed deviation from the literal contract text in
/// AP-DS-005 (item 5), made for the Performance requirement (item 8): a
/// Studio-side caller must be able to `await` a simulation pass without
/// blocking a frame, matching `DiagramIntelligenceService`'s own async
/// design from AP-DS-003. At this phase's scale the recompute is
/// synchronous internally (wrapped in `Future.value`/`async`) — the seam
/// exists for a future background-isolate execution without any caller
/// changing. Every other method keeps the exact contracted signature.
class SimulationEngine {
  SimulationEngine({
    VerificationEngine verificationEngine = const VerificationEngine(),
    DiagnosticsEngine diagnosticsEngine = const DiagnosticsEngine(),
    MeasurementEngine measurementEngine = const MeasurementEngine(),
  })  : _verification = verificationEngine,
        _diagnostics = diagnosticsEngine,
        _measurement = measurementEngine;

  final VerificationEngine _verification;
  final DiagnosticsEngine _diagnostics;
  final MeasurementEngine _measurement;

  final Map<String, SimulationSession> _sessions = {};

  // ---- Sessions ----------------------------------------------------

  SimulationSession createSession(
    EngineeringGraph graph, {
    String? name,
    List<OperatingStateDefinition> availableOperatingStates = const [],
    List<InputStateDefinition> availableInputStates = const [],
  }) {
    final id = EngineIds.generate('sim-session');
    final session = SimulationSession(
      id: id,
      name: name ?? 'Session $id',
      graph: graph,
      availableOperatingStates: availableOperatingStates,
      availableInputStates: availableInputStates,
    );
    _sessions[id] = session;
    return session;
  }

  SimulationSession? getSession(String sessionId) => _sessions[sessionId];

  SimulationSession _require(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('No simulation session registered for id "$sessionId".');
    }
    return session;
  }

  SimulationSession duplicateSession(String sessionId, {String? name}) {
    final original = _require(sessionId);
    final id = EngineIds.generate('sim-session');
    final duplicate = SimulationSession(
      id: id,
      name: name ?? '${original.name} (copy)',
      graph: original.graph,
      history: List.of(original.history),
      playbackPosition: original.playbackPosition,
      bookmarks: List.of(original.bookmarks),
      availableOperatingStates: original.availableOperatingStates,
      availableInputStates: original.availableInputStates,
    );
    _sessions[id] = duplicate;
    return duplicate;
  }

  SimulationCompareResult compareSessions(String sessionIdA, String sessionIdB) {
    final a = _require(sessionIdA);
    final b = _require(sessionIdB);
    final nodeIds = {...a.state.nodeStates.keys, ...b.state.nodeStates.keys};
    final differences = <SimulationNodeDiff>[];
    for (final nodeId in nodeIds) {
      final poweredA = a.state.isPowered(nodeId);
      final poweredB = b.state.isPowered(nodeId);
      final groundedA = a.state.isGrounded(nodeId);
      final groundedB = b.state.isGrounded(nodeId);
      final functionalA = a.state.isFunctional(nodeId);
      final functionalB = b.state.isFunctional(nodeId);
      if (poweredA != poweredB || groundedA != groundedB || functionalA != functionalB) {
        differences.add(SimulationNodeDiff(
          nodeId: nodeId,
          poweredA: poweredA,
          poweredB: poweredB,
          groundedA: groundedA,
          groundedB: groundedB,
          functionalA: functionalA,
          functionalB: functionalB,
        ));
      }
    }
    differences.sort((x, y) => x.nodeId.compareTo(y.nodeId));
    return SimulationCompareResult(
      sessionIdA: sessionIdA,
      sessionIdB: sessionIdB,
      differences: differences,
      generatedAt: DateTime.now(),
    );
  }

  void deleteSession(String sessionId) => _sessions.remove(sessionId);

  Map<String, Object?> exportSession(String sessionId) => _require(sessionId).toJson();

  /// "Resume" per the spec's Session Management list: rebuild a session
  /// from an export against the (caller-supplied) graph it belongs to.
  SimulationSession importSession(Map<String, Object?> json, EngineeringGraph graph) {
    final session = SimulationSession.fromJson(json, graph);
    _sessions[session.id] = session;
    return session;
  }

  // ---- Deterministic execution / playback ---------------------------

  Future<SimulationStateSnapshot> run(String sessionId) async => _require(sessionId).recompute();

  Future<void> step(String sessionId) async => _require(sessionId).step();

  void reset(String sessionId) => _require(sessionId).reset();

  void pause(String sessionId) => _require(sessionId).pause();

  void resume(String sessionId) => _require(sessionId).resume();

  /// "Play" — exposed as a controllable `Stream<SimulationStateSnapshot>`
  /// rather than assuming any UI/Timer framework (this is a backend
  /// engine): each step through the remaining event history yields the
  /// newly-recomputed state, honoring [pause]/[resume] between steps via
  /// the session's own `isPaused` flag, and respecting [stepDelay] as the
  /// caller-controlled "simulation speed." The Studio layer drives this
  /// with its own Timer/ticker; this method does not assume wall-clock
  /// timing beyond the delay the caller explicitly requests.
  Stream<SimulationStateSnapshot> play(String sessionId, {Duration stepDelay = Duration.zero}) async* {
    final session = _require(sessionId);
    session.resume();
    while (session.playbackPosition < session.history.length) {
      if (session.isPaused) return;
      if (stepDelay > Duration.zero) await Future.delayed(stepDelay);
      session.step();
      yield session.state;
    }
  }

  // ---- Timeline / bookmarks / replay --------------------------------

  List<SimulationEvent> timeline(String sessionId) => _require(sessionId).history;

  void addBookmark(String sessionId, String label) => _require(sessionId).addBookmark(label);

  void jumpToBookmark(String sessionId, String bookmarkLabel) => _require(sessionId).jumpToBookmark(bookmarkLabel);

  void replay(String sessionId, {String? fromBookmark}) => _require(sessionId).replay(fromBookmark: fromBookmark);

  // ---- Fault injection ------------------------------------------------

  void injectFault(String sessionId, SimulationFault fault) => _require(sessionId).injectFault(fault);

  void clearFault(String sessionId, String faultId) => _require(sessionId).clearFault(faultId);

  void restoreNormal(String sessionId) => _require(sessionId).restoreNormal();

  // ---- Operating / input state (Phase 9) -------------------------------

  void setOperatingState(String sessionId, String stateId) => _require(sessionId).setOperatingState(stateId);

  void setInputState(String sessionId, String inputId, Object? value) =>
      _require(sessionId).setInputState(inputId, value);

  // ---- Verification / diagnostics (read-only queries) -----------------

  VerificationReport verify(String sessionId) {
    final session = _require(sessionId);
    return _verification.runAll(session.graph, state: session.state);
  }

  FaultReport faultReport(String sessionId) {
    final session = _require(sessionId);
    return _diagnostics.faultReport(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
  }

  PropagationReport propagationReport(String sessionId, String targetNodeId) {
    final session = _require(sessionId);
    return _diagnostics.propagationReport(session.graph, session.activeFaults, targetNodeId,
        blockedRelationshipIds: session.blockedRelationshipIds);
  }

  PowerReport powerReport(String sessionId) {
    final session = _require(sessionId);
    final verification = verify(sessionId);
    return _diagnostics.powerReport(session.graph, session.activeFaults, verification,
        blockedRelationshipIds: session.blockedRelationshipIds);
  }

  GroundReport groundReport(String sessionId) {
    final session = _require(sessionId);
    final verification = verify(sessionId);
    return _diagnostics.groundReport(session.graph, session.activeFaults, verification,
        blockedRelationshipIds: session.blockedRelationshipIds);
  }

  // ---- Measurement (WP-DS-005A Engineering Instruments) ---------------

  /// Requests a measurement between two probe points, at the session's
  /// current fault/playback state. Diagram Studio's Instruments Framework
  /// calls this and only this to obtain a reading — it never computes one
  /// itself (see [MeasurementEngine]'s doc for the disclosed scope
  /// boundary this represents).
  MeasurementResult measure(
    String sessionId, {
    required ProbePoint probeA,
    required ProbePoint probeB,
    required MeasurementType type,
    MeasurementMode mode = MeasurementMode.manual,
  }) {
    final session = _require(sessionId);
    return _measurement.measure(
      session.graph,
      session.activeFaults,
      probeA: probeA,
      probeB: probeB,
      type: type,
      mode: mode,
      blockedRelationshipIds: session.blockedRelationshipIds,
    );
  }

  SimulationReport simulationReport(String sessionId) {
    final session = _require(sessionId);
    final verification = verify(sessionId);
    return _diagnostics.simulationReport(
      sessionId: session.id,
      sessionName: session.name,
      graph: session.graph,
      faults: session.activeFaults,
      verification: verification,
      blockedRelationshipIds: session.blockedRelationshipIds,
    );
  }
}
