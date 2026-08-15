import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/ai_analysis_exception.dart';
import '../models/ai_conversation.dart';
import '../models/ai_response.dart';
import '../models/ai_suggestion.dart';
import '../models/engineering_context.dart';
import '../models/engineering_entity.dart';
import '../models/knowledge_candidate.dart';
import '../models/ocr_page_result.dart';
import '../models/source_material.dart';
import 'ai_provider.dart';
import 'ai_suggestion_parser.dart';
import 'prompt_service.dart';

/// The result of one `AiAnalysisService.analyzeForSource` call: the
/// resulting suggestions, and — only when a provider was actually
/// invoked — the `AiConversation` that produced them (`null` when an
/// unchanged combined fingerprint let the whole-source cache reuse
/// the prior suggestions untouched, so nothing was actually sent).
typedef AiAnalysisResult = ({List<AiSuggestion> suggestions, AiConversation? conversation});

/// The AI Analysis Service (Work Package 016 STUDIO-TASK-000046/000047)
/// — orchestrates `PromptService` → `AiProvider` → `AiSuggestionParser`.
/// The only place in Studio that calls an `AiProvider`; nothing else
/// (not the Connection Manager, not any widget) talks to a provider
/// directly.
abstract final class AiAnalysisService {
  /// Analyzes [source]'s current deterministic evidence, reusing
  /// [existingSuggestions] unchanged if nothing about that evidence has
  /// actually changed since they were produced — "Re-analysis shall
  /// occur only when deterministic engineering evidence changes"
  /// (SDD-022), the same whole-source cache-reuse contract Work
  /// Package 015 established for Engineering Contexts, applied one
  /// layer up. Throws [AiAnalysisException] if the provider fails or
  /// its response cannot be parsed.
  static Future<AiAnalysisResult> analyzeForSource({
    required SourceMaterial source,
    required List<OcrPageResult> ocrResults,
    required List<EngineeringEntity> entities,
    required List<EngineeringContext> contexts,
    required List<KnowledgeCandidate> existingCandidates,
    required List<AiSuggestion> existingSuggestions,
    required AiProvider provider,
  }) async {
    final ocrForSource = ocrResults.where((result) => result.sourceId == source.id && result.success).toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    final entitiesForSource = entities.where((entity) => entity.sourceId == source.id).toList();
    final contextsForSource = contexts.where((context) => context.sourceId == source.id).toList();

    final combinedFingerprint = computeCombinedFingerprint(
      ocrResults: ocrForSource,
      entities: entitiesForSource,
      contexts: contextsForSource,
    );

    final existingForSource = existingSuggestions.where((suggestion) => suggestion.sourceId == source.id).toList();
    if (existingForSource.isNotEmpty &&
        existingForSource.every((suggestion) => suggestion.sourceFingerprint == combinedFingerprint)) {
      return (suggestions: existingForSource, conversation: null);
    }

    final request = PromptService.buildCandidateSuggestionRequest(
      source: source,
      ocrResults: ocrForSource,
      entities: entitiesForSource,
      contexts: contextsForSource,
      existingCandidates: existingCandidates,
    );

    final AiResponse response;
    try {
      response = await provider.complete(request);
    } catch (error) {
      throw AiAnalysisException('The AI provider failed to respond: $error');
    }

    if (!response.success) {
      throw AiAnalysisException(response.errorMessage ?? 'The AI provider failed to respond.');
    }

    final suggestions = AiSuggestionParser.parse(
      response.rawText,
      sourceId: source.id,
      providerId: response.providerId,
      modelId: response.modelId,
      sourceFingerprint: combinedFingerprint,
    );

    return (suggestions: suggestions, conversation: AiConversation(request: request, response: response));
  }

  /// SHA-256 of the source's OCR content fingerprint plus a sorted
  /// signature of every entity's/context's own id and content — a
  /// change to any entity's normalized value or any context's title/
  /// page range changes this fingerprint even if the underlying OCR
  /// bytes did not, since AI analysis reasons over entities/contexts,
  /// not OCR text directly.
  static String computeCombinedFingerprint({
    required List<OcrPageResult> ocrResults,
    required List<EngineeringEntity> entities,
    required List<EngineeringContext> contexts,
  }) {
    final ocrSignature = ocrResults.map((result) => result.sourceFingerprint).join('|');
    final entitySignature = (entities.map((entity) => '${entity.id}:${entity.normalizedValue}').toList()..sort())
        .join('|');
    final contextSignature =
        (contexts.map((context) => '${context.id}:${context.title}:${context.pageStart}-${context.pageEnd}').toList()
              ..sort())
            .join('|');
    final joined = '$ocrSignature#$entitySignature#$contextSignature';
    return sha256.convert(utf8.encode(joined)).toString();
  }
}
