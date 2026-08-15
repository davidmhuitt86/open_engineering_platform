import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/engineering_context_status.dart';
import 'package:oep_studio/knowledge/models/engineering_context_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/context_detection_service.dart';
import 'package:oep_studio/knowledge/services/engineering_entity_extraction_service.dart';

const _headingHeight = 0.04;
const _bodyHeight = 0.02;

/// Builds one OCR line's worth of words from [text]'s own words, each
/// sharing [lineIndex]/[height] so the line's own union bounding box
/// height is exactly [height] — the heading-detection heuristic's own
/// signal.
List<OcrWord> _lineWords(String text, {required int lineIndex, required double height, double y = 0.1}) {
  final words = text.split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      OcrWord(
        text: words[i],
        confidence: 0.92,
        boundingBox: OcrBoundingBox(x: 0.05 + i * 0.08, y: y, width: 0.07, height: height),
        readingOrder: lineIndex * 100 + i,
        lineIndex: lineIndex,
      ),
  ];
}

OcrPageResult _page(int page, List<List<OcrWord>> lines, {String fingerprint = 'fp-1'}) {
  return OcrPageResult(
    sourceId: 's1',
    page: page,
    words: [for (final line in lines) ...line],
    imageWidth: 1000,
    imageHeight: 1000,
    sourceFingerprint: fingerprint,
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: true,
  );
}

/// A plain filler body-height line — real documents have far more body
/// lines than headings, so the median-height heuristic needs at least
/// a few body lines to anchor on; a bare 2-line fixture (1 heading + 1
/// body) makes the *heading's own height* the median, defeating the
/// detector entirely. Padding fixtures with one or two of these keeps
/// them realistic without changing what's actually being asserted.
List<OcrWord> _filler(int lineIndex) =>
    _lineWords('This document explains general safety notes today.', lineIndex: lineIndex, height: _bodyHeight);

SourceMaterial _source() {
  return SourceMaterial(
    id: 's1',
    originalFileName: 'manual.pdf',
    localPath: '/tmp/manual.pdf',
    type: SourceMaterialType.pdf,
    sizeBytes: 100,
    importDate: DateTime(2026, 1, 1),
    addedBy: 'tester',
  );
}

void main() {
  group('ContextDetectionService.detectForSource', () {
    test('detects a major context from a heading, with its body entity as a child', () {
      final page1 = _page(1, [
        _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
        _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
        _filler(2),
      ]);
      final source = _source();
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: source,
        ocrResults: [page1],
        existingEntities: const [],
      );
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: entities,
        existingContexts: const [],
      );

      expect(contexts, hasLength(1));
      expect(contexts.first.type, EngineeringContextType.torqueTable);
      expect(contexts.first.title, 'Torque Specifications');
      expect(contexts.first.parentContextId, isNull);
      expect(contexts.first.childEntityIds, isNotEmpty);
      expect(entities.any((e) => contexts.first.childEntityIds.contains(e.id) && e.normalizedValue == '24 Nm'), isTrue);
    });

    test('a heading combining two keywords picks the more specific type (torque, not specification)', () {
      final page1 = _page(1, [
        _lineWords('Torque Specification Table', lineIndex: 0, height: _headingHeight),
        _lineWords('See values below for reference only text.', lineIndex: 1, height: _bodyHeight),
        _filler(2),
      ]);
      final source = _source();
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: const [],
      );
      expect(contexts, hasLength(1));
      expect(contexts.first.type, EngineeringContextType.torqueTable);
    });

    test('a callout (WARNING) is detected regardless of line height, nested inside the enclosing major context', () {
      final page1 = _page(1, [
        _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
        _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
        _lineWords('WARNING Do not exceed specified torque values.', lineIndex: 2, height: _bodyHeight),
      ]);
      final source = _source();
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: const [],
      );

      final major = contexts.firstWhere((c) => c.type == EngineeringContextType.torqueTable);
      final warning = contexts.firstWhere((c) => c.type == EngineeringContextType.warning);
      expect(warning.parentContextId, major.id);
    });

    test('a callout appearing before any major heading has no parent', () {
      final page1 = _page(1, [
        _lineWords('NOTE Read this manual carefully before use.', lineIndex: 0, height: _bodyHeight),
        _filler(1),
        _lineWords('Torque Specifications', lineIndex: 2, height: _headingHeight),
      ]);
      final source = _source();
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: const [],
      );
      final note = contexts.firstWhere((c) => c.type == EngineeringContextType.note);
      expect(note.parentContextId, isNull);
    });

    test('a major context spanning multiple pages reports its true page range', () {
      final page1 = _page(1, [
        _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
        _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
      ]);
      final page2 = _page(2, [
        _lineWords('Drain plug torque is 35 ft-lb value.', lineIndex: 0, height: _bodyHeight),
      ]);
      final page3 = _page(3, [
        _lineWords('Parts List', lineIndex: 0, height: _headingHeight),
        _lineWords('Replacement filter part 90915-YZZD4 needed.', lineIndex: 1, height: _bodyHeight),
      ]);
      final source = _source();
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1, page2, page3],
        entities: const [],
        existingContexts: const [],
      );
      final torque = contexts.firstWhere((c) => c.type == EngineeringContextType.torqueTable);
      expect(torque.pageStart, 1);
      expect(torque.pageEnd, 2);
      final parts = contexts.firstWhere((c) => c.type == EngineeringContextType.partsList);
      expect(parts.pageStart, 3);
      expect(parts.pageEnd, 3);
    });

    test('no headings on a page produces no contexts', () {
      final page1 = _page(1, [_lineWords('Just some ordinary body text here today.', lineIndex: 0, height: _bodyHeight)]);
      final source = _source();
      final contexts = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: const [],
      );
      expect(contexts, isEmpty);
    });

    test('an unchanged combined fingerprint reuses existing contexts, preserving status', () {
      final page1 = _page(1, [
        _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
        _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
        _filler(2),
      ]);
      final source = _source();
      final first = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: const [],
      );
      final accepted = [first.first.copyWith(status: EngineeringContextStatus.accepted)];

      final second = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [page1],
        entities: const [],
        existingContexts: accepted,
      );
      expect(second, hasLength(1));
      expect(second.first.status, EngineeringContextStatus.accepted);
      expect(second.first.id, first.first.id);
    });

    test('a changed fingerprint drops stale contexts and re-detects fresh pending ones', () {
      final oldPage = _page(
        1,
        [
          _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
          _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
          _filler(2),
        ],
        fingerprint: 'fp-1',
      );
      final source = _source();
      final first = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [oldPage],
        entities: const [],
        existingContexts: const [],
      );
      final accepted = [first.first.copyWith(status: EngineeringContextStatus.accepted)];

      final newPage = _page(
        1,
        [
          _lineWords('Parts List', lineIndex: 0, height: _headingHeight),
          _lineWords('Replacement filter part 90915-YZZD4 needed.', lineIndex: 1, height: _bodyHeight),
          _filler(2),
        ],
        fingerprint: 'fp-2',
      );
      final second = ContextDetectionService.detectForSource(
        source: source,
        ocrResults: [newPage],
        entities: const [],
        existingContexts: accepted,
      );
      expect(second, hasLength(1));
      expect(second.first.status, EngineeringContextStatus.pending);
      expect(second.first.type, EngineeringContextType.partsList);
    });

    test('only this source\'s own contexts are returned', () {
      final page1 = _page(1, [
        _lineWords('Torque Specifications', lineIndex: 0, height: _headingHeight),
        _lineWords('Cylinder head bolts torqued to 24 Nm total.', lineIndex: 1, height: _bodyHeight),
        _filler(2),
      ]);
      final otherSource = SourceMaterial(
        id: 's2',
        originalFileName: 'other.pdf',
        localPath: '/tmp/other.pdf',
        type: SourceMaterialType.pdf,
        sizeBytes: 10,
        importDate: DateTime(2026, 1, 1),
        addedBy: 'tester',
      );
      final otherPage = OcrPageResult(
        sourceId: 's2',
        page: 1,
        words: _lineWords('Parts List', lineIndex: 0, height: _headingHeight),
        imageWidth: 1000,
        imageHeight: 1000,
        sourceFingerprint: 'fp-other',
        engineVersion: 'Tesseract 5.4.0',
        processedTime: DateTime(2026, 1, 1),
        success: true,
      );
      final otherContexts = ContextDetectionService.detectForSource(
        source: otherSource,
        ocrResults: [otherPage],
        entities: const [],
        existingContexts: const [],
      );
      final contexts = ContextDetectionService.detectForSource(
        source: _source(),
        ocrResults: [page1],
        entities: const [],
        existingContexts: otherContexts,
      );
      expect(contexts.every((c) => c.sourceId == 's1'), isTrue);
    });
  });
}
