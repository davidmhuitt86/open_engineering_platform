import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('ValidationService', () {
    late SymbolLibrary symbols;
    late ValidationService validation;

    setUp(() async {
      symbols = SymbolLibrary(symbolsDirectory: 'assets/symbols');
      await symbols.initialize();
      validation = ValidationService(symbols: symbols);
    });

    test('clean graph produces no errors', () {
      final graph = (GraphBuilder(id: 'clean')
            ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'A',
              symbolId: 'battery',
            )
            ..addNode(
              id: 'b',
              category: NodeCategory.ground,
              displayName: 'B',
              symbolId: 'ground',
            )
            ..connect('a', 'b', id: 'r1'))
          .build();

      final report = validation.validate(graph);
      expect(report.hasErrors, isFalse);
    });

    test('detects broken relationships', () {
      final graph = EngineeringGraph.empty('broken').withRelationship(
        const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'missing_a',
          targetNode: 'missing_b',
        ),
      );
      final report = validation.validate(graph);
      expect(report.errors.where((f) => f.code == 'broken_relationship').length, 2);
    });

    test('detects unknown symbols', () {
      final graph = EngineeringGraph.empty('unknown').withNode(
        const EngineeringNode(
          id: 'a',
          category: NodeCategory.component,
          displayName: 'A',
          symbolId: 'not_a_real_symbol',
        ),
      );
      final report = validation.validate(graph);
      expect(report.findings.any((f) => f.code == 'unknown_symbol'), isTrue);
    });

    test('detects duplicate ports on a single node', () {
      final graph = EngineeringGraph.empty('dup_ports').withNode(
        const EngineeringNode(
          id: 'a',
          category: NodeCategory.component,
          displayName: 'A',
          symbolId: 'battery',
          ports: [
            Port(id: 'p1', name: 'P1'),
            Port(id: 'p1', name: 'P1 duplicate'),
          ],
        ),
      );
      final report = validation.validate(graph);
      expect(report.errors.any((f) => f.code == 'duplicate_port'), isTrue);
    });

    test('detects floating nodes', () {
      final graph = EngineeringGraph.empty('floating').withNode(
        const EngineeringNode(
          id: 'a',
          category: NodeCategory.component,
          displayName: 'A',
          symbolId: 'battery',
        ),
      );
      final report = validation.validate(graph);
      expect(report.findings.any((f) => f.code == 'floating_node'), isTrue);
    });

    test('detects invalid evidence mapping', () {
      final graph = EngineeringGraph.empty('bad_evidence').withNode(
        const EngineeringNode(
          id: 'a',
          category: NodeCategory.component,
          displayName: 'A',
          symbolId: 'battery',
          evidenceLinks: [
            EvidenceLink(id: 'e1', kind: EvidenceKind.text, sourceReference: ''),
          ],
        ),
      );
      final report = validation.validate(graph);
      expect(report.errors.any((f) => f.code == 'invalid_evidence_mapping'), isTrue);
    });
  });
}
