import '../commands/command_registry.dart';
import '../routing/studio_destination.dart';

/// The base of every event published on [PlatformEventBus] (WP-STUDIO-028
/// Platform Event & Notification Framework). Immutable, like every other
/// Platform model ([CommandDescriptor], [CapabilityDescriptor]) — an
/// event is a fact about something that already happened, never a
/// mutable handle callers poke at.
abstract class PlatformEvent {
  const PlatformEvent();
}

/// Published exactly once per [PlatformInputService.runCommand] call,
/// after [CommandRegistry.execute] has already produced a [CommandResult]
/// — this event doesn't change how a command runs or what it returns to
/// its immediate caller; it's a side-channel broadcast for anything else
/// (a future activity log, a future Notification Center) that wants to
/// observe "some command just ran," without needing to sit in the
/// Command Palette's own call path.
class CommandExecutedEvent extends PlatformEvent {
  const CommandExecutedEvent({required this.commandId, required this.result});

  final String commandId;
  final CommandResult result;
}

/// Which lifecycle moment a [StudioLifecycleEvent] describes. Only
/// [entered] is published today (WP-STUDIO-028) — there is no reliable,
/// already-existing signal for "the user is about to leave a Studio"
/// distinct from "the user arrived at the next one," so [left] is
/// deliberately not modeled yet rather than guessed at.
enum StudioLifecyclePhase { entered }

/// Published exactly once per real Studio-destination transition — not
/// once per rebuild of the shell that hosts every route. See
/// `StudioShell`'s own `didUpdateWidget` for how "real transition" is
/// determined.
class StudioLifecycleEvent extends PlatformEvent {
  const StudioLifecycleEvent({required this.destination, required this.phase});

  final StudioDestination destination;
  final StudioLifecyclePhase phase;
}

/// Lightweight progress reporting (WP-STUDIO-028) — wraps an
/// already-existing progress signal (e.g. `DownloadSession
/// .progressPercentage`) rather than introducing new progress-tracking
/// state of its own. [fraction] is `0.0`–`1.0`, or `null` for
/// indeterminate progress.
class ProgressEvent extends PlatformEvent {
  const ProgressEvent({required this.id, required this.label, this.fraction});

  /// Identifies the specific operation this progress reading belongs to
  /// (e.g. a download session id) — stable across repeated events for
  /// the same operation so a listener can track it over time.
  final String id;

  /// Human-readable description of what's in progress.
  final String label;

  final double? fraction;
}

/// What happened to a workspace (WP-STUDIO-029 Workspace Lifecycle &
/// Session Management) — published by `WorkspaceManager`.
enum WorkspaceEventKind {
  /// An existing document was opened, or a new blank one started.
  opened,

  /// The document was written to disk (Save or Save As).
  saved,

  /// The document was closed (returned to a blank session).
  closed,

  /// The document's dirty flag changed value (became dirty, or became
  /// clean without an explicit save — e.g. Close/New discarding
  /// changes). Distinct from [saved]: a dirty→clean transition through
  /// [saved] is a successful write; through this kind alone, it isn't.
  dirtyChanged,

  /// The user chose to reopen a workspace `WorkspaceManager` flagged as
  /// recoverable at startup.
  recovered,
}

/// Published by `WorkspaceManager` — a fact about Diagram Studio's
/// document lifecycle (the only workspace with dirty-state tracking
/// today; see this Work Package's Architecture Review for why Knowledge
/// Curation Sessions, which auto-persist on every change, have nothing
/// analogous to publish). [path] is `null` for a blank/never-saved
/// document.
class WorkspaceEvent extends PlatformEvent {
  const WorkspaceEvent({required this.kind, this.path});

  final WorkspaceEventKind kind;
  final String? path;
}

/// What happened to an `Operation` (WP-STUDIO-030 Engineering Operations
/// Framework) — published by whichever Platform bridge or Studio owns the
/// underlying work. An operation is anything with a meaningful
/// start/finish that's worth surfacing across Studios (a download, a
/// background OCR pass) — deliberately not a generic "task queue"; see
/// `OperationManager`'s own doc comment for why only two sources feed it
/// today rather than a new invented abstraction every call site must
/// adopt.
enum OperationEventKind {
  /// The operation began running.
  started,

  /// The operation's progress reading changed. Carries the same
  /// [OperationEvent.fraction] semantics as [ProgressEvent].
  progressed,

  /// The operation finished successfully.
  completed,

  /// The operation finished unsuccessfully.
  failed,
}

/// Published on transitions of a long-running unit of work (WP-STUDIO-030)
/// — the shared fact type `OperationManager` accumulates into
/// `activeOperations`/`recentOperations`. Distinct from [ProgressEvent]:
/// a [ProgressEvent] is a bare progress reading with no lifecycle
/// (start/finish) attached, which is exactly why [OperationEvent] exists
/// instead of extending [ProgressEvent] — `OperationManager` needs to
/// know when something starts and ends, not just how far along it is.
class OperationEvent extends PlatformEvent {
  const OperationEvent({
    required this.id,
    required this.kind,
    required this.label,
    this.fraction,
  });

  /// Identifies the specific operation this event belongs to — stable
  /// across the [started]/[progressed]/[completed]/[failed] events for
  /// the same unit of work so `OperationManager` can track it over time.
  final String id;

  final OperationEventKind kind;

  /// Human-readable description of what's running (e.g. "Downloading
  /// service manual…", "Recognizing text — Repair Order 4471").
  final String label;

  /// `0.0`–`1.0`, or `null` for indeterminate/not-yet-known progress.
  /// Only meaningful on [OperationEventKind.progressed].
  final double? fraction;
}

/// The severity a notification is shown with (originally
/// `PlatformNotificationService`'s own enum; relocated here in
/// WP-STUDIO-030 so `NotificationEvent` doesn't have to import a
/// `flutter/material.dart`-adjacent file just for one enum — this is the
/// single shared definition now, not a duplicate).
enum NotificationSeverity { success, error, info }

/// Published every time `PlatformNotificationService` shows a
/// notification (WP-STUDIO-030) — lets a `NotificationCenter` accumulate
/// a history of what the user was told, independent of the transient
/// `SnackBar` that's already gone once dismissed.
class NotificationEvent extends PlatformEvent {
  const NotificationEvent({required this.severity, required this.message});

  final NotificationSeverity severity;
  final String message;
}

/// Published by `EngineeringObjectRuntime` (WP-STUDIO-031 Engineering
/// Object Runtime) whenever its cache is rebuilt from a fresh
/// `FoundationServiceState.objectList`/`relationshipList` — after opening
/// a repository, refreshing it, or closing one (`objectCount`/
/// `relationshipCount` both `0`). Not published on every unrelated
/// Foundation state change — only when the underlying object/relationship
/// data itself actually changed; see `EngineeringObjectRuntime`'s own doc
/// comment for the identity check that guarantees this.
class EngineeringObjectEvent extends PlatformEvent {
  const EngineeringObjectEvent({required this.objectCount, required this.relationshipCount});

  final int objectCount;
  final int relationshipCount;
}
