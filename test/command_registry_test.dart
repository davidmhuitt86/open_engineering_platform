import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';

/// Pumps a bare [ProviderScope] and hands back a live [WidgetRef] —
/// [CommandRegistry.execute] takes a [WidgetRef] (matching
/// `StudioSearchProvider`'s own convention), and Riverpod only vends
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
  group('CommandRegistry.defaultRegistry — discovery', () {
    test('validate reports no issues for the real, seeded registry', () {
      expect(CommandRegistry.defaultRegistry.validate(), isEmpty);
    });

    test('findCommand resolves a known id and returns null for an unknown one', () {
      final registry = CommandRegistry.defaultRegistry;
      expect(registry.findCommand('diagram.saveDocument'), isNotNull);
      expect(registry.findCommand('no.such.command'), isNull);
    });

    test('commandsForCapability returns only commands for that capability', () {
      final registry = CommandRegistry.defaultRegistry;
      final jobCommands = registry.commandsForCapability('acquisition.jobOrchestration');
      expect(jobCommands.map((c) => c.id).toSet(), {'acquisition.executeJob', 'acquisition.cancelJob'});
    });

    test('commandsForStudio returns every command belonging to any of that Studio\'s capabilities', () {
      final registry = CommandRegistry.defaultRegistry;
      final diagramCommands = registry.commandsForStudio(StudioDestination.diagram);
      expect(diagramCommands, isNotEmpty);
      expect(diagramCommands.every((c) => c.capabilityId.startsWith('diagram.')), isTrue);
    });

    test('a destination with no registered capabilities has no commands', () {
      expect(CommandRegistry.defaultRegistry.commandsForStudio(StudioDestination.dashboard), isEmpty);
    });

    test('Knowledge Studio has 5 registered commands (WP-STUDIO-025), '
        'wrapping FoundationRuntimeNotifier methods', () {
      final knowledgeCommands = CommandRegistry.defaultRegistry.commandsForStudio(StudioDestination.knowledge);
      expect(knowledgeCommands.map((c) => c.id).toSet(), {
        'knowledge.acceptCandidate',
        'knowledge.rejectCandidate',
        'knowledge.deleteCandidate',
        'knowledge.acceptAiSuggestion',
        'knowledge.rejectAiSuggestion',
      });
    });

    test('every registered command id is unique', () {
      final ids = CommandRegistry.defaultRegistry.commands.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('Engineering Exchange has 3 registered commands (WP-EXC-010)', () {
      final exchangeCommands = CommandRegistry.defaultRegistry.commandsForStudio(StudioDestination.exchange);
      expect(exchangeCommands.map((c) => c.id).toSet(), {
        'exchange.search',
        'exchange.refreshMarketplace',
        'exchange.refreshRepository',
      });
    });
  });

  group('CommandRegistry.validate — catches inconsistent metadata', () {
    test('flags a blank command id', () {
      final registry = CommandRegistry([
        CommandDescriptor(
          id: '',
          label: 'Something',
          description: 'Does something.',
          capabilityId: 'diagram.editing',
          execute: (ref, args) {},
        ),
      ]);
      expect(registry.validate(), isNotEmpty);
    });

    test('flags a duplicate command id', () {
      final registry = CommandRegistry([
        CommandDescriptor(
          id: 'fake.duplicate',
          label: 'One',
          description: 'First.',
          capabilityId: 'diagram.editing',
          execute: (ref, args) {},
        ),
        CommandDescriptor(
          id: 'fake.duplicate',
          label: 'Two',
          description: 'Second.',
          capabilityId: 'diagram.validation',
          execute: (ref, args) {},
        ),
      ]);
      final issues = registry.validate();
      expect(issues, hasLength(1));
      expect(issues.single, contains('fake.duplicate'));
    });

    test('flags a capabilityId that does not resolve in the StudioRegistry', () {
      final registry = CommandRegistry([
        CommandDescriptor(
          id: 'fake.orphan',
          label: 'Orphan',
          description: 'References a capability that does not exist.',
          capabilityId: 'no.such.capability',
          execute: (ref, args) {},
        ),
      ]);
      final issues = registry.validate();
      expect(issues, hasLength(1));
      expect(issues.single, contains('no.such.capability'));
    });

    test('a registry with no commands at all is trivially valid', () {
      expect(CommandRegistry(const []).validate(), isEmpty);
    });
  });

  group('CommandRegistry.execute — typed execution contract', () {
    testWidgets('notFound when no command is registered with that id', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await CommandRegistry.defaultRegistry.execute(ref, 'no.such.command');
      expect(result.outcome, CommandOutcome.notFound);
      expect(result.isSuccess, isFalse);
    });

    testWidgets('invalidArguments when a required argument is missing', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await CommandRegistry.defaultRegistry.execute(ref, 'diagram.openDocument');
      expect(result.outcome, CommandOutcome.invalidArguments);
    });

    testWidgets('invalidArguments when a required argument is blank', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await CommandRegistry.defaultRegistry
          .execute(ref, 'diagram.openDocument', args: const CommandArgs(value: '   '));
      expect(result.outcome, CommandOutcome.invalidArguments);
    });

    testWidgets('success when a real, already-existing no-argument command runs cleanly '
        '(diagram.undo is a no-op with no diagram open yet)', (tester) async {
      final ref = await _pumpRef(tester);
      final result = await CommandRegistry.defaultRegistry.execute(ref, 'diagram.undo');
      expect(result.outcome, CommandOutcome.success);
      expect(result.isSuccess, isTrue);
    });

    testWidgets('failure when a command\'s executor throws', (tester) async {
      final ref = await _pumpRef(tester);
      final registry = CommandRegistry([
        CommandDescriptor(
          id: 'fake.throws',
          label: 'Throws',
          description: 'Always throws, for testing the failure outcome.',
          capabilityId: 'diagram.editing',
          execute: (ref, args) => throw StateError('boom'),
        ),
      ]);
      final result = await registry.execute(ref, 'fake.throws');
      expect(result.outcome, CommandOutcome.failure);
      expect(result.errorMessage, contains('boom'));
    });

    testWidgets('a command with requiresArgument: false ignores CommandArgs.none', (tester) async {
      final ref = await _pumpRef(tester);
      final registry = CommandRegistry([
        CommandDescriptor(
          id: 'fake.noArg',
          label: 'No Arg',
          description: 'Does not require an argument.',
          capabilityId: 'diagram.editing',
          execute: (ref, args) {},
        ),
      ]);
      final result = await registry.execute(ref, 'fake.noArg');
      expect(result.isSuccess, isTrue);
    });
  });
}
