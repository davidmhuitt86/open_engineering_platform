import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/protocol/oip_message.dart';
import 'package:oep_instruments_runtime/protocol/oip_message_category.dart';
import 'package:oep_instruments_runtime/transports/oip_host_server.dart';
import 'package:oep_instruments_runtime/transports/wifi_oip_transport.dart';

/// Real loopback test: an [OipHostServer] listening on localhost, a real
/// [WifiOipTransport] client connecting to it, and real bytes flowing
/// both directions over a real TCP socket — no mocks. This is the
/// concrete proof this transport actually works end to end, distinct
/// from the state-machine/registry tests elsewhere in this package that
/// don't touch real I/O.
void main() {
  group('WifiOipTransport <-> OipHostServer (real TCP loopback)', () {
    test('client connects, server accepts, and messages flow both directions', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);

      final serverConnectionFuture = server.connections.first;

      final client = WifiOipTransport(transportId: 'test-client');
      await client.initialize();
      addTearDown(client.shutdown);
      await client.connect('127.0.0.1:${server.port}');

      final serverConnection = await serverConnectionFuture;

      // Client -> Server
      final clientMessage = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'requestMeasurement',
        sessionId: 's1',
        messageId: 'm1',
        timestamp: DateTime(2026, 1, 1),
        payload: {'measurementType': 'dcVoltage'},
      );
      final serverReceivedFuture = serverConnection.messages.first;
      await client.send(clientMessage);
      final serverReceived = await serverReceivedFuture;
      expect(serverReceived.type, 'requestMeasurement');
      expect(serverReceived.payload['measurementType'], 'dcVoltage');

      // Server -> Client
      final resultMessage = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: 's1',
        messageId: 'm2',
        timestamp: DateTime(2026, 1, 1),
        payload: {'value': 12.6, 'unit': 'V'},
      );
      final clientReceivedFuture = client.receive().first;
      serverConnection.send(resultMessage);
      final clientReceived = await clientReceivedFuture;
      expect(clientReceived.type, 'measurementResult');
      expect(clientReceived.payload['value'], 12.6);
    });

    test('multiple messages in sequence are each decoded correctly (framing works)', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final serverConnectionFuture = server.connections.first;

      final client = WifiOipTransport(transportId: 'test-client-2');
      await client.initialize();
      addTearDown(client.shutdown);
      await client.connect('127.0.0.1:${server.port}');
      final serverConnection = await serverConnectionFuture;

      final received = <OipMessage>[];
      final subscription = serverConnection.messages.listen(received.add);
      addTearDown(subscription.cancel);

      for (var i = 0; i < 5; i++) {
        await client.send(OipMessage(
          protocolVersion: '1.0',
          category: OipMessageCategory.heartbeat,
          type: 'ping',
          sessionId: 's1',
          messageId: 'm$i',
          timestamp: DateTime(2026, 1, 1),
        ));
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received.map((m) => m.messageId).toList(), ['m0', 'm1', 'm2', 'm3', 'm4']);
    });

    test('disconnect closes the client side cleanly', () async {
      final server = await OipHostServer.bind(address: '127.0.0.1', port: 0);
      addTearDown(server.close);
      final client = WifiOipTransport(transportId: 'test-client-3');
      await client.initialize();
      await client.connect('127.0.0.1:${server.port}');
      await client.disconnect();
      expect(() => client.send(OipMessage(
            protocolVersion: '1.0',
            category: OipMessageCategory.heartbeat,
            type: 'ping',
            sessionId: 's1',
            messageId: 'm1',
            timestamp: DateTime(2026, 1, 1),
          )), throwsStateError);
    });
  });
}
