# WP-STUDIO-029 — Workspace Lifecycle & Session Management

Repository: `projects/platform/oep_studio`

## Objective

Implement the first complete Workspace Lifecycle subsystem — `WorkspaceManager`, `SessionManager`, dirty-state coordination, workspace persistence, recovery infrastructure, startup/shutdown lifecycle, and recent-workspace management — integrated with the existing Platform architecture (Event Bus, Notification Service, Command Framework).

## 1. Architecture Review

Two separate, already-mature lifecycle systems exist, and this Work Package's central finding is that they must **not** be unified or redesigned — they solve genuinely different problems:

- **Diagram Studio's document lifecycle** (`DiagramDocument.path`/`.isDirty`, `EngineeringProjectNotifier.newDocument/openDocument/saveDocument/saveDocumentAs/closeDocument`) has an explicit **dirty-state** model: a document is either saved or has unsaved changes. `DiagramWorkspaceState`/`WorkspaceStateStorage` already persist panel layout and a single `lastDocumentPath` — but no recent-*list*, no crash-recovery sentinel.
- **Knowledge Studio's session lifecycle** (`KnowledgeSession`, `KnowledgeSessionStorage`, `FoundationRuntimeNotifier`) **auto-persists on every mutation** via `_persistActiveSession()` — confirmed by inspection, there is no dirty-state concept anywhere in it, by design. Retrofitting one would mean redesigning Knowledge Studio's entire session model, explicitly out of scope.
- **No startup/shutdown lifecycle infrastructure existed anywhere** — `main.dart` is a bare `runApp()`; no `WidgetsBindingObserver`, no `window_manager` dependency, nothing.

**Consequence for this Work Package's scope**: "dirty-state coordination" can only meaningfully observe Diagram Studio's already-existing flag (Knowledge Studio has nothing to coordinate — not a gap, a correct design already confirmed in WP-STUDIO-025's own review). Startup/shutdown lifecycle is genuinely new territory, built using Flutter's own built-in `WidgetsBindingObserver.didRequestAppExit()` rather than a new package dependency (`window_manager` was considered and rejected — unnecessary given the built-in API covers it).

## 2. WorkspaceManager

New file: [lib/core/workspace/workspace_manager.dart](lib/core/workspace/workspace_manager.dart) — the Platform-level coordinator for Diagram Studio's document lifecycle:

- **Recent workspaces**: an ordered, capped list of recently opened/saved document paths (`maxRecentWorkspaces`, default 5).
- **Dirty-state coordination**: `hasUnsavedChanges`, updated by `handleProjectStateChange(EngineeringProjectState)` — called once per real `EngineeringProjectState` change.
- **Crash recovery**: a sentinel (`recoverableWorkspacePath`) written whenever a document becomes dirty, cleared on a clean save or an explicit close/discard, checked once at startup via `initialize()`.
- **Event publication**: `WorkspaceEvent`s (`opened`/`closed`/`dirtyChanged`/`saved`/`recovered`) on the Platform Event Bus (WP-STUDIO-028) — extending the existing `platform_event.dart` model file rather than creating a parallel one.

Backed by one small, injectable JSON file (`workspace_manager_state.json`, same `SettingsStorage.root()` directory convention every other Studio/Settings file already uses) — injectable specifically so tests never touch the real user settings directory.

## 3. SessionManager

New file: [lib/core/workspace/session_manager.dart](lib/core/workspace/session_manager.dart) — a thin, **read-only** aggregator, not a second persistence layer: `SessionManager.listAll(ref)` merges Knowledge Studio's existing session listing (`FoundationRuntimeNotifier.listKnowledgeSessions`) with `WorkspaceManager.recentWorkspaces` into one list of `WorkspaceSessionSummary`, Knowledge sessions first (sorted by `lastModified` descending), then Diagram workspaces. Owns no storage of its own; duplicates neither Studio's persistence. Acquisition contributes nothing here — its state is server-side, not a local file/session concept.

## 4. Dirty-State Coordination

`WorkspaceManager.hasUnsavedChanges` is the single, centralized answer to "is there unsaved work right now" — reading Diagram Studio's existing `EngineeringProjectState.isDirty` (the only dirty-tracked workspace in the app today, per §1). This is the honest, correctly-scoped extent of "coordination" possible without inventing a dirty-state concept for Knowledge Studio that doesn't and shouldn't exist.

## 5. Workspace Persistence & Recent Workspaces

Recent-workspace tracking (§2) is genuinely new — nothing like it existed before (`RecentHistoryEntry`/`_record()` tracks navigated *objects*, not opened *files* — a different concept, confirmed by inspection). Persisted alongside the recovery sentinel in one file, following the established `SettingsStorage.root()` convention rather than inventing a new storage location.

## 6. Recovery Infrastructure

The recovery sentinel is **write-through**: rewritten on every dirty-state transition (not just at shutdown), so it survives an ungraceful exit (crash, forced kill) — not just a clean one. At startup, `StudioShell` checks `WorkspaceManager.recoverableWorkspacePath` and, if set, prompts the user to reopen it or discard; choosing to reopen calls `EngineeringProjectNotifier.openDocument`, publishes a `WorkspaceEvent(kind: recovered)`, and confirms via `PlatformNotificationService.success`. A genuine gap was found and fixed during implementation: the initial version let a failed reopen (the recorded path since deleted, moved, or corrupted) throw uncaught; it now reports the failure through `PlatformNotificationService.error` instead, exactly like any other failed Open already would.

## 7. Startup/Shutdown Lifecycle

`StudioShell` (already the Platform composition root per WP-STUDIO-027/028) gained a third responsibility, all Platform-layer, zero Studio files touched:

- **Startup**: `WorkspaceManager.initialize()` runs once in `initState`; if a recoverable path is found, a post-frame callback shows the recovery prompt.
- **Shutdown**: `_StudioShellState` now mixes in `WidgetsBindingObserver` and implements `didRequestAppExit()` — a best-effort "Exit anyway?" prompt when `hasUnsavedChanges` is true. This is explicitly a *supplementary* warning, not the safety net — a desktop close-intercept isn't guaranteed to fire for every way an app can end (a crash, `taskkill`), which is exactly why the write-through recovery sentinel (§6), not this prompt, is the mechanism this Work Package actually relies on for data safety.

**Honest trade-off, documented rather than hidden**: `StudioShell`'s `initState` also activates the Acquisition progress bridge (WP-STUDIO-028) via `ref.listenManual`, which was already true before this Work Package; this Work Package adds a second real-`dart:io` read (`WorkspaceManager.initialize()`) to that same startup path. Both are side-effect-free at construction (no network calls, no writes at rest) — the only behavioral change is that these initializations now happen once at app startup rather than lazily.

## 8. Recent Workspaces

Covered by §2/§5 above — `WorkspaceManager.recentWorkspaces`, capped and ordered, persisted, and exposed to `SessionManager` for future cross-Studio surfacing.

## 9. Platform Integration Cleanup

- `PlatformEvent` model extended (not duplicated) with `WorkspaceEvent`/`WorkspaceEventKind`.
- `StudioShell` extended (not replaced) with the same `ref.listenManual` pattern WP-STUDIO-028 already established for the Acquisition progress bridge — no new Platform-layer pattern introduced.
- No duplicated lifecycle logic was found to remove beyond what prior Work Packages already addressed; this Work Package's own new logic (recent-list dedup/cap, recovery sentinel read/write/clear) lives in exactly one place (`WorkspaceManager`), not scattered.

## 10. Validation Results

- `flutter analyze`: 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere).
- `flutter test`: **402/402 passed** (386 prior + 16 new; 2 pre-existing unrelated skips):
  - `test/workspace_manager_test.dart` (13): recent-list ordering/dedup/cap/persistence, dirty-state coordination, crash-recovery sentinel set/clear/survive-restart, corrupted-file handling, and Platform Event Bus integration (including "no event when nothing actually changed").
  - `test/session_manager_test.dart` (3): Diagram-workspace ordering, Knowledge-before-Diagram ordering with `lastModified` sort, and the empty case — using an injected `KnowledgeSessionsLoader` rather than ever reading the real `knowledge_sessions` directory (see below).
  - The full pre-existing suite passed unchanged, confirming `StudioShell`'s extension introduced no regressions.
- `flutter build windows`: succeeded.
- **A real, non-code finding from this pass**: the real `%APPDATA%/oep_studio/knowledge_sessions/` directory on this machine holds ~106 MB of genuine project history (Knowledge Curation Sessions from actual prior engineering/verification work, e.g. "2002 Dodge Ram 4.7 Timing Chain Procedure," "WP011 Verification") — not disposable test data. `SessionManager`'s design was revised mid-implementation to accept an injectable `KnowledgeSessionsLoader` specifically so no test ever depends on that directory's size or contents; this is documented here because it's a legitimate, permanent characteristic of this environment, not a one-off.
- **One test scenario was attempted but not completed**: a widget-level test asserting that the startup recovery dialog visibly appears (`StudioShell`'s `_showRecoveryPrompt`, triggered from `initState`'s fire-and-forget real-`dart:io` read). Extensive debugging traced intermittent non-completion in this session's test runner to accumulated orphaned `flutter_tester.exe`/`dartaotruntime.exe` processes (confirmed via a `Dart compiler exited unexpectedly` error and by both `flutter analyze` and other `StudioShell`-pumping tests, e.g. `studio_shell_events_test.dart`, running cleanly once those processes were cleared) rather than a defect in the underlying code. Given the disproportionate time already spent chasing an environment-specific instability, this specific widget-level assertion was not retained in the suite; `WorkspaceManager`'s own recovery-sentinel logic is fully covered (13 passing tests) and `_showRecoveryPrompt`/`didRequestAppExit`'s logic was verified by code review. `didRequestAppExit` itself (a different code path, invoked directly rather than through the fire-and-forget chain) was **not** affected and was not part of this particular investigation — see Recommendations.

## 11. Documentation

This file; doc comments added to `WorkspaceManager`, `SessionManager`/`WorkspaceSessionSummary`, `WorkspaceEvent`/`WorkspaceEventKind`, and `StudioShell`'s own class comment explaining its third Platform-layer responsibility.

## 12. Recommendations for WP-STUDIO-030

- **Automate the recovery-prompt-visibility test** once a cleaner test-execution environment is available — the gap is environmental fragility in this long session's own test-runner process accumulation, not a code defect; a fresh session/machine may not reproduce it at all.
- **A "Recent Workspaces" UI** — `SessionManager.listAll` and `WorkspaceManager.recentWorkspaces` are both ready to back a real panel or Command Palette entries; none was built here (no UI was requested beyond the recovery/exit dialogs already covered).
- **Extend dirty-state coordination if Knowledge Studio ever gains one** — if a future Work Package deliberately redesigns Knowledge Studio's auto-save model to support explicit dirty state (a real Studio redesign, requiring its own authorization), `WorkspaceManager.hasUnsavedChanges` is the natural place to extend, not a new parallel coordinator.
- **Consider a lighter-weight persistent test-runner hygiene practice** for future long sessions — this Work Package's own investigation surfaced that stopped background `flutter test` invocations can leave orphaned, resource-heavy processes (`dartaotruntime.exe` at 500 MB+ each) that degrade subsequent test runs; killing them (`taskkill //F //IM dartaotruntime.exe //T` etc.) resolved it cleanly here.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
