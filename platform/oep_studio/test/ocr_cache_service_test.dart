import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/services/ocr_cache_service.dart';

OcrPageResult _result(int page, {String fingerprint = 'abc', bool success = true}) {
  return OcrPageResult(
    sourceId: 's1',
    page: page,
    words: const [],
    imageWidth: 100,
    imageHeight: 100,
    sourceFingerprint: fingerprint,
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: success,
  );
}

void main() {
  group('isCacheValid', () {
    test('true for a successful result whose fingerprint matches', () {
      final valid = OcrCacheService.isCacheValid(
        existingResults: [_result(1, fingerprint: 'abc')],
        page: 1,
        currentFingerprint: 'abc',
      );
      expect(valid, isTrue);
    });

    test('false when no result exists for that page', () {
      final valid = OcrCacheService.isCacheValid(
        existingResults: [_result(1)],
        page: 2,
        currentFingerprint: 'abc',
      );
      expect(valid, isFalse);
    });

    test('false when the fingerprint no longer matches (source changed)', () {
      final valid = OcrCacheService.isCacheValid(
        existingResults: [_result(1, fingerprint: 'old')],
        page: 1,
        currentFingerprint: 'new',
      );
      expect(valid, isFalse);
    });

    test('false for a previously-failed page even with a matching fingerprint — never cached as a permanent failure', () {
      final valid = OcrCacheService.isCacheValid(
        existingResults: [_result(1, fingerprint: 'abc', success: false)],
        page: 1,
        currentFingerprint: 'abc',
      );
      expect(valid, isFalse);
    });
  });

  group('pagesNeedingProcessing', () {
    test('an empty cache needs every page', () {
      final pages = OcrCacheService.pagesNeedingProcessing(
        existingResults: const [],
        pageCount: 3,
        currentFingerprint: 'abc',
      );
      expect(pages, [1, 2, 3]);
    });

    test('a fully valid cache needs nothing', () {
      final pages = OcrCacheService.pagesNeedingProcessing(
        existingResults: [_result(1, fingerprint: 'abc'), _result(2, fingerprint: 'abc')],
        pageCount: 2,
        currentFingerprint: 'abc',
      );
      expect(pages, isEmpty);
    });

    test('only the stale/missing pages are listed when the source changed', () {
      final pages = OcrCacheService.pagesNeedingProcessing(
        existingResults: [_result(1, fingerprint: 'old'), _result(2, fingerprint: 'new')],
        pageCount: 3,
        currentFingerprint: 'new',
      );
      expect(pages, [1, 3]);
    });
  });
}
