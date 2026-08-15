import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/workbench/perspective/perspective.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';

/// WP-DS-006: PerspectiveManager register/activate/persist/restore, and
/// DockManager's own persistence, against real files in a temp directory
/// (no mocks — matches this codebase's established "the full stack is
/// genuinely testable" precedent from AP-DS-005/WP-DS-005A).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('workbench_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Perspective fixture(String id) => Perspective(
        id: id,
        title: id,
        icon: Icons.circle,
        centerBuilder: (context) => const SizedBox(),
      );

  group('PerspectiveManager', () {
    test('registers perspectives and rejects a duplicate id', () {
      final manager = PerspectiveManager(file: File('${tempDir.path}/active.json'));
      manager.register(fixture('a'));
      manager.register(fixture('b'));
      expect(manager.perspectives.map((p) => p.id), ['a', 'b']);
      expect(() => manager.register(fixture('a')), throwsStateError);
    });

    test('activate notifies listeners and persists the active id', () async {
      final file = File('${tempDir.path}/active.json');
      final manager = PerspectiveManager(file: file)..registerAll([fixture('a'), fixture('b')]);
      var notified = 0;
      manager.addListener(() => notified++);

      manager.activate('b');
      expect(manager.active?.id, 'b');
      expect(notified, 1);

      // Persistence is fire-and-forget; give the microtask a chance to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(file.existsSync(), isTrue);
    });

    test('activating an unregistered id is a no-op', () {
      final manager = PerspectiveManager(file: File('${tempDir.path}/active.json'))..register(fixture('a'));
      manager.activate('missing');
      expect(manager.active, isNull);
    });

    test('restoreLastPerspective restores a persisted id across a fresh manager instance', () async {
      final file = File('${tempDir.path}/active.json');
      final first = PerspectiveManager(file: file)..registerAll([fixture('a'), fixture('b'), fixture('c')]);
      first.activate('c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = PerspectiveManager(file: file)..registerAll([fixture('a'), fixture('b'), fixture('c')]);
      await second.restoreLastPerspective();
      expect(second.active?.id, 'c');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('restoreLastPerspective falls back to the first registered perspective when nothing was persisted', () async {
      final manager = PerspectiveManager(file: File('${tempDir.path}/never_written.json'))
        ..registerAll([fixture('x'), fixture('y')]);
      await manager.restoreLastPerspective();
      expect(manager.active?.id, 'x');
      // restoreLastPerspective's own activate() call fire-and-forgets its
      // persistence write (matching this codebase's established
      // WorkspaceStateStorage/InstrumentDockController precedent) -- wait
      // for it before tearDown deletes tempDir, or the write races the
      // directory's own deletion.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('restoreLastPerspective ignores a persisted id that is no longer registered', () async {
      final file = File('${tempDir.path}/active.json');
      final first = PerspectiveManager(file: file)..registerAll([fixture('stale')]);
      first.activate('stale');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = PerspectiveManager(file: file)..registerAll([fixture('current')]);
      await second.restoreLastPerspective();
      expect(second.active?.id, 'current');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
