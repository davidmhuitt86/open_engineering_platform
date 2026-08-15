import '../models/ai_request.dart';
import '../models/engineering_context.dart';
import '../models/engineering_entity.dart';
import '../models/knowledge_candidate.dart';
import '../models/ocr_page_result.dart';
import '../models/source_material.dart';
import 'knowledge_session_service.dart';

/// The Prompt Construction Service (Work Package 016
/// STUDIO-TASK-000047; SDD-022 § Prompt Construction): "Prompt
/// generation belongs entirely within the AI Analysis Service...
/// Widgets shall never construct prompts. Connection Manager shall
/// never construct prompts." This is the *only* place in Studio that
/// builds prompt text — `AiAnalysisService` calls this, a provider
/// only ever receives the resulting [AiRequest]'s two plain strings.
/// Pure — no I/O, no provider call; the same OCR text/Engineering
/// Entities/Engineering Contexts always produce the same prompt.
abstract final class PromptService {
  /// Builds a Knowledge Candidate suggestion request from [source]'s
  /// current deterministic evidence (STUDIO-TASK-000047: "Prompt
  /// generation shall use: OCR, Engineering Entities, Engineering
  /// Contexts"). [existingCandidates] is additionally included — SDD-022
  /// permissively lists "Existing Knowledge Candidates" among what AI
  /// "may consume" — so the prompt can ask the model to avoid
  /// suggesting an exact duplicate of something already curated.
  static AiRequest buildCandidateSuggestionRequest({
    required SourceMaterial source,
    required List<OcrPageResult> ocrResults,
    required List<EngineeringEntity> entities,
    required List<EngineeringContext> contexts,
    required List<KnowledgeCandidate> existingCandidates,
  }) {
    final evidenceLabels = <String, String>{};

    final contextLines = <String>[];
    for (final context in contexts) {
      evidenceLabels[context.id] = context.title;
      final childEntities = entities.where((entity) => context.childEntityIds.contains(entity.id)).toList();
      final childSummary = childEntities.isEmpty
          ? 'no child entities'
          : childEntities.map((entity) => '${entity.normalizedValue} (${entity.type.label})').join(', ');
      contextLines.add(
        '- [${context.id}] "${context.title}" (${context.type.label}, pages '
        '${context.pageStart}-${context.pageEnd}, confidence ${(context.confidence * 100).round()}%): '
        '$childSummary',
      );
    }

    final entityLines = <String>[];
    for (final entity in entities) {
      evidenceLabels[entity.id] = entity.normalizedValue;
      entityLines.add(
        '- [${entity.id}] "${entity.normalizedValue}" (${entity.type.label}, page ${entity.page}, '
        'confidence ${(entity.confidence * 100).round()}%)',
      );
    }

    final existingNames = [for (final candidate in existingCandidates) candidate.name];

    final ocrExcerpt = ocrResults
        .where((result) => result.success)
        .map((result) => result.plainText)
        .join('\n')
        .trim();
    const maxOcrChars = 4000;
    final truncatedOcr = ocrExcerpt.length > maxOcrChars ? '${ocrExcerpt.substring(0, maxOcrChars)}…' : ocrExcerpt;

    final userPrompt = StringBuffer()
      ..writeln('Source Material: ${source.originalFileName}')
      ..writeln()
      ..writeln('OCR Text:')
      ..writeln(truncatedOcr.isEmpty ? '(no OCR text available)' : truncatedOcr)
      ..writeln()
      ..writeln('Engineering Contexts:')
      ..writeln(contextLines.isEmpty ? '(none detected yet)' : contextLines.join('\n'))
      ..writeln()
      ..writeln('Engineering Entities:')
      ..writeln(entityLines.isEmpty ? '(none extracted yet)' : entityLines.join('\n'))
      ..writeln()
      ..writeln('Existing Knowledge Candidates (avoid suggesting an exact duplicate):')
      ..write(existingNames.isEmpty ? '(none yet)' : existingNames.join(', '));

    return AiRequest(
      id: KnowledgeSessionService.generateId('ai-request'),
      systemPrompt: _systemPrompt,
      userPrompt: userPrompt.toString(),
      sourceId: source.id,
      referencedEntityIds: [for (final entity in entities) entity.id],
      referencedContextIds: [for (final context in contexts) context.id],
      evidenceLabels: evidenceLabels,
      createdTime: DateTime.now(),
    );
  }

  /// The system prompt template — a fixed, replaceable string
  /// (SDD-022: "Prompt templates shall remain replaceable"), not a
  /// per-request-constructed value, since it describes the assistant's
  /// role and required output format rather than any specific evidence.
  static const String _systemPrompt =
      'You are an engineering documentation assistant helping an engineer '
      'curate a Knowledge Session for the Open Engineering Platform (OEP). '
      'You are given deterministic evidence already produced by earlier '
      'processing stages: OCR text, Engineering Entities (specific '
      'extracted values such as torque specifications or part numbers), '
      'and Engineering Contexts (logical groupings such as Torque Tables, '
      'Procedures, or Parts Lists).\n\n'
      'Propose Knowledge Candidate suggestions based only on the evidence '
      'provided. Never invent facts not present in the evidence. Every '
      'suggestion must cite the specific entity or context ids it is '
      'based on.\n\n'
      'Respond with a JSON object of exactly this shape, and nothing else:\n'
      '{"suggestions": [{"type": '
      '"component|procedure|specification|tool|material|fluid|warning|'
      'measurement|image|document", "name": "...", "description": "...", '
      '"confidence": 0.0-1.0, "reasoning": "...", '
      '"supportingEntityIds": ["..."], "supportingContextIds": ["..."]}]}';
}
