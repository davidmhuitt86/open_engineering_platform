import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/digital_multimeter_plugin.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_measurement_mode.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_probe_jack.dart';
import 'package:oep_instruments_runtime/measurement/measurement_range.dart';
import 'package:oep_instruments_runtime/plugins/plugin_context.dart';
import 'package:oep_instruments_runtime/protocol/oip_message.dart';
import 'package:oep_instruments_runtime/protocol/oip_message_category.dart';
import 'package:oep_instruments_runtime/session/engineering_session.dart';
import 'package:oep_instruments_runtime/transports/oip_host_server.dart';
import 'package:oep_instruments_runtime/transports/wifi_oip_transport.dart';

void main() {
  group('DigitalMultimeterPlugin', () {
    late EngineeringSession session;
    late PluginContext context;

    setUp(() {
      session = EngineeringSession(id: 's1', hostId: 'host1', owner: 'diagramStudio');
      context = PluginContext(hostId: 'host1', session: session);
    });

    test('initialize registers every declared capability', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      expect(plugin.capabilities.supports('measurement.dcVoltage'), isTrue);
      expect(plugin.capabilities.supports('measurement.continuity'), isTrue);
      // PRODUCT-READINESS-007 §18/§19 -- diode is now a real, wired mode:
      // capability negotiation must be able to see that too, not just the
      // original four.
      expect(plugin.capabilities.supports('measurement.diode'), isTrue);
      expect(plugin.capabilities.validateDependencies(), isEmpty);
    });

    test('receiveMeasurement never computes a value -- it only carries what the message payload provided', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);

      final message = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm1',
        timestamp: DateTime(2026, 1, 1),
        payload: {
          'id': 'meas-1',
          'value': 12.6,
          'unit': 'V',
          'measurementType': 'dcVoltage',
          'source': 'simulationEngine',
          'quality': 'measured',
          'state': 'stable',
        },
      );
      plugin.receiveMeasurement(message);

      expect(plugin.lastMeasurement?.value, 12.6);
      expect(plugin.lastMeasurement?.unit, 'V');
      expect(plugin.lastMeasurement?.source, 'simulationEngine');
    });

    test('setMode changes the active measurement mode and notifies revision', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      var notified = 0;
      plugin.revision.addListener(() => notified++);

      plugin.setMode(DmmMeasurementMode.resistance);

      expect(plugin.mode, DmmMeasurementMode.resistance);
      expect(notified, 1);
    });

    test('probe placement updates probe state and target', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);

      plugin.setProbeRedTarget('pin-42');
      expect(plugin.probeRed.currentTargetId, 'pin-42');

      plugin.setProbeRedTarget(null);
      expect(plugin.probeRed.currentTargetId, isNull);
    });

    test('the red jack starts on VOhm, matching every non-current mode', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      expect(plugin.redJack, DmmProbeJack.voltageOhm);
      expect(plugin.isJackCorrectForMode, isTrue);
    });

    test('selecting Current mode without moving the jack is flagged as incorrect', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.setMode(DmmMeasurementMode.current);
      expect(plugin.isJackCorrectForMode, isFalse);

      plugin.setRedJack(DmmProbeJack.tenAmp);
      expect(plugin.isJackCorrectForMode, isTrue);
    });

    test('connectTransport + requestMeasurement sends a real request over a real transport, '
        'and the Host\'s response arrives back via receiveMeasurement', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final serverConnectionFuture = server.connections.first;

      final transport = WifiOipTransport(transportId: 'dmm-client');
      await transport.initialize();
      await transport.connect('127.0.0.1:${server.port}');
      final serverConnection = await serverConnectionFuture;

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.connectTransport(transport);
      expect(plugin.isConnected, isTrue);

      plugin.setProbeRedTarget('pin-1');
      plugin.setProbeBlackTarget('pin-gnd');

      final requestFuture = serverConnection.messages.first;
      await plugin.requestMeasurement();
      final request = await requestFuture;
      expect(request.type, 'requestMeasurement');
      expect(request.payload['probeRedTargetId'], 'pin-1');
      expect(request.payload['probeBlackTargetId'], 'pin-gnd');
      expect(request.sessionId, session.id);

      // The Host answers -- the plugin's own receiveMeasurement should
      // pick this up automatically via the subscription connectTransport
      // set up, with no extra wiring needed from the caller.
      serverConnection.send(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'r1',
        timestamp: DateTime(2026, 1, 1),
        payload: {'value': 5.0, 'unit': 'V', 'source': 'simulationEngine'},
      ));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(plugin.lastMeasurement?.value, 5.0);

      await plugin.disconnectTransport();
      expect(plugin.isConnected, isFalse);
      await transport.shutdown();
    });

    test('AP-DIAGRAM-OIP-DMM-SYNC-001: setMode, once connected, sends a real setDmmMode request to the Host', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final serverConnectionFuture = server.connections.first;

      final transport = WifiOipTransport(transportId: 'dmm-client-mode-sync');
      await transport.initialize();
      addTearDown(transport.shutdown);
      await transport.connect('127.0.0.1:${server.port}');
      final serverConnection = await serverConnectionFuture;

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.connectTransport(transport);

      final requestFuture = serverConnection.messages.first;
      plugin.setMode(DmmMeasurementMode.resistance);
      final request = await requestFuture;
      expect(request.category, OipMessageCategory.instrument);
      expect(request.type, 'setDmmMode');
      expect(request.payload['measurementType'], 'resistance');
    });

    test('AP-DIAGRAM-OIP-DMM-SYNC-001: a dmmStateChanged event from the Host updates mode/probes '
        'without sending anything back (no echo)', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final serverConnectionFuture = server.connections.first;

      final transport = WifiOipTransport(transportId: 'dmm-client-remote-state');
      await transport.initialize();
      addTearDown(transport.shutdown);
      await transport.connect('127.0.0.1:${server.port}');
      final serverConnection = await serverConnectionFuture;

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.connectTransport(transport);

      // Nothing this test sends should ever produce an outbound message
      // from the plugin -- if it did (an echo/ping-pong), this listener
      // would see it and the final `expect` below would fail.
      var echoed = false;
      serverConnection.messages.listen((_) => echoed = true);

      serverConnection.send(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.instrument,
        type: 'dmmStateChanged',
        sessionId: session.id,
        messageId: 'e1',
        timestamp: DateTime(2026, 1, 1),
        payload: {
          'measurementType': 'continuity',
          'probeRedTargetId': 'node-a',
          'probeRedPortId': 'port-1',
          'probeBlackTargetId': 'node-b',
          'probeBlackPortId': null,
        },
      ));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(plugin.mode, DmmMeasurementMode.continuity);
      expect(plugin.probeRed.currentTargetId, 'node-a');
      expect(plugin.probeBlack.currentTargetId, 'node-b');
      expect(echoed, isFalse);
    });

    test('PRODUCT-READINESS-007 §7: a stale measurementResult (replyTo pointing at a superseded request) is discarded', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final serverConnectionFuture = server.connections.first;

      final transport = WifiOipTransport(transportId: 'dmm-client-stale');
      await transport.initialize();
      addTearDown(transport.shutdown);
      await transport.connect('127.0.0.1:${server.port}');
      final serverConnection = await serverConnectionFuture;

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.connectTransport(transport);

      // Request #1.
      final firstRequestFuture = serverConnection.messages.first;
      await plugin.requestMeasurement();
      final firstRequest = await firstRequestFuture;

      // Request #2 -- immediately supersedes #1 (e.g. the user changed
      // probes/mode before #1's answer arrived).
      final secondRequestFuture = serverConnection.messages.first;
      await plugin.requestMeasurement();
      final secondRequest = await secondRequestFuture;
      expect(secondRequest.messageId, isNot(firstRequest.messageId));

      // #1's answer arrives AFTER #2 was sent -- must be discarded.
      serverConnection.send(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'stale-response',
        replyTo: firstRequest.messageId,
        timestamp: DateTime(2026, 1, 1),
        payload: {'value': 999.0, 'unit': 'V'},
      ));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(plugin.lastMeasurement, isNull, reason: 'the stale #1 response must never overwrite the still-outstanding #2');

      // #2's real answer arrives -- must be accepted.
      serverConnection.send(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'current-response',
        replyTo: secondRequest.messageId,
        timestamp: DateTime(2026, 1, 1),
        payload: {'value': 5.0, 'unit': 'V'},
      ));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(plugin.lastMeasurement?.value, 5.0);
    });

    test('receiveMeasurement parses a structured electricalState and a MeasurementRange value, never string-parsing a range', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);

      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-open',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'Ω', 'electricalState': 'open'},
      ));
      expect(plugin.lastMeasurement?.electricalState, 'open');
      expect(plugin.lastMeasurement?.value, isNull);

      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-range',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'V', 'electricalState': 'valid', 'valueRange': {'low': 13, 'high': 16}},
      ));
      expect(plugin.lastMeasurement?.value, const MeasurementRange(low: 13, high: 16));
    });

    test('requestMeasurement is a safe no-op when nothing is connected', () async {
      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      await plugin.requestMeasurement(); // must not throw
      expect(plugin.lastMeasurement, isNull);
    });

    testWidgets('render builds a real, working panel showing the current mode and measurement', (tester) async {
      // A realistic phone viewport -- the full instrument face (bezel
      // header through the probe jack row and footer) is naturally
      // taller than the default 800x600 test surface.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.setMode(DmmMeasurementMode.resistance);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: plugin.render),
        ),
      );

      expect(find.text('Ω'), findsOneWidget);
      expect(find.text('----'), findsOneWidget);
    });

    testWidgets('PRODUCT-READINESS-007 §3/§13/§18: OL, fault, unsupported, and a range value each render distinctly', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final plugin = DigitalMultimeterPlugin();
      await plugin.initialize(context);
      plugin.setMode(DmmMeasurementMode.resistance);

      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: Builder(builder: plugin.render)),
      );

      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-ol',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'Ω', 'electricalState': 'open'},
      ));
      await tester.pump();
      expect(find.text('OL'), findsOneWidget);

      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-fault',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'Ω', 'electricalState': 'fault'},
      ));
      await tester.pump();
      expect(find.text('FAULT'), findsOneWidget);

      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-unsupported',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'A', 'electricalState': 'unsupported'},
      ));
      await tester.pump();
      expect(find.text('UNSUPP'), findsOneWidget);

      plugin.setMode(DmmMeasurementMode.acVoltage);
      plugin.receiveMeasurement(OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: session.id,
        messageId: 'm-range',
        timestamp: DateTime(2026, 1, 1),
        payload: {'unit': 'V', 'electricalState': 'valid', 'valueRange': {'low': 13, 'high': 16}},
      ));
      await tester.pump();
      expect(find.text('13-16'), findsOneWidget);
    });
  });
}
