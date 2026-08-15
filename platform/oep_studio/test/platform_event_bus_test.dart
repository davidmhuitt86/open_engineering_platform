import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';

void main() {
  group('PlatformEventBus — publish/subscribe', () {
    test('a subscriber receives an event published after it starts listening', () async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);

      final received = <PlatformEvent>[];
      final subscription = bus.events.listen(received.add);
      addTearDown(subscription.cancel);

      bus.publish(const StudioLifecycleEvent(
        destination: StudioDestination.diagram,
        phase: StudioLifecyclePhase.entered,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single, isA<StudioLifecycleEvent>());
    });

    test('on<T>() filters to only the requested event subtype', () async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);

      final progressEvents = <ProgressEvent>[];
      final subscription = bus.on<ProgressEvent>().listen(progressEvents.add);
      addTearDown(subscription.cancel);

      bus.publish(const StudioLifecycleEvent(
        destination: StudioDestination.acquisition,
        phase: StudioLifecyclePhase.entered,
      ));
      bus.publish(const ProgressEvent(id: 'download-1', label: 'file.pdf', fraction: 0.5));
      bus.publish(const ProgressEvent(id: 'download-2', label: 'other.pdf', fraction: null));
      await Future<void>.delayed(Duration.zero);

      expect(progressEvents, hasLength(2));
      expect(progressEvents.map((e) => e.id), ['download-1', 'download-2']);
    });

    test('events are delivered to multiple subscribers in publish order (deterministic dispatch)', () async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);

      final subscriberA = <String>[];
      final subscriberB = <String>[];
      final subA = bus.on<CommandExecutedEvent>().listen((e) => subscriberA.add(e.commandId));
      final subB = bus.on<CommandExecutedEvent>().listen((e) => subscriberB.add(e.commandId));
      addTearDown(subA.cancel);
      addTearDown(subB.cancel);

      bus.publish(const CommandExecutedEvent(commandId: 'diagram.undo', result: CommandResult.success));
      bus.publish(const CommandExecutedEvent(commandId: 'diagram.redo', result: CommandResult.success));
      await Future<void>.delayed(Duration.zero);

      expect(subscriberA, ['diagram.undo', 'diagram.redo']);
      expect(subscriberB, ['diagram.undo', 'diagram.redo']);
    });

    test('publishing after dispose is a silent no-op, not a thrown error', () {
      final bus = PlatformEventBus();
      bus.dispose();
      expect(
        () => bus.publish(const ProgressEvent(id: 'x', label: 'x')),
        returnsNormally,
      );
    });

    test('PlatformEventBus.instance is a shared singleton', () {
      expect(PlatformEventBus.instance, same(PlatformEventBus.instance));
    });
  });
}
