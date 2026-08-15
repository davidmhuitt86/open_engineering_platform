import 'dart:convert';

import '../models/ai_analysis_exception.dart';
import '../models/ai_suggestion.dart';
import '../models/knowledge_candidate_type.dart';
import 'knowledge_session_service.dart';

/// Parses one provider's raw response text into `AiSuggestion`s (Work
/// Package 016). Pure — no I/O. Deliberately strict: a provider (real
/// or mock) that doesn't honor `PromptService`'s own requested JSON
/// contract is a genuine "Invalid AI responses" failure
/// (`docs/AI_PROVIDER_ARCHITECTURE.md` § Architectural Observations),
/// not something to silently paper over — inventing a lenient
/// best-effort parse would risk fabricating a suggestion's content
/// from malformed input, which nothing in this architecture permits.
abstract final class AiSuggestionParser {
  static List<AiSuggestion> parse(
    String rawText, {
    required String sourceId,
    required String providerId,
    required String modelId,
    required String sourceFingerprint,
  }) {
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(rawText);
      if (parsed is! Map<String, dynamic>) {
        throw AiAnalysisException('The AI response was not a JSON object. Raw response: ${_truncate(rawText)}');
      }
      decoded = parsed;
    } on FormatException {
      throw AiAnalysisException('The AI response was not valid JSON. Raw response: ${_truncate(rawText)}');
    }

    final suggestionsJson = decoded['suggestions'];
    if (suggestionsJson is! List) {
      throw AiAnalysisException(
        'The AI response did not contain a "suggestions" list. Raw response: ${_truncate(rawText)}',
      );
    }

    final now = DateTime.now();
    return [
      for (final entry in suggestionsJson) _parseSuggestion(
        entry,
        sourceId: sourceId,
        providerId: providerId,
        modelId: modelId,
        sourceFingerprint: sourceFingerprint,
        now: now,
      ),
    ];
  }

  static AiSuggestion _parseSuggestion(
    dynamic entry, {
    required String sourceId,
    required String providerId,
    required String modelId,
    required String sourceFingerprint,
    required DateTime now,
  }) {
    if (entry is! Map<String, dynamic>) {
      throw const AiAnalysisException('A suggestion entry was not a JSON object.');
    }

    final typeName = entry['type'];
    if (typeName is! String) {
      throw const AiAnalysisException('A suggestion was missing its "type" field.');
    }
    final KnowledgeCandidateType type;
    try {
      type = KnowledgeCandidateType.values.byName(typeName);
    } on ArgumentError {
      throw AiAnalysisException('A suggestion used an unrecognized candidate type: "$typeName".');
    }

    final name = entry['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const AiAnalysisException('A suggestion was missing its "name" field.');
    }

    final description = entry['description'];
    final confidenceValue = entry['confidence'];
    if (confidenceValue is! num) {
      throw const AiAnalysisException('A suggestion was missing a numeric "confidence" field.');
    }
    final confidence = confidenceValue.toDouble().clamp(0.0, 1.0);

    final reasoning = entry['reasoning'];
    if (reasoning is! String || reasoning.trim().isEmpty) {
      throw const AiAnalysisException('A suggestion was missing its "reasoning" field.');
    }

    return AiSuggestion(
      id: KnowledgeSessionService.generateId('ai-suggestion'),
      sourceId: sourceId,
      providerId: providerId,
      modelId: modelId,
      suggestedType: type,
      suggestedName: name.trim(),
      suggestedDescription: description is String ? description.trim() : '',
      supportingEntityIds: _stringList(entry['supportingEntityIds']),
      supportingContextIds: _stringList(entry['supportingContextIds']),
      confidence: confidence,
      reasoning: reasoning.trim(),
      sourceFingerprint: sourceFingerprint,
      createdTime: now,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [for (final entry in value) if (entry is String) entry];
  }

  /// Caps how much of a malformed raw response an error message quotes
  /// — enough to diagnose the actual shape a provider returned, without
  /// an unbounded response blowing up the error banner.
  static String _truncate(String text) => text.length > 500 ? '${text.substring(0, 500)}…' : text;
}
