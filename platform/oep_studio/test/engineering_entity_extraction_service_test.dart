import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_status.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/engineering_entity_extraction_service.dart';

OcrWord _word(String text, {required int order, required double confidence, double x = 0}) {
  return OcrWord(
    text: text,
    confidence: confidence,
    boundingBox: OcrBoundingBox(x: x, y: 0.1, width: 0.05, height: 0.05),
    readingOrder: order,
    lineIndex: 0,
  );
}

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

OcrPageResult _page(int page, List<OcrWord> words, {String fingerprint = 'fp-1'}) {
  return OcrPageResult(
    sourceId: 's1',
    page: page,
    words: words,
    imageWidth: 1000,
    imageHeight: 1000,
    sourceFingerprint: fingerprint,
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: true,
  );
}

void main() {
  group('EngineeringEntityExtractionService.extractForSource', () {
    test('extracts a torque entity from a line split across OCR words', () {
      final page = _page(1, [
        _word('Torque', order: 0, confidence: 0.9, x: 0),
        _word('24', order: 1, confidence: 0.95, x: 0.2),
        _word('Nm', order: 2, confidence: 0.85, x: 0.3),
      ]);
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: const [],
      );
      expect(entities, hasLength(1));
      expect(entities.first.type, EngineeringEntityType.torqueSpecification);
      expect(entities.first.normalizedValue, '24 Nm');
      expect(entities.first.status, EngineeringEntityStatus.pending);
    });

    test('confidence is the average of the overlapping words only', () {
      final page = _page(1, [
        _word('Torque', order: 0, confidence: 1.0, x: 0),
        _word('24', order: 1, confidence: 0.9, x: 0.2),
        _word('Nm', order: 2, confidence: 0.8, x: 0.3),
      ]);
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: const [],
      );
      // "24 Nm" overlaps the "24" (0.9) and "Nm" (0.8) words, not "Torque".
      expect(entities.first.confidence, closeTo(0.85, 1e-9));
    });

    test('bounding box is the union of every overlapping word', () {
      final page = _page(1, [
        _word('24', order: 0, confidence: 0.9, x: 0.2),
        _word('Nm', order: 1, confidence: 0.9, x: 0.3),
      ]);
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: const [],
      );
      final box = entities.first.boundingBox;
      expect(box.x, 0.2);
      expect(box.width, closeTo(0.15, 1e-9)); // from x=0.2 to x=0.3+0.05
    });

    test('a page whose fingerprint is unchanged reuses existing entities, preserving status', () {
      final page = _page(1, [
        _word('24', order: 0, confidence: 0.9, x: 0.2),
        _word('Nm', order: 1, confidence: 0.9, x: 0.3),
      ], fingerprint: 'fp-1');
      final first = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: const [],
      );
      final accepted = [first.first.copyWith(status: EngineeringEntityStatus.accepted, createdCandidateId: 'c1')];

      final second = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: accepted,
      );
      expect(second, hasLength(1));
      expect(second.first.status, EngineeringEntityStatus.accepted);
      expect(second.first.createdCandidateId, 'c1');
      expect(second.first.id, first.first.id);
    });

    test('a page whose fingerprint changed drops stale entities and re-extracts fresh pending ones', () {
      final oldPage = _page(1, [
        _word('24', order: 0, confidence: 0.9, x: 0.2),
        _word('Nm', order: 1, confidence: 0.9, x: 0.3),
      ], fingerprint: 'fp-1');
      final first = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [oldPage],
        existingEntities: const [],
      );
      final accepted = [first.first.copyWith(status: EngineeringEntityStatus.accepted)];

      final newPage = _page(1, [
        _word('35', order: 0, confidence: 0.9, x: 0.2),
        _word('Nm', order: 1, confidence: 0.9, x: 0.3),
      ], fingerprint: 'fp-2');
      final second = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [newPage],
        existingEntities: accepted,
      );
      expect(second, hasLength(1));
      expect(second.first.status, EngineeringEntityStatus.pending);
      expect(second.first.normalizedValue, '35 Nm');
      expect(second.first.sourceFingerprint, 'fp-2');
    });

    test('a failed OCR page produces no entities', () {
      final failedPage = OcrPageResult(
        sourceId: 's1',
        page: 1,
        words: const [],
        imageWidth: 0,
        imageHeight: 0,
        sourceFingerprint: 'fp-1',
        engineVersion: 'Tesseract 5.4.0',
        processedTime: DateTime(2026, 1, 1),
        success: false,
        errorMessage: 'OCR failed',
      );
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [failedPage],
        existingEntities: const [],
      );
      expect(entities, isEmpty);
    });

    test('only this source\'s own entities are returned, even if existingEntities has other sources\' too', () {
      final page = _page(1, [_word('24', order: 0, confidence: 0.9, x: 0.2), _word('Nm', order: 1, confidence: 0.9, x: 0.3)]);
      final otherSourceEntity = EngineeringEntityExtractionService.extractForSource(
        source: SourceMaterial(
          id: 's2',
          originalFileName: 'other.pdf',
          localPath: '/tmp/other.pdf',
          type: SourceMaterialType.pdf,
          sizeBytes: 10,
          importDate: DateTime(2026, 1, 1),
          addedBy: 'tester',
        ),
        ocrResults: [_page(1, [_word('12', order: 0, confidence: 0.9, x: 0.2), _word('V', order: 1, confidence: 0.9, x: 0.3)])],
        existingEntities: const [],
      );
      final entities = EngineeringEntityExtractionService.extractForSource(
        source: _source(),
        ocrResults: [page],
        existingEntities: otherSourceEntity,
      );
      expect(entities.every((e) => e.sourceId == 's1'), isTrue);
    });
  });
}
