# Anthropic Provider

Work Package 018 (STUDIO-TASK-000056 through STUDIO-TASK-000059) implements
the first production `AiProvider`: `AnthropicProvider`, using Anthropic's
Messages API. It validates both the AI Provider architecture (Work Package
016) and the Settings architecture (Work Package 017) with a real,
production-grade implementation, and introduces a new, reusable credential
infrastructure (`lib/core/security/`) that stores API keys in Windows
Credential Manager — never in Settings, a Repository, or a Knowledge
Session.

No Foundation changes. No Public C API changes. No architectural redesign.
`AnthropicProvider` implements the existing, frozen `AiProvider` interface
exactly as it stood after Work Package 016.

## Provider Implementation

`AnthropicProvider` (`lib/knowledge/services/anthropic_provider.dart`)
implements three interfaces:

- **`AiProvider`** (frozen, Work Package 016) — `modelInfo` and
  `complete(AiRequest)`. Nothing about this interface changed to
  accommodate Anthropic.
- **`TestableAiProvider`** (new, optional) — `testConnection()`, for
  STUDIO-TASK-000058. `MockAiProvider` also implements this now (always
  reports connected, no network), so the whole Test Connection flow is
  exercisable through Mock alone in automated tests.
- **`CancellableAiProvider`** (new, optional) — `cancelActiveRequest()`,
  for STUDIO-TASK-000056's "Cancellation".

Neither optional interface was added to `AiProvider` itself — a provider
with nothing to test or cancel (`MockAiProvider`, mostly) isn't forced to
implement a meaningless method. Callers discover the capability with
`provider is TestableAiProvider` / `provider is CancellableAiProvider`,
never by referencing `AnthropicProvider` by name.

**Self-configuring, not caller-configured.** `AiProvider.complete` takes
only an `AiRequest` — a frozen, single-argument signature. Rather than
change that signature to thread configuration through (which the work
package's instructions forbid), `AnthropicProvider` reads its own
configuration fresh on every call:

- `AiSettings` (model, temperature, timeout, max tokens) via
  `SettingsService.load()`.
- The API key via `CredentialService.instance` (a `CredentialStore`).

Both are injectable constructor parameters (`loadSettings`, `readApiKey`),
alongside an injectable `http.Client`, so unit tests can fake all three
without any real file I/O, credential storage, or network call.

### Structured output via tool use

Anthropic's responses are naturally prose/markdown, not guaranteed pure
JSON. `AiSuggestionParser` (Work Package 016) is deliberately strict — it
does not attempt a lenient best-effort parse of malformed data, by design.
Rather than loosen that shared parser to tolerate markdown-wrapped JSON,
`AnthropicProvider` forces a tool call (Anthropic's "tool use" / function
calling) whose `input_schema` mirrors `PromptService`'s own requested JSON
contract field-for-field, with `tool_choice` forcing that specific tool.
The tool call's `input` — already a parsed JSON object matching the
contract — is re-encoded to text and handed to `AiSuggestionParser`
unchanged. `AiSuggestionParser` needed zero changes for this work package.

### Retry, timeout, cancellation

- **Timeout**: every request is wrapped in `.timeout(Duration(seconds:
  settings.timeoutSeconds))`.
- **Retry**: HTTP 429 (rate limited) and 5xx responses, plus network/timeout
  exceptions, are retried up to two additional times with a linear backoff
  (500ms, 1000ms). HTTP 401/403 (authentication) and other 4xx responses
  fail immediately — retrying a bad API key wastes time and quota for no
  benefit.
- **Cancellation**: `cancelActiveRequest()` sets an internal flag and
  closes/replaces the underlying `http.Client`. The flag is checked before
  every attempt and again immediately after a retry's backoff wait, so a
  cancellation during a backoff is honored without waiting for one more
  full network round trip.

### Response parsing

A successful (HTTP 200) response is parsed for:

- The forced tool call's `input` (the suggestions payload).
- `usage.input_tokens` / `usage.output_tokens` → `AiResponse.inputTokens`/
  `outputTokens`.
- `stop_reason` → `AiResponse.stopReason`.
- The response's own `id` (and `stop_sequence`, if present) →
  `AiResponse.rawMetadata`, a generic bag so `AiResponse` itself stays
  provider-agnostic rather than growing an Anthropic-shaped field for
  every future provider.

## Authentication & Secure Credential Storage

**API keys are never written to `UserConfiguration`, a Repository, or a
Knowledge Session.** They live only in Windows Credential Manager, reached
through a new, reusable, provider-independent abstraction:

```
AnthropicProvider / AI Settings page
        |
CredentialStore (interface)
        |
CredentialService.instance  (platform selection)
        |
WindowsCredentialStore  (dart:ffi -> advapi32.dll)
```

- **`CredentialStore`** (`lib/core/security/credential_store.dart`) — the
  interface every credential consumer uses:
  `saveCredential({providerId, secret})`, `readCredential(providerId)`,
  `deleteCredential(providerId)`, `listCredentials()`. `providerId` is a
  generic namespacing key, not AI-specific — this is Studio's one
  reusable credential infrastructure, intended for future OpenAI/Gemini/
  Ollama/LM Studio/OpenRouter providers, GitHub integration, the Plugin
  Marketplace, and any future authentication need, not just Anthropic.
- **`CredentialService`** (`lib/core/security/credential_service.dart`) —
  selects the platform backend. Only Windows is implemented today
  (`WindowsCredentialStore`), matching Studio's own current scope; macOS
  Keychain and Linux Secret Service are natural future backends behind
  the same interface.
- **`WindowsCredentialStore`** (`lib/core/security/windows_credential_store.dart`) —
  stores secrets in Windows Credential Manager via `advapi32.dll`'s
  Unicode Credential Manager functions (`CredWriteW`/`CredReadW`/
  `CredDeleteW`/`CredEnumerateW`), called directly through `dart:ffi` —
  the same native-interop approach OEP already uses for the Foundation
  Bridge. `windows_credential_native_types.dart` mirrors the native
  `CREDENTIALW`/`FILETIME` structs and function signatures, and
  `windows_credential_bindings.dart` loads the DLL and looks up the
  functions — the same two-layer split `oep_api_native_types.dart`/
  `OepApiBindings` already establishes for the Foundation Bridge.

Every credential's Windows target name is prefixed
(`oep_studio/credential/<providerId>`), so `listCredentials()` (via
`CredEnumerateW` with an explicit `oep_studio/credential/*` filter) only
ever enumerates Studio's own credentials — never other applications'
saved passwords or the user's other Windows credentials.

### Why not `flutter_secure_storage`?

The first implementation used the `flutter_secure_storage` package. Its
Windows backend (`flutter_secure_storage_windows`) requires the ATL
(Active Template Library) component of the Visual Studio C++ build tools,
which is not installed in this project's build environment and was not
present as a prerequisite anywhere else in this codebase — `flutter build
windows` failed with `Cannot open include file: 'atlstr.h'`. Rather than
require installing a new Visual Studio component (a system-level change)
or add a third-party plugin dependency at all, the package was removed
entirely in favor of a direct `dart:ffi` call to
`advapi32.dll` — the same architectural philosophy already used
throughout OEP for the Foundation Bridge: native Windows APIs through
`dart:ffi`, no ATL, no COM, no external process, no C++ runtime
dependency beyond what `dart:ffi` itself already requires, and no
additional third-party plugin. This is also a better fit for the
project's own documented minimal-dependency philosophy.

## Settings Integration

The Artificial Intelligence settings page (Work Package 017, extended
here) now genuinely consumes `AiProviderRegistry` for its provider picker
— superseding Work Package 017's own deliberate decoupling, which was
itself scoped "yet" pending the first production provider:

- **Provider** — a dropdown sourced from
  `AiProviderRegistry.defaultRegistry.availableModels` (currently `mock`
  and `anthropic`).
- **Model** — free text (each provider has its own valid model strings; a
  hardcoded dropdown would be provider-specific logic the Settings page
  shouldn't own).
- **API Key** — a masked field, saved/removed via `CredentialService.instance`
  directly, never bound to `SettingsController`/`UserConfiguration`. A
  saved key's actual value is never re-displayed — only whether one is
  configured ("A key is configured for this provider").
- **Timeout / Temperature / Max Tokens** (new: `AiSettings.maxOutputTokens`,
  Anthropic's `max_tokens` request parameter — distinct from the existing
  `contextWindowTokens`, which remains informational only, since
  Anthropic's context window is a fixed model property, not a request
  parameter).
- **Test Connection** — calls `FoundationRuntimeNotifier.testAiConnection()`
  (Connection Manager), never a provider directly, and displays whatever
  `aiConnectionStatus`/`aiConnectionMessage` it recorded: **Connected**,
  **Authentication Failed**, **Network Error**, or **Provider Error**
  (STUDIO-TASK-000058), with the eventual detail message alongside the
  badge.

`AiSettings.maxOutputTokens` bumped `UserConfiguration.currentSchemaVersion`
to 2, with a real migration step (`SettingsMigrationService`'s `1: (json)
=> ...`) backfilling the new field's default for a schema-1 file saved
before it existed — the first genuine schema migration since Work Package
017 introduced the versioning mechanism.

## Prompt Execution

Unchanged from Work Package 016: `PromptService` remains the *only* place
prompt text is constructed. `AiAnalysisService` still orchestrates
`PromptService → AiProvider → AiSuggestionParser`, calling whatever
`AiProvider` the Connection Manager resolves via
`AiProviderRegistry.defaultRegistry.providerFor(...)` — now `anthropic` is
a real, selectable option, with zero changes to `AiAnalysisService`,
`PromptService`, or the AI Review Workspace's review workflow itself.

## Response Parsing (Property Inspector)

The AI Suggestion Property Inspector mode (`AiSuggestionProperties`) gained
two new sections, shown only when the current `AiConversation`'s response
carries the data (i.e. a suggestion actually produced by a real API call,
not the cache-reuse path):

- **Token Usage** — Input Tokens / Output Tokens.
- **Response Metadata** — Stop Reason plus any other `rawMetadata` entries
  (e.g. Anthropic's own response id).

## Error Handling

All of the following are translated into a professional `AiResponse.errorMessage`
(for `complete()`) or `AiConnectionTestResult` (for `testConnection()`) —
never a raw exception, stack trace, or HTTP body reaching the UI:

| Condition | `complete()` | `testConnection()` |
|---|---|---|
| AI disabled in Settings | Immediate failure, no request sent | N/A (Test Connection always attempts, so a key can be verified before enabling) |
| Missing API key | Immediate failure | `authenticationFailed` |
| HTTP 401/403 | Immediate failure (no retry) | `authenticationFailed` |
| HTTP 429 / 5xx | Retried up to twice, then failure | `providerError` |
| Timeout | Retried up to twice, then failure | `networkError` |
| Network/connection failure | Retried up to twice, then failure | `networkError` |
| Malformed (non-JSON) response body | Failure | `providerError` |
| 200 response missing the expected tool call | Failure ("did not include the expected suggestions data") | N/A |
| Response truncated by `max_tokens` (`stop_reason == "max_tokens"`) | Failure ("cut off before it finished ... Increase \"Max Tokens\"") | N/A |
| Cancelled mid-request/backoff | Failure ("The request was cancelled.") | N/A |

A response cut off by the `max_tokens` limit is checked explicitly and
reported as its own failure, distinct from "no suggestions." When
Anthropic's generation is truncated mid-tool-call, it returns an *empty*
`input: {}` for the forced tool rather than invalid JSON — indistinguishable
from a model that legitimately found nothing to suggest unless
`stop_reason` is inspected first. This was found during manual verification
(a real Knowledge Session with 26 entities + 19 contexts + full OCR text
exhausted the original 1024-token default before finishing); the
check was added, and `AiSettings.defaults()`'s `maxOutputTokens` (1024 →
4096) and `timeoutSeconds` (30 → 120) were both raised so a first-run
default is less likely to hit either limit on a realistic document.
Existing saved `settings.json` files are unaffected by a default change —
a user who saved settings under the old defaults must raise them manually
on the Artificial Intelligence settings page.

## Architectural Observations

- **The Connection Manager gained three new coordination fields** —
  `aiConnectionStatus`, `aiConnectionMessage`, `currentAiModel`, and
  `activeAiRequestSourceId` — all pure UI/coordination state (mirroring
  Work Package 016/017's own precedent), never the settings content or
  credential itself.
- **No Cancel button was added to the AI Review Workspace dialog.**
  `CancellableAiProvider`/`activeAiRequestSourceId` exist as real,
  testable plumbing, but STUDIO-TASK-000059 explicitly requires "The
  review workflow itself shall remain unchanged" — surfacing
  cancellation in that dialog is left to a future work package that
  explicitly requests it.
- **`flutter_secure_storage` was removed and replaced with a native
  `dart:ffi` implementation** after `flutter build windows` failed on
  the missing ATL build-tools component — see "Why not
  `flutter_secure_storage`?" above. `CredentialStore` is designed as
  Studio's general-purpose, reusable credential infrastructure, not an
  AI-specific concern, per this work package's own instruction.
- **The Artificial Intelligence settings page now depends on
  `AiProviderRegistry`**, superseding Work Package 017's own explicit
  decoupling decision — that decoupling was itself scoped "yet," pending
  the first production provider, which this work package is.
- **Every production provider needs a corresponding mock capability for
  automated testing.** `MockAiProvider` now also implements
  `TestableAiProvider` (always connected, no network) so the Test
  Connection flow is exercisable end-to-end without Anthropic.
  `AnthropicProvider`'s own request/response/retry/error-mapping logic
  is unit-tested against a fake `http.Client`
  (`package:http/testing.dart`'s `MockClient`) — no real network, no
  real credential. A separate, permanent, self-skipping
  `test/anthropic_provider_live_test.dart` exercises the real Anthropic
  API only when `ANTHROPIC_API_KEY` is set in the environment — an
  "optional integration test using a real API key," never required for
  `flutter test` to pass. Production manual verification (Settings →
  API Key → Test Connection → live AI analysis → Review Workflow →
  persistence), by contrast, is performed through the real Studio UI —
  never through an environment variable — since that is how end users
  will actually configure and use this feature.
- **`WindowsCredentialStore` is exercised by a real unit test**
  (`test/windows_credential_store_test.dart`) against the genuine
  Windows Credential Manager — not a Flutter plugin/platform channel,
  `dart:ffi`'s direct `advapi32.dll` access works in a bare `flutter
  test` process, unlike `flutter_secure_storage`'s federated plugin
  architecture. The suite uses disposable, invented test data (never a
  real secret) and deletes everything it writes in `tearDown`.

- **Manual verification against a real, evidence-heavy engineering
  document exposed two undersized defaults.** With `AiSettings.defaults()`'s
  original `maxOutputTokens: 1024`, a real analysis request (26 entities +
  19 contexts + full OCR text to cite) was truncated by Anthropic before
  the tool call finished, and the original `timeoutSeconds: 30` was too
  short once `maxOutputTokens` was raised enough for the model to actually
  finish generating. Both defaults were raised (`maxOutputTokens` → 4096,
  `timeoutSeconds` → 120) based on this real-world evidence, and
  `SettingsMigrationService`'s schema-1→2 step was updated to backfill the
  same new value for files migrated from a schema-1 install. This is a
  configuration/tuning finding, not an architectural one — no interface,
  model shape, or module boundary changed.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.
