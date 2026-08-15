# WP-STUDIO-024 — Platform Command Palette

Repository: `projects/platform/oep_studio`

## Objective

Implement the first user-facing consumer of the Platform Command Framework: a centralized Command Palette that discovers and executes commands already registered with the Platform, validating the architecture built by WP-STUDIO-021 (Studio Registry), WP-STUDIO-022 (Capability Metadata), and WP-STUDIO-023 (Command Framework). The palette is a pure Platform UI component — it does not register commands, own metadata, contain Studio logic, or implement execution logic; all of that stays in the infrastructure those three Work Packages already built.

## Pre-implementation check: existing infrastructure

Per this Work Package's own instruction, the repository was searched before writing any code for an existing command palette, action system, or search dialog. None exists — a repo-wide search for "palette"/"command dialog"/"action list" matched only a doc-comment forward-reference in `studio_destination.dart`, an unrelated `Icons.palette_outlined` (color palette), and this Work Package's own predecessor files. **No refactor of prior art was triggered; this is new construction**, built to strengthen (not duplicate) the WP-STUDIO-021/022/023 architecture.

One important piece of prior art *was* found and reused rather than replaced: `StudioToolbar` (`lib/app/widgets/studio_toolbar.dart`) already has a disabled search field with hint text `"Search (Ctrl+K)"`, and its class doc comment explicitly says these toolbar actions "are wired to the Command System (SDD-010) in a later work package." That is this Work Package. See Phase 6 below.

## 1. Command Palette Architecture

New file: [lib/app/widgets/command_palette_dialog.dart](lib/app/widgets/command_palette_dialog.dart), placed alongside `studio_toolbar.dart`/`studio_nav_rail.dart` — the existing home for Platform-chrome-level widgets, as distinct from any Studio's own `panels`/`workspaces` folders. `showCommandPaletteDialog(BuildContext context)` opens it via the same `showDialog<void>(...)` convention already used by `showSessionBrowserDialog`/`showFoundationErrorDialog`, and its internals follow the same `AlertDialog`/`StudioColors.surfaceRaised` visual language for every secondary dialog (argument prompt, error outcome) it shows.

The dialog reads two static singletons directly — `CommandRegistry.defaultRegistry` and `StudioRegistry.defaultRegistry` — and stores no local copy of anything they return. `showCommandPaletteDialog` also accepts optional `commandRegistry`/`studioRegistry` parameters (defaulting to those same singletons) solely so tests can exercise the "no commands registered" empty state with a deliberately empty registry; production call sites never pass them.

## 2. UI Implementation (Phase 1)

A modal `Dialog` (560×480 max) containing:
- **Header** — "Commands" title with an icon, establishing it as a distinct Platform surface (not a Studio panel).
- **Search field** — a `TextField` matching the styling of `SearchPage`'s own search box (`isDense`, `prefixIcon`, rounded `OutlineInputBorder`).
- **Scrollable command list** — `ListView.builder` over the filtered command set; each row (`_CommandRow`) shows the command name, a Studio-name tag, a capability-name tag, and (when non-empty) the command's description — the four bullet points Phase 1 required, each read live rather than duplicated (see Phase 2).

No existing widget was redesigned to build this — `KnowledgePanel`/`StudioNavRail`/`StudioToolbar` etc. are untouched except for the one intentional toolbar wiring in Phase 6.

## 3. Command Framework Integration (Phase 2)

Every value shown or acted on comes from a live registry call, never a local field:
- The command list itself: `CommandRegistry.defaultRegistry.commands` (or the injected registry in tests).
- Studio name per row: `StudioRegistry.defaultRegistry.ownerOf(command.capabilityId)?.label`.
- Capability name per row: `StudioRegistry.defaultRegistry.findCapability(command.capabilityId)?.label`.
- Command name/description: `command.label`/`command.description` directly off the `CommandDescriptor`.

There is no second list, no cached snapshot, and no `if (command.id == ...)` branching anywhere in the file — the palette has zero Studio-specific knowledge; it only knows the generic `CommandDescriptor`/`CapabilityDescriptor` shapes WP-STUDIO-022/023 already defined.

## 4. Search Implementation (Phase 3)

`_matches()` performs simple, case-insensitive substring matching against exactly the four fields Phase 3 named: command label, description, the resolved Studio name, and the resolved capability name. No fuzzy matching, ranking, or synonym expansion — matching WP-STUDIO-023's own `UnifiedSearchService` precedent of "simple substring is sufficient, don't build more."

## 5. Execution Integration (Phase 4)

Selecting a command always calls `CommandRegistry.execute(ref, command.id, args: ...)` — the palette never touches `AcquisitionRuntimeNotifier`, `EngineeringProjectNotifier`, or any other Studio object directly. For a command with `requiresArgument: true`, a generic (Studio-agnostic) prompt dialog collects a single string value first; cancelling it aborts before `execute` is ever called. Outcomes are handled per `CommandOutcome`:
- **success** → the palette closes and a `SnackBar` confirms completion (matching the existing `SnackBar` pattern already used in `commit_report_dialog.dart`/`ai_settings_page.dart`/`settings_workspace_page.dart`).
- **notFound / invalidArguments / failure** → an `AlertDialog` (same `StudioColors.surfaceRaised` styling as `showFoundationErrorDialog`) shows `result.errorMessage`; the palette itself stays open so the user can try something else.

## 6. Empty States (Phase 5)

- **No commands registered** — shown when `CommandRegistry.commands` is empty (verified with an injected empty registry in tests, since the real default registry is never empty in production).
- **No search results** — shown when the current query matches nothing, naming the query back to the user.
- **Execution failure** — handled via the outcome `AlertDialog` above, not a silent no-op.

## 7. Platform Integration (Phase 6)

`StudioToolbar`'s existing, previously-inert search field (`enabled: false`, hint `"Search (Ctrl+K)"`) is now wired to `showCommandPaletteDialog`. It is not a new toolbar button — same position, same size, same visual chrome — wrapped in a `Material`/`InkWell` (with the disabled `TextField` beneath it excluded from hit-testing via `IgnorePointer`, so the tap reaches the `InkWell`) rather than added as a new element, which would have risked exactly the "toolbar redesign" this Work Package is told not to do. The hint text was shortened from `"Search (Ctrl+K)"` to `"Commands"` — the `(Ctrl+K)` portion was dropped rather than carried forward, since implementing that keyboard shortcut is explicitly out of scope for this Work Package and leaving it would have promised behavior that doesn't exist yet. No `Shortcuts`/`CallbackShortcuts` binding was added anywhere.

## Validation Results

- **Every registered command appears**: verified against the real `CommandRegistry.defaultRegistry` (13 commands) — the first-registered (`New Diagram`) and last-registered (`Publish to Reference Vault`) both resolve in the list, scrolled into view.
- **Filtering works correctly**: verified for all four match fields (command name, Studio name, capability name, description), each with both a positive and a negative assertion.
- **Execution routes exclusively through the Command Framework**: verified by exercising `diagram.undo` (a real registered command) end-to-end through the dialog and observing the same `CommandResult`-driven success/close/SnackBar behavior `CommandRegistry.execute` already guarantees (tested directly in WP-STUDIO-023) — the dialog itself contains no call to any Studio Notifier.
- **No duplicated metadata**: confirmed by code inspection — `command_palette_dialog.dart` has no local list, map, or constant reproducing any command/capability data; every display value is a direct registry lookup performed at build time.
- **No Studio-specific logic inside the Command Palette**: confirmed by code inspection — no command id or Studio destination is referenced by name anywhere in the file; all behavior is driven by the generic `requiresArgument`/`CommandOutcome` shapes.
- **Existing functionality remains unchanged**: `flutter analyze` — 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere). `flutter test` — **357/357 passed** (345 prior + 12 new; 2 pre-existing unrelated skips). `flutter build windows` — succeeded.

New test file: [test/command_palette_dialog_test.dart](test/command_palette_dialog_test.dart), 12 tests covering discovery, all four search dimensions, both empty states, both execution paths (no-argument success; `requiresArgument` prompt + cancel), and the toolbar entry point end-to-end via a full `StudioApp` pump.

## Documentation

This file; inline doc comments added to `command_palette_dialog.dart` and updated on `studio_toolbar.dart` explaining the now-live field.

## Recommendations for WP-STUDIO-025

- **Keyboard shortcut.** The toolbar hint used to say `"(Ctrl+K)"` and users will expect it; wiring an actual `CallbackShortcuts`/`Shortcuts` binding at the `StudioShell` level (mirroring the precedent already set by Diagram Studio's own `CallbackShortcuts` for `StudioCommandActions`) is the natural, explicitly-deferred next step.
- **Richer arguments.** As WP-STUDIO-023 already flagged, `acquisition.createSource`/`createJob`/`startDownload` and Diagram's clipboard commands all need more than one string to invoke for real; the palette's current single-field prompt can't serve those until `CommandArgs` grows a richer shape.
- **Recent/favorite commands** were explicitly out of scope here (per this Work Package's own "Out of Scope" list) but are a common, low-risk next enhancement once real usage data exists — do not build them speculatively.
- **Startup validation.** With three interlinked registries now live (`StudioRegistry`, `CommandRegistry`, and the palette consuming both), asserting `CommandRegistry.defaultRegistry.validate().isEmpty` and `StudioRegistry.defaultRegistry.validateCapabilities().isEmpty` once at app startup (debug builds) is increasingly worth doing before a fourth consumer arrives.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization.
