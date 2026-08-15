import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_instruments_runtime/oep_instruments_runtime.dart';

/// Diagram Studio's Host-side bridge to the OEP Instrument Protocol
/// (OIP-API-001) — the ONLY place in `oep_studio` that talks OIP. Answers
/// `requestMeasurement` messages from connected instrument clients (e.g.
/// the Android Digital Multimeter app) by calling the real
/// [SimulationEngine.measure], never computing a value itself.
///
/// **Off by default, explicit opt-in required.** This service does not
/// start listening on a network port until [start] is called — opening a
/// listening socket is a real, user-visible action (per this
/// codebase's own safety discipline around network-exposing behavior),
/// not something that happens silently just because Diagram Studio is
/// open.
///
/// **Session model, disclosed simplification**: OIP-SESSION-001 §6 says
/// "Clients shall never create Sessions independently" — a full
/// implementation would have Diagram Studio create a Session and the
/// client join it. This first increment instead: a client sends
/// whatever `sessionId` string it likes as an OIP-level conversation
/// id; the bridge lazily creates one real [SimulationEngine] session per
/// distinct OIP session id it sees (against the current diagram's
/// graph), and maps between the two — the client's own id is never used
/// as the real engine session id directly, since [SimulationEngine]
/// generates its own. This keeps today's real, working request/response
/// path honest about the gap from the full multi-client shared-session
/// architecture the docs describe.
class OipHostBridgeService {
  /// [engine] is a fixed instance (used directly by tests, and by anyone
  /// who genuinely only ever has one). [engineProvider], when given, is
  /// called fresh on every incoming request instead — this is how the
  /// app-wide singleton (`instrumentBridgeServiceProvider`) resolves
  /// whichever `SimulationEngine` belongs to the diagram currently open in
  /// Diagram Studio, since that can change (or not exist yet) across the
  /// service's own long lifetime, independent of any one page. If both
  /// are given, [engineProvider] wins.
  OipHostBridgeService({SimulationEngine? engine, SimulationEngine? Function()? engineProvider})
      : _engineProvider = engineProvider ?? (engine != null ? () => engine : null);

  final SimulationEngine? Function()? _engineProvider;

  OipHostServer? _server;
  final List<StreamSubscription<OipMessage>> _connectionSubscriptions = [];
  StreamSubscription<OipHostConnection>? _connectionsSubscription;

  /// OIP session id (as sent by a client) -> real [SimulationEngine]
  /// session id this bridge created for it.
  final Map<String, String> _sessionMap = {};

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// [graph] is a fixed snapshot (used directly by tests). [graphProvider],
  /// when given, is called fresh on every incoming request instead, so a
  /// long-running Studio session answers against whatever diagram is
  /// currently open/edited rather than whatever was open when [start] was
  /// called. If both are given, [graphProvider] wins.
  Future<void> start({EngineeringGraph? graph, EngineeringGraph? Function()? graphProvider, int port = 9411}) async {
    if (_server != null) return;
    final resolvedProvider = graphProvider ?? (graph != null ? () => graph : null);
    final server = await OipHostServer.bind(port: port);
    _server = server;
    _connectionsSubscription = server.connections.listen((connection) => _handleConnection(connection, resolvedProvider));
  }

  Future<void> stop() async {
    await _connectionsSubscription?.cancel();
    _connectionsSubscription = null;
    for (final subscription in _connectionSubscriptions) {
      await subscription.cancel();
    }
    _connectionSubscriptions.clear();
    await _server?.close();
    _server = null;
    _sessionMap.clear();
  }

  void _handleConnection(OipHostConnection connection, EngineeringGraph? Function()? graphProvider) {
    final subscription = connection.messages.listen((message) {
      if (message.category == OipMessageCategory.measurement && message.type == 'requestMeasurement') {
        _handleMeasurementRequest(connection, message, graphProvider);
      }
    });
    _connectionSubscriptions.add(subscription);
  }

  void _handleMeasurementRequest(OipHostConnection connection, OipMessage request, EngineeringGraph? Function()? graphProvider) {
    final graph = graphProvider?.call();
    if (graph == null) return; // No diagram open -- nothing to measure against.
    final engine = _engineProvider?.call();
    if (engine == null) return; // No engine running yet -- nothing to measure with.

    final engineSessionId = _sessionMap.putIfAbsent(request.sessionId, () => engine.createSession(graph).id);

    final payload = request.payload;
    final measurementType = _measurementTypeFromWireName(payload['measurementType'] as String?);
    if (measurementType == null) return;

    final probeBlackTargetId = payload['probeBlackTargetId'] as String?;
    final probeRedTargetId = payload['probeRedTargetId'] as String?;
    if (probeBlackTargetId == null || probeRedTargetId == null) return;

    final result = engine.measure(
      engineSessionId,
      probeA: ProbePoint(nodeId: probeRedTargetId),
      probeB: ProbePoint(nodeId: probeBlackTargetId),
      type: measurementType,
      mode: MeasurementMode.manual,
    );

    connection.send(OipMessage(
      protocolVersion: request.protocolVersion,
      category: OipMessageCategory.measurement,
      type: 'measurementResult',
      sessionId: request.sessionId,
      messageId: '${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      payload: {
        'value': result.measuredValue,
        'unit': result.unit,
        'measurementType': payload['measurementType'],
        'source': 'simulationEngine',
        'quality': result.reachable ? 'measured' : 'unavailable',
        'state': result.reachable ? 'stable' : 'unavailable',
      },
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
}
