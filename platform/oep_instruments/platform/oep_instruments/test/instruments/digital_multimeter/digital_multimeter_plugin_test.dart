import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/digital_multimeter_plugin.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_measurement_mode.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_probe_jack.dart';
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
  });
}
