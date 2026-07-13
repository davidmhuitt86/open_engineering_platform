import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('EngineeringEngine', () {
    test('create() wires all Phase 1 default providers', () {
      final engine = EngineeringEngine.create();
      expect(engine.state, EngineState.uninitialized);
      for (final type in const [
        GraphProvider,
        SymbolProvider,
        ValidationProvider,
        NavigationProvider,
        SelectionProvider,
        ImportProvider,
        ExportProvider,
        SimulationProvider,
        SerializationProvider,
      ]) {
        expect(engine.registry.registeredTypes, contains(type));
      }
    });

    test('initialize() loads the seed symbol library and flips state', () async {
      final engine = EngineeringEngine.create();
      await engine.initialize();
      expect(engine.state, EngineState.initialized);
      expect(engine.registry.symbols.all.length, 14);
      await engine.shutdown();
    });

    test('diagnostics reports state, version, and open graphs', () async {
      final engine = EngineeringEngine.create();
      await engine.initialize();
      await engine.graph.create(id: 'demo');
      final diagnostics = engine.diagnostics();
      expect(diagnostics.state, EngineState.initialized);
      expect(diagnostics.version, EngineeringEngine.version);
      expect(diagnostics.openGraphIds, contains('demo'));
      expect(diagnostics.registeredSymbolCount, 14);
      await engine.shutdown();
    });

    test('validate() delegates to the registered ValidationProvider', () async {
      final engine = EngineeringEngine.create();
      await engine.initialize();
      final graph = await engine.graph.create(id: 'demo');
      final report = engine.validate(graph);
      expect(report.isClean, isTrue); // empty graph has no findings
      await engine.shutdown();
    });

    test('shutdown() is idempotent', () async {
      final engine = EngineeringEngine.create();
      await engine.initialize();
      await engine.shutdown();
      await engine.shutdown(); // should not throw
      expect(engine.state, EngineState.shutdown);
    });
  });
}
