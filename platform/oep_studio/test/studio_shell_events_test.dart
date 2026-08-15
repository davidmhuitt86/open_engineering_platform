import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/app/studio_shell.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';

Widget _harness(StudioDestination selected, PlatformEventBus bus) {
  return ProviderScope(
    child: MaterialApp(
      home: StudioShell(
        selected: selected,
        onSelect: (_) {},
        eventBus: bus,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('StudioShell — StudioLifecycleEvent (WP-STUDIO-028)', () {
    testWidgets('publishes exactly one lifecycle event on first mount', (tester) async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final received = <StudioLifecycleEvent>[];
      final subscription = bus.on<StudioLifecycleEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(_harness(StudioDestination.dashboard, bus));
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.destination, StudioDestination.dashboard);
      expect(received.single.phase, StudioLifecyclePhase.entered);
    });

    testWidgets('publishes a new event when the destination actually changes', (tester) async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final received = <StudioLifecycleEvent>[];
      final subscription = bus.on<StudioLifecycleEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(_harness(StudioDestination.dashboard, bus));
      await tester.pump();
      await tester.pumpWidget(_harness(StudioDestination.diagram, bus));
      await tester.pump();

      expect(received.map((e) => e.destination), [StudioDestination.dashboard, StudioDestination.diagram]);
    });

    testWidgets('does not publish again when rebuilt with the same destination (deterministic dispatch)', (
      tester,
    ) async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final received = <StudioLifecycleEvent>[];
      final subscription = bus.on<StudioLifecycleEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(_harness(StudioDestination.knowledge, bus));
      await tester.pump();
      // Rebuild with the exact same `selected` — a real scenario (e.g.
      // an ancestor rebuilding for an unrelated reason) that must not
      // be mistaken for a Studio switch.
      await tester.pumpWidget(_harness(StudioDestination.knowledge, bus));
      await tester.pump();
      await tester.pumpWidget(_harness(StudioDestination.knowledge, bus));
      await tester.pump();

      expect(received, hasLength(1));
    });
  });
}
