import '../models/ai_model_info.dart';
import 'ai_provider.dart';
import 'anthropic_provider.dart';
import 'mock_ai_provider.dart';

/// The AI Provider Registry (Work Package 016 STUDIO-TASK-000046:
/// "AIProviderRegistry") — the single place Studio looks up an
/// `AiProvider` by id. Adding a future real provider means registering
/// one more entry here; nothing in the Connection Manager, the AI
/// Review Workspace, or `AiAnalysisService` changes ("Additional
/// providers may be added without changing Knowledge Workspace
/// architecture," SDD-022).
///
/// Seeded with `MockAiProvider` and — as of Work Package 018 —
/// `AnthropicProvider`, the first production provider. Registering it
/// here is the *entire* integration point: the AI Review Workspace's
/// provider picker (`AiProviderRegistry.defaultRegistry.availableModels`)
/// and `AiAnalysisService` already work with whatever this list
/// contains, unmodified.
class AiProviderRegistry {
  AiProviderRegistry(List<AiProvider> providers) : _providers = {for (final p in providers) p.modelInfo.providerId: p};

  final Map<String, AiProvider> _providers;

  AiProvider? providerFor(String providerId) => _providers[providerId];

  List<AiModelInfo> get availableModels => [for (final provider in _providers.values) provider.modelInfo];

  /// The registry Studio actually uses — a `const`-like default
  /// instance seeded with every concretely-implemented provider. A
  /// single, shared instance (not re-constructed per lookup) so a
  /// future provider requiring setup (e.g. loading cached model lists)
  /// only does so once.
  static final AiProviderRegistry defaultRegistry = AiProviderRegistry([MockAiProvider(), AnthropicProvider()]);
}
