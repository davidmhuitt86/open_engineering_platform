import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/notifications/notification_center.dart';

void main() {
  group('NotificationCenter', () {
    late PlatformEventBus bus;
    late NotificationCenter center;

    setUp(() {
      bus = PlatformEventBus();
      center = NotificationCenter(eventBus: bus);
    });

    tearDown(() {
      center.dispose();
      bus.dispose();
    });

    test('a NotificationEvent is recorded, most-recent first', () async {
      bus.publish(const NotificationEvent(severity: NotificationSeverity.success, message: 'Diagram saved.'));
      bus.publish(const NotificationEvent(severity: NotificationSeverity.error, message: 'Could not save.'));
      await Future<void>.delayed(Duration.zero);

      expect(center.history, hasLength(2));
      expect(center.history.first.message, 'Could not save.');
      expect(center.history.first.severity, NotificationSeverity.error);
      expect(center.history.last.message, 'Diagram saved.');
    });

    test('unreadCount increases per notification and resets via markAllRead', () async {
      bus.publish(const NotificationEvent(severity: NotificationSeverity.info, message: 'Refreshed.'));
      bus.publish(const NotificationEvent(severity: NotificationSeverity.info, message: 'Refreshed again.'));
      await Future<void>.delayed(Duration.zero);

      expect(center.unreadCount, 2);
      center.markAllRead();
      expect(center.unreadCount, 0);
      expect(center.history, hasLength(2), reason: 'markAllRead clears the unread count, not the history');
    });

    test('history is capped at maxHistory, most-recent first', () async {
      for (var i = 0; i < NotificationCenter.maxHistory + 5; i++) {
        bus.publish(NotificationEvent(severity: NotificationSeverity.info, message: 'message $i'));
      }
      await Future<void>.delayed(Duration.zero);

      expect(center.history, hasLength(NotificationCenter.maxHistory));
      expect(center.history.first.message, 'message ${NotificationCenter.maxHistory + 4}');
    });

    test('changes fires after history has already been updated', () async {
      var countWhenFired = -1;
      final subscription = center.changes.listen((_) {
        countWhenFired = center.history.length;
      });
      addTearDown(subscription.cancel);

      bus.publish(const NotificationEvent(severity: NotificationSeverity.success, message: 'ok'));
      await Future<void>.delayed(Duration.zero);

      expect(countWhenFired, 1);
    });

    test('NotificationCenter.instance is a shared singleton', () {
      expect(NotificationCenter.instance, same(NotificationCenter.instance));
    });
  });
}
