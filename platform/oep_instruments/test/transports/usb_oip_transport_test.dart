import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/protocol/oip_message.dart';
import 'package:oep_instruments_runtime/protocol/oip_message_category.dart';
import 'package:oep_instruments_runtime/transports/usb_oip_transport.dart';

/// UsbOipTransport is a disclosed, deliberate stub (see its own doc
/// comment) — these tests exist to prove it fails LOUDLY and
/// predictably rather than silently pretending to work, so nothing
/// downstream can accidentally treat a "connected" USB transport as
/// real.
void main() {
  group('UsbOipTransport (disclosed stub)', () {
    test('connect never silently succeeds -- it completes with UnimplementedError', () async {
      final transport = UsbOipTransport(transportId: 'usb-1');
      await expectLater(transport.connect('device-1'), throwsUnimplementedError);
    });

    test('send throws', () async {
      final transport = UsbOipTransport(transportId: 'usb-1');
      final message = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.heartbeat,
        type: 'ping',
        sessionId: 's1',
        messageId: 'm1',
        timestamp: DateTime(2026, 1, 1),
      );
      await expectLater(transport.send(message), throwsUnimplementedError);
    });

    test('state always reports disconnected', () {
      final transport = UsbOipTransport(transportId: 'usb-1');
      expect(transport.state.name, 'disconnected');
    });
  });
}
