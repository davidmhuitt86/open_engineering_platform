import 'ai_connection_status.dart';

/// The outcome of `TestableAiProvider.testConnection()` (Work Package
/// 018 STUDIO-TASK-000058) — a status plus a professional,
/// human-readable message, so the Artificial Intelligence settings page
/// can show both the badge and the detail without inventing its own
/// wording per provider.
class AiConnectionTestResult {
  const AiConnectionTestResult({required this.status, required this.message});

  final AiConnectionStatus status;
  final String message;
}
