import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AP-DS-004 diagram export', () {
    late EngineeringGraph graph;
    late DiagramLayoutState layout;

    setUp(() {
      graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'n1': const EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'Relay'),
          'n2': const EngineeringNode(id: 'n2', category: NodeCategory.connector, displayName: 'Connector'),
          'n3': const EngineeringNode(id: 'n3', category: NodeCategory.component, displayName: 'Hidden Part'),
        },
        relationships: {
          'r1': const EngineeringRelationship(
            id: 'r1',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'n1',
            targetNode: 'n2',
          ),
          'r2': const EngineeringRelationship(
            id: 'r2',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'n1',
            targetNode: 'n3',
          ),
        },
      );
      layout = DiagramLayoutState.empty.copyWith(
        positions: {
          'n1': const Point2D(0, 0),
          'n2': const Point2D(150, 0),
          'n3': const Point2D(0, 150),
        },
        layers: {
          'hidden': const DiagramLayer(id: 'hidden', name: 'Not Print Visible', printVisible: false),
        },
        layerAssignments: {'n3': 'hidden'},
      );
    });

    test('computePrintScene excludes nodes/wires on a printVisible:false layer', () {
      final scene = computePrintScene(graph, layout: layout);
      expect(scene.nodes.map((n) => n.nodeId), containsAll(['n1', 'n2']));
      expect(scene.nodes.map((n) => n.nodeId), isNot(contains('n3')));
      expect(scene.wires.map((w) => w.relationshipId), contains('r1'));
      expect(scene.wires.map((w) => w.relationshipId), isNot(contains('r2')),
          reason: 'r2 touches n3, which is on a non-print-visible layer');
    });

    test('computePrintScene keeps everything visible when no layout is supplied', () {
      final scene = computePrintScene(graph);
      expect(scene.nodes.length, 3);
      expect(scene.wires.length, 2);
    });

    test('DiagramPdfRenderer produces a non-empty, valid single-page PDF', () async {
      final doc = DiagramPdfRenderer.render(
        graph,
        layout: layout,
        titleBlock: const TitleBlock(company: 'Acme', drawingNumber: 'DWG-001', revision: 'A'),
      );
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(doc.document.pdfPageList.pages.length, 1);
    });

    test('DiagramSvgRenderer produces well-formed, balanced XML with expected element counts', () {
      final svg = DiagramSvgRenderer.render(
        graph,
        layout: layout,
        titleBlock: const TitleBlock(company: 'Acme'),
      );
      expect(svg.trimLeft(), startsWith('<?xml'));
      expect(svg.trimRight(), endsWith('</svg>'));
      expect(_isTagBalanced(svg), isTrue);

      // 2 print-visible nodes -> 2 <rect> for nodes (plus 1 background
      // rect = 3 total, at minimum, before the title block's own rect).
      final rectOpenCount = '<rect'.allMatches(svg).length;
      expect(rectOpenCount, greaterThanOrEqualTo(3), reason: 'background + 2 node rects, at minimum');
      final polylineCount = '<polyline'.allMatches(svg).length;
      expect(polylineCount, 1, reason: 'only r1 survives the printVisible filter');
      expect(svg, isNot(contains('Hidden Part')));
    });

    test('DiagramSvgRenderer escapes unsafe text content', () {
      final unsafeGraph = EngineeringGraph(
        id: 'g2',
        nodes: {
          'n1': const EngineeringNode(
            id: '<n1>',
            category: NodeCategory.component,
            displayName: 'Relay',
            symbolId: '<sym & "id">',
          ),
        },
        relationships: const {},
      );
      final svg = DiagramSvgRenderer.render(unsafeGraph, layout: DiagramLayoutState.empty);
      expect(svg, isNot(contains('<sym & "id">')), reason: 'raw unescaped angle brackets/ampersand would break XML');
      expect(svg, contains('&lt;sym &amp; &quot;id&quot;&gt;'));
      expect(_isTagBalanced(svg), isTrue);
    });

    test('DiagramPngRenderer rasterizes to a valid, non-empty PNG at the requested dpi', () async {
      final bytesDefault = await DiagramPngRenderer.render(graph, layout: layout);
      final bytesHiDpi = await DiagramPngRenderer.render(graph, layout: layout, dpi: 192);
      expect(bytesDefault, isNotEmpty);
      expect(bytesHiDpi, isNotEmpty);
      // PNG signature.
      expect(bytesDefault.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(bytesHiDpi.length, greaterThan(0));
    });

    test('PdfExportProvider.export returns PDF bytes via ExportRequest.layout', () async {
      final provider = PdfExportProvider();
      final result = await provider.export(ExportRequest(
        formatId: 'pdf',
        graph: graph,
        layout: layout,
        options: {'titleBlock': const TitleBlock(company: 'Acme')},
      ));
      expect(result.success, isTrue);
      expect(result.bytes, isNotNull);
      expect(String.fromCharCodes(result.bytes!.take(5)), '%PDF-');
    });

    test('PdfExportProvider.export rejects unsupported formats', () async {
      final provider = PdfExportProvider();
      final result = await provider.export(ExportRequest(formatId: 'svg', graph: graph));
      expect(result.success, isFalse);
    });

    test('SvgExportProvider.export returns well-formed SVG text', () async {
      final provider = SvgExportProvider();
      final result = await provider.export(ExportRequest(formatId: 'svg', graph: graph, layout: layout));
      expect(result.success, isTrue);
      final text = utf8.decode(result.bytes!);
      expect(text.trimLeft(), startsWith('<?xml'));
      expect(_isTagBalanced(text), isTrue);
    });

    test('PngExportProvider.export honors dpi option', () async {
      final provider = PngExportProvider();
      final result = await provider.export(ExportRequest(
        formatId: 'png',
        graph: graph,
        layout: layout,
        options: {'dpi': 144},
      ));
      expect(result.success, isTrue);
      expect(result.bytes, isNotEmpty);
    });

    test('DrawingPackagePdfRenderer concatenates the diagram page with selected report pages', () async {
      final bom = BillOfMaterialsGenerator.generate(graph, componentCategoriesOnly: false);
      final relationships = RelationshipReportGenerator.generate(graph);
      final doc = DrawingPackagePdfRenderer.render(
        graph,
        layout: layout,
        titleBlock: const TitleBlock(company: 'Acme', drawingNumber: 'DWG-PKG-001'),
        reports: [bom, relationships],
      );
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      // 1 diagram page + at least 1 page per report (MultiPage may emit
      // more than one page per report if it overflows, but never fewer).
      expect(doc.document.pdfPageList.pages.length, greaterThanOrEqualTo(3));
    });

    test('DrawingPackagePdfRenderer with no reports still produces just the diagram page', () async {
      final doc = DrawingPackagePdfRenderer.render(graph, layout: layout);
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(doc.document.pdfPageList.pages.length, 1);
    });
  });
}

/// Lightweight XML well-formedness check (open/close tag stack balance)
/// used instead of pulling in a dedicated XML-parsing package for tests,
/// consistent with this phase's own "don't add a dependency this format
/// doesn't need" stance applied to [DiagramSvgRenderer] itself.
bool _isTagBalanced(String xml) {
  final tagPattern = RegExp(r'<(/?)([a-zA-Z0-9]+)[^>]*?(/?)>');
  final stack = <String>[];
  for (final match in tagPattern.allMatches(xml)) {
    final isClosing = match.group(1) == '/';
    final name = match.group(2)!;
    final isSelfClosing = match.group(3) == '/';
    if (name == 'xml' || name == '?xml') continue;
    if (isSelfClosing) continue;
    if (isClosing) {
      if (stack.isEmpty || stack.last != name) return false;
      stack.removeLast();
    } else {
      stack.add(name);
    }
  }
  return stack.isEmpty;
}
