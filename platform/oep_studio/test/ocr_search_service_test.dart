import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/services/ocr_search_service.dart';

const _box = OcrBoundingBox(x: 0, y: 0, width: 0.1, height: 0.1);

OcrWord _word(String text, {required int order, required int line}) {
  return OcrWord(text: text, confidence: 0.9, boundingBox: _box, readingOrder: order, lineIndex: line);
}

OcrPageResult _page(int page, List<OcrWord> words) {
  return OcrPageResult(
    sourceId: 's1',
    page: page,
    words: words,
    imageWidth: 100,
    imageHeight: 100,
    sourceFingerprint: 'abc',
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: true,
  );
}

void main() {
  group('OcrSearchService.find', () {
    test('returns no matches for a blank query', () {
      final page = _page(1, [_word('Torque', order: 0, line: 0)]);
      expect(OcrSearchService.find(pageResults: [page], query: '   '), isEmpty);
    });

    test('matches a single word case-insensitively', () {
      final page = _page(1, [_word('Torque', order: 0, line: 0), _word('Spec', order: 1, line: 0)]);
      final matches = OcrSearchService.find(pageResults: [page], query: 'torque');
      expect(matches, hasLength(1));
      expect(matches.first.page, 1);
      expect(matches.first.wordIndices, [0]);
    });

    test('matches a multi-word phrase spanning two words on the same line', () {
      final page = _page(1, [
        _word('Torque', order: 0, line: 0),
        _word('Spec', order: 1, line: 0),
        _word('35', order: 2, line: 0),
        _word('Nm', order: 3, line: 0),
      ]);
      final matches = OcrSearchService.find(pageResults: [page], query: 'spec 35');
      expect(matches, hasLength(1));
      expect(matches.first.wordIndices, [1, 2]);
    });

    test('does not match across a line break', () {
      final page = _page(1, [
        _word('Torque', order: 0, line: 0),
        _word('Spec', order: 1, line: 1),
      ]);
      final matches = OcrSearchService.find(pageResults: [page], query: 'torque spec');
      expect(matches, isEmpty);
    });

    test('finds every occurrence across multiple pages, in page order', () {
      final page1 = _page(1, [_word('Torque', order: 0, line: 0)]);
      final page2 = _page(2, [_word('torque', order: 0, line: 0)]);
      final matches = OcrSearchService.find(pageResults: [page1, page2], query: 'torque');
      expect(matches.map((m) => m.page).toList(), [1, 2]);
    });

    test('a query with no occurrences returns an empty list', () {
      final page = _page(1, [_word('Torque', order: 0, line: 0)]);
      expect(OcrSearchService.find(pageResults: [page], query: 'gasket'), isEmpty);
    });
  });
}
