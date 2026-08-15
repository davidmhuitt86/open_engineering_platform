import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/ai_connection_status.dart';
import 'package:oep_studio/knowledge/models/ai_request.dart';
import 'package:oep_studio/knowledge/services/anthropic_provider.dart';
import 'package:oep_studio/settings/models/ai_settings.dart';

/// Optional, real-network integration test against the **real**
/// Anthropic API (Work Package 018) — distinct from
/// `anthropic_provider_test.dart`'s fake-transport unit tests, which
/// remain the default for automated testing (`MockAiProvider` for
/// end-to-end flows, a fake `http.Client` for `AnthropicProvider`'s own
/// logic).
///
/// This file is always safe to run, including in CI: it skips itself
/// entirely unless `ANTHROPIC_API_KEY` is set in the environment. No
/// key is ever typed into this file or handled by anyone but you — set
/// it yourself, in your own shell, and run:
///
/// ```
/// $env:ANTHROPIC_API_KEY = "sk-ant-..."   # PowerShell, current session only
/// flutter test test/anthropic_provider_live_test.dart
/// ```
void main() {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];

  AiSettings liveSettings() =>
      AiSettings.defaults().copyWith(enabled: true, providerId: AnthropicProvider.providerId, timeoutSeconds: 30, maxOutputTokens: 256);

  group('AnthropicProvider (live, real Anthropic API — requires ANTHROPIC_API_KEY)', () {
    test('testConnection reports connected with a real key', () async {
      if (apiKey == null || apiKey.isEmpty) {
        markTestSkipped('ANTHROPIC_API_KEY not set — set it in your own environment to run this test.');
        return;
      }
      final provider = AnthropicProvider(readApiKey: (_) async => apiKey, loadSettings: () async => liveSettings());

      final result = await provider.testConnection();

      expect(result.status, AiConnectionStatus.connected, reason: result.message);
    });

    test('complete() gets a real, correctly-shaped suggestion from Claude', () async {
      if (apiKey == null || apiKey.isEmpty) {
        markTestSkipped('ANTHROPIC_API_KEY not set — set it in your own environment to run this test.');
        return;
      }
      final provider = AnthropicProvider(readApiKey: (_) async => apiKey, loadSettings: () async => liveSettings());
      final request = AiRequest(
        id: 'live-test-request',
        systemPrompt:
            'You are an engineering documentation assistant. Respond with a JSON object of exactly this '
            'shape, and nothing else: {"suggestions": [{"type": "component", "name": "...", '
            '"description": "...", "confidence": 0.0-1.0, "reasoning": "...", "supportingEntityIds": [], '
            '"supportingContextIds": []}]}',
        userPrompt: 'Evidence: a torque specification of "45 Nm" was found for a wheel lug nut. Propose one suggestion.',
        sourceId: 'live-test-source',
        referencedEntityIds: const [],
        referencedContextIds: const [],
        evidenceLabels: const {},
        createdTime: DateTime.now(),
      );

      final response = await provider.complete(request);

      expect(response.success, isTrue, reason: response.errorMessage);
      expect(response.rawText, contains('suggestions'));
      expect(response.inputTokens, isNotNull);
      expect(response.outputTokens, isNotNull);
      // ignore: avoid_print
      print('[live] model=${response.modelId} tokens=${response.inputTokens}/${response.outputTokens} '
          'stopReason=${response.stopReason}');
    });
  });
}
