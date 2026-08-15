import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/operations/operation.dart';
import 'package:oep_studio/core/operations/operation_manager.dart';

void main() {
  group('OperationManager', () {
    late PlatformEventBus bus;
    late OperationManager manager;

    setUp(() {
      bus = PlatformEventBus();
      manager = OperationManager(eventBus: bus);
    });

    tearDown(() {
      manager.dispose();
      bus.dispose();
    });

    test('a started event adds an active operation', () async {
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf', fraction: 0.0));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeOperations, hasLength(1));
      expect(manager.activeOperations.single.id, 'dl-1');
      expect(manager.activeOperations.single.status, OperationStatus.running);
      expect(manager.recentOperations, isEmpty);
    });

    test('a progressed event updates fraction in place without duplicating the entry', () async {
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf', fraction: 0.0));
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.progressed, label: 'file.pdf', fraction: 0.5));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeOperations, hasLength(1));
      expect(manager.activeOperations.single.fraction, 0.5);
    });

    test('a completed event moves the operation from active to recent', () async {
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf', fraction: 0.0));
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.completed, label: 'file.pdf'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeOperations, isEmpty);
      expect(manager.recentOperations, hasLength(1));
      expect(manager.recentOperations.single.status, OperationStatus.completed);
    });

    test('a failed event moves the operation to recent with failed status', () async {
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf', fraction: 0.0));
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.failed, label: 'file.pdf'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeOperations, isEmpty);
      expect(manager.recentOperations.single.status, OperationStatus.failed);
    });

    test('a completed/failed event with no prior started event still records the correct terminal status', () async {
      bus.publish(const OperationEvent(id: 'ocr-1', kind: OperationEventKind.failed, label: 'Recognizing text'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeOperations, isEmpty);
      expect(manager.recentOperations.single.status, OperationStatus.failed);
    });

    test('recentOperations is capped at maxRecentOperations, most-recent first', () async {
      for (var i = 0; i < OperationManager.maxRecentOperations + 5; i++) {
        bus.publish(OperationEvent(id: 'op-$i', kind: OperationEventKind.started, label: 'op $i'));
        bus.publish(OperationEvent(id: 'op-$i', kind: OperationEventKind.completed, label: 'op $i'));
      }
      await Future<void>.delayed(Duration.zero);

      expect(manager.recentOperations, hasLength(OperationManager.maxRecentOperations));
      expect(manager.recentOperations.first.id, 'op-${OperationManager.maxRecentOperations + 4}');
    });

    test('changes fires after state has already been updated (read-after-write)', () async {
      var activeCountWhenFired = -1;
      final subscription = manager.changes.listen((_) {
        activeCountWhenFired = manager.activeOperations.length;
      });
      addTearDown(subscription.cancel);

      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf'));
      await Future<void>.delayed(Duration.zero);

      expect(activeCountWhenFired, 1);
    });

    test('OperationManager.instance is a shared singleton', () {
      expect(OperationManager.instance, same(OperationManager.instance));
    });
  });
}
