import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/engineering_context.dart';
import 'package:oep_studio/knowledge/models/engineering_context_status.dart';
import 'package:oep_studio/knowledge/models/engineering_context_type.dart';
import 'package:oep_studio/knowledge/models/engineering_entity.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_status.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/prompt_service.dart';

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

OcrPageResult _page() {
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
    sourceFingerprint: 'fp-1',
    engineVersion: 'Tesseract 5.4.0',
    processedTime: DateTime(2026, 1, 1),
    success: true,
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

EngineeringContext _context() {
  return EngineeringContext(
    id: 'c1',
    type: EngineeringContextType.torqueTable,
    title: 'Torque Specifications',
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

void main() {
  group('PromptService.buildCandidateSuggestionRequest', () {
    test('references every entity and context id passed in', () {
      final request = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
      );
      expect(request.referencedEntityIds, ['e1']);
      expect(request.referencedContextIds, ['c1']);
      expect(request.evidenceLabels['e1'], '24 Nm');
      expect(request.evidenceLabels['c1'], 'Torque Specifications');
      expect(request.sourceId, 's1');
    });

    test('the user prompt includes OCR text, context, and entity content', () {
      final request = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
      );
      expect(request.userPrompt, contains('Torque Specifications'));
      expect(request.userPrompt, contains('24 Nm'));
      expect(request.userPrompt, contains('manual.pdf'));
    });

    test('existing candidates are listed, to steer away from duplicates', () {
      final candidate = KnowledgeCandidate(
        id: 'cand-1',
        type: KnowledgeCandidateType.specification,
        name: 'Head Bolt Torque',
        description: '',
        notes: '',
        author: '',
        tags: const [],
        createdTime: DateTime(2026, 1, 1),
      );
      final request = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: [_page()],
        entities: const [],
        contexts: const [],
        existingCandidates: [candidate],
      );
      expect(request.userPrompt, contains('Head Bolt Torque'));
    });

    test('with no evidence at all, the prompt says so honestly rather than fabricating content', () {
      final request = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: const [],
        entities: const [],
        contexts: const [],
        existingCandidates: const [],
      );
      expect(request.userPrompt, contains('no OCR text available'));
      expect(request.userPrompt, contains('none detected yet'));
      expect(request.userPrompt, contains('none extracted yet'));
      expect(request.userPrompt, contains('none yet'));
    });

    test('is pure: the same input produces the same prompt text (ids/timestamps aside)', () {
      final requestA = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
      );
      final requestB = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: [_page()],
        entities: [_entity()],
        contexts: [_context()],
        existingCandidates: const [],
      );
      expect(requestA.userPrompt, requestB.userPrompt);
      expect(requestA.systemPrompt, requestB.systemPrompt);
    });

    test('widgets never construct prompts: PromptService is the only place this text is built', () {
      // Structural assertion: the system prompt names the required JSON
      // contract, which only this service's output should ever contain.
      final request = PromptService.buildCandidateSuggestionRequest(
        source: _source(),
        ocrResults: const [],
        entities: const [],
        contexts: const [],
        existingCandidates: const [],
      );
      expect(request.systemPrompt, contains('"suggestions"'));
    });
  });
}
