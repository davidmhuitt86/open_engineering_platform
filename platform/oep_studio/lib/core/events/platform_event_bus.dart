import 'dart:async';

import 'platform_event.dart';

/// The Platform's lightweight, centralized Event Bus (WP-STUDIO-028) —
/// a single `Stream<PlatformEvent>` broadcast, nothing more. This does
/// not replace or duplicate the Riverpod state each Studio's own
/// Notifier already owns ([EngineeringProjectNotifier],
/// [AcquisitionRuntimeNotifier], [FoundationRuntimeNotifier]) — those
/// remain the source of truth for domain state, and every publisher on
/// this bus (`PlatformInputService`, `StudioShell`) already reads that
/// state itself before publishing a fact about it. This bus exists only
/// for cross-cutting facts ("a command ran," "the active Studio
/// changed," "an operation's progress changed") that don't have one
/// natural Studio-scoped home to `ref.watch`.
///
/// Deliberately minimal: no event replay, no persistence, no filtering
/// beyond [on]'s type check. A future consumer (a Notification Center,
/// an activity log — neither built by this Work Package) would
/// subscribe via [on]; nothing in the Platform is required to have a
/// listener for the bus to work correctly.
class PlatformEventBus {
  PlatformEventBus() : _controller = StreamController<PlatformEvent>.broadcast();

  final StreamController<PlatformEvent> _controller;

  /// Every event published, in publication order (broadcast — replayed
  /// to no new subscriber; a listener only sees events published after
  /// it starts listening, matching a normal `Stream.broadcast()`).
  Stream<PlatformEvent> get events => _controller.stream;

  /// [events] filtered to just one concrete [PlatformEvent] subtype —
  /// the typed entry point most listeners should actually use, e.g.
  /// `PlatformEventBus.instance.on<ProgressEvent>()`.
  Stream<T> on<T extends PlatformEvent>() => events.where((event) => event is T).cast<T>();

  /// Publishes [event] to every current subscriber. Never throws on its
  /// own account; a listener's own error is a listener concern (a
  /// broadcast `StreamController`'s default behavior), not this bus's.
  void publish(PlatformEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }

  static final PlatformEventBus instance = PlatformEventBus();
}
