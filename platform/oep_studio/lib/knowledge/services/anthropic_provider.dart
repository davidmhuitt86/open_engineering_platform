import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/security/credential_service.dart';
import '../../settings/models/ai_settings.dart';
import '../../settings/services/settings_service.dart';
import '../models/ai_connection_status.dart';
import '../models/ai_connection_test_result.dart';
import '../models/ai_model_info.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/knowledge_candidate_type.dart';
import 'ai_provider.dart';
import 'cancellable_ai_provider.dart';
import 'testable_ai_provider.dart';

/// Reads the stored API key for a provider id — matches
/// `CredentialStore.readCredential`'s own signature, so it can be
/// passed directly as the default, or replaced with a fake in tests.
typedef ApiKeyReader = Future<String?> Function(String providerId);

/// The first production `AiProvider` implementation (Work Package 018
/// STUDIO-TASK-000056), using Anthropic's Messages API. Implements
/// exactly the frozen `AiProvider` interface plus two optional
/// capabilities (`TestableAiProvider`, `CancellableAiProvider`) —
/// nothing about `AiProvider` itself changed to accommodate this
/// provider ("AnthropicProvider shall implement the existing AIProvider
/// interface").
///
/// **Self-configuring, not caller-configured**: `AiProvider.complete`
/// takes only an [AiRequest] — a frozen, single-argument signature — so
/// this provider reads its own configuration (model/temperature/
/// timeout/max tokens from `AiSettings`, the API key from
/// `CredentialService.instance` (a `CredentialStore`)) fresh on every
/// call, rather than having the Connection Manager thread configuration
/// through a call it
/// doesn't otherwise need to understand. See
/// `docs/ANTHROPIC_PROVIDER.md` § Architectural Observations.
///
/// **Structured output via tool use**: Anthropic responses are
/// naturally prose/markdown and not guaranteed pure JSON. Rather than
/// loosen `AiSuggestionParser`'s deliberately strict parsing (a
/// documented Work Package 016 design decision), this provider forces
/// a tool call whose `input_schema` mirrors `PromptService`'s own
/// requested JSON contract exactly, and hands `AiSuggestionParser` the
/// tool call's `input` re-encoded as JSON text — so the shared parser
/// needs no changes at all.
class AnthropicProvider implements AiProvider, TestableAiProvider, CancellableAiProvider {
  /// [client]/[loadSettings]/[readApiKey] are injectable seams — unit
  /// tests supply a fake `http.Client` (`package:http/testing.dart`'s
  /// `MockClient`, no real network) and fake settings/key readers (no
  /// real `SettingsService` file I/O, no real OS secure storage, no
  /// real API key), so `AnthropicProvider`'s own request-building/
  /// response-parsing/retry/error-mapping logic is fully testable
  /// without ever touching the network or a real credential. Production
  /// code (the registry's `defaultRegistry`) uses the defaults, which
  /// call the real services.
  AnthropicProvider({http.Client? client, Future<AiSettings> Function()? loadSettings, ApiKeyReader? readApiKey})
    : _client = client ?? http.Client(),
      _loadSettings = loadSettings ?? _defaultLoadSettings,
      _readApiKey = readApiKey ?? CredentialService.instance.readCredential;

  static const providerId = 'anthropic';
  static const _apiBase = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _toolName = 'propose_knowledge_candidates';
  static const _maxAttempts = 3;
  static const _retryBaseDelay = Duration(milliseconds: 500);

  static Future<AiSettings> _defaultLoadSettings() async => (await SettingsService.load()).ai;

  http.Client _client;
  bool _cancelled = false;
  final Future<AiSettings> Function() _loadSettings;
  final ApiKeyReader _readApiKey;

  @override
  AiModelInfo get modelInfo => const AiModelInfo(
    providerId: providerId,
    modelId: 'claude-sonnet-4-5-20250929',
    displayName: 'Anthropic (Claude)',
    description:
        'Real production AI provider using the Anthropic Messages API. '
        'Requires an API key configured on the Artificial Intelligence '
        'settings page, stored using operating-system secure credential '
        'storage.',
  );

  @override
  Future<AiResponse> complete(AiRequest request) async {
    _cancelled = false;
    final settings = await _loadSettings();

    if (!settings.enabled) {
      return _failure(
        request,
        'AI is disabled. Enable AI on the Artificial Intelligence settings page to run analysis.',
      );
    }
    final apiKey = await _readApiKey(providerId);
    if (apiKey == null || apiKey.isEmpty) {
      return _failure(
        request,
        'No Anthropic API key is configured. Add one on the Artificial Intelligence settings page.',
      );
    }
    final model = settings.modelId.trim().isEmpty ? modelInfo.modelId : settings.modelId.trim();

    String? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (_cancelled) return _failure(request, 'The request was cancelled.');
      if (attempt > 0) {
        await Future.delayed(_retryBaseDelay * attempt);
        if (_cancelled) return _failure(request, 'The request was cancelled.');
      }

      try {
        final requestBody = jsonEncode(_buildRequestBody(request, model: model, settings: settings));
        final httpResponse = await _client
            .post(
              Uri.parse(_apiBase),
              headers: {'x-api-key': apiKey, 'anthropic-version': _apiVersion, 'content-type': 'application/json'},
              body: requestBody,
            )
            .timeout(Duration(seconds: settings.timeoutSeconds));

        if (httpResponse.statusCode == 200) {
          return _parseSuccess(request, httpResponse.body, model: model);
        }
        if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
          return _failure(
            request,
            'Anthropic rejected the API key (HTTP ${httpResponse.statusCode}). Check the key on the '
            'Artificial Intelligence settings page.',
          );
        }
        if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) {
          lastError = 'HTTP ${httpResponse.statusCode}: ${_shortBody(httpResponse.body)}';
          continue;
        }
        return _failure(
          request,
          'Anthropic returned an error (HTTP ${httpResponse.statusCode}): ${_shortBody(httpResponse.body)}',
        );
      } on TimeoutException {
        if (_cancelled) return _failure(request, 'The request was cancelled.');
        lastError = 'timed out after ${settings.timeoutSeconds}s';
      } on http.ClientException catch (error) {
        if (_cancelled) return _failure(request, 'The request was cancelled.');
        lastError = error.message;
      } catch (error) {
        if (_cancelled) return _failure(request, 'The request was cancelled.');
        lastError = error.toString();
      }
    }
    return _failure(request, 'Could not reach Anthropic after $_maxAttempts attempts: $lastError');
  }

  @override
  Future<AiConnectionTestResult> testConnection() async {
    final apiKey = await _readApiKey(providerId);
    if (apiKey == null || apiKey.isEmpty) {
      return const AiConnectionTestResult(
        status: AiConnectionStatus.authenticationFailed,
        message: 'No API key is configured.',
      );
    }
    final settings = await _loadSettings();
    final model = settings.modelId.trim().isEmpty ? modelInfo.modelId : settings.modelId.trim();

    try {
      final response = await _client
          .post(
            Uri.parse(_apiBase),
            headers: {'x-api-key': apiKey, 'anthropic-version': _apiVersion, 'content-type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'ping'},
              ],
            }),
          )
          .timeout(Duration(seconds: settings.timeoutSeconds));

      if (response.statusCode == 200) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.connected,
          message: 'Connected to Anthropic successfully using model "$model".',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.authenticationFailed,
          message: 'Anthropic rejected the API key (HTTP ${response.statusCode}).',
        );
      }
      return AiConnectionTestResult(
        status: AiConnectionStatus.providerError,
        message: 'Anthropic returned HTTP ${response.statusCode}: ${_shortBody(response.body)}',
      );
    } on TimeoutException {
      return AiConnectionTestResult(
        status: AiConnectionStatus.networkError,
        message: 'Connection to Anthropic timed out after ${settings.timeoutSeconds}s.',
      );
    } on http.ClientException catch (error) {
      return AiConnectionTestResult(status: AiConnectionStatus.networkError, message: 'Network error: ${error.message}');
    } catch (error) {
      return AiConnectionTestResult(status: AiConnectionStatus.providerError, message: 'Unexpected error: $error');
    }
  }

  @override
  void cancelActiveRequest() {
    _cancelled = true;
    _client.close();
    _client = http.Client();
  }

  Map<String, dynamic> _buildRequestBody(AiRequest request, {required String model, required AiSettings settings}) {
    return {
      'model': model,
      'max_tokens': settings.maxOutputTokens,
      'temperature': settings.temperature,
      'system': request.systemPrompt,
      'messages': [
        {'role': 'user', 'content': request.userPrompt},
      ],
      'tools': [
        {
          'name': _toolName,
          'description': 'Propose Knowledge Candidate suggestions based on the provided engineering evidence.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'suggestions': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'type': {
                      'type': 'string',
                      'enum': [for (final type in KnowledgeCandidateType.values) type.name],
                    },
                    'name': {'type': 'string'},
                    'description': {'type': 'string'},
                    'confidence': {'type': 'number'},
                    'reasoning': {'type': 'string'},
                    'supportingEntityIds': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    'supportingContextIds': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                  'required': ['type', 'name', 'confidence', 'reasoning'],
                },
              },
            },
            'required': ['suggestions'],
          },
        },
      ],
      'tool_choice': {'type': 'tool', 'name': _toolName},
    };
  }

  AiResponse _parseSuccess(AiRequest request, String body, {required String model}) {
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(body);
      if (parsed is! Map<String, dynamic>) {
        return _failure(request, 'Anthropic returned an unexpected response shape.');
      }
      decoded = parsed;
    } on FormatException {
      return _failure(request, 'Anthropic returned a response that was not valid JSON.');
    }

    final content = decoded['content'];
    if (content is! List) {
      return _failure(request, 'Anthropic\'s response did not include any content.');
    }

    // A response cut off before the model finished writing its tool
    // call is fundamentally incomplete — Anthropic truncates the
    // in-progress `input` down to `{}` rather than emitting malformed
    // JSON, which would otherwise look identical to "nothing to
    // suggest." This must be caught and reported explicitly, with an
    // actionable fix, rather than silently treated as zero suggestions.
    if (decoded['stop_reason'] == 'max_tokens') {
      return _failure(
        request,
        'Anthropic\'s response was cut off before it finished (ran out of tokens generating suggestions). '
        'Increase "Max Tokens" on the Artificial Intelligence settings page and try again.',
      );
    }

    Map<String, dynamic>? toolInput;
    for (final block in content) {
      if (block is Map<String, dynamic> && block['type'] == 'tool_use' && block['name'] == _toolName) {
        final input = block['input'];
        if (input is Map<String, dynamic>) toolInput = input;
        break;
      }
    }
    if (toolInput == null) {
      return _failure(request, 'Anthropic\'s response did not include the expected suggestions data.');
    }

    // Anthropic's tool_choice forces a tool call but does not strictly
    // enforce the input_schema's own "required" fields server-side — a
    // model that deliberately (not due to truncation, ruled out above)
    // decides there is nothing worth suggesting may return `{}` instead
    // of the technically-correct `{"suggestions": []}`. Treat a missing
    // key as the honest "nothing to report" case (the same
    // interpretation `MockAiProvider`/`ContextDetectionService` already
    // use for zero evidence) rather than a malformed response —
    // `AiSuggestionParser` remains strict about every *other* shape
    // violation, this only normalizes Anthropic's own known omission.
    final normalizedInput = toolInput.containsKey('suggestions') ? toolInput : {'suggestions': const [], ...toolInput};

    final usage = decoded['usage'];
    final inputTokens = usage is Map<String, dynamic> ? usage['input_tokens'] as int? : null;
    final outputTokens = usage is Map<String, dynamic> ? usage['output_tokens'] as int? : null;

    return AiResponse(
      requestId: request.id,
      providerId: providerId,
      modelId: (decoded['model'] as String?) ?? model,
      rawText: jsonEncode(normalizedInput),
      receivedTime: DateTime.now(),
      success: true,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      stopReason: decoded['stop_reason'] as String?,
      rawMetadata: {
        if (decoded['id'] != null) 'responseId': decoded['id'],
        if (decoded['stop_sequence'] != null) 'stopSequence': decoded['stop_sequence'],
      },
    );
  }

  AiResponse _failure(AiRequest request, String message) {
    return AiResponse(
      requestId: request.id,
      providerId: providerId,
      modelId: modelInfo.modelId,
      rawText: '',
      receivedTime: DateTime.now(),
      success: false,
      errorMessage: message,
    );
  }

  static String _shortBody(String body) => body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
