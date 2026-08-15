import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/protocol/oip_version_negotiation.dart';

void main() {
  group('negotiateProtocolVersion', () {
    test('picks the highest mutually-supported version', () {
      final result = negotiateProtocolVersion(['1.0', '1.1', '2.0'], ['1.0', '1.1']);
      expect(result, '1.1');
    });

    test('returns null when there is no compatible version (§25: Connection Refused)', () {
      final result = negotiateProtocolVersion(['2.0'], ['1.0']);
      expect(result, isNull);
    });

    test('single shared version', () {
      expect(negotiateProtocolVersion(['1.0'], ['1.0']), '1.0');
    });
  });
}
