import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ai_suggestion_status.dart';
import 'package:oep_studio/knowledge/models/engineering_context.dart';
import 'package:oep_studio/knowledge/models/engineering_context_status.dart';
import 'package:oep_studio/knowledge/models/engineering_context_type.dart';
import 'package:oep_studio/knowledge/models/engineering_entity.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_status.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/ai_analysis_service.dart';
import 'package:oep_studio/knowledge/services/mock_ai_provider.dart';

const _box = OcrBoundingBox(x: 0, y: 0, width: 0.1, height: 0.1);

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

OcrPageResult _page({String fingerprint = 'fp-1'}) {
  return OcrPageResult(
    sourceId: 's1',
    page: 1,
    words: [
      const OcrWord(text: 'Torque', confidence: 0.9, boundingBox: _box, readingOrder: 0, lineIndex: 0),
      const OcrWord(text: '24', confidence: 0.9, boundingBox: _box, readingOrder: 1, lineIndex: 0),
      const OcrWord(text: 'Nm', confidence: 0.9, boundingBox: _box, readingOrder: 2, lineIndex: 0),
    ],
    imageWidth: 1000,
    imageHeight: 1000,
    sourceFingerprint: fingerprint,
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: true,
  );
}

EngineeringContext _context({String title = 'Torque Specifications'}) {
  return EngineeringContext(
    id: 'c1',
    type: EngineeringContextType.torqueTable,
    title: title,
    sourceId: 's1',
    pageStart: 1,
    pageEnd: 1,
    boundingRegion: _box,
    childEntityIds: const ['e1'],
    confidence: 0.9,
    sourceFingerprint: 'fp-1',
    detectedTime: DateTime(2026, 1, 1),
    status: EngineeringContextStatus.pending,
  );
}

EngineeringEntity _entity() {
  return EngineeringEntity(
    id: 'e1',
    type: EngineeringEntityType.torqueSpecification,
    matchedPatternId: 'torque-metric',
    extractedText: '24Nm',
    normalizedValue: '24 Nm',
    sourceId: 's1',
    page: 1,
    boundingBox: _box,
    confidence: 0.9,
    characterStart: 0,
    characterEnd: 4,
    sourceFingerprint: 'fp-1',
    extractedTime: DateTime(2026, 1, 1),
    status: EngineeringEntityStatus.pending,
  );
}

void main() {
  group('AiAnalysisService.analyzeForSource', () {
    test('produces real suggestions end-to-end via MockAiProvider', () async {
      final result = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
        existingSuggestions: const [],
        provider: MockAiProvider(),
      );
      expect(result.suggestions, isNotEmpty);
      expect(result.conversation, isNotNull);
      expect(result.conversation!.request.sourceId, 's1');
      expect(result.conversation!.response!.success, isTrue);
      expect(result.suggestions.every((s) => s.status == AiSuggestionStatus.pending), isTrue);
    });

    test('reuses existing suggestions unchanged when the combined fingerprint is unchanged', () async {
      final first = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
        existingSuggestions: const [],
        provider: MockAiProvider(),
      );
      final accepted = [first.suggestions.first.copyWith(status: AiSuggestionStatus.accepted, createdCandidateId: 'cand-1')];

      final second = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
        existingSuggestions: accepted,
        provider: MockAiProvider(),
      );
      expect(second.suggestions, hasLength(1));
      expect(second.suggestions.first.status, AiSuggestionStatus.accepted);
      expect(second.suggestions.first.createdCandidateId, 'cand-1');
      expect(second.conversation, isNull, reason: 'a cache hit should not have called the provider at all');
    });

    test('re-analyzes when the underlying context content changes, even if OCR did not', () async {
      final first = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
        existingSuggestions: const [],
        provider: MockAiProvider(),
      );
      final accepted = [first.suggestions.first.copyWith(status: AiSuggestionStatus.accepted)];

      final second = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context(title: 'Renamed Torque Section')],
        existingCandidates: const [],
        existingSuggestions: accepted,
        provider: MockAiProvider(),
      );
      expect(second.conversation, isNotNull, reason: 'changed context content should trigger fresh analysis');
      expect(second.suggestions.every((s) => s.status == AiSuggestionStatus.pending), isTrue);
    });

    test('only this source\'s own suggestions are read for cache comparison', () async {
      final otherSourceSuggestion = (await AiAnalysisService.analyzeForSource(
        source: SourceMaterial(
          id: 's2',
          originalFileName: 'other.pdf',
          localPath: '/tmp/other.pdf',
          type: SourceMaterialType.pdf,
          sizeBytes: 10,
          importDate: DateTime(2026, 1, 1),
          addedBy: 'tester',
        ),
        ocrResults: [
          OcrPageResult(
            sourceId: 's2',
            page: 1,
            words: [const OcrWord(text: 'Parts', confidence: 0.9, boundingBox: _box, readingOrder: 0, lineIndex: 0)],
            imageWidth: 1000,
            imageHeight: 1000,
            sourceFingerprint: 'fp-other',
            engineVersion: 'Tesseract 5.4.0',
            processedTime: DateTime(2026, 1, 1),
            success: true,
          ),
        ],
        entities: const [],
        contexts: const [],
        existingCandidates: const [],
        existingSuggestions: const [],
        provider: MockAiProvider(),
      )).suggestions;

      final result = await AiAnalysisService.analyzeForSource(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
        existingSuggestions: otherSourceSuggestion,
        provider: MockAiProvider(),
      );
      expect(result.suggestions.every((s) => s.sourceId == 's1'), isTrue);
    });
  });
}
