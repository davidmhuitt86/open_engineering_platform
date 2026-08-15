# WP-STUDIO-027 — Platform Interaction Layer

Repository: `projects/platform/oep_studio`

## Objective

Complete the first generation of Platform interaction infrastructure by centralizing keyboard shortcuts, toolbar actions, context menu routing, and interaction flow using the existing `PlatformInputService` (WP-STUDIO-026).

## 1. Architecture Review

**Keyboard shortcuts**: Diagram Studio already has its own local `CallbackShortcuts` (Ctrl+Z/Y/Shift+Z/C/X/V/D/S/A, Delete, Backspace, Escape), scoped to `DiagramStudioPage` and wired to `StudioCommandActions`/its own document-bar methods — Studio-owned interaction, untouched by this Work Package. **No Platform-level keyboard shortcut binding existed anywhere else** — Ctrl+K, promised by the toolbar's own hint text since WP-STUDIO-024, was still not implemented.

**Toolbar actions**: `StudioToolbar`'s `Open`/`Save`/`Import`/`Export`/`Validate` buttons have been fully inert (`onPressed: null`) since Work Package 001. Diagram Studio's own document-bar buttons (`_newDocument`/`_openDocument`/`_saveDocument`/`_saveAsDocument`/`_closeDocument`, private to `DiagramStudioPage`) already call the same underlying `EngineeringProjectNotifier` methods the `diagram.*` Commands wrap — but each carries additional Studio-specific orchestration a generic Command executor doesn't perform: `_confirmDiscardChanges()` dirty-check dialogs, native file pickers (`openFile`/`getSaveLocation`), `_persistWorkspaceState()`, and local `setState` to refresh the page's own document bar. Rerouting these through `PlatformInputService.runCommand` would either lose today's plain exception propagation (silently becoming a swallowed `CommandResult.failure` instead) or require duplicating that orchestration inside a Command executor — both judged unsafe/inappropriate for this Work Package's scope ("do not redesign Studios").

**Context menus**: a repo-wide search for `showMenu`/`ContextMenu`/`onSecondaryTap` found none. The only `PopupMenuButton` usage anywhere (`lib/diagram_studio/toolbars/diagram_toolbars.dart`) is Diagram Studio's own left-click symbol-picker dropdowns ("Add node", "Replace symbol") — a Studio-specific value-selection control, not a right-click command surface, and not shaped like a Command (`id` + at most one string argument). There is nothing resembling a Platform context-menu system to integrate.

## 2. Keyboard Shortcut Framework

`StudioShell` (`lib/app/studio_shell.dart`, wraps every route via `app_router.dart`'s `ShellRoute`) is now wrapped in `Focus(autofocus: true, child: CallbackShortcuts(bindings: {...}, child: Scaffold(...)))` — reusing the exact same `CallbackShortcuts` widget Diagram Studio's own shortcuts already rely on, one layer higher, rather than introducing a new shortcut mechanism. This is the centralized "framework": one shared binding point, extendable by adding more entries to the same `bindings` map in the future.

Because Flutter's key-event handling walks from the currently focused node up through its ancestors, a Studio's own more specific `CallbackShortcuts` (like Diagram Studio's) always gets first refusal; the Shell-level binding only fires for a combination nothing closer has already claimed. No existing Studio shortcut was touched, and none can be shadowed by this change — Ctrl+K isn't bound anywhere else.

## 3. Ctrl+K → Command Palette

```dart
const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPaletteDialog(context),
```

Verified end-to-end: pumping the full `StudioApp`, sending Ctrl+K, and confirming the palette opens — from the Dashboard (no Studio-level shortcut competing) and implicitly everywhere else, since the binding lives at the Shell level every route renders inside.

## 4. Toolbar Integration

`StudioToolbar`'s existing "Validate" button is now wired — the one toolbar action judged genuinely safe and appropriate to route through `PlatformInputService`, because `diagram.revalidate` is a pure, side-effect-free state recompute with none of the dirty-check/file-picker/persistence orchestration described in §1. It's enabled only when `StudioDestination.diagram` is the active destination (`canValidate = selected == StudioDestination.diagram`), calling `PlatformInputService.defaultService.runCommand(ref, 'diagram.revalidate')`; every other destination sees the exact same disabled button as before — a strict, verified improvement with zero behavior change anywhere else. `_ToolbarAction` gained an optional `onPressed` parameter (default `null`) to make this possible without altering its appearance.

`Open`/`Save`/`Import`/`Export` remain placeholders, per §1's reasoning — this is an intentional, documented "not appropriate yet" conclusion, not an oversight.

## 5. Context Menu Integration

None exists to integrate (§1). Nothing was built, per the Requirements ("do not implement context menus" — this Work Package reviews and integrates *existing* ones only, and there are none).

## 6. Command Metadata Improvements

All 18 registered `CommandDescriptor`s were re-read for clarity and consistency (label capitalization, one-sentence descriptions, action-oriented phrasing). **No changes were made** — the metadata written across WP-STUDIO-023/025 was already consistent and clear; inventing edits for their own sake would have been busywork, not improvement.

## 7. Routing Cleanup

No further duplication was found beyond what WP-STUDIO-026 already fixed (the `diagram.undo`/`redo` executors now routing through `StudioCommandActions`). The Diagram Studio document-bar methods discussed in §1 were deliberately left as-is rather than partially rerouted, since a partial fix (swapping only the final notifier call) would have introduced the silent-failure regression described there.

## Validation Results

- `flutter analyze`: 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere).
- `flutter test`: **370/370 passed** (365 prior + 5 new; 2 pre-existing unrelated skips):
  - `test/studio_toolbar_test.dart` (new, 4 tests): Validate disabled on a non-Diagram destination, enabled on Diagram, runs without throwing with no diagram open, and every other toolbar action remains exactly as inert as before.
  - `test/command_palette_dialog_test.dart` (+1 test): Ctrl+K opens the palette from a full `StudioApp` pump.
  - The full pre-existing suite (`widget_test.dart`, `unified_workflow_test.dart`, etc.) passed unchanged, confirming the `Focus`/`CallbackShortcuts` wrapping and `StudioToolbar`'s `StatelessWidget` → `ConsumerWidget` conversion introduced no regressions.
- `flutter build windows`: succeeded.

## 8. Documentation

This file; updated doc comments on `StudioShell`, `StudioToolbar`, and `_ToolbarAction` explaining the new shortcut binding and the Validate wiring's rationale.

## 9. Recommendations for WP-STUDIO-028

- **Diagram Studio's document-bar actions** are the clearest remaining "duplicated interaction routing" candidate, but fixing them properly requires a richer solution than this Work Package's scope allows: either (a) teach `CommandRegistry`/`PlatformInputService` to carry a Studio-specific "pre-flight" step (dirty-check, file picker) before dispatch, or (b) accept that Studio-orchestrated actions with UI side effects (confirmation dialogs, native pickers) simply aren't a good fit for the Command Framework's current shape and leave them Studio-owned permanently. This is a real design decision, not a routing fix — worth a dedicated Work Package.
- **A generic "which commands apply to the active Studio" toolbar** — right now only "Validate" was wired, by hand, with a hardcoded `StudioDestination.diagram` check. If more per-Studio toolbar actions get wired this way, consider having `StudioToolbar` instead ask `StudioRegistry.capabilitiesFor(selected)`/`CommandRegistry.commandsForStudio(selected)` generically, rather than accumulating more one-off `selected == StudioDestination.x` checks.
- **Context menus**: still nothing to build until a real need for one arises; don't invent one speculatively.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
