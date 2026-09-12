import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/oep_instruments_runtime.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/instruments_host/oip_host_bridge_service.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';

/// PRODUCT-READINESS-007 — real, end-to-end proof of the OIP Host bridge:
/// a real [WifiOipTransport] client sends a real `requestMeasurement`
/// message, [OipHostBridgeService] answers it using the real, native
/// [ElectricalSolver] + [ElectricalMeasurementQuery] (no mocks, and no
/// `SimulationEngine` anywhere in this file any more — the old
/// reachability-only authority this bridge used before this phase is
/// gone from this path entirely), and the client receives a real,
/// correlated `measurementResult` back over a real TCP loopback
/// connection.
///
/// Fixture topology: `battery --(0.1Ω wire)-- lamp --(0.1Ω wire)--
/// chassisGround`, with NO resistive component modeled for `lamp` itself
/// (this bridge's default `ElectricalSolver` has no behaviorResolver) --
/// so `lamp`'s own node is simply the meeting point of two real, tiny
/// wire resistances, giving exact, hand-verifiable numbers: `lamp`
/// divides 12.6V/0V evenly across two EQUAL 0.1Ω wires -> `6.3V`;
/// `battery`-to-`lamp` current is `(12.6-6.3)/0.1 = 63A`; `battery`-to-
/// `chassisGround` resistance (nothing to deactivate -- `battery` has no
/// separate reference terminal of its own in this minimal fixture) is
/// the plain series sum `0.1 + 0.1 = 0.2Ω`.
void main() {
  // DigitalMultimeterPlugin plays real SystemSound/HapticFeedback tones
  // (via platform channels), which need a Flutter binding -- normally
  // provided implicitly by a `testWidgets` test running earlier in the
  // same process. This file uses plain `test()` only, so the binding
  // must be initialized explicitly here.
  TestWidgetsFlutterBinding.ensureInitialized();

  EngineeringGraph fixtureGraph() => EngineeringGraph(
        id: 'g1',
        nodes: {
          'battery': const EngineeringNode(
            id: 'battery',
            category: NodeCategory.component,
            displayName: 'Battery',
            metadata: {'v2Category': 'power'},
            properties: {'nominalVoltageV': 12.6},
          ),
          'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
          'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'lamp'),
          'r2': const EngineeringRelationship(id: 'r2', relationshipType: RelationshipType.connectedTo, sourceNode: 'chassisGround', targetNode: 'lamp'),
        },
      );

  Future<({WifiOipTransport transport, DigitalMultimeterPlugin plugin})> connectClient(int port) async {
    final transport = WifiOipTransport(transportId: 'test-dmm');
    await transport.initialize();
    await transport.connect('127.0.0.1:$port');
    final plugin = DigitalMultimeterPlugin();
    final session = EngineeringSession(id: 'client-session-1', hostId: 'oep_studio', owner: 'test');
    await plugin.initialize(PluginContext(hostId: 'oep_studio', session: session));
    plugin.connectTransport(transport);
    return (transport: transport, plugin: plugin);
  }

  test('a real DMM client requests VDC and receives a real, correlated answer from the native ElectricalSolver', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);
    expect(bridge.isRunning, isTrue);

    final client = await connectClient(bridge.port!);
    addTearDown(() => client.transport.shutdown());
    final plugin = client.plugin;

    plugin.setMode(DmmMeasurementMode.dcVoltage);
    plugin.setProbeRedTarget('lamp');
    plugin.setProbeBlackTarget('chassisGround');

    await plugin.requestMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(plugin.lastMeasurement, isNotNull);
    expect(plugin.lastMeasurement!.value, closeTo(6.3, 1e-6));
    expect(plugin.lastMeasurement!.unit, 'V');
    expect(plugin.lastMeasurement!.source, 'electricalSolver');
    expect(plugin.lastMeasurement!.electricalState, 'valid');
  });

  test('RES between battery and chassisGround uses the real deactivated-source network reduction', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);
    final client = await connectClient(bridge.port!);
    addTearDown(() => client.transport.shutdown());
    final plugin = client.plugin;

    plugin.setMode(DmmMeasurementMode.resistance);
    plugin.setProbeRedTarget('battery');
    plugin.setProbeBlackTarget('chassisGround');
    await plugin.requestMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(plugin.lastMeasurement!.value, closeTo(0.2, 1e-6));
    expect(plugin.lastMeasurement!.unit, 'Ω');
  });

  test('CURRENT across the single battery->lamp wire is a genuine network-solved value', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);
    final client = await connectClient(bridge.port!);
    addTearDown(() => client.transport.shutdown());
    final plugin = client.plugin;

    plugin.setMode(DmmMeasurementMode.current);
    plugin.setProbeRedTarget('battery');
    plugin.setProbeBlackTarget('lamp');
    await plugin.requestMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(plugin.lastMeasurement!.value, closeTo(63.0, 1e-3));
    expect(plugin.lastMeasurement!.unit, 'A');
  });

  test('CONT reports real continuity, and AC voltage honestly reports UNSUPPORTED (the native Engine is DC-resistive only)', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);
    final client = await connectClient(bridge.port!);
    addTearDown(() => client.transport.shutdown());
    final plugin = client.plugin;

    plugin.setMode(DmmMeasurementMode.continuity);
    plugin.setProbeRedTarget('battery');
    plugin.setProbeBlackTarget('chassisGround');
    await plugin.requestMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(plugin.lastMeasurement!.electricalState, 'valid');
    expect(plugin.lastMeasurement!.value, 0);

    plugin.setMode(DmmMeasurementMode.acVoltage);
    await plugin.requestMeasurement();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(plugin.lastMeasurement!.electricalState, 'unsupported');
    expect(plugin.lastMeasurement!.value, isNull, reason: 'never a fabricated AC value -- the Engine genuinely has no AC model (§49)');
  });

  test('§12 protocol errors: an unknown measurement type gets a structured error, not a fabricated result or a silent drop', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);

    final transport = WifiOipTransport(transportId: 'raw-client');
    await transport.initialize();
    addTearDown(transport.shutdown);
    await transport.connect('127.0.0.1:${bridge.port}');

    final responseFuture = transport.receive().first;
    await transport.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.measurement,
      type: 'requestMeasurement',
      sessionId: 's1',
      messageId: 'req-1',
      timestamp: DateTime.now(),
      payload: {'measurementType': 'totallyUnknownMode', 'probeRedTargetId': 'battery', 'probeBlackTargetId': 'chassisGround'},
    ));
    final response = await responseFuture;
    expect(response.category, OipMessageCategory.error);
    expect(response.replyTo, 'req-1');
    expect(response.payload['code'], 'unknownMeasurementType');
  });

  test('§12 protocol errors: a missing probe target gets a structured error, correlated via replyTo', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    await bridge.start(graph: fixtureGraph(), port: 0);

    final transport = WifiOipTransport(transportId: 'raw-client-2');
    await transport.initialize();
    addTearDown(transport.shutdown);
    await transport.connect('127.0.0.1:${bridge.port}');

    final responseFuture = transport.receive().first;
    await transport.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.measurement,
      type: 'requestMeasurement',
      sessionId: 's1',
      messageId: 'req-2',
      timestamp: DateTime.now(),
      payload: {'measurementType': 'dcVoltage', 'probeRedTargetId': 'battery'},
    ));
    final response = await responseFuture;
    expect(response.category, OipMessageCategory.error);
    expect(response.replyTo, 'req-2');
    expect(response.payload['code'], 'invalidTarget');
  });

  test('§10 diagram instance routing: a request naming an unknown diagramInstanceId is a protocol error, never answered against the wrong diagram', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    var lookedUpInstanceId = '';
    await bridge.start(
      graph: fixtureGraph(),
      graphProviderByInstance: (id) {
        lookedUpInstanceId = id;
        return null; // No diagram open for any instance id in this test.
      },
      port: 0,
    );

    final transport = WifiOipTransport(transportId: 'raw-client-3');
    await transport.initialize();
    addTearDown(transport.shutdown);
    await transport.connect('127.0.0.1:${bridge.port}');

    final responseFuture = transport.receive().first;
    await transport.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.measurement,
      type: 'requestMeasurement',
      sessionId: 's1',
      messageId: 'req-3',
      timestamp: DateTime.now(),
      payload: {
        'measurementType': 'dcVoltage',
        'probeRedTargetId': 'battery',
        'probeBlackTargetId': 'chassisGround',
        'diagramInstanceId': 'workspace-tab-other',
      },
    ));
    final response = await responseFuture;
    expect(response.category, OipMessageCategory.error);
    expect(response.payload['code'], 'missingDiagramInstance');
    expect(lookedUpInstanceId, 'workspace-tab-other');
  });

  test('§10 diagram instance routing: a request naming a KNOWN diagramInstanceId is answered against that specific instance\'s own graph', () async {
    final bridge = OipHostBridgeService();
    addTearDown(bridge.stop);
    final otherGraph = EngineeringGraph(id: 'other', nodes: {
      'x': const EngineeringNode(id: 'x', category: NodeCategory.component, displayName: 'X', metadata: {'v2Category': 'power'}, properties: {'nominalVoltageV': 9.0}),
      'y': const EngineeringNode(id: 'y', category: NodeCategory.ground, displayName: 'Y'),
    }, relationships: {
      'w': const EngineeringRelationship(id: 'w', relationshipType: RelationshipType.connectedTo, sourceNode: 'x', targetNode: 'y'),
    });
    await bridge.start(
      graph: fixtureGraph(), // "primary" -- must NOT be what answers this request.
      graphProviderByInstance: (id) => id == 'workspace-tab-other' ? otherGraph : null,
      port: 0,
    );

    final transport = WifiOipTransport(transportId: 'raw-client-4');
    await transport.initialize();
    addTearDown(transport.shutdown);
    await transport.connect('127.0.0.1:${bridge.port}');

    final responseFuture = transport.receive().first;
    await transport.send(OipMessage(
      protocolVersion: '1.0',
      category: OipMessageCategory.measurement,
      type: 'requestMeasurement',
      sessionId: 's1',
      messageId: 'req-4',
      timestamp: DateTime.now(),
      payload: {
        'measurementType': 'dcVoltage',
        'probeRedTargetId': 'x',
        'probeBlackTargetId': 'y',
        'diagramInstanceId': 'workspace-tab-other',
      },
    ));
    final response = await responseFuture;
    expect(response.category, OipMessageCategory.measurement);
    expect(response.replyTo, 'req-4');
    // 9V source, single 0.1Ω wire straight to a real ground -- the
    // "single boundary, zero current" case, so this reads the FULL 9V,
    // not a divided value (proving this answered against `otherGraph`,
    // which has no competing second boundary the way `fixtureGraph`'s
    // own `lamp` does).
    expect(response.payload['value'], closeTo(9.0, 1e-6));
  });

  test('start() is idempotent and stop() releases the port', () async {
    final bridge = OipHostBridgeService();
    await bridge.start(graph: fixtureGraph(), port: 0);
    final firstPort = bridge.port;

    await bridge.start(graph: fixtureGraph(), port: 0); // no-op, already running
    expect(bridge.port, firstPort);

    await bridge.stop();
    expect(bridge.isRunning, isFalse);
  });

  group('AP-DIAGRAM-OIP-DMM-SYNC-001 -- real bidirectional sync with the diagram-embedded MultimeterController', () {
    test('a real MultimeterController change is broadcast to a connected client as mode + measurement', () async {
      final graph = fixtureGraph();
      final controller = MultimeterController(simulationService: DiagramSimulationService(engine: SimulationEngine()));
      addTearDown(controller.dispose);

      final bridge = OipHostBridgeService();
      addTearDown(bridge.stop);
      await bridge.start(graph: graph, port: 0, multimeterControllerProvider: () => controller);

      final client = await connectClient(bridge.port!);
      addTearDown(() => client.transport.shutdown());
      final plugin = client.plugin;

      // The controller's own real, diagram-panel-driven change -- not
      // anything this test sends over the wire itself.
      controller.setType(MeasurementType.voltageDc);
      controller.setProbeA(const ProbePoint(nodeId: 'lamp'));
      controller.setProbeB(const ProbePoint(nodeId: 'chassisGround'));
      await controller.measureElectrical(graph: graph, solver: const ElectricalSolver(), generationCounter: ElectricalSolutionGenerationCounter());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // The client's own mode mirrored the Host's real controller, with
      // no request ever sent from the client.
      expect(plugin.mode, DmmMeasurementMode.dcVoltage);
      expect(plugin.probeRed.currentTargetId, 'lamp');
      expect(plugin.probeBlack.currentTargetId, 'chassisGround');
      expect(plugin.lastMeasurement?.value, closeTo(6.3, 1e-6));
    });

    test('a real setDmmMode request from a connected client changes the real MultimeterController', () async {
      final controller = MultimeterController(simulationService: DiagramSimulationService(engine: SimulationEngine()));
      addTearDown(controller.dispose);

      final bridge = OipHostBridgeService();
      addTearDown(bridge.stop);
      await bridge.start(graph: fixtureGraph(), port: 0, multimeterControllerProvider: () => controller);

      final client = await connectClient(bridge.port!);
      addTearDown(() => client.transport.shutdown());

      expect(controller.selectedType, MeasurementType.voltageDc);
      // The instrument's own user tapping its mode dial -- setMode sends
      // the real setDmmMode request over the real transport.
      client.plugin.setMode(DmmMeasurementMode.resistance);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(controller.selectedType, MeasurementType.resistance);
    });
  });
}
