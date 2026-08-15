# WP-STUDIO-028 — Platform Event & Notification Framework

Repository: `projects/platform/oep_studio`

## Objective

Complete the Platform communication layer: a centralized Event Bus, Notification Service, lifecycle events, and lightweight progress reporting, reducing direct coupling between Platform components. This is Category C infrastructure every prior Work Package since WP-PLAT-020 deliberately deferred ("Do NOT implement Event Bus," "Do NOT implement notifications") — this Work Package is the first authorized to build it.

## 1. Architecture Review

Inventoried every existing callback/listener/notification mechanism before writing anything:

- **Riverpod `Notifier` state** (`FoundationRuntimeNotifier`, `EngineeringProjectNotifier`, `AcquisitionRuntimeNotifier`) is the app's primary, and correct, reactivity mechanism — this Work Package does not replace or compete with it. Every event publisher added here already reads that state itself before publishing a fact about it; the bus carries facts, not state.
- **Engine-level `Stream`s** are already consumed inside `EngineeringProjectNotifier` (`sessionChanges`, `selection.changes`, `viewState.changes`) — precedent for Stream-based plumbing already exists in this codebase; the Event Bus reuses the same primitive (`Stream`/`StreamController`), not a new paradigm.
- **Ad hoc `SnackBar` notifications** were the clearest real duplication: `commit_report_dialog.dart`, `ai_settings_page.dart`, `settings_workspace_page.dart`, `evidence_navigation.dart`, and `command_palette_dialog.dart` each built their own `ScaffoldMessenger.showSnackBar(SnackBar(...))` independently, with no shared styling.
- **`RecentHistoryEntry`/`_record()`** (`unified_navigation.dart`) is an existing "something happened, log it centrally" precedent, but only fires for a subset of navigation (cross-reference/search-result clicks), not plain nav-rail switches — not reused directly, but confirms the pattern of centralizing cross-cutting facts is already accepted here.
- **Progress**: `DownloadSession.progressPercentage` (`int`, WP-PLAT-020) is the one already-computed, already-reliable progress signal in the app. Only `status == 'completed'` is a confirmed status string anywhere in the UI (`acquisition_pipeline_panel.dart`); no other status string is verified, so progress detection was designed around the numeric percentage, not a guessed status vocabulary.

## 2. Platform Event Bus

New file: [lib/core/events/platform_event_bus.dart](lib/core/events/platform_event_bus.dart) — a single `StreamController<PlatformEvent>.broadcast()` wrapped in `publish()`/`events`/`on<T>()`, plus a `static final instance` singleton matching the `StudioRegistry`/`CommandRegistry` convention. No persistence, no replay, no filtering beyond a type check — deliberately minimal, per "keep the implementation lightweight."

## 3. PlatformEvent Model

New file: [lib/core/events/platform_event.dart](lib/core/events/platform_event.dart) — an immutable `PlatformEvent` base with three concrete, all-real-emitter subtypes:
- `CommandExecutedEvent { commandId, result }`
- `StudioLifecycleEvent { destination, phase }` (`StudioLifecyclePhase.entered` only — `left` was not modeled; there's no reliable existing signal distinguishing "left Studio A" from "entered Studio B" beyond the entry itself, so it wasn't guessed at)
- `ProgressEvent { id, label, fraction }`

## 4. Notification Service

New file: [lib/core/notifications/platform_notification_service.dart](lib/core/notifications/platform_notification_service.dart) — `PlatformNotificationService.success/error/info(context, message)`, a consistent wrapper around `ScaffoldMessenger` (not a new mechanism — still exactly `SnackBar` underneath, now with consistent severity coloring). `command_palette_dialog.dart`'s existing ad hoc `showSnackBar` call was migrated to it. The other four scattered call sites found in §1 (all inside Knowledge Studio or Settings) were deliberately **not** migrated in this pass — see Recommendations.

The Notification Service does **not** subscribe to the Event Bus itself. `command_palette_dialog.dart` already shows its own result feedback (a `PlatformNotificationService.success` call on success, an `AlertDialog` on failure); having the Notification Service *also* react to `CommandExecutedEvent` independently would have shown the user two notifications for one command run — exactly the kind of duplication this Work Package is meant to remove, not add.

## 5. Lifecycle Events

`StudioShell` (`lib/app/studio_shell.dart`) — already the one place every route renders through (WP-STUDIO-027 already added its `Focus`/`CallbackShortcuts` wrapping there) — became a `ConsumerStatefulWidget`. Its `State` publishes exactly one `StudioLifecycleEvent(phase: entered)` in `initState` (first mount) and in `didUpdateWidget` **only when `oldWidget.selected != widget.selected`** — comparing the shell's own `selected` prop, not re-deriving Studio-switch detection from scratch. This guarantees "exactly once per real transition," verified by test (rebuilding with the *same* destination publishes nothing further).

Zero Studio files were touched for this — the shell already receives `selected` from `app_router.dart`'s `ShellRoute`, so no Studio needed to change to make lifecycle events observable.

## 6. Progress Reporting

`StudioShell.initState` also calls `ref.listenManual<AcquisitionServiceState>(acquisitionRuntimeServiceProvider, ...)`, translating any `DownloadSession` with `progressPercentage < 100` into a `ProgressEvent`, disposed in `State.dispose()`. This reuses already-existing, already-fetched data — no new progress-tracking state was introduced anywhere.

**Honest trade-off**: this means `AcquisitionRuntimeNotifier` now initializes (constructs an idle `http.Client`, no network I/O) as soon as the app starts, rather than only once the user first opens Engineering Acquisition Studio. The alternative — adding this listener inside `AcquisitionStudioPage` itself — would have required editing a Studio file directly, which was judged a bigger risk to "do not redesign Studios" than this small, side-effect-free early-initialization cost. No network request fires until the user takes a real action; only object construction happens earlier.

## 7. Platform Cleanup

- `PlatformInputService.runCommand` (WP-STUDIO-026) now publishes `CommandExecutedEvent` after every call — a one-line addition to the method that was already the sole dispatch chokepoint (verified in WP-STUDIO-026: nothing else calls `CommandRegistry.execute` directly), so there is exactly one publish per command run, never a duplicate.
- `command_palette_dialog.dart`'s ad hoc `SnackBar` was replaced with `PlatformNotificationService.success` (§4) — real duplication removed, not just identified.
- No other duplication was removed; the remaining scattered `SnackBar` call sites are documented, not silently left unmentioned (see Recommendations).

## 8. Validation Results

- `flutter analyze`: 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere).
- `flutter test`: **386/386 passed** (370 prior + 16 new; 2 pre-existing unrelated skips):
  - `test/platform_event_bus_test.dart` (5): publish/subscribe, typed `on<T>()` filtering, deterministic multi-subscriber ordering, post-dispose no-op, singleton identity.
  - `test/platform_notification_service_test.dart` (5): success/error/info show the right message, success and error use distinct colors (verified per notification, split into independent tests after discovering a single `ScaffoldMessenger` queues a second `SnackBar` behind the first rather than replacing it — a test-methodology fix, not a production bug).
  - `test/platform_input_service_test.dart` (+3): `CommandExecutedEvent` published exactly once per `runCommand` call, including for a `notFound` result, and via the default `PlatformEventBus.instance` when no bus is injected.
  - `test/studio_shell_events_test.dart` (3, new file): lifecycle event fires once on mount, once per real destination change, and — critically — **not** again when rebuilt with the same destination (deterministic dispatch, directly verifying task 8's requirement).
- One real debugging detour, documented for future reference: three new `testWidgets` tests initially hung indefinitely using a bare `await Future<void>.delayed(Duration.zero)` to let a broadcast stream's microtask-queued event deliver before asserting. This is a known Flutter test-binding gotcha (this codebase's own `widget_test.dart` already documents an adjacent case for `tester.runAsync`) — fixed by using `await tester.pump()` instead, which correctly flushes the pending microtask.
- `flutter build windows`: succeeded.

## 9. Documentation

This file, plus doc comments on `PlatformEventBus`, `PlatformEvent`/its subtypes, `PlatformNotificationService`, `PlatformInputService`, and `StudioShell` explaining each new responsibility and its rationale.

## 10. Recommendations for WP-STUDIO-029

- **Migrate the remaining scattered `SnackBar` call sites** (`commit_report_dialog.dart`, `ai_settings_page.dart`, `settings_workspace_page.dart`, `evidence_navigation.dart`) to `PlatformNotificationService` — identified in this Work Package's review but deliberately left alone since they live inside Knowledge Studio/Settings files; migrating them is straightforward but should be scoped and verified on its own rather than bundled in.
- **A real Event Bus consumer** — nothing subscribes to `CommandExecutedEvent`/`StudioLifecycleEvent`/`ProgressEvent` in production yet (only tests do, to prove the bus works). A Notification Center panel, an activity/audit log, or a progress indicator in the status bar are all natural next consumers — none were built here to avoid inventing UI beyond what was asked.
- **`StudioLifecyclePhase.left`** was deliberately not modeled — if a future consumer genuinely needs "the user is about to leave Studio X" as a distinct moment from "entered Studio Y," that's a real design question (what does "leaving" mean when navigating Dashboard → Diagram → Dashboard, e.g.) worth its own consideration rather than a guess made here.
- **Revisit the Acquisition early-initialization trade-off** (§6) if it ever proves costly — e.g., if `AcquisitionRuntimeNotifier`'s `build()` grows real I/O in the future, moving the progress bridge into `AcquisitionStudioPage` itself (accepting a small, deliberate Studio-file edit) would be the fix.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
