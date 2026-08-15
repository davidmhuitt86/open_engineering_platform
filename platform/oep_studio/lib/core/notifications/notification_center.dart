import 'dart:async';

import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';

/// One notification the user was shown, retained after its transient
/// `SnackBar` (`PlatformNotificationService`) has already dismissed
/// itself.
class NotificationCenterEntry {
  const NotificationCenterEntry({required this.severity, required this.message, required this.timestamp});

  final NotificationSeverity severity;
  final String message;
  final DateTime timestamp;
}

/// The Platform's notification history (WP-STUDIO-030 Engineering
/// Operations Framework) — extends `PlatformNotificationService`
/// (WP-STUDIO-028) into a Notification *Center* by accumulating every
/// [NotificationEvent] it already publishes into a queryable, bounded
/// history. Deliberately not a rewrite: `PlatformNotificationService`'s
/// `SnackBar` behavior is completely unchanged — this class only listens
/// to the fact that was already being broadcast.
class NotificationCenter {
  NotificationCenter({PlatformEventBus? eventBus}) : _eventBus = eventBus ?? PlatformEventBus.instance {
    _subscription = _eventBus.on<NotificationEvent>().listen(_handle);
  }

  final PlatformEventBus _eventBus;
  late final StreamSubscription<NotificationEvent> _subscription;

  /// How many entries [history] retains.
  static const int maxHistory = 50;

  final List<NotificationCenterEntry> _history = [];
  final StreamController<void> _changesController = StreamController<void>.broadcast();

  /// Fires after [history] has already been updated.
  Stream<void> get changes => _changesController.stream;

  /// Most-recent-first, capped at [maxHistory].
  List<NotificationCenterEntry> get history => List.unmodifiable(_history);

  /// [history] entries not yet acknowledged via [markAllRead].
  int get unreadCount => _unreadCount;
  int _unreadCount = 0;

  void markAllRead() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    _changesController.add(null);
  }

  void _handle(NotificationEvent event) {
    _history.insert(
      0,
      NotificationCenterEntry(severity: event.severity, message: event.message, timestamp: DateTime.now()),
    );
    if (_history.length > maxHistory) {
      _history.removeRange(maxHistory, _history.length);
    }
    _unreadCount++;
    _changesController.add(null);
  }

  void dispose() {
    _subscription.cancel();
    _changesController.close();
  }

  static final NotificationCenter instance = NotificationCenter();
}
