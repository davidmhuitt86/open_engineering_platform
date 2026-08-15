import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/input/platform_input_service.dart';

/// Pumps a bare [ProviderScope] and hands back a live [WidgetRef] —
/// [PlatformInputService.runCommand] takes a [WidgetRef], matching
/// [CommandRegistry.execute]'s own convention, and Riverpod only vends
/// one from inside the widget tree.
Future<WidgetRef> _pumpRef(WidgetTester tester) async {
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return capturedRef;
}

void main() {
  group('PlatformInputService — forwarding, not duplicated routing', () {
    test('commands is a direct passthrough of the underlying CommandRegistry', () {
      final service = PlatformInputService();
      expect(service.commands, CommandRegistry.defaultRegistry.commands);
    });

    test('defaultService wraps CommandRegistry.defaultRegistry', () {
      expect(PlatformInputService.defaultService.commands, CommandRegistry.defaultRegistry.commands);
    });

    test('an injected CommandRegistry is what commands reflects, not the real default', () {
      final fakeRegistry = CommandRegistry([
        CommandDescriptor(
          id: 'fake.one',
          label: 'Fake',
          description: 'A fake command for isolation.',
          capabilityId: 'diagram.editing',
          execute: (ref, args) {},
        ),
      ]);
      final service = PlatformInputService(commandRegistry: fakeRegistry);
      expect(service.commands, hasLength(1));
      expect(service.commands.single.id, 'fake.one');
    });
  });

  group('PlatformInputService.runCommand — forwards to CommandRegistry.execute verbatim', () {
    testWidgets('notFound when no command is registered with that id', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await PlatformInputService.defaultService.runCommand(ref, 'no.such.command');
      expect(result.outcome, CommandOutcome.notFound);
    });

    testWidgets('invalidArguments when a required argument is missing', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await PlatformInputService.defaultService.runCommand(ref, 'diagram.openDocument');
      expect(result.outcome, CommandOutcome.invalidArguments);
    });

    testWidgets('success on a real, already-existing no-argument command (diagram.undo, safe no-op)', (
      tester,
    ) async {
      final ref = await _pumpRef(tester);
      final result = await PlatformInputService.defaultService.runCommand(ref, 'diagram.undo');
      expect(result.isSuccess, isTrue);
    });

    testWidgets('failure surfaces exactly as CommandRegistry.execute would, for an injected throwing command', (
      tester,
    ) async {
      final ref = await _pumpRef(tester);
      final service = PlatformInputService(
        commandRegistry: CommandRegistry([
          CommandDescriptor(
            id: 'fake.throws',
            label: 'Throws',
            description: 'Always throws.',
            capabilityId: 'diagram.editing',
            execute: (ref, args) => throw StateError('boom'),
          ),
        ]),
      );
      final result = await service.runCommand(ref, 'fake.throws');
      expect(result.outcome, CommandOutcome.failure);
      expect(result.errorMessage, contains('boom'));
    });
  });

  group('PlatformInputService.runCommand — publishes CommandExecutedEvent (WP-STUDIO-028)', () {
    testWidgets('publishes exactly one CommandExecutedEvent per call, carrying the same result', (tester) async {
      final ref = await _pumpRef(tester);
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final service = PlatformInputService(eventBus: bus);

      final received = <CommandExecutedEvent>[];
      final subscription = bus.on<CommandExecutedEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      final result = await service.runCommand(ref, 'diagram.undo');
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.commandId, 'diagram.undo');
      expect(received.single.result.outcome, result.outcome);
    });

    testWidgets('still publishes an event when the command is not found', (tester) async {
      final ref = await _pumpRef(tester);
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final service = PlatformInputService(eventBus: bus);

      final received = <CommandExecutedEvent>[];
      final subscription = bus.on<CommandExecutedEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      await service.runCommand(ref, 'no.such.command');
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.result.outcome, CommandOutcome.notFound);
    });

    testWidgets('defaults to PlatformEventBus.instance when no bus is injected', (tester) async {
      final ref = await _pumpRef(tester);
      final received = <CommandExecutedEvent>[];
      final subscription = PlatformEventBus.instance.on<CommandExecutedEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      await PlatformInputService().runCommand(ref, 'diagram.redo');
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.commandId, 'diagram.redo');
    });
  });
}
