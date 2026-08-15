import 'dart:convert';

import '../models/ai_connection_status.dart';
import '../models/ai_connection_test_result.dart';
import '../models/ai_model_info.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/knowledge_candidate_type.dart';
import 'ai_provider.dart';
import 'testable_ai_provider.dart';

/// The Mock AI Provider (Work Package 016 STUDIO-TASK-000049):
/// "Implement a deterministic mock provider. The mock provider returns
/// predefined responses... No network activity." The only concrete
/// `AiProvider` this work package implements — "No production provider
/// integration" (this work package's own explicit instruction) — but
/// exercises the *entire* pipeline (`PromptService` → `AiProvider` →
/// `AiSuggestionParser` → `AiSuggestion`) end to end with real,
/// reproducible output, proving the abstraction actually works without
/// any network dependency.
///
/// "Deterministic" here means *a pure function of the request's own
/// content* — the same [AiRequest] always produces byte-identical
/// [AiResponse.rawText] — not "the same canned string regardless of
/// input." One suggestion is generated per referenced Engineering
/// Context (the richer evidence unit); if a source has no detected
/// contexts yet, one is generated per referenced Engineering Entity
/// instead; a source with neither produces zero suggestions — the
/// honest answer when there is no deterministic evidence to reason
/// about, the same "nothing to report" precedent
/// `ContextDetectionService`/`EngineeringEntityExtractionService`
/// already established for empty input.
class MockAiProvider implements AiProvider, TestableAiProvider {
  @override
  AiModelInfo get modelInfo => const AiModelInfo(
    providerId: 'mock',
    modelId: 'mock-deterministic-v1',
    displayName: 'Mock Deterministic Provider',
    description:
        'Returns predictable, reproducible suggestions derived only from '
        'the request\'s own referenced evidence — for automated testing, '
        'UI verification, and provider-independent development. Makes no '
        'network calls.',
  );

  @override
  Future<AiResponse> complete(AiRequest request) async {
    final evidenceIds = request.referencedContextIds.isNotEmpty
        ? request.referencedContextIds
        : request.referencedEntityIds;

    final suggestions = [
      for (final evidenceId in evidenceIds)
        _suggestionFor(
          evidenceId: evidenceId,
          isContext: request.referencedContextIds.isNotEmpty,
          request: request,
        ),
    ];

    final rawText = jsonEncode({'suggestions': suggestions});
    return AiResponse(
      requestId: request.id,
      providerId: modelInfo.providerId,
      modelId: modelInfo.modelId,
      rawText: rawText,
      receivedTime: DateTime.now(),
      success: true,
    );
  }

  /// Always reports connected, instantly, with no network activity —
  /// lets automated tests and manual verification exercise the entire
  /// "Test Connection" flow (STUDIO-TASK-000058) through Mock alone,
  /// without ever needing a real provider or API key.
  @override
  Future<AiConnectionTestResult> testConnection() async {
    return const AiConnectionTestResult(
      status: AiConnectionStatus.connected,
      message: 'Mock provider is always available — no real connection is made.',
    );
  }

  Map<String, dynamic> _suggestionFor({
    required String evidenceId,
    required bool isContext,
    required AiRequest request,
  }) {
    final label = request.evidenceLabels[evidenceId] ?? evidenceId;
    final hash = _stableHash(evidenceId);
    final type = KnowledgeCandidateType.values[hash % KnowledgeCandidateType.values.length];
    final confidence = 0.5 + (hash % 50) / 100;

    return {
      'type': type.name,
      'name': 'Suggested ${type.label}: $label',
      'description': 'Derived from the ${isContext ? 'engineering context' : 'engineering entity'} '
          '"$label" detected on this source.',
      'confidence': confidence,
      'reasoning': 'The ${isContext ? 'context' : 'entity'} "$label" was recognized as a candidate '
          '${type.label} because it appears in the deterministic engineering evidence for this '
          'source. This is a deterministic, mock-generated suggestion — no real AI model was '
          'consulted.',
      'supportingEntityIds': isContext ? const <String>[] : [evidenceId],
      'supportingContextIds': isContext ? [evidenceId] : const <String>[],
    };
  }

  /// A simple, explicit, guaranteed-stable hash (sum of code units) —
  /// deliberately not `String.hashCode`, whose exact algorithm is not
  /// part of the Dart language specification, to keep "deterministic"
  /// an unambiguous, verifiable property of this provider rather than
  /// an implementation detail of the SDK.
  static int _stableHash(String value) => value.codeUnits.fold(0, (sum, unit) => sum + unit);
}
