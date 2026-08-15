import '../../knowledge/models/ai_request.dart';
import '../../knowledge/models/ai_response.dart';
import '../../knowledge/services/ai_provider_registry.dart';

/// Diagram Studio's own AI orchestrator (WORK_PACKAGE_024,
/// ENGINE-TASK-000116) — the one place Diagram Studio calls an
/// `AiProvider`, mirroring `AiAnalysisService`'s equivalent role for
/// Knowledge Studio. Calls the *existing* `AiProviderRegistry` directly;
/// no new provider infrastructure is implemented here.
abstract final class DiagramAiService {
  /// Resolves [providerId] from the shared registry and sends [request],
  /// returning its raw `AiResponse` (`response.success` distinguishes a
  /// provider failure from a genuine answer — callers decide how to
  /// surface either).
  static Future<AiResponse> ask({
    required String providerId,
    required AiRequest request,
  }) async {
    final provider = AiProviderRegistry.defaultRegistry.providerFor(providerId);
    if (provider == null) {
      return AiResponse(
        requestId: request.id,
        providerId: providerId,
        modelId: '',
        rawText: '',
        receivedTime: DateTime.now(),
        success: false,
        errorMessage: 'No AI provider registered with id "$providerId".',
      );
    }
    return provider.complete(request);
  }
}
