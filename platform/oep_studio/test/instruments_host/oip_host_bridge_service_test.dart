import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/oep_instruments_runtime.dart';
import 'package:oep_studio/diagram_studio/instruments_host/oip_host_bridge_service.dart';

/// Real, end-to-end proof of the OIP Host bridge: a real
/// [WifiOipTransport] client sends a real `requestMeasurement` message,
/// [OipHostBridgeService] answers it using the real [SimulationEngine]
/// (no mocks) against a small fixture graph, and the client receives a
/// real `measurementResult` back over a real TCP loopback connection.
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
            properties: {'expectedValue': 12.6, 'expectedUnit': 'V'},
          ),
          'lamp': const EngineeringNode(
            id: 'lamp',
            category: NodeCategory.component,
            displayName: 'Lamp',
            properties: {'expectedValue': 12.6, 'expectedUnit': 'V'},
          ),
          'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'lamp'),
          'r2': const EngineeringRelationship(id: 'r2', relationshipType: RelationshipType.connectedTo, sourceNode: 'chassisGround', targetNode: 'lamp'),
        },
      );

  test('a real Digital Multimeter client requests a measurement and receives a real answer from SimulationEngine', () async {
    final engine = SimulationEngine();
    final bridge = OipHostBridgeService(engine: engine);
    addTearDown(bridge.stop);

    await bridge.start(graph: fixtureGraph(), port: 0);
    expect(bridge.isRunning, isTrue);

    final transport = WifiOipTransport(transportId: 'test-dmm');
    await transport.initialize();
    addTearDown(transport.shutdown);
    await transport.connect('127.0.0.1:${bridge.port}');

    final plugin = DigitalMultimeterPlugin();
    final session = EngineeringSession(id: 'client-session-1', hostId: 'oep_studio', owner: 'test');
    await plugin.initialize(PluginContext(hostId: 'oep_studio', session: session));
    plugin.connectTransport(transport);

    plugin.setMode(DmmMeasurementMode.dcVoltage);
    plugin.setProbeRedTarget('lamp');
    plugin.setProbeBlackTarget('chassisGround');

    await plugin.requestMeasurement();
    // The bridge's response travels back over a real socket -- give it a
    // real event-loop turn to arrive.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(plugin.lastMeasurement, isNotNull);
    expect(plugin.lastMeasurement!.value, 12.6);
    expect(plugin.lastMeasurement!.unit, 'V');
    expect(plugin.lastMeasurement!.source, 'simulationEngine');
  });

  test('start() is idempotent and stop() releases the port', () async {
    final engine = SimulationEngine();
    final bridge = OipHostBridgeService(engine: engine);
    await bridge.start(graph: fixtureGraph(), port: 0);
    final firstPort = bridge.port;

    await bridge.start(graph: fixtureGraph(), port: 0); // no-op, already running
    expect(bridge.port, firstPort);

    await bridge.stop();
    expect(bridge.isRunning, isFalse);
  });
}
