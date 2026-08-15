import '../models/engineering_entity.dart';
import '../models/engineering_entity_status.dart';
import '../models/ocr_bounding_box.dart';
import '../models/ocr_page_result.dart';
import '../models/ocr_word.dart';
import '../models/source_material.dart';
import 'engineering_pattern_library.dart';
import 'knowledge_session_service.dart';

/// The Engineering Entity Extraction Engine (Work Package 014
/// STUDIO-TASK-000038): "Analyze OCR text using deterministic pattern
/// matching." Pure — no I/O, no randomness, no async — given the same
/// `OcrPageResult`s this always produces the same entities
/// ("every extraction must be reproducible from the same OCR input").
/// `EntityExtractionEngine` is a synchronous, in-memory regex pass over
/// already-recognized OCR text; unlike `OcrPipelineService`, nothing
/// here calls an external process.
///
/// **Line-scoped, exactly like `OcrSearchService`** (Work Package 013):
/// each pattern is matched against one OCR line's reconstructed text at
/// a time, never against text spanning two lines — printed engineering
/// values (a torque-spec table row, a wire-gauge callout) are
/// overwhelmingly single-line, and this reuses an already-established,
/// already-documented precedent rather than inventing a second
/// cross-line joining convention.
abstract final class EngineeringEntityExtractionService {
  /// Extracts (or reuses already-extracted) entities for every page of
  /// [source]'s [ocrResults]. [existingEntities] may contain other
  /// sources' entities too; only [source]'s own are read or returned.
  /// A page whose `OcrPageResult.sourceFingerprint` still matches an
  /// already-extracted entity's own [EngineeringEntity.sourceFingerprint]
  /// is left completely untouched — preserving any
  /// [EngineeringEntityStatus] the engineer already assigned. A page
  /// whose fingerprint has changed (the source was re-OCR'd against
  /// updated content) has its old entities dropped and freshly
  /// re-extracted as new, pending suggestions — the same cache-reuse
  /// contract `OcrCacheService` established for OCR results themselves,
  /// applied one layer up.
  static List<EngineeringEntity> extractForSource({
    required SourceMaterial source,
    required List<OcrPageResult> ocrResults,
    required List<EngineeringEntity> existingEntities,
  }) {
    final existingForSource = existingEntities.where((entity) => entity.sourceId == source.id).toList();
    final resultsForSource = ocrResults.where((result) => result.sourceId == source.id && result.success);

    final merged = <EngineeringEntity>[];
    for (final page in resultsForSource) {
      final stillValid = existingForSource.where(
        (entity) => entity.page == page.page && entity.sourceFingerprint == page.sourceFingerprint,
      );
      if (stillValid.isNotEmpty) {
        merged.addAll(stillValid);
      } else {
        merged.addAll(_extractFromPage(source: source, page: page));
      }
    }
    return merged;
  }

  static List<EngineeringEntity> _extractFromPage({required SourceMaterial source, required OcrPageResult page}) {
    final entities = <EngineeringEntity>[];
    final now = DateTime.now();

    final lineWordIndices = <int, List<int>>{};
    for (var i = 0; i < page.words.length; i++) {
      lineWordIndices.putIfAbsent(page.words[i].lineIndex, () => []).add(i);
    }
    final orderedLines = lineWordIndices.values.toList()..sort((a, b) => a.first.compareTo(b.first));

    for (final wordIndices in orderedLines) {
      final starts = <int>[];
      final buffer = StringBuffer();
      for (final index in wordIndices) {
        starts.add(buffer.length);
        buffer.write(page.words[index].text);
        buffer.write(' ');
      }
      final lineText = buffer.toString();

      for (final pattern in EngineeringPatternLibrary.patterns) {
        for (final match in pattern.regex.allMatches(lineText)) {
          final overlapping = <int>[
            for (var k = 0; k < wordIndices.length; k++)
              if (starts[k] < match.end && starts[k] + page.words[wordIndices[k]].text.length > match.start)
                wordIndices[k],
          ];
          if (overlapping.isEmpty) continue;

          final matchedText = match.group(0)!;
          entities.add(
            EngineeringEntity(
              id: KnowledgeSessionService.generateId('entity'),
              type: pattern.type,
              matchedPatternId: pattern.id,
              extractedText: matchedText,
              normalizedValue: pattern.normalize(matchedText),
              sourceId: source.id,
              page: page.page,
              boundingBox: _unionBoundingBox([for (final index in overlapping) page.words[index].boundingBox]),
              confidence: _averageConfidence([for (final index in overlapping) page.words[index]]),
              characterStart: match.start,
              characterEnd: match.end,
              sourceFingerprint: page.sourceFingerprint,
              extractedTime: now,
              status: EngineeringEntityStatus.pending,
            ),
          );
        }
      }
    }
    return entities;
  }

  static OcrBoundingBox _unionBoundingBox(List<OcrBoundingBox> boxes) {
    var minX = boxes.first.x;
    var minY = boxes.first.y;
    var maxX = boxes.first.x + boxes.first.width;
    var maxY = boxes.first.y + boxes.first.height;
    for (final box in boxes.skip(1)) {
      if (box.x < minX) minX = box.x;
      if (box.y < minY) minY = box.y;
      if (box.x + box.width > maxX) maxX = box.x + box.width;
      if (box.y + box.height > maxY) maxY = box.y + box.height;
    }
    return OcrBoundingBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  }

  static double _averageConfidence(List<OcrWord> words) =>
      words.map((word) => word.confidence).reduce((a, b) => a + b) / words.length;
}
