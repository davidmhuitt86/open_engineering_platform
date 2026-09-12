import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/protocol/oip_message.dart';
import 'package:oep_instruments_runtime/protocol/oip_message_category.dart';

/// PRODUCT-READINESS-007 §11 — `replyTo` is additive request/response
/// correlation: a request never carries it; a response sets it to the
/// request's own `messageId`; an older message with no `replyTo` at all
/// still round-trips unchanged (backward compatibility).
void main() {
  group('OipMessage.replyTo (request/response correlation)', () {
    test('round-trips through toJson/fromJson when present', () {
      final message = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'measurementResult',
        sessionId: 's1',
        messageId: 'response-1',
        replyTo: 'request-1',
        timestamp: DateTime(2026, 1, 1),
        payload: {'value': 12.6},
      );
      final json = message.toJson();
      expect(json['replyTo'], 'request-1');
      final decoded = OipMessage.fromJson(json);
      expect(decoded.replyTo, 'request-1');
    });

    test('is null (and omitted from toJson) for a plain request, and for an older message with no replyTo at all', () {
      final request = OipMessage(
        protocolVersion: '1.0',
        category: OipMessageCategory.measurement,
        type: 'requestMeasurement',
        sessionId: 's1',
        messageId: 'request-1',
        timestamp: DateTime(2026, 1, 1),
      );
      expect(request.replyTo, isNull);
      expect(request.toJson().containsKey('replyTo'), isFalse);

      final legacyJson = {
        'protocolVersion': '1.0',
        'category': 'measurement',
        'type': 'measurementResult',
        'sessionId': 's1',
        'messageId': 'm1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'payload': <String, Object?>{},
      };
      final decoded = OipMessage.fromJson(legacyJson);
      expect(decoded.replyTo, isNull);
    });
  });
}
