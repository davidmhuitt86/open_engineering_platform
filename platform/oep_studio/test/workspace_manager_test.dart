import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/events/platform_event.dart';
import 'package:oep_studio/core/events/platform_event_bus.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/core/workspace/workspace_manager.dart';

/// Builds an [EngineeringProjectState] with just the two `DiagramDocument`
/// fields [WorkspaceManager] actually reads (`path`/`isDirty`, both
/// plain mutable fields — no file I/O needed to set them directly).
EngineeringProjectState _fakeState({String? path, required bool dirty}) {
  final document = DiagramDocument()
    ..path = path
    ..isDirty = dirty;
  return EngineeringProjectState(document: document);
}

void main() {
  late File stateFile;

  setUp(() {
    stateFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
        'wp029_workspace_manager_test_${DateTime.now().microsecondsSinceEpoch}.json');
  });

  tearDown(() async {
    if (stateFile.existsSync()) await stateFile.delete();
  });

  group('WorkspaceManager — recent workspaces', () {
    test('initialize with no file leaves recentWorkspaces empty', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      expect(manager.recentWorkspaces, isEmpty);
    });

    test('opening a document adds it to the front of the recent list', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: 'b.json', dirty: false));
      expect(manager.recentWorkspaces, ['b.json', 'a.json']);
    });

    test('reopening an already-recent path moves it to the front without duplicating it', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: 'b.json', dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));
      expect(manager.recentWorkspaces, ['a.json', 'b.json']);
    });

    test('the recent list is capped at maxRecentWorkspaces', () async {
      final manager = WorkspaceManager(file: stateFile, maxRecentWorkspaces: 2);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: 'b.json', dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: 'c.json', dirty: false));
      expect(manager.recentWorkspaces, ['c.json', 'b.json']);
    });

    test('the recent list persists across a fresh WorkspaceManager reading the same file', () async {
      final first = WorkspaceManager(file: stateFile);
      await first.initialize();
      await first.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));

      final second = WorkspaceManager(file: stateFile);
      await second.initialize();
      expect(second.recentWorkspaces, ['a.json']);
    });
  });

  group('WorkspaceManager — dirty-state coordination', () {
    test('hasUnsavedChanges reflects the most recent state', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      expect(manager.hasUnsavedChanges, isFalse);

      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true));
      expect(manager.hasUnsavedChanges, isTrue);

      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));
      expect(manager.hasUnsavedChanges, isFalse);
    });
  });

  group('WorkspaceManager — crash recovery', () {
    test('becoming dirty sets a recoverable path that survives a fresh instance (crash simulation)', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true));
      // No clean shutdown — simulate a crash by just reading the file
      // with a brand-new WorkspaceManager instance.
      final afterCrash = WorkspaceManager(file: stateFile);
      await afterCrash.initialize();
      expect(afterCrash.recoverableWorkspacePath, 'a.json');
    });

    test('a clean save clears the recoverable path', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true));
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false));

      final reloaded = WorkspaceManager(file: stateFile);
      await reloaded.initialize();
      expect(reloaded.recoverableWorkspacePath, isNull);
    });

    test('discarding via Close clears the recoverable path even though it never saved', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true));
      await manager.handleProjectStateChange(_fakeState(path: null, dirty: false));

      expect(manager.recoverableWorkspacePath, isNull);
    });

    test('clearRecoverable clears it directly, e.g. after the user responds to the startup prompt', () async {
      final manager = WorkspaceManager(file: stateFile);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true));
      expect(manager.recoverableWorkspacePath, 'a.json');

      await manager.clearRecoverable();
      expect(manager.recoverableWorkspacePath, isNull);
    });

    test('a corrupted state file is treated as a fresh install, not an error', () async {
      await stateFile.writeAsString('{ not valid json');
      final manager = WorkspaceManager(file: stateFile);
      await expectLater(manager.initialize(), completes);
      expect(manager.recentWorkspaces, isEmpty);
      expect(manager.recoverableWorkspacePath, isNull);
    });
  });

  group('WorkspaceManager — Platform Event Bus integration', () {
    test('publishes opened/closed/dirtyChanged/saved events on the injected bus, not the app-wide singleton', () async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final received = <WorkspaceEvent>[];
      final subscription = bus.on<WorkspaceEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      final manager = WorkspaceManager(file: stateFile, eventBus: bus);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false)); // opened
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: true)); // dirtyChanged
      await manager.handleProjectStateChange(_fakeState(path: 'a.json', dirty: false)); // dirtyChanged + saved
      await manager.handleProjectStateChange(_fakeState(path: null, dirty: false)); // closed

      expect(received.map((e) => e.kind).toList(), [
        WorkspaceEventKind.opened,
        WorkspaceEventKind.dirtyChanged,
        WorkspaceEventKind.dirtyChanged,
        WorkspaceEventKind.saved,
        WorkspaceEventKind.closed,
      ]);
    });

    test('no event is published for a state that has not actually changed', () async {
      final bus = PlatformEventBus();
      addTearDown(bus.dispose);
      final received = <WorkspaceEvent>[];
      final subscription = bus.on<WorkspaceEvent>().listen(received.add);
      addTearDown(subscription.cancel);

      final manager = WorkspaceManager(file: stateFile, eventBus: bus);
      await manager.initialize();
      await manager.handleProjectStateChange(_fakeState(path: null, dirty: false));
      await manager.handleProjectStateChange(_fakeState(path: null, dirty: false));

      expect(received, isEmpty);
    });
  });
}
