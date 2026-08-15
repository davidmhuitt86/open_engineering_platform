/// An optional capability an `AiProvider` may implement (Work Package
/// 018 STUDIO-TASK-000056: "Cancellation"). Kept off `AiProvider` itself
/// for the same reason as `TestableAiProvider` — providers with no
/// in-flight network request to cancel (`MockAiProvider`) aren't forced
/// to implement a no-op. Callers use `provider is CancellableAiProvider`.
abstract class CancellableAiProvider {
  /// Cancels this provider's current in-flight request, if any. A
  /// no-op if nothing is in flight.
  void cancelActiveRequest();
}
