import '../models/ai_model_info.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';

/// The AI Provider Interface (Work Package 016 STUDIO-TASK-000046;
/// SDD-022 § Provider Architecture): "Studio shall communicate only
/// with AIProvider... No Workspace component shall depend upon
/// provider-specific APIs." Every provider — `MockAiProvider` today,
/// any future OpenAI/Anthropic/Gemini/Ollama/LM Studio/OpenRouter
/// implementation — implements exactly this interface and nothing
/// else is visible to `AiAnalysisService` or any widget.
///
/// A provider receives only [AiRequest]'s plain-text prompts, never a
/// `SourceMaterial`/`EngineeringEntity`/`EngineeringContext` object
/// directly — that boundary is what keeps "No provider-specific logic
/// outside provider implementations" true: a provider cannot depend on
/// Studio's domain model even if it wanted to, because it is never
/// given one.
abstract class AiProvider {
  AiModelInfo get modelInfo;

  Future<AiResponse> complete(AiRequest request);
}
