import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../performance/synthetic_diagram_generator.dart';

/// AP-DS-005 Performance (item 8): honest, disclosed synthetic-scale
/// measurement. Reuses `SyntheticDiagram.generate` from AP-DS-001B rather
/// than writing a new generator. This measures a full `run()` at 1,000 and
/// 10,000-object scale; it does NOT verify 100,000-object scale (not
/// feasible in the time available for this phase, matching this project's
/// disclosed precedent in `PERFORMANCE_REPORT.md` from AP-DS-001B) -- see
/// the final report for the explicit disclosure.
void main() {
  group('SimulationEngine performance (synthetic scale)', () {
    test('full run() completes in a reasonable time at 1,000 objects', () async {
      final diagram = SyntheticDiagram.generate(1000);
      final engine = SimulationEngine();
      final session = engine.createSession(diagram.graph);

      final stopwatch = Stopwatch()..start();
      await engine.run(session.id);
      stopwatch.stop();

      // Generous bound -- this is a smoke/regression bound, not a tight
      // performance SLA.
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('full run() completes in a reasonable time at 10,000 objects', () async {
      final diagram = SyntheticDiagram.generate(10000);
      final engine = SimulationEngine();
      final session = engine.createSession(diagram.graph);

      final stopwatch = Stopwatch()..start();
      await engine.run(session.id);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(20000));
    });
  });
}
