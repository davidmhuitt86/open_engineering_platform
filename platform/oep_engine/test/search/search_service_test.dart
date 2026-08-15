import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EngineeringGraph graph;
  late DiagramLayoutState layout;
  late SearchService search;

  setUp(() {
    final symbols = SymbolLibrary();
    symbols.register(const SymbolDefinition(
      identifier: 'battery',
      name: 'Battery Cell',
      category: SymbolCategory.electrical,
      geometry: SymbolGeometry(kind: GeometryKind.svgAsset, assetPath: 'x.svg'),
      aliases: ['batt'],
    ));
    search = SearchService(symbols: symbols);

    graph = (GraphBuilder(id: 'g')
          ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'Battery Positive',
              symbolId: 'battery')
          ..addNode(id: 'b', category: NodeCategory.ground, displayName: 'Chassis Ground')
          ..connect('a', 'b', id: 'r1', type: RelationshipType.grounds))
        .build();

    layout = DiagramLayoutState.empty.withLayer(const DiagramLayer(id: 'layer1', name: 'Power'));
    layout = layout.withAnnotation(const DiagramAnnotation(
      id: 'ann1',
      type: AnnotationType.textLabel,
      text: 'Torque spec: 12 Nm',
      position: Point2D(0, 0),
    ));
  });

  group('SearchService', () {
    test('finds nodes by displayName (case-insensitive)', () {
      final results = search.search(graph, layout, 'battery pos');
      expect(results.any((r) => r.kind == SearchResultKind.node && r.id == 'a'), isTrue);
    });

    test('finds nodes by category', () {
      final results = search.search(graph, layout, 'ground');
      expect(results.any((r) => r.kind == SearchResultKind.node && r.id == 'b'), isTrue);
    });

    test('finds relationships by relationshipType', () {
      final results = search.search(graph, layout, 'grounds');
      expect(results.any((r) => r.kind == SearchResultKind.relationship && r.id == 'r1'), isTrue);
    });

    test('finds symbols via the SymbolProvider, including aliases', () {
      final results = search.search(graph, layout, 'batt');
      expect(results.any((r) => r.kind == SearchResultKind.symbol && r.id == 'battery'), isTrue);
    });

    test('finds annotation text', () {
      final results = search.search(graph, layout, 'torque');
      expect(results.any((r) => r.kind == SearchResultKind.annotation && r.id == 'ann1'), isTrue);
    });

    test('finds layers by name', () {
      final results = search.search(graph, layout, 'power');
      expect(results.any((r) => r.kind == SearchResultKind.layer && r.id == 'layer1'), isTrue);
    });

    test('an empty query returns no results', () {
      expect(search.search(graph, layout, ''), isEmpty);
      expect(search.search(graph, layout, '   '), isEmpty);
    });

    test('a query matching nothing returns no results', () {
      expect(search.search(graph, layout, 'xyz-nonexistent'), isEmpty);
    });
  });
}
