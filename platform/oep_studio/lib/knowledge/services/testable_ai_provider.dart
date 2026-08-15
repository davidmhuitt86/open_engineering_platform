import '../models/ai_connection_test_result.dart';

/// An optional capability an `AiProvider` may implement (Work Package
/// 018 STUDIO-TASK-000058: "Test Connection"). Deliberately **not**
/// added to `AiProvider` itself — that interface is frozen by Work
/// Package 016 and this work package's own instruction ("AnthropicProvider
/// shall implement the existing AIProvider interface," not redefine
/// it) — so a provider with nothing to test (like `MockAiProvider`,
/// which makes no real connection) is not forced to implement a
/// meaningless check, and callers use `provider is TestableAiProvider`
/// to discover the capability without depending on any concrete
/// provider type.
abstract class TestableAiProvider {
  Future<AiConnectionTestResult> testConnection();
}
