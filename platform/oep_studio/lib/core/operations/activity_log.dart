import 'dart:async';

import '../commands/command_registry.dart';
import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';
import '../routing/studio_registry.dart';

/// One recorded fact in the [ActivityLog] — a human-readable line plus
/// which Studio (if any) it's attributable to, for a future "filter by
/// Studio" surface; no such filter is built by this Work Package.
class ActivityLogEntry {
  const ActivityLogEntry({required this.message, required this.timestamp, this.studioLabel});

  final String message;
  final DateTime timestamp;

  /// [StudioDestination.label] of the Studio this entry is attributable
  /// to, or `null` for a Platform-level fact with no single owning
  /// Studio (e.g. a workspace event).
  final String? studioLabel;
}

/// A centralized, cross-Studio activity history (WP-STUDIO-030
/// Engineering Operations Framework) — built entirely by observing
/// events already published on the [PlatformEventBus] by prior Work
/// Packages ([CommandExecutedEvent] since WP-STUDIO-028, [OperationEvent]
/// and [WorkspaceEvent] since WP-STUDIO-029/030), rather than requiring
/// any Studio to call a new "log this" API. This is the deliberate answer
/// to this Work Package's "improve engineering review integration" task:
/// Knowledge Studio's review commands (`knowledge.acceptCandidate`, etc.)
/// and Diagram's `diagram.revalidate` are already registered
/// [CommandDescriptor]s that already publish [CommandExecutedEvent] —
/// this log surfaces every one of them automatically, with no
/// review-specific code of its own.
///
/// WP-STUDIO-031 adds a fourth subscription, [EngineeringObjectEvent],
/// published by `EngineeringObjectRuntime` whenever its cache reloads —
/// the same "observe an already-published fact" pattern as the other
/// three, not a special case.
class ActivityLog {
  ActivityLog({PlatformEventBus? eventBus, CommandRegistry? commandRegistry, StudioRegistry? studioRegistry})
      : _commandRegistry = commandRegistry ?? CommandRegistry.defaultRegistry,
        _studioRegistry = studioRegistry ?? StudioRegistry.defaultRegistry,
        _eventBus = eventBus ?? PlatformEventBus.instance {
    _subscriptions = [
      _eventBus.on<CommandExecutedEvent>().listen(_handleCommand),
      _eventBus.on<OperationEvent>().listen(_handleOperation),
      _eventBus.on<WorkspaceEvent>().listen(_handleWorkspace),
      _eventBus.on<EngineeringObjectEvent>().listen(_handleEngineeringObject),
    ];
  }

  final PlatformEventBus _eventBus;
  final CommandRegistry _commandRegistry;
  final StudioRegistry _studioRegistry;
  late final List<StreamSubscription<PlatformEvent>> _subscriptions;

  /// How many entries [entries] retains — an activity history is for
  /// recent context, not an audit trail; nothing in this Work Package
  /// reads past this bound.
  static const int maxEntries = 100;

  final List<ActivityLogEntry> _entries = [];
  final StreamController<void> _changesController = StreamController<void>.broadcast();

  /// Fires after [entries] has already been updated — same
  /// read-after-write guarantee `OperationManager.changes` provides, for
  /// the same reason.
  Stream<void> get changes => _changesController.stream;

  /// Most-recent-first, capped at [maxEntries].
  List<ActivityLogEntry> get entries => List.unmodifiable(_entries);

  void _record(String message, {String? studioLabel}) {
    _entries.insert(0, ActivityLogEntry(message: message, timestamp: DateTime.now(), studioLabel: studioLabel));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    _changesController.add(null);
  }

  void _handleCommand(CommandExecutedEvent event) {
    final command = _commandRegistry.findCommand(event.commandId);
    final studioLabel = command != null ? _studioRegistry.ownerOf(command.capabilityId)?.label : null;
    final label = command?.label ?? event.commandId;
    _record(event.result.isSuccess ? label : '$label (failed: ${event.result.errorMessage})', studioLabel: studioLabel);
  }

  void _handleOperation(OperationEvent event) {
    final message = switch (event.kind) {
      OperationEventKind.started => 'Started: ${event.label}',
      OperationEventKind.progressed => null,
      OperationEventKind.completed => 'Completed: ${event.label}',
      OperationEventKind.failed => 'Failed: ${event.label}',
    };
    if (message != null) _record(message);
  }

  void _handleWorkspace(WorkspaceEvent event) {
    final message = switch (event.kind) {
      WorkspaceEventKind.opened => 'Workspace opened${event.path != null ? ': ${event.path}' : ''}',
      WorkspaceEventKind.saved => 'Workspace saved${event.path != null ? ': ${event.path}' : ''}',
      WorkspaceEventKind.closed => 'Workspace closed',
      WorkspaceEventKind.dirtyChanged => null,
      WorkspaceEventKind.recovered => 'Workspace recovered${event.path != null ? ': ${event.path}' : ''}',
    };
    if (message != null) _record(message);
  }

  void _handleEngineeringObject(EngineeringObjectEvent event) {
    if (event.objectCount == 0 && event.relationshipCount == 0) {
      _record('Repository objects cleared');
    } else {
      _record('Repository objects loaded: ${event.objectCount} objects, ${event.relationshipCount} relationships');
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _changesController.close();
  }

  static final ActivityLog instance = ActivityLog();
}
