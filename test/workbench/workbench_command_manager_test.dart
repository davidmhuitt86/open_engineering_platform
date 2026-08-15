import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/commands/command_registry.dart';
import 'package:oep_studio/workbench/command/workbench_command_manager.dart';
import 'package:oep_studio/workbench/perspective/perspective.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';

/// Pumps a bare [ProviderScope] and hands back a live [WidgetRef] — same
/// convention as `test/command_registry_test.dart`.
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
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('workbench_command_manager_test_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Perspective fixture(String id) => Perspective(
        id: id,
        title: id,
        icon: Icons.circle,
        centerBuilder: (context) => const SizedBox(),
      );

  group('WorkbenchCommandManager', () {
    test('registry includes every Platform command plus the Workbench-only command', () {
      final perspectives = PerspectiveManager(file: File('${tempDir.path}/active.json'))
        ..registerAll([fixture('a'), fixture('b')]);
      final manager = WorkbenchCommandManager(perspectiveManager: perspectives);

      expect(
        manager.registry.findCommand(WorkbenchCommandManager.workbenchActivatePerspectiveCommandId),
        isNotNull,
      );
      // Every command from the real Platform default registry is present too.
      for (final command in CommandRegistry.defaultRegistry.commands) {
        expect(manager.registry.findCommand(command.id), isNotNull, reason: command.id);
      }
      expect(
        manager.registry.commands.length,
        CommandRegistry.defaultRegistry.commands.length + 1,
      );
    });

    testWidgets('activatePerspective command actually activates the requested perspective', (tester) async {
      final ref = await _pumpRef(tester);
      final perspectives = PerspectiveManager(file: File('${tempDir.path}/active.json'))
        ..registerAll([fixture('a'), fixture('b')]);
      final manager = WorkbenchCommandManager(perspectiveManager: perspectives);

      expect(perspectives.active, isNull);
      final result = await manager.registry.execute(
        ref,
        WorkbenchCommandManager.workbenchActivatePerspectiveCommandId,
        args: const CommandArgs(value: 'b'),
      );

      expect(result.isSuccess, isTrue);
      expect(perspectives.active?.id, 'b');
      await tester.pump(const Duration(milliseconds: 60));
    });

    testWidgets('activatePerspective without an argument is rejected as invalid', (tester) async {
      final ref = await _pumpRef(tester);
      final perspectives = PerspectiveManager(file: File('${tempDir.path}/active.json'))
        ..registerAll([fixture('a')]);
      final manager = WorkbenchCommandManager(perspectiveManager: perspectives);

      final result = await manager.registry.execute(
        ref,
        WorkbenchCommandManager.workbenchActivatePerspectiveCommandId,
      );
      expect(result.outcome, CommandOutcome.invalidArguments);
    });
  });
}
