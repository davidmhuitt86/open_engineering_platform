# WP-STUDIO-026 — Platform Input Framework

Repository: `projects/platform/oep_studio`

## Objective

Create a centralized Platform Input Framework that becomes the single entry point for user-initiated command execution, forwarding to the existing Command Framework (WP-STUDIO-023) without duplicating its routing logic.

## 1. Architecture Review

**How commands enter the Platform today**: `CommandRegistry.execute()` had exactly one production call site before this Work Package — `command_palette_dialog.dart`'s `_runCommand` (WP-STUDIO-024). There is no other UI surface that invokes a Platform command; Diagram Studio's own toolbar/keyboard-shortcut path (`StudioCommandActions`) and Knowledge Studio's dialogs (`FoundationRuntimeNotifier`, WP-STUDIO-025) both call their Studio's own methods directly and are not — and, per this Work Package's scope, are not being made to be — routed through the Command Framework themselves; only the subset of their operations already registered as Commands (WP-STUDIO-023/025) is reachable that way.

**Duplicated input handling identified**: `command_registry.dart`'s `diagram.undo`/`diagram.redo` executors called `engine.editing.undo()`/`engine.editing.redo()` directly — the exact same one-line operation `StudioCommandActions.undo()`/`.redo()` (`lib/diagram_studio/commands/studio_command_actions.dart`) already encapsulates for Diagram Studio's own toolbar and keyboard-shortcut callers. This was a small, real duplication (two independent definitions of "how to undo/redo") rather than a parallel architecture, and was safe to fix in place: both command executors now construct `StudioCommandActions(engine)` and call its `undo()`/`redo()`, reusing the existing abstraction instead of re-deriving it. No behavior changed — `StudioCommandActions.undo()`/`.redo()` call exactly the same `engine.editing.undo()`/`.redo()` underneath.

## 2. PlatformInputService

New file: [lib/core/input/platform_input_service.dart](lib/core/input/platform_input_service.dart) — a thin, non-duplicating forwarder:

```dart
class PlatformInputService {
  PlatformInputService({CommandRegistry? commandRegistry})
      : _commandRegistry = commandRegistry ?? CommandRegistry.defaultRegistry;

  List<CommandDescriptor> get commands => _commandRegistry.commands;

  Future<CommandResult> runCommand(WidgetRef ref, String commandId, {CommandArgs args = CommandArgs.none}) {
    return _commandRegistry.execute(ref, commandId, args: args);
  }

  static final PlatformInputService defaultService = PlatformInputService();
}
```

It re-implements none of `CommandRegistry`'s resolution, argument-validation, or dispatch logic (per the Requirement "do not duplicate existing routing") — both methods are one-line passthroughs. `defaultService` follows the same static-singleton convention already established by `StudioRegistry.defaultRegistry`/`CommandRegistry.defaultRegistry`, so no new architectural pattern was introduced.

## 3. Command Routing Integration

`command_registry.dart`'s `diagram.undo`/`diagram.redo` executors now route through `StudioCommandActions` (§1) rather than calling the engine directly — the one routing change made to the Command Framework itself in this Work Package.

## 4. Command Palette Integration

[command_palette_dialog.dart](lib/app/widgets/command_palette_dialog.dart) no longer references `CommandRegistry` for discovery or execution: `showCommandPaletteDialog` now takes an optional `PlatformInputService` (defaulting to `PlatformInputService.defaultService`) instead of a `CommandRegistry`, and the dialog reads `inputService.commands` for its list and calls `inputService.runCommand(...)` to dispatch — the palette is now just the first of what could be several future input sources sharing the same entry point, exactly as the objective describes. `StudioRegistry` usage (Studio/capability name lookups for display) is unchanged — that's metadata lookup, not command routing, and stayed exactly where WP-STUDIO-024 put it.

No keyboard shortcut, context menu, or any other new input surface was added — per the Requirements, `PlatformInputService` exists only as the shared forwarding point a *future* Work Package would use for those.

## 5. Validation Results

- `flutter analyze`: 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere).
- `flutter test`: **365/365 passed** (358 prior + 7 new; 2 pre-existing unrelated skips). New file `test/platform_input_service_test.dart` (7 tests: passthrough `commands`, `defaultService` wraps the real registry, an injected fake registry is honored, and `runCommand`'s `notFound`/`invalidArguments`/`success`/`failure` outcomes all forward exactly as `CommandRegistry.execute` would). Updated `test/command_palette_dialog_test.dart`'s `commandRegistry:` parameters to `inputService:` to match the new signature.
- `flutter build windows`: succeeded.
- Confirmed no UI was redesigned, no keyboard shortcut or context menu was implemented, and no existing routing was duplicated — `PlatformInputService` contains no resolution/validation logic of its own.

## 6. Documentation & Future Extension Points

This file, plus doc comments on `PlatformInputService` itself explaining its role. **Future extension points**: any new input source (a keyboard shortcut handler, a context-menu handler, a future menu bar) should call `PlatformInputService.defaultService.runCommand(ref, commandId, args: ...)` — it does not need its own reference to `CommandRegistry`, does not need to re-validate arguments, and does not need to re-implement error handling; all of that stays centralized in `CommandRegistry.execute`, reached through this one shared entry point.

## 7. Recommendations for WP-STUDIO-027

- **Keyboard shortcuts** (deferred by every Work Package since WP-STUDIO-024) are now the natural next step architecturally: a `Shortcuts`/`CallbackShortcuts` binding at the `StudioShell` level would call `PlatformInputService.defaultService.runCommand(...)` directly, with no further plumbing needed.
- **Context menus** are equally ready to be wired the same way, whenever a Work Package is scoped to build one.
- **`PlatformInputService` currently has no notion of "input source"** (palette vs. shortcut vs. menu) — it wasn't asked for and wasn't added, to avoid inventing unrequested features. If a future Work Package needs to distinguish invocation origin (e.g., for a "recent commands" list, explicitly out of scope for WP-STUDIO-024/026), that would be the natural place to extend `runCommand`'s signature, not a reason to add a second forwarding layer.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
