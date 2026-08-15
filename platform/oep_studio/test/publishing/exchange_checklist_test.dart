import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/publishing/exchange_checklist.dart';
import 'package:oep_studio/diagram_studio/publishing/package_manifest.dart';

void main() {
  group('ExchangeChecklist', () {
    test('all items complete -> ready() is true', () {
      final items = ExchangeChecklist.build(
        titleBlock: const TitleBlock(company: 'Acme', drawingNumber: 'DWG-1', revision: 'A'),
        validationPassed: true,
        validationRun: true,
        bomRowCount: 3,
        nodeCount: 10,
      );
      expect(ExchangeChecklist.ready(items), isTrue);
      expect(items.every((i) => i.complete), isTrue);
    });

    test('empty title block and no validation run -> ready() is false, with honest details', () {
      final items = ExchangeChecklist.build(
        titleBlock: TitleBlock.empty,
        validationPassed: false,
        validationRun: false,
        bomRowCount: 0,
        nodeCount: 0,
      );
      expect(ExchangeChecklist.ready(items), isFalse);
      final validationItem = items.firstWhere((i) => i.label == 'Validation passing');
      expect(validationItem.complete, isFalse);
      expect(validationItem.detail, contains('not been run'));
    });

    test('validation run but failed is distinguished from never run', () {
      final ranAndFailed = ExchangeChecklist.build(
        titleBlock: TitleBlock.empty,
        validationPassed: false,
        validationRun: true,
        bomRowCount: 0,
        nodeCount: 0,
      );
      final item = ranAndFailed.firstWhere((i) => i.label == 'Validation passing');
      expect(item.detail, contains('failures'));
    });
  });

  group('PackageManifest', () {
    test('toMarkdown lists diagram identity, title block snapshot, and included reports', () {
      final manifest = PackageManifest(
        diagramTitle: 'diagram-a.json',
        generatedAt: DateTime(2026, 8, 1),
        includedReports: const ['Bill of Materials', 'Wire List'],
        titleBlockSnapshot: const TitleBlock(drawingNumber: 'DWG-1', revision: 'C'),
      );
      final markdown = manifest.toMarkdown();

      expect(markdown, contains('Package Manifest'));
      expect(markdown, contains('diagram-a.json'));
      expect(markdown, contains('DWG-1'));
      expect(markdown, contains('Bill of Materials'));
      expect(markdown, contains('Wire List'));
    });

    test('toJson round-trips the title block snapshot', () {
      final manifest = PackageManifest(
        diagramTitle: 'x',
        generatedAt: DateTime(2026, 1, 1),
        includedReports: const [],
        titleBlockSnapshot: const TitleBlock(company: 'Acme'),
      );
      final json = manifest.toJson();
      expect((json['titleBlockSnapshot'] as Map)['company'], 'Acme');
    });
  });
}
