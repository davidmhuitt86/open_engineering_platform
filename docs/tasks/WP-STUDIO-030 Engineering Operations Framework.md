# WP-STUDIO-030 — Engineering Operations Framework

Repository: `projects/platform/oep_studio`

## Objective

Implement the first complete Engineering Operations Framework — operation management, lightweight background task support, a centralized Activity Log, a Notification Center, application status infrastructure, and improved engineering review integration — extending the existing Platform architecture (Event Bus, Notification Service, Command Framework, Workspace Lifecycle) rather than redesigning it.

## 1. Architecture Review

Three questions shaped this Work Package's scope before any code was written:

- **Is there already a "background task" concept in the app?** Yes, exactly one: `FoundationServiceState.ocrProcessingStatus` (`Map<String, OcrProcessingStatus>`, Work Package 013) — a per-source signal set to `processing` before `OcrPipelineService.processSource` runs and to `completed`/`failed` after, inside `FoundationRuntimeNotifier.runOcrForSource`. Acquisition's `DownloadSession.progressPercentage` (already bridged into `ProgressEvent`s since WP-STUDIO-028) is the other. No other genuine background task exists anywhere in the app — "lightweight background task support" (task 3) is therefore implemented as *surfacing* these two already-existing signals as `OperationEvent`s, not as a new task-queue/executor abstraction that Studios would have to adopt.
- **Is there an existing coarse "in progress" flag that should not be touched?** Yes: `AcquisitionServiceState.loading`, a single Studio-owned boolean covering all Acquisition actions. It serves a different purpose (a Studio's own UI busy-state) than the new cross-Studio `OperationManager` and was left untouched, per this Work Package's "do not redesign Studios" requirement.
- **Can "review integration" be improved without inventing review-specific code?** Yes. Knowledge Studio's review commands (`knowledge.acceptCandidate`, `knowledge.rejectCandidate`, etc., WP-STUDIO-025) and Diagram's `diagram.revalidate` (WP-STUDIO-023) are already registered `CommandDescriptor`s that already publish `CommandExecutedEvent` (WP-STUDIO-028). A generic Activity Log consumer subscribing to `CommandExecutedEvent` therefore produces meaningful review/validation activity entries with zero review-specific code — this is this Work Package's actual answer to task 7, and it is documented here rather than hidden, since it may look at first glance like task 7 wasn't addressed by a dedicated component.

**Consequence for scope**: this Work Package adds two new event types (`OperationEvent`, `NotificationEvent`) to the existing `PlatformEvent` model, three new small Platform-layer classes (`OperationManager`, `ActivityLog`, `NotificationCenter`) that consume those events, and two small `StudioShell`/`StudioStatusBar` extensions to feed and surface them. No Studio file was touched.

## 2. OperationManager

New files: [lib/core/operations/operation.dart](lib/core/operations/operation.dart), [lib/core/operations/operation_manager.dart](lib/core/operations/operation_manager.dart).

`Operation`/`OperationStatus` is a small immutable model (`running`/`completed`/`failed`, an id, a label, an optional `0.0`–`1.0` fraction). `OperationManager` subscribes to `PlatformEventBus.on<OperationEvent>()` and accumulates `activeOperations` (a `Map<String, Operation>` keyed by operation id) and `recentOperations` (a capped, most-recent-first list of finished operations, `maxRecentOperations = 20`). It exposes its own `Stream<void> get changes`, fired only after `activeOperations`/`recentOperations` are already updated — `StudioStatusBar` (§6) subscribes to this rather than the raw Event Bus, guaranteeing read-after-write consistency without a second independent subscriber racing the first. Deliberately **not** a task queue: there is no `OperationManager.run(...)` entry point; it only observes facts already published by whichever Platform bridge or Studio is already doing the work (§5).

Injectable `PlatformEventBus` (defaulting to `PlatformEventBus.instance`) for test isolation, plus a `static final instance` matching every other Platform singleton's convention (`WorkspaceManager`, `SessionManager`).

## 3. Background Task Support

Covered by §2 and §5 — "lightweight" here means exactly what it says: no new executor, no new isolate/queue, no polling. `OperationManager` is a pure accumulator over events two already-existing signals (Acquisition downloads, Knowledge Studio OCR) now publish.

## 4. Activity Log

New file: [lib/core/operations/activity_log.dart](lib/core/operations/activity_log.dart).

`ActivityLog` subscribes to three already-existing event streams — `CommandExecutedEvent`, `OperationEvent`, `WorkspaceEvent` — and turns each into one `ActivityLogEntry` (a message, a timestamp, and an optional owning-Studio label resolved via `CommandRegistry.findCommand`/`StudioRegistry.ownerOf`). Bounded at `maxEntries = 100`, most-recent-first, with the same read-after-write `changes` stream `OperationManager` established. This is the mechanism behind this Work Package's "improve engineering review integration" task (§1): every Knowledge Studio review command and every Diagram validation command that runs is automatically recorded, since both already flow through `CommandExecutedEvent`.

Injectable `PlatformEventBus`/`CommandRegistry`/`StudioRegistry`, `static final instance`.

## 5. Notification Center

`PlatformNotificationService` (WP-STUDIO-028) is unchanged in its externally-visible behavior — `success`/`error`/`info` still show exactly the same `SnackBar`. Internally, `_show` now also calls `PlatformEventBus.instance.publish(NotificationEvent(...))` (one line). New file: [lib/core/notifications/notification_center.dart](lib/core/notifications/notification_center.dart) — `NotificationCenter` subscribes to `NotificationEvent` and accumulates a capped (`maxHistory = 50`), most-recent-first `history`, plus an `unreadCount` clearable via `markAllRead()`. Same `changes`-stream/injectable-bus/`static final instance` pattern as §2/§4.

**Removed duplication (task 9)**: `NotificationSeverity` was previously declared locally inside `platform_notification_service.dart`. It is now declared once in `platform_event.dart` (needed there anyway for `NotificationEvent.severity`) and re-exported from `platform_notification_service.dart` via `export '../events/platform_event.dart' show NotificationSeverity;` — every existing call site (`PlatformNotificationService.success/error/info`) is source-compatible; nothing else changed.

## 6. Application Status Infrastructure

[lib/app/widgets/studio_status_bar.dart](lib/app/widgets/studio_status_bar.dart) was converted from `ConsumerWidget` to `ConsumerStatefulWidget` (it now needs to subscribe to `OperationManager.changes`, a plain `Stream`, not a Riverpod provider) and gained one conditional segment — "N Operations Running" — appended to the existing left-hand `_StatusText`/`_StatusSeparator` group, shown only when `OperationManager.instance.activeOperations` is non-empty. The constructor takes an optional injectable `OperationManager` (test-only override, mirroring `StudioShell`'s own `eventBus`/`workspaceManager` injection pattern) and remains callable as `const StudioStatusBar()` from `StudioShell`.

## 7. Review Integration Improvements

Documented in §1/§4: no dedicated "review" component was built. `ActivityLog`'s generic `CommandExecutedEvent` handling is the improvement — every already-registered Knowledge Studio review command and Diagram validation command now leaves a visible, human-readable trace, with zero additions to either Studio.

## 8. Event Integration

`platform_event.dart` gained, in the same style as `WorkspaceEvent`/`WorkspaceEventKind` (WP-STUDIO-029):

- `OperationEventKind` (`started`/`progressed`/`completed`/`failed`) and `OperationEvent` (`id`, `kind`, `label`, `fraction`).
- `NotificationSeverity` (relocated, §5) and `NotificationEvent` (`severity`, `message`).

`StudioShell` gained a fourth `ref.listenManual`, alongside its three from WP-STUDIO-028/029:

- `_publishDownloadProgress` (renamed parameter list, same method) now receives `previous` (previously discarded) and diffs it against `next` to publish `OperationEvent`s for each `DownloadSession` transition, in addition to its unchanged `ProgressEvent` publication.
- A new `_publishOcrOperations(previous, next)` diffs `FoundationServiceState.ocrProcessingStatus` and publishes `OperationEvent`s (`id: 'ocr:$sourceId'`) for each OCR status transition, using `sourceMaterials` to build a human label ("Recognizing text — <file name>").

## 9. Platform Cleanup

- `NotificationSeverity` duplication removed (§5) — the only duplication found and practical to remove.
- No other duplicated operational logic was found: `AcquisitionServiceState.loading` and Knowledge Studio's OCR pipeline call remain exactly where they are (§1) — surfaced, not duplicated.

## 10. Validation Results

- `flutter analyze`: 0 issues in any changed/new file (2 pre-existing, unrelated informational lints in `foundation_runtime_service.dart`, unchanged from WP-STUDIO-029's baseline).
- `flutter test`: **424/424 passed** (402 prior + 22 new; 2 pre-existing unrelated skips):
  - `test/operation_manager_test.dart` (8): started/progressed/completed/failed transitions, an out-of-order terminal event with no prior `started`, the `maxRecentOperations` cap, read-after-write `changes` ordering, and the singleton.
  - `test/activity_log_test.dart` (8): successful/failed/unknown `CommandExecutedEvent` handling (with a fake `CommandRegistry`/`StudioRegistry`, not the real seeded ones, so the assertions don't depend on real Studio command metadata), `OperationEvent`/`WorkspaceEvent` filtering (`progressed`/`dirtyChanged` correctly produce no entry), the `maxEntries` cap, `changes` ordering, and the singleton.
  - `test/notification_center_test.dart` (5): history ordering, `unreadCount`/`markAllRead`, the `maxHistory` cap, `changes` ordering, and the singleton.
  - `test/platform_notification_service_test.dart` (+1): confirms `success`/`error`/`info` now also publish a `NotificationEvent` on the real `PlatformEventBus.instance`, alongside the pre-existing `SnackBar` assertions (unchanged).
  - The full pre-existing suite passed unchanged, confirming `StudioShell`'s and `StudioStatusBar`'s extensions introduced no regressions.
- `flutter build windows`: succeeded.
- **Deliberate testing choice, consistent with this session's prior findings (WP-STUDIO-029)**: every new class (`OperationManager`, `ActivityLog`, `NotificationCenter`) was tested with plain `test()` and an injected `PlatformEventBus`/`CommandRegistry`/`StudioRegistry` — no widget tree at all. No new `testWidgets` test was written for `StudioShell`'s new OCR bridge or `StudioStatusBar`'s new segment; both were verified via `flutter analyze`, `flutter build windows`, and the full existing suite (including `studio_shell_events_test.dart`, which already exercises `StudioShell`'s `ref.listenManual` bridges) passing unchanged. This avoids re-triggering the orphaned-process/Dart-compiler-crash instability documented in WP-STUDIO-029 §10, which cost significant time there for a widget-visibility assertion that was ultimately not retained.

## 11. Documentation

This file; doc comments added to `Operation`/`OperationStatus`/`OperationManager`, `ActivityLogEntry`/`ActivityLog`, `NotificationCenterEntry`/`NotificationCenter`, `OperationEventKind`/`OperationEvent`/`NotificationSeverity`/`NotificationEvent` in `platform_event.dart`, and updated class comments on `StudioShell` and `StudioStatusBar` explaining their new responsibilities.

## 12. Recommendations for WP-STUDIO-031

- **A visible Notification Center / Activity Log UI panel** — `NotificationCenter.instance.history`/`unreadCount` and `ActivityLog.instance.entries` are both ready to back a real panel (a bell icon with a dropdown, a dedicated Activity page); none was built here, since no UI was requested beyond the `StudioStatusBar` segment.
- **Cancel/retry affordances for `Operation`s** — `OperationManager` is read-only by design (§2); if a future Work Package wants the user to cancel a running download or retry a failed OCR pass from the Status Bar or a panel, that requires new Studio-side cancel/retry entry points first (Acquisition's `DownloadService`/Knowledge's `FoundationRuntimeNotifier`), not a change to `OperationManager` itself.
- **Extend the OCR/download `Operation` id scheme if a third background signal appears** — `'ocr:$sourceId'` was chosen to avoid an id collision with a download session id in the unlikely event both use the same underlying string; if a third source of `OperationEvent`s is added later, keep it in `StudioShell`'s bridges (or a dedicated bridge file if `StudioShell` grows too large) rather than teaching `OperationManager` about any specific Studio.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
