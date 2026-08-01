import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/operations/activity_log.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';

Widget _fakePageBuilder(BuildContext context, GoRouterState state) => const SizedBox.shrink();

void main() {
  group('ActivityLog', () {
    late PlatformEventBus bus;
    late StudioRegistry studioRegistry;
    late CommandRegistry commandRegistry;
    late ActivityLog log;

    setUp(() {
      bus = PlatformEventBus();
      studioRegistry = StudioRegistry([
        const StudioDescriptor(
          destination: StudioDestination.diagram,
          pageBuilder: _fakePageBuilder,
          capabilities: [
            CapabilityDescriptor(id: 'diagram.validation', label: 'Validation', description: 'Revalidates.'),
          ],
        ),
      ]);
      commandRegistry = CommandRegistry(
        [
          CommandDescriptor(
            id: 'diagram.revalidate',
            label: 'Revalidate Diagram',
            description: 'Reruns validation.',
            capabilityId: 'diagram.validation',
            execute: (ref, args) {},
          ),
        ],
        studioRegistry: studioRegistry,
      );
      log = ActivityLog(eventBus: bus, commandRegistry: commandRegistry, studioRegistry: studioRegistry);
    });

    tearDown(() {
      log.dispose();
      bus.dispose();
    });

    test('a successful CommandExecutedEvent records the command\'s label with its owning Studio', () async {
      bus.publish(const CommandExecutedEvent(commandId: 'diagram.revalidate', result: CommandResult.success));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries, hasLength(1));
      expect(log.entries.single.message, 'Revalidate Diagram');
      expect(log.entries.single.studioLabel, StudioDestination.diagram.label);
    });

    test('a failed CommandExecutedEvent records the failure reason', () async {
      bus.publish(CommandExecutedEvent(commandId: 'diagram.revalidate', result: CommandResult.failure('boom')));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries.single.message, contains('failed'));
      expect(log.entries.single.message, contains('boom'));
    });

    test('an unknown commandId still records an entry, falling back to the raw id', () async {
      bus.publish(const CommandExecutedEvent(commandId: 'no.such.command', result: CommandResult.success));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries.single.message, 'no.such.command');
      expect(log.entries.single.studioLabel, isNull);
    });

    test('OperationEvent started/completed/failed each record an entry; progressed does not', () async {
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.started, label: 'file.pdf'));
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.progressed, label: 'file.pdf', fraction: 0.5));
      bus.publish(const OperationEvent(id: 'dl-1', kind: OperationEventKind.completed, label: 'file.pdf'));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries, hasLength(2));
      expect(log.entries.last.message, contains('Started'));
      expect(log.entries.first.message, contains('Completed'));
    });

    test('WorkspaceEvent opened/saved/closed/recovered each record an entry; dirtyChanged does not', () async {
      bus.publish(const WorkspaceEvent(kind: WorkspaceEventKind.opened, path: 'a.diagram'));
      bus.publish(const WorkspaceEvent(kind: WorkspaceEventKind.dirtyChanged));
      bus.publish(const WorkspaceEvent(kind: WorkspaceEventKind.saved, path: 'a.diagram'));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries, hasLength(2));
    });

    test('EngineeringObjectEvent records a loaded entry with the object/relationship counts', () async {
      bus.publish(const EngineeringObjectEvent(objectCount: 42, relationshipCount: 7));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries.single.message, contains('42'));
      expect(log.entries.single.message, contains('7'));
    });

    test('EngineeringObjectEvent with zero counts records a cleared entry', () async {
      bus.publish(const EngineeringObjectEvent(objectCount: 0, relationshipCount: 0));
      await Future<void>.delayed(Duration.zero);

      expect(log.entries.single.message, contains('cleared'));
    });

    test('entries is capped at maxEntries, most-recent first', () async {
      for (var i = 0; i < ActivityLog.maxEntries + 5; i++) {
        bus.publish(WorkspaceEvent(kind: WorkspaceEventKind.opened, path: 'file-$i.diagram'));
      }
      await Future<void>.delayed(Duration.zero);

      expect(log.entries, hasLength(ActivityLog.maxEntries));
      expect(log.entries.first.message, contains('file-${ActivityLog.maxEntries + 4}.diagram'));
    });

    test('changes fires after entries has already been updated', () async {
      var countWhenFired = -1;
      final subscription = log.changes.listen((_) {
        countWhenFired = log.entries.length;
      });
      addTearDown(subscription.cancel);

      bus.publish(const WorkspaceEvent(kind: WorkspaceEventKind.closed));
      await Future<void>.delayed(Duration.zero);

      expect(countWhenFired, 1);
    });

    test('ActivityLog.instance is a shared singleton', () {
      expect(ActivityLog.instance, same(ActivityLog.instance));
    });
  });
}
