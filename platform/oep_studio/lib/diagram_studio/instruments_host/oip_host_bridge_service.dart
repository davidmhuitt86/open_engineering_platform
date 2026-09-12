import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_instruments_runtime/oep_instruments_runtime.dart';

import '../instruments/multimeter/multimeter_controller.dart';

/// PRODUCT-READINESS-007 — Diagram Studio's Host-side bridge to the OEP
/// Instrument Protocol (OIP-API-001) — the ONLY place in `oep_studio` that
/// talks OIP. Answers `requestMeasurement` messages from connected
/// instrument clients (e.g. the Android/Flutter Digital Multimeter app) by
/// running them through the AUTHORITATIVE native Electrical Solution
/// Engine — [ElectricalSolver] + [ElectricalMeasurementQuery] — never
/// computing a value itself and never falling back to the old
/// `SimulationEngine.measure()`/`MeasurementEngine` reachability-only
/// path (§1/§25: "The DMM must use ElectricalSolver / ElectricalMeasurementQuery").
///
/// **Architecture (§1)**:
/// ```
/// requestMeasurement (OIP)
///       -> resolve diagram instance's own EngineeringGraph
///       -> ElectricalSolver.solve(graph, operatingContext)
///       -> ElectricalMeasurementQuery.measure(solved, request)
///       -> ElectricalMeasurementResult
///       -> measurementResult (OIP), replyTo the original request
/// ```
///
/// **Off by default, explicit opt-in required.** This service does not
/// start listening on a network port until [start] is called — opening a
/// listening socket is a real, user-visible action (per this codebase's
/// own safety discipline around network-exposing behavior), not something
/// that happens silently just because Diagram Studio is open.
///
/// **Diagram instance routing (§10)**: a request may carry an optional
/// `diagramInstanceId` in its payload — resolved via
/// [graphProviderByInstance] against the real, already-multi-instance-
/// capable `engineeringProjectServiceFamily(instanceId)` machinery
/// (`engineering_project_service.dart`), never a single global "the
/// diagram." A request with no `diagramInstanceId` (every existing/older
/// client) resolves against [graphProvider] — the backward-compatible
/// "primary" diagram, exactly as before this phase. A request naming an
/// instance id that resolves to no open diagram is a protocol ERROR
/// (`missingDiagramInstance`), never a silent drop and never answered
/// against the wrong diagram.
///
/// **Structured protocol errors (§12)**: a malformed/unroutable request
/// (unknown measurement type, missing probe target, missing diagram
/// instance) now gets a real `error`-category [OipMessage] response
/// (carrying an [OipError]), correlated via `replyTo` — never a silent
/// drop, and never confused with an ELECTRICAL result (an open/fault/
/// unsupported [ElectricalReading] is still a normal `measurementResult`
/// response, just with that state — see [_readingToPayload]).
///
/// **Session model, disclosed simplification** (carried over unchanged
/// from the prior phase): OIP-SESSION-001 §6 says "Clients shall never
/// create Sessions independently" — a full implementation would have
/// Diagram Studio create a Session and the client join it. This bridge
/// instead treats whatever `sessionId` string a client sends as its own
/// OIP-level conversation id and answers directly against the resolved
/// diagram's own graph — no per-client engine session object is created
/// any more (the old [SimulationEngine] session map this class used to
/// maintain is gone along with [SimulationEngine] itself, since
/// [ElectricalSolver] is a stateless, per-solve computation, not a
/// stateful session-owning engine).
class OipHostBridgeService {
  OipHostBridgeService({
    this.electricalSolver = const ElectricalSolver(),
    ElectricalOperatingContext Function(String? diagramInstanceId)? operatingContextProvider,
  }) : _operatingContextProvider = operatingContextProvider ?? ((_) => ElectricalOperatingContext.none);

  /// The native solver — injectable so a caller with real, richer
  /// source-voltage/reference-role resolvers (e.g. the TRX300-aware ones
  /// PRODUCT-READINESS-006B's own tests use) can supply them; defaults to
  /// [ElectricalSolver]'s own generic, structural-signal-only behavior.
  final ElectricalSolver electricalSolver;

  /// §9 (PRODUCT-READINESS-004) reused, per diagram instance — real UI
  /// switch/key state is not yet bridged from Diagram Studio into this
  /// service (a disclosed limitation, matching PRODUCT-READINESS-006B's
  /// own finding for the V2 WebView bridge); a caller with that real
  /// wiring can supply it here instead of the `.none` default.
  final ElectricalOperatingContext Function(String? diagramInstanceId) _operatingContextProvider;

  static const ElectricalMeasurementQuery _query = ElectricalMeasurementQuery();

  OipHostServer? _server;
  final List<StreamSubscription<OipMessage>> _connectionSubscriptions = [];
  StreamSubscription<OipHostConnection>? _connectionsSubscription;

  /// AP-DIAGRAM-OIP-DMM-SYNC-001 — every currently-connected client (e.g.
  /// the Android Digital Multimeter app), so this bridge can broadcast an
  /// unsolicited state update to all of them, not just reply to whoever
  /// asked. Entries are removed once that connection's own message
  /// stream closes, so a disconnected client is never sent to again.
  final List<OipHostConnection> _connections = [];

  /// AP-DIAGRAM-OIP-DMM-SYNC-001 — the live, diagram-embedded
  /// [MultimeterController] this bridge mirrors to every connected
  /// client, and applies a remote `setDmmMode` request to. Read fresh
  /// from [_multimeterControllerProvider] wherever needed (never cached
  /// past a single use) — the real controller instance can change (e.g.
  /// a new diagram session), matching [graphProvider]'s own
  /// re-invoked-per-request convention. `null` (the default, and
  /// whenever the provider itself returns `null`) means there is no
  /// diagram-embedded DMM session to mirror right now — a connected
  /// client's `setDmmMode` is then a harmless no-op, and no broadcasts
  /// are ever sent.
  MultimeterController? Function()? _multimeterControllerProvider;
  MultimeterController? _observedController;
  void Function()? _multimeterListener;

  /// §26 (PRODUCT-READINESS-004 generation semantics) — one monotonic
  /// solve-generation counter PER diagram instance (never wall-clock,
  /// never shared across instances — a generation from diagram A must
  /// never be compared against one from diagram B).
  final Map<String, ElectricalSolutionGenerationCounter> _generationCounters = {};

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// [graph]/[graphProvider] resolve the backward-compatible "primary"
  /// diagram (used when a request carries no `diagramInstanceId`, or when
  /// [graphProviderByInstance] is not supplied at all). [graphProviderByInstance],
  /// when given, is consulted first for any request that DOES carry a
  /// `diagramInstanceId` — see class doc comment "Diagram instance
  /// routing." All three are re-invoked fresh on every incoming request
  /// (never cached), so a long-running Studio session answers against
  /// whatever diagram is currently open/edited.
  /// [multimeterControllerProvider] — AP-DIAGRAM-OIP-DMM-SYNC-001: read
  /// fresh, never cached, matching [graphProvider]'s own convention.
  /// When supplied, this bridge mirrors the live, diagram-embedded
  /// [MultimeterController] to every connected client (mode + current
  /// reading, pushed as unsolicited `measurementResult`/`dmmStateChanged`
  /// messages whenever the controller changes) and applies an incoming
  /// `setDmmMode` request from a client to it — direct request: "wire
  /// the android instrument app to the new dmm... relay the displayed
  /// values... accept mode controls from the app." Omitted (the
  /// default), this bridge behaves exactly as before: purely
  /// request/reply, no broadcasts, no remote mode control.
  Future<void> start({
    EngineeringGraph? graph,
    EngineeringGraph? Function()? graphProvider,
    EngineeringGraph? Function(String diagramInstanceId)? graphProviderByInstance,
    MultimeterController? Function()? multimeterControllerProvider,
    int port = 9411,
  }) async {
    if (_server != null) return;
    final resolvedPrimaryProvider = graphProvider ?? (graph != null ? () => graph : null);
    _multimeterControllerProvider = multimeterControllerProvider;
    final server = await OipHostServer.bind(port: port);
    _server = server;
    _connectionsSubscription =
        server.connections.listen((connection) => _handleConnection(connection, resolvedPrimaryProvider, graphProviderByInstance));
    _attachMultimeterListener();
  }

  Future<void> stop() async {
    await _connectionsSubscription?.cancel();
    _connectionsSubscription = null;
    for (final subscription in _connectionSubscriptions) {
      await subscription.cancel();
    }
    _connectionSubscriptions.clear();
    _connections.clear();
    _detachMultimeterListener();
    _multimeterControllerProvider = null;
    await _server?.close();
    _server = null;
    _generationCounters.clear();
  }

  void _handleConnection(
    OipHostConnection connection,
    EngineeringGraph? Function()? primaryGraphProvider,
    EngineeringGraph? Function(String diagramInstanceId)? graphProviderByInstance,
  ) {
    _connections.add(connection);
    final subscription = connection.messages.listen(
      (message) {
        if (message.category == OipMessageCategory.measurement && message.type == 'requestMeasurement') {
          _handleMeasurementRequest(connection, message, primaryGraphProvider, graphProviderByInstance);
        } else if (message.category == OipMessageCategory.instrument && message.type == 'setDmmMode') {
          _handleSetDmmMode(message);
        }
      },
      onDone: () => _connections.remove(connection),
    );
    _connectionSubscriptions.add(subscription);
    // A client that just connected should see the DMM's real current
    // state immediately, not only on its next change -- the same "show
    // what's actually true right now" reasoning every other honest
    // state surface in this codebase already follows.
    _broadcastMultimeterStateTo(connection);
  }

  /// AP-DIAGRAM-OIP-DMM-SYNC-001 — re-subscribes to whatever controller
  /// [_multimeterControllerProvider] currently resolves to. Called once
  /// on [start] and again whenever a broadcast attempt notices the
  /// resolved controller instance has changed (e.g. a new diagram
  /// session replaced the old one) — never left listening to a stale,
  /// disposed controller.
  void _attachMultimeterListener() {
    final controller = _multimeterControllerProvider?.call();
    if (identical(controller, _observedController)) return;
    _detachMultimeterListener();
    _observedController = controller;
    if (controller == null) return;
    void listener() => _broadcastMultimeterStateToAll();
    _multimeterListener = listener;
    controller.addListener(listener);
  }

  void _detachMultimeterListener() {
    final controller = _observedController;
    final listener = _multimeterListener;
    if (controller != null && listener != null) controller.removeListener(listener);
    _observedController = null;
    _multimeterListener = null;
  }

  void _broadcastMultimeterStateToAll() {
    _attachMultimeterListener(); // pick up a controller-instance change first
    for (final connection in List<OipHostConnection>.of(_connections)) {
      _broadcastMultimeterStateTo(connection);
    }
  }

  /// Sends the diagram-embedded DMM's current mode and reading to
  /// [connection] as unsolicited (`replyTo: null`) messages — accepted
  /// by [DigitalMultimeterPlugin.receiveMeasurement]/`receiveEvent`
  /// exactly like a normal reply, per their own "a response with no
  /// `replyTo` is accepted... a non-request-driven broadcast" contract.
  /// A silent no-op when there is nothing to mirror (`_observedController
  /// == null`) or the controller's current mode has no real
  /// [DmmMeasurementMode] equivalent (§ [_wireNameForMeasurementType]'s
  /// own doc comment — never a fabricated mode name).
  void _broadcastMultimeterStateTo(OipHostConnection connection) {
    final controller = _observedController;
    if (controller == null) return;
    final wireMode = _wireNameForMeasurementType(controller.selectedType);
    if (wireMode == null) return;
    connection.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.instrument,
      type: 'dmmStateChanged',
      sessionId: 'diagram-studio-host',
      messageId: '${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      payload: {
        'measurementType': wireMode,
        'probeRedTargetId': controller.probeA?.nodeId,
        'probeRedPortId': controller.probeA?.portId,
        'probeBlackTargetId': controller.probeB?.nodeId,
        'probeBlackPortId': controller.probeB?.portId,
      },
    ));
    final result = controller.electricalResult;
    if (result != null) {
      connection.send(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: 'diagram-studio-host',
        messageId: '${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        payload: _readingToPayload(result, wireMeasurementType: wireMode),
      ));
    }
  }

  /// AP-DIAGRAM-OIP-DMM-SYNC-001 — a connected client (e.g. the Android
  /// app's own mode dial) asking this Host to change the diagram-
  /// embedded DMM's mode. Applies directly to [MultimeterController
  /// .setType] — the SAME method the diagram panel's own mode dial
  /// calls — never a second, parallel mode-tracking mechanism. A no-op
  /// (not an error reply) when there is no controller to apply to, or
  /// the requested wire name has no real [MeasurementType] equivalent:
  /// probe *placement* is intentionally NOT remote-controllable this way
  /// (§ class doc comment — a phone has no diagram to click a component
  /// in), only mode.
  void _handleSetDmmMode(OipMessage message) {
    final controller = _multimeterControllerProvider?.call();
    if (controller == null) return;
    final type = _measurementTypeFromWireName(message.payload['measurementType'] as String?);
    if (type == null) return;
    controller.setType(type);
  }

  void _handleMeasurementRequest(
    OipHostConnection connection,
    OipMessage request,
    EngineeringGraph? Function()? primaryGraphProvider,
    EngineeringGraph? Function(String diagramInstanceId)? graphProviderByInstance,
  ) {
    final payload = request.payload;
    final diagramInstanceId = payload['diagramInstanceId'] as String?;

    final EngineeringGraph? graph;
    if (diagramInstanceId != null) {
      if (graphProviderByInstance == null) {
        _sendError(connection, request, code: 'missingDiagramInstance',
            description: 'This Host does not support routing by diagramInstanceId.', recoverable: false);
        return;
      }
      graph = graphProviderByInstance(diagramInstanceId);
      if (graph == null) {
        _sendError(connection, request, code: 'missingDiagramInstance',
            description: 'No diagram is open for instance "$diagramInstanceId".', recoverable: true,
            suggestedAction: 'Open that Diagram Studio tab, then retry.');
        return;
      }
    } else {
      graph = primaryGraphProvider?.call();
      if (graph == null) {
        _sendError(connection, request, code: 'missingDiagramInstance',
            description: 'No diagram is currently open.', recoverable: true, suggestedAction: 'Open a diagram in Diagram Studio, then retry.');
        return;
      }
    }

    final measurementType = _measurementTypeFromWireName(payload['measurementType'] as String?);
    if (measurementType == null) {
      _sendError(connection, request, code: 'unknownMeasurementType',
          description: 'Unrecognized measurementType "${payload['measurementType']}".', recoverable: false);
      return;
    }

    final probeBlackTargetId = payload['probeBlackTargetId'] as String?;
    final probeRedTargetId = payload['probeRedTargetId'] as String?;
    if (probeBlackTargetId == null || probeRedTargetId == null) {
      _sendError(connection, request, code: 'invalidTarget',
          description: 'Both probeRedTargetId and probeBlackTargetId are required.', recoverable: true,
          suggestedAction: 'Place both probes before requesting a measurement.');
      return;
    }

    final positiveTerminal = ProbePoint(nodeId: probeRedTargetId, portId: payload['probeRedPortId'] as String?);
    final negativeTerminal = ProbePoint(nodeId: probeBlackTargetId, portId: payload['probeBlackPortId'] as String?);

    if (!graph.nodes.containsKey(positiveTerminal.nodeId) || !graph.nodes.containsKey(negativeTerminal.nodeId)) {
      _sendError(connection, request, code: 'invalidTarget',
          description: 'A probe target does not exist in the current diagram.', recoverable: true,
          suggestedAction: 'Re-select a valid probe target.');
      return;
    }

    final generationCounter = _generationCounters.putIfAbsent(diagramInstanceId ?? '__primary__', ElectricalSolutionGenerationCounter.new);
    final operatingContext = _operatingContextProvider(diagramInstanceId);
    final solved = electricalSolver.solve(graph, operatingContext, generationCounter: generationCounter);
    final result = _query.measure(
      solved,
      ElectricalMeasurementRequest(positiveTerminal: positiveTerminal, negativeTerminal: negativeTerminal, mode: measurementType),
    );

    connection.send(OipMessage(
      protocolVersion: request.protocolVersion,
      category: OipMessageCategory.measurement,
      type: 'measurementResult',
      sessionId: request.sessionId,
      messageId: '${DateTime.now().microsecondsSinceEpoch}',
      replyTo: request.messageId,
      timestamp: DateTime.now(),
      payload: _readingToPayload(result, wireMeasurementType: payload['measurementType'] as String?),
    ));
  }

  /// Translates the Engine's own [ElectricalReading] (via
  /// [ElectricalMeasurementResult.reading]) into the OIP measurement
  /// payload — §3/§12: a legitimate zero stays a real `0` under `state:
  /// 'stable'`; OL/overload/fault/unsupported/unknown/unreached each get
  /// their own real `electricalState` (never collapsed into the same
  /// placeholder), with `value: null` for every one of them (never a
  /// fabricated number standing in for "no value").
  Map<String, Object?> _readingToPayload(ElectricalMeasurementResult result, {required String? wireMeasurementType}) {
    final reading = result.reading;
    return {
      'value': reading.isValid ? reading.value : null,
      'unit': reading.unit,
      'measurementType': wireMeasurementType,
      'source': 'electricalSolver',
      // Backward-compatible coarse quality/state, unchanged in spirit from
      // the pre-006B wire vocabulary, for any client that doesn't yet read
      // `electricalState`.
      'quality': reading.isValid ? 'measured' : 'unavailable',
      'state': reading.isValid ? 'stable' : 'unavailable',
      // §3 — the real, structured state a §18-aware client (the updated
      // DigitalMultimeterPlugin/Panel) reads instead of the coarse pair
      // above.
      'electricalState': reading.state.name,
      if (reading.note != null) 'note': reading.note,
      'solutionGeneration': result.generation.toJson(),
    };
  }

  void _sendError(
    OipHostConnection connection,
    OipMessage request, {
    required String code,
    required String description,
    required bool recoverable,
    String? suggestedAction,
  }) {
    final error = OipError(
      code: code,
      severity: OipErrorSeverity.error,
      description: description,
      recoverable: recoverable,
      suggestedAction: suggestedAction,
    );
    connection.send(OipMessage(
      protocolVersion: request.protocolVersion,
      category: OipMessageCategory.error,
      type: 'measurementError',
      sessionId: request.sessionId,
      messageId: '${DateTime.now().microsecondsSinceEpoch}',
      replyTo: request.messageId,
      timestamp: DateTime.now(),
      payload: error.toJson(),
    ));
  }

  /// Maps [DmmMeasurementMode]'s wire names (e.g. `'dcVoltage'`) to
  /// `oep_engine`'s own [MeasurementType] enum (e.g. `voltageDc`) — the
  /// two packages independently name the same concepts slightly
  /// differently (`dcVoltage` vs `voltageDc`), so this is a real,
  /// necessary translation layer, not a redundant duplicate enum.
  MeasurementType? _measurementTypeFromWireName(String? wireName) {
    switch (wireName) {
      case 'dcVoltage':
        return MeasurementType.voltageDc;
      case 'acVoltage':
        return MeasurementType.voltageAc;
      case 'resistance':
        return MeasurementType.resistance;
      case 'continuity':
        return MeasurementType.continuity;
      case 'current':
        return MeasurementType.current;
      case 'diode':
        return MeasurementType.diode;
      case 'frequency':
        return MeasurementType.frequency;
      case 'dutyCycle':
        return MeasurementType.dutyCycle;
      case 'temperature':
        return MeasurementType.temperature;
      case 'capacitance':
        return MeasurementType.capacitance;
      default:
        return null;
    }
  }

  /// The exact inverse of [_measurementTypeFromWireName], for mirroring
  /// this side's own current mode out to a connected client. `null` for
  /// a [MeasurementType] with no [DmmMeasurementMode] equivalent (e.g.
  /// `power` — the diagram panel's own mode dial has it, the Android
  /// app's does not) — a real, disclosed instrument-capability gap, not
  /// something to paper over with an invented wire name; the broadcast
  /// is simply skipped for that mode.
  String? _wireNameForMeasurementType(MeasurementType type) {
    switch (type) {
      case MeasurementType.voltageDc:
        return 'dcVoltage';
      case MeasurementType.voltageAc:
        return 'acVoltage';
      case MeasurementType.resistance:
        return 'resistance';
      case MeasurementType.continuity:
        return 'continuity';
      case MeasurementType.current:
        return 'current';
      case MeasurementType.diode:
        return 'diode';
      case MeasurementType.frequency:
        return 'frequency';
      case MeasurementType.dutyCycle:
        return 'dutyCycle';
      case MeasurementType.temperature:
        return 'temperature';
      case MeasurementType.capacitance:
        return 'capacitance';
      default:
        return null;
    }
  }
}
