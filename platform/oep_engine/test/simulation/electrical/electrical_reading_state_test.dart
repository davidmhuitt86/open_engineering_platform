import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-004 Phase A, §20.C-F — proves every required
/// distinction in the explicit reading-state vocabulary is real: each
/// state is genuinely different data, not just a different label on the
/// same collapsed representation (the exact failure mode PRODUCT-
/// READINESS-002/003/004 repeatedly found in the Legacy V2 solver and its
/// Android/OIP consumers).
void main() {
  group('ElectricalReadingState distinctions', () {
    test('C: zero voltage is distinct from unknown', () {
      final zero = ElectricalReading.valid(0, unit: 'V');
      final unknown = ElectricalReading.unknown(unit: 'V');

      expect(zero.state, ElectricalReadingState.valid);
      expect(zero.value, 0);
      expect(unknown.state, ElectricalReadingState.unknown);
      expect(unknown.value, isNull);
      expect(zero, isNot(equals(unknown)));
    });

    test('D: open circuit is distinct from zero', () {
      final zero = ElectricalReading.valid(0, unit: 'V');
      final open = ElectricalReading.open(unit: 'V');

      expect(open.state, ElectricalReadingState.open);
      expect(open.value, isNull, reason: 'an open reading must never carry a fabricated 0');
      expect(zero, isNot(equals(open)));
    });

    test('E: fault is distinct from open', () {
      final open = ElectricalReading.open();
      final fault = ElectricalReading.fault(note: 'short-to-ground fault active');

      expect(fault.state, ElectricalReadingState.fault);
      expect(fault.value, isNull);
      expect(open, isNot(equals(fault)));
    });

    test('F: unsupported is distinct from unknown', () {
      final unknown = ElectricalReading.unknown();
      final unsupported = ElectricalReading.unsupported(note: 'current is not modeled by this solver');

      expect(unsupported.state, ElectricalReadingState.unsupported);
      expect(unsupported.value, isNull);
      expect(unknown, isNot(equals(unsupported)));
    });

    test('every non-valid state constructor refuses to carry a numeric value', () {
      for (final reading in [
        ElectricalReading.unknown(),
        ElectricalReading.unreached(),
        ElectricalReading.open(),
        ElectricalReading.overload(),
        ElectricalReading.fault(),
        ElectricalReading.unsupported(),
      ]) {
        expect(reading.value, isNull, reason: '${reading.state} must never carry a value');
        expect(reading.isValid, isFalse);
      }
    });

    test('round-trips through JSON without losing the state/value distinction', () {
      for (final reading in [
        ElectricalReading.valid(0, unit: 'V'),
        ElectricalReading.valid(12.6, unit: 'V'),
        ElectricalReading.unknown(unit: 'V'),
        ElectricalReading.unreached(unit: 'V'),
        ElectricalReading.open(unit: 'V'),
        ElectricalReading.overload(unit: 'Ω'),
        ElectricalReading.fault(unit: 'V', note: 'short'),
        ElectricalReading.unsupported(unit: 'A'),
      ]) {
        final roundTripped = ElectricalReading.fromJson(reading.toJson());
        expect(roundTripped, equals(reading));
      }
    });
  });
}
