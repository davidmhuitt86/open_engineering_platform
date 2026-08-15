import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/knowledge/models/ai_connection_status.dart';
import 'package:oep_studio/knowledge/models/ai_request.dart';
import 'package:oep_studio/knowledge/services/anthropic_provider.dart';
import 'package:oep_studio/settings/models/ai_settings.dart';

/// Exercises `AnthropicProvider`'s own request-building/response-parsing/
/// retry/error-mapping logic against a fake `http.Client`
/// (`package:http/testing.dart`'s `MockClient`) — **no real network
/// call, no real API key, no real `SettingsService`/OS secure storage
/// I/O**. This is the "MockAiProvider remains the default for unit and
/// integration tests" principle applied to `AnthropicProvider` itself:
/// its *transport* is faked here, distinct from an "optional
/// integration test using a real API key" (manual verification only —
/// see `docs/ANTHROPIC_PROVIDER.md`).
void main() {
  AiRequest buildRequest() => AiRequest(
    id: 'req-1',
    systemPrompt: 'system',
    userPrompt: 'user',
    sourceId: 'source-1',
    referencedEntityIds: const [],
    referencedContextIds: const [],
    evidenceLabels: const {},
    createdTime: DateTime(2026, 1, 1),
  );

  AiSettings enabledSettings({String modelId = 'claude-test-model', int timeoutSeconds = 5}) =>
      AiSettings.defaults().copyWith(enabled: true, providerId: 'anthropic', modelId: modelId, timeoutSeconds: timeoutSeconds);

  http.Response toolUseResponse({
    List<Map<String, dynamic>> suggestions = const [],
    int inputTokens = 42,
    int outputTokens = 7,
  }) {
    final body = jsonEncode({
      'id': 'msg_fake123',
      'model': 'claude-test-model',
      'stop_reason': 'tool_use',
      'usage': {'input_tokens': inputTokens, 'output_tokens': outputTokens},
      'content': [
        {
          'type': 'tool_use',
          'name': 'propose_knowledge_candidates',
          'input': {'suggestions': suggestions},
        },
      ],
    });
    return http.Response(body, 200);
  }

  group('AnthropicProvider.complete', () {
    test('fails with a professional message when AI is disabled', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => fail('should not make a network call')),
        loadSettings: () async => AiSettings.defaults().copyWith(enabled: false),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('disabled'));
    });

    test('fails with a professional message when no API key is configured', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => fail('should not make a network call')),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => null,
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('API key'));
    });

    test('sends the model/temperature/max_tokens from AiSettings and a forced tool_choice', () async {
      late Map<String, dynamic> sentBody;
      final provider = AnthropicProvider(
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['x-api-key'], 'fake-test-key');
          expect(request.headers['anthropic-version'], isNotEmpty);
          return toolUseResponse();
        }),
        loadSettings: () async =>
            enabledSettings(modelId: 'claude-configured').copyWith(temperature: 0.42, maxOutputTokens: 777),
        readApiKey: (_) async => 'fake-test-key',
      );

      await provider.complete(buildRequest());

      expect(sentBody['model'], 'claude-configured');
      expect(sentBody['temperature'], 0.42);
      expect(sentBody['max_tokens'], 777);
      expect(sentBody['tool_choice'], {'type': 'tool', 'name': 'propose_knowledge_candidates'});
      expect(sentBody['system'], 'system');
      expect(sentBody['messages'], [
        {'role': 'user', 'content': 'user'},
      ]);
    });

    test('parses a successful tool_use response into rawText/tokens/stopReason/metadata', () async {
      final provider = AnthropicProvider(
        client: MockClient(
          (request) async => toolUseResponse(
            suggestions: [
              {
                'type': 'component',
                'name': 'Suggested Component',
                'description': 'desc',
                'confidence': 0.8,
                'reasoning': 'why',
                'supportingEntityIds': <String>[],
                'supportingContextIds': <String>[],
              },
            ],
            inputTokens: 100,
            outputTokens: 20,
          ),
        ),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isTrue);
      expect(response.inputTokens, 100);
      expect(response.outputTokens, 20);
      expect(response.stopReason, 'tool_use');
      expect(response.rawMetadata?['responseId'], 'msg_fake123');
      final decoded = jsonDecode(response.rawText) as Map<String, dynamic>;
      expect((decoded['suggestions'] as List).length, 1);
    });

    test('maps HTTP 401 to a professional authentication failure (no retry)', () async {
      var callCount = 0;
      final provider = AnthropicProvider(
        client: MockClient((request) async {
          callCount++;
          return http.Response('{"error":"unauthorized"}', 401);
        }),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'bad-fake-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('401'));
      expect(callCount, 1); // auth failures are not retried
    });

    test('retries on HTTP 500 and eventually fails after exhausting attempts', () async {
      var callCount = 0;
      final provider = AnthropicProvider(
        client: MockClient((request) async {
          callCount++;
          return http.Response('server exploded', 500);
        }),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(callCount, greaterThan(1)); // retried at least once
    });

    test('retries on HTTP 500 then succeeds if a later attempt returns 200', () async {
      var callCount = 0;
      final provider = AnthropicProvider(
        client: MockClient((request) async {
          callCount++;
          if (callCount < 2) return http.Response('server exploded', 500);
          return toolUseResponse();
        }),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isTrue);
      expect(callCount, 2);
    });

    test('a malformed (non-JSON) response body is a professional failure, not a crash', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => http.Response('not json at all', 200)),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, isNotNull);
    });

    test('a 200 response missing the expected tool_use block is a professional failure', () async {
      final provider = AnthropicProvider(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'I refuse to use the tool.'},
              ],
            }),
            200,
          ),
        ),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('expected suggestions data'));
    });

    test('a response truncated by max_tokens is a professional, actionable failure', () async {
      final provider = AnthropicProvider(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'id': 'msg_truncated',
              'model': 'claude-test-model',
              'stop_reason': 'max_tokens',
              'usage': {'input_tokens': 5000, 'output_tokens': 1024},
              'content': [
                {'type': 'tool_use', 'name': 'propose_knowledge_candidates', 'input': <String, dynamic>{}},
              ],
            }),
            200,
          ),
        ),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final response = await provider.complete(buildRequest());

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('cut off'));
      expect(response.errorMessage, contains('Max Tokens'));
    });
  });

  group('AnthropicProvider.testConnection', () {
    test('reports authenticationFailed when no API key is configured', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => fail('should not make a network call')),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => null,
      );

      final result = await provider.testConnection();

      expect(result.status, AiConnectionStatus.authenticationFailed);
    });

    test('reports connected on HTTP 200', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => toolUseResponse()),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final result = await provider.testConnection();

      expect(result.status, AiConnectionStatus.connected);
    });

    test('reports authenticationFailed on HTTP 401', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => http.Response('nope', 401)),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'bad-fake-key',
      );

      final result = await provider.testConnection();

      expect(result.status, AiConnectionStatus.authenticationFailed);
    });

    test('reports providerError on HTTP 500', () async {
      final provider = AnthropicProvider(
        client: MockClient((request) async => http.Response('boom', 500)),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      final result = await provider.testConnection();

      expect(result.status, AiConnectionStatus.providerError);
    });
  });

  group('AnthropicProvider.cancelActiveRequest', () {
    test('cancelling during a retry backoff stops further attempts', () async {
      var callCount = 0;
      final provider = AnthropicProvider(
        client: MockClient((request) async {
          callCount++;
          return http.Response('server exploded', 500);
        }),
        loadSettings: () async => enabledSettings(),
        readApiKey: (_) async => 'fake-test-key',
      );

      // Attempt 0 fails immediately (no pre-delay), then the loop awaits
      // a backoff before attempt 1. Cancel during that backoff window —
      // the post-delay cancellation check should stop attempt 1 from
      // ever firing.
      final future = provider.complete(buildRequest());
      await Future.delayed(const Duration(milliseconds: 50));
      provider.cancelActiveRequest();
      final response = await future;

      expect(response.success, isFalse);
      expect(response.errorMessage, contains('cancelled'));
      expect(callCount, 1);
    });
  });
}
