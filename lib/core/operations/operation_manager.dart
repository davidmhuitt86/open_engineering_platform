import 'dart:async';

import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';
import 'operation.dart';

/// The Platform's cross-Studio operation tracker (WP-STUDIO-030
/// Engineering Operations Framework) — accumulates [OperationEvent]s
/// published on a [PlatformEventBus] into a queryable
/// [activeOperations]/[recentOperations] view.
///
/// Deliberately narrow in scope: this is not a task *queue* and does not
/// run anything itself — it only observes facts that some other Platform
/// bridge or Studio already publishes about work it's already doing (a
/// download session, a background OCR pass; see `StudioShell`'s
/// bridges). There is no `OperationManager.run(...)` entry point, and
/// none is planned — inventing one would mean the Platform starting to
/// own execution of Studio-specific work, which is explicitly out of
/// scope (see this Work Package's Architecture Review for why
/// `AcquisitionServiceState.loading` and Knowledge Studio's own OCR
/// pipeline call remain exactly where they are).
class OperationManager {
  OperationManager({PlatformEventBus? eventBus}) : _eventBus = eventBus ?? PlatformEventBus.instance {
    _subscription = _eventBus.on<OperationEvent>().listen(_handle);
  }

  final PlatformEventBus _eventBus;
  late final StreamSubscription<OperationEvent> _subscription;

  final Map<String, Operation> _active = {};
  final List<Operation> _recent = [];

  /// How many finished (completed/failed) operations [recentOperations]
  /// retains — old enough history isn't actionable, just a growing list
  /// nothing ever reads past this point.
  static const int maxRecentOperations = 20;

  final StreamController<void> _changesController = StreamController<void>.broadcast();

  /// Fires after [activeOperations]/[recentOperations] have already been
  /// updated for the event that triggered it — a listener (e.g.
  /// `StudioStatusBar`) that reacts to this stream always reads
  /// already-consistent state, without needing to also listen to the raw
  /// [PlatformEventBus] itself and risk an event-ordering race between
  /// two independent subscribers of the same broadcast stream.
  Stream<void> get changes => _changesController.stream;

  /// Every operation currently running, in the order it most recently
  /// changed.
  List<Operation> get activeOperations => List.unmodifiable(_active.values);

  /// Finished operations (completed or failed), most-recent first,
  /// capped at [maxRecentOperations].
  List<Operation> get recentOperations => List.unmodifiable(_recent);

  void _handle(OperationEvent event) {
    final existing = _active[event.id];
    final updated = existing?.withEvent(event) ?? operationFromEvent(event);

    switch (event.kind) {
      case OperationEventKind.started:
      case OperationEventKind.progressed:
        _active[event.id] = updated;
      case OperationEventKind.completed:
      case OperationEventKind.failed:
        _active.remove(event.id);
        _recent.insert(0, updated);
        if (_recent.length > maxRecentOperations) {
          _recent.removeRange(maxRecentOperations, _recent.length);
        }
    }
    _changesController.add(null);
  }

  void dispose() {
    _subscription.cancel();
    _changesController.close();
  }

  static final OperationManager instance = OperationManager();
}
