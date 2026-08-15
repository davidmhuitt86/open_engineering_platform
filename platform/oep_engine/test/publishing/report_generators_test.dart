import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('AP-DS-004 report generators', () {
    late EngineeringGraph graph;
    late DiagramLayoutState layout;

    setUp(() {
      graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'n1': const EngineeringNode(
            id: 'n1',
            category: NodeCategory.component,
            displayName: 'Ignition Relay',
            properties: {'manufacturer': 'Acme', 'manufacturerPartNumber': 'AR-100', 'quantity': 2},
          ),
          'n2': const EngineeringNode(
            id: 'n2',
            category: NodeCategory.connector,
            displayName: 'Main Connector',
            ports: [Port(id: 'p1', name: 'Pin 1'), Port(id: 'p2', name: 'Pin 2')],
          ),
          'n3': const EngineeringNode(id: 'n3', category: NodeCategory.wire, displayName: 'Wire Node'),
        },
        relationships: {
          'r1': const EngineeringRelationship(
            id: 'r1',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'n1',
            targetNode: 'n2',
            metadata: {'wireColor': 'Red', 'wireGauge': '18AWG'},
          ),
        },
      );
      layout = DiagramLayoutState.empty.copyWith(
        positions: {'n1': const Point2D(0, 0), 'n2': const Point2D(30, 40)},
        layers: {'harness1': const DiagramLayer(id: 'harness1', name: 'Engine Harness')},
        layerAssignments: {'n1': 'harness1', 'n2': 'harness1'},
      );
    });

    test('BillOfMaterialsGenerator includes only orderable-part categories by default', () {
      final bom = BillOfMaterialsGenerator.generate(graph);
      expect(bom.rows.length, 2, reason: 'Component and Connector are orderable; Wire is not');
      final relayRow = bom.rows.firstWhere((r) => r['description'] == 'Ignition Relay');
      expect(relayRow['manufacturer'], 'Acme');
      expect(relayRow['manufacturerPartNumber'], 'AR-100');
      expect(relayRow['quantity'], 2);
      final connectorRow = bom.rows.firstWhere((r) => r['description'] == 'Main Connector');
      expect(connectorRow['manufacturer'], '', reason: 'unpopulated properties render blank, not fabricated');
    });

    test('BillOfMaterialsGenerator(componentCategoriesOnly: false) includes every node', () {
      final bom = BillOfMaterialsGenerator.generate(graph, componentCategoriesOnly: false);
      expect(bom.rows.length, 3);
    });

    test('WireReportGenerator computes straight-line length and harness membership for connectedTo relationships', () {
      final report = WireReportGenerator.generate(graph, layout);
      expect(report.rows.length, 1);
      final row = report.rows.first;
      expect(row['wireColor'], 'Red');
      expect(row['wireGauge'], '18AWG');
      expect(row['source'], 'Ignition Relay');
      expect(row['destination'], 'Main Connector');
      expect(row['harnessMembership'], 'harness1');
      expect(row['lengthUnits'], closeTo(50.0, 0.01), reason: 'straight-line distance between (0,0) and (30,40) is 50');
    });

    test('ConnectorReportGenerator emits one row per pin and discloses the per-pin-connectivity limitation', () {
      final report = ConnectorReportGenerator.generate(graph);
      expect(report.rows.length, 2, reason: 'Main Connector has 2 ports; the Component node has no ports of its own kind counted here');
      expect(report.rows.every((r) => r['connector'] == 'Main Connector'), isTrue);
      expect(report.notes, isNotEmpty);
    });

    test('HarnessReportGenerator groups by layer assignment', () {
      final report = HarnessReportGenerator.generate(graph, layout);
      expect(report.rows.length, 2);
      expect(report.rows.every((r) => r['harness'] == 'Engine Harness'), isTrue);
    });

    test('RelationshipReportGenerator lists every relationship regardless of type', () {
      final report = RelationshipReportGenerator.generate(graph);
      expect(report.rows.single['type'], 'connectedTo');
      expect(report.rows.single['source'], 'Ignition Relay');
    });

    test('EngineeringObjectReportGenerator lists every node regardless of category', () {
      final report = EngineeringObjectReportGenerator.generate(graph);
      expect(report.rows.length, 3);
    });

    test('TabularReport sortedBy/filtered/groupedBy/withCustomColumn behave correctly', () {
      final report = BillOfMaterialsGenerator.generate(graph, componentCategoriesOnly: false);
      final sorted = report.sortedBy('description');
      expect(sorted.rows.first['description'], 'Ignition Relay', reason: '"Ignition Relay" < "Main Connector" < "Wire Node" alphabetically');
      final filtered = report.filtered((r) => r['category'] == 'component');
      expect(filtered.rows.length, 1);
      final grouped = report.groupedBy('category');
      expect(grouped.length, 3);
      final withCustom = report.withCustomColumn('doubled', 'Doubled Qty', (r) => (r['quantity'] as int? ?? 1) * 2);
      expect(withCustom.rows.firstWhere((r) => r['description'] == 'Ignition Relay')['doubled'], 4);
    });

    test('TabularReportRenderer.toCsv quotes fields containing commas/quotes and toMarkdown renders a valid table', () {
      final report = TabularReport(
        title: 'Test',
        generatedAt: DateTime(2026, 1, 1),
        columns: const ['a', 'b'],
        rows: const [
          {'a': 'has, comma', 'b': 'has "quote"'},
        ],
      );
      final csv = TabularReportRenderer.toCsv(report);
      expect(csv, contains('"has, comma"'));
      expect(csv, contains('"has ""quote"""'));

      final markdown = TabularReportRenderer.toMarkdown(report);
      expect(markdown, contains('# Test'));
      expect(markdown, contains('| a | b |'));
      expect(markdown, contains('has, comma'));
    });
  });
}
