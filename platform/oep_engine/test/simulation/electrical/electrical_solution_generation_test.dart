import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-004 Phase A, §20.N-O / §12/§13 — proves a solved
/// state has a real, monotonically-comparable generation identity that
/// does not depend on wall-clock timestamps for ordering.
void main() {
  group('ElectricalSolutionGeneration', () {
    test('N: a solution has a generation/version identity', () {
      final generation = ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024));
      expect(generation.sequence, 0);
    });

    test('O: two solves can produce distinguishable generations', () {
      final counter = ElectricalSolutionGenerationCounter();
      final first = counter.next();
      final second = counter.next();

      expect(first, isNot(equals(second)));
      expect(second.isNewerThan(first), isTrue);
      expect(first.isNewerThan(second), isFalse);
      expect(first.compareTo(second), lessThan(0));
    });

    test('generation ordering is determined by sequence alone, not wall-clock time '
        '(§13 determinism -- staleness must not depend on clock resolution/skew)', () {
      // Deliberately construct an "earlier" wall-clock time on the LATER
      // sequence number, to prove ordering never consults solvedAt.
      final later = ElectricalSolutionGeneration(sequence: 5, solvedAt: DateTime(2020));
      final earlier = ElectricalSolutionGeneration(sequence: 3, solvedAt: DateTime(2030));

      expect(later.isNewerThan(earlier), isTrue,
          reason: 'sequence 5 must be newer than sequence 3 regardless of either solvedAt value');
    });

    test('a stale result (older generation) can be identified against a newer one -- '
        'the mechanism PRODUCT-READINESS-003 needed for stale-result rejection', () {
      final counter = ElectricalSolutionGenerationCounter();
      final requestOneGeneration = counter.next();
      final requestTwoGeneration = counter.next();

      // Simulate "request 1, request 2, result 2 arrives, result 1 arrives late".
      final results = <ElectricalSolutionGeneration>[requestTwoGeneration, requestOneGeneration];
      ElectricalSolutionGeneration? current;
      for (final incoming in results) {
        if (current == null || incoming.isNewerThan(current)) {
          current = incoming;
        }
      }
      expect(current, requestTwoGeneration, reason: 'the late-arriving older result must never overwrite the newer one');
    });
  });
}
