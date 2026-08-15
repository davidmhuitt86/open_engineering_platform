import 'ai_request.dart';
import 'ai_response.dart';

/// One complete request/response pair (Work Package 016
/// STUDIO-TASK-000046: "AIConversation") — the Connection Manager's
/// "Current AI Suggestion... AI Review State" surface for inspecting
/// exactly what was sent and exactly what came back, satisfying SDD-022's
/// "No hidden prompts. No hidden state." directly: the AI Review
/// Workspace's "Prompt" section renders this object's own fields, never
/// a separately-reconstructed approximation.
///
/// Ephemeral, like [AiRequest]/[AiResponse] — ephemeral, like
/// `CommitPlan`, never persisted with the Knowledge Session.
class AiConversation {
  const AiConversation({required this.request, this.response});

  final AiRequest request;

  /// `null` while a real (future, non-Mock) provider's request is still
  /// in flight, or if it failed before any response was received at
  /// all.
  final AiResponse? response;
}
