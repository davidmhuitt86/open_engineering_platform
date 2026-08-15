# WP-STUDIO-023 — Platform Command Framework

Repository: `projects/platform/oep_studio`

## 1. Objective

Create a Platform Command Framework: a common mechanism for defining, discovering, validating, and executing commands. The Platform owns command dispatch; Studios own command implementation. No Command Palette, menu, keyboard shortcuts, Studio redesign, or invented commands — this Work Package establishes the Platform execution layer only. All user interfaces will consume it in future Work Packages.

## 1. Command Framework Architecture

New file: [lib/core/commands/command_registry.dart](lib/core/commands/command_registry.dart), a sibling of `lib/core/routing/studio_registry.dart` (WP-STUDIO-021/022) rather than an addition to it — unlike Capability Metadata (WP-STUDIO-022, which explicitly stays *on* `StudioDescriptor`), this Work Package's objective explicitly asks for "a centralized CommandRegistry," so a distinct class is correct here, not a violation of the "don't create a separate registry" principle from WP-022 (that principle was scoped to capabilities specifically).

The split mirrors the objective's own framing:
- **Platform owns dispatch**: `CommandRegistry.execute()` — resolves a command id, validates arguments, catches any exception, and returns a typed `CommandResult`. This is the only place a command is actually invoked.
- **Studios own implementation**: every `CommandDescriptor.execute` closure is a one-line call into a method that already existed before this Work Package (`EngineeringProjectNotifier`, `AcquisitionRuntimeNotifier`) — the Command Framework changes none of them.
- **Cross-referenced, not merged, with WP-STUDIO-022**: each command carries a `capabilityId` that must resolve to a real `CapabilityDescriptor.id` on `StudioRegistry.defaultRegistry`; `CommandRegistry.validate()` enforces this referential integrity. Commands are not stored on `StudioDescriptor` itself.

## 2. Review of WP-STUDIO-021 / WP-STUDIO-022 and Survey of Existing Execution Surfaces

Before writing any `CommandDescriptor`, each Studio's actual, already-existing execution surface was inspected, since "register only commands that already exist" required grounding, not invention:

| Studio | Ambient state owner | Already-existing, cleanly wrappable operations |
|---|---|---|
| Diagram Studio | `EngineeringProjectNotifier` (`core/services/engineering_project_service.dart`), a `Notifier` reachable via `ref.read(engineeringProjectServiceProvider.notifier)` | `newDocument()`, `openDocument(path)`, `saveDocument()`, `saveDocumentAs(path)`, `closeDocument()`, `revalidate()` — the last one's own doc comment literally says it exists "so a 'Revalidate' button has something concrete to call." Plus `engine.editing.undo()`/`redo()`, reachable via the notifier's `engine` getter. |
| Engineering Acquisition Studio | `AcquisitionRuntimeNotifier` (WP-PLAT-020) | `executeJob(id)`, `cancelJob(id)`, `verify(id)`, `extractMetadata(id)`, `publish(id)` — each a clean `Future<void> Function(String)`. |
| Knowledge Studio | **None.** `KnowledgeStudioPage` is a `StatelessWidget`; its many services (`KnowledgeSessionService`, `CommitPlanService`, `CommitTransactionService`, etc.) are called directly from per-dialog `ConsumerWidget`s, not from one Platform-reachable owner. | Nothing that can be wrapped without inventing a new ambient provider — which would itself be a Knowledge Studio redesign, explicitly out of scope. |

Also reviewed: `lib/diagram_studio/commands/studio_command_actions.dart` (`StudioCommandActions` — Diagram's existing undo/redo/copy/cut/paste/delete/duplicate, but copy/cut/paste/delete/duplicate need a live `EditingSession`/`GraphSelection` passed in, not just a `WidgetRef`) and `diagram_recent_commands_panel.dart` (the undo stack's descriptions). Both confirm Diagram Studio already has a notion of "commands" at the Engine level — this Work Package's Platform-level `CommandDescriptor` wraps the subset of that (undo/redo) with a clean, argument-free signature, and leaves copy/cut/paste/delete/duplicate unwrapped rather than inventing a new selection-carrying argument type not grounded in anything the Platform layer already has a place for.

## 3. CommandDescriptor Model

```dart
class CommandDescriptor {
  const CommandDescriptor({
    required this.id,            // globally unique, "<studio>.<command>"
    required this.label,         // short human-readable name
    required this.description,   // one sentence, what it actually does
    required this.capabilityId,  // must resolve in StudioRegistry
    required this.execute,       // CommandExecutor — Studio-owned
    this.requiresArgument = false,
  });
}
```

## 4. CommandRegistry

Centralized, immutable, constructed with a list of `CommandDescriptor`s plus (optionally) the `StudioRegistry` it validates against (defaults to `StudioRegistry.defaultRegistry`). No plugin loading, no reflection — a plain static list, exactly like `StudioRegistry.defaultRegistry` and `SettingsRegistry.defaultRegistry` before it.

## 5. Command Registrations

**Diagram Studio (8, capability `diagram.editing` unless noted):** `diagram.newDocument`, `diagram.openDocument` (requires argument), `diagram.saveDocument`, `diagram.saveDocumentAs` (requires argument), `diagram.closeDocument`, `diagram.undo`, `diagram.redo`, `diagram.revalidate` (capability `diagram.validation`).

**Engineering Acquisition Studio (5):** `acquisition.executeJob` (capability `acquisition.jobOrchestration`, requires argument), `acquisition.cancelJob` (same capability, requires argument), `acquisition.verify` (capability `acquisition.integrityPipeline`, requires argument), `acquisition.extractMetadata` (same capability, requires argument), `acquisition.publish` (capability `acquisition.vaultPublishing`, requires argument).

**Knowledge Studio (0, by design)** — documented inline in `command_registry.dart` and in §2 above, not silently omitted.

**Not registered, and why:** `acquisition.createSource`/`createJob`/`startDownload` take a multi-field `Map<String, Object?>` body, which doesn't fit this Work Package's single-optional-`String` `CommandArgs` contract without inventing a richer args shape — left for a future Work Package rather than forced. Diagram's copy/cut/paste/delete/duplicate need a live selection object for the same reason.

## 6. Execution Contract

```dart
class CommandArgs {
  const CommandArgs({this.value});   // at most one String — path or id
  final String? value;
  static const CommandArgs none = CommandArgs();
}

enum CommandOutcome { success, notFound, invalidArguments, failure }

class CommandResult {
  final CommandOutcome outcome;
  final String? errorMessage;
  bool get isSuccess => outcome == CommandOutcome.success;
}

typedef CommandExecutor = FutureOr<void> Function(WidgetRef ref, CommandArgs args);

Future<CommandResult> execute(WidgetRef ref, String commandId, {CommandArgs args = CommandArgs.none});
```

`execute()` resolves the id (→ `notFound`), checks `requiresArgument` against a non-blank `args.value` (→ `invalidArguments`), then runs the executor inside a `try`/`catch` (an exception → `failure` with `error.toString()`, otherwise → `success`). A caller always receives a `CommandResult`; nothing thrown by a command's own implementation propagates past `CommandRegistry.execute`.

## 7. Validation Tests

New file: `test/command_registry_test.dart`, 17 tests:
- **Discovery** (7): `validate()` on the real registry is empty; `findCommand` known/unknown; `commandsForCapability` returns exactly the right set; `commandsForStudio` returns only that Studio's commands and is empty for a non-Studio destination and for Knowledge; every command id is unique.
- **Validation** (4, fake registries via the public constructor): blank id, duplicate id, unresolvable `capabilityId`, and an empty registry being trivially valid.
- **Execution contract** (6, via a pumped `ProviderScope`/`Consumer` to obtain a real `WidgetRef`): `notFound`, `invalidArguments` (missing and blank-string argument), `success` on a real registered command (`diagram.undo`, verified harmless with no diagram open — `engine` is `null`, so it's a no-op, matching `revalidate()`'s own null-guard pattern), `failure` when an executor throws (isolated via a fake throwing descriptor, not a real command, to avoid any network dependency), and a no-argument command ignoring `CommandArgs.none`.

**Test results**: `flutter analyze` — 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere). `flutter test` — **345/345 passed** (328 prior + 17 new; 2 pre-existing unrelated skips). `flutter build windows` — succeeded.

## 8. Recommendations for WP-STUDIO-024

- **Knowledge Studio needs an ambient state owner before it can have commands.** This is the clearest concrete gap this Work Package surfaced: Knowledge Studio has no `Notifier`/Connection-Manager comparable to `EngineeringProjectNotifier`/`AcquisitionRuntimeNotifier`. Giving it one is a Knowledge Studio change and should be its own Work Package, reviewed on its own terms — not something to retrofit here just to reach command-registration parity.
- **A richer `CommandArgs` shape for multi-field commands.** `acquisition.createSource`/`createJob`/`startDownload` and Diagram's clipboard/delete operations all need more than one optional `String` to invoke for real. Consider a typed, per-command argument model (or a `Map<String, Object?>` escape hatch validated against a declared schema) before registering them.
- **First real consumer.** Per this Work Package's own scope, nothing calls `CommandRegistry.defaultRegistry.execute()` yet. A Command Palette, a menu, or keyboard shortcuts are all explicitly out of scope here and are the natural next Work Package(s) — each should read `CommandRegistry.defaultRegistry.commands`/`commandsForStudio` for discovery and call `execute()` for dispatch, rather than reaching into `EngineeringProjectNotifier`/`AcquisitionRuntimeNotifier` directly.
- **Startup validation.** As recommended for `StudioRegistry.validateCapabilities()` in WP-STUDIO-022, consider asserting `CommandRegistry.defaultRegistry.validate().isEmpty` once at app startup in debug builds, now that there are two registries whose cross-references (`capabilityId`) can drift out of sync as both evolve.
