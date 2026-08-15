import 'credential_models.dart';

/// The credential storage abstraction (Work Package 018
/// STUDIO-TASK-000057; SDD-023 Security: "Secrets shall use
/// operating-system credential facilities whenever available").
///
/// **The rest of Studio communicates only through this interface.** No
/// subsystem — not `AnthropicProvider`, not any future OpenAI/Gemini/
/// Ollama/LM Studio/OpenRouter provider, not the Plugin Marketplace,
/// not a future GitHub/enterprise-server integration — calls a
/// platform credential API directly. `providerId` is a generic
/// namespacing key (not AI-specific): this is Studio's one, reusable
/// credential infrastructure, not an AI-only concern, per this work
/// package's own instruction ("This security layer is not AI-specific.
/// It will become the credential infrastructure for future services").
///
/// A credential's *value* is never re-exposed once stored beyond a
/// direct [readCredential] call for the caller that needs it in that
/// moment — [listCredentials] returns only identities
/// ([CredentialSummary]), never secret values, so "is something
/// configured" can be answered without ever holding the actual secret
/// in memory longer than necessary.
abstract class CredentialStore {
  /// Stores [secret] for [providerId], overwriting any previous value.
  Future<void> saveCredential({required String providerId, required String secret});

  /// Reads the stored secret for [providerId], or `null` if none has
  /// been saved.
  Future<String?> readCredential(String providerId);

  /// Removes any stored secret for [providerId]. A no-op if none exists.
  Future<void> deleteCredential(String providerId);

  /// Every `providerId` with a currently-stored credential — never the
  /// secret values themselves.
  Future<List<CredentialSummary>> listCredentials();
}
