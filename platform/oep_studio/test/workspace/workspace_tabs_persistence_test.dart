import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';
import 'package:oep_studio/workspace/workspace_tabs_storage.dart';

import '../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-PERSISTENCE-001/AP-OEP-WORKSPACE-MULTI-INSTANCE-001
/// — focused tests for [WorkspaceTabsController]'s persistence behavior.
/// The schema now stores `{id, surfaceId}` tab records (not bare
/// surfaceId strings) so two tabs can legitimately share a `surfaceId`
/// — see [WorkspaceTabsStorage]'s own doc comment for the
/// backward-compatible migration from the original
/// `{surfaces: [...], activeId}` shape. Uses an in-memory fake
/// [WorkspaceTabsStorage] subclass throughout (no real filesystem
/// coupling) except for the one end-to-end provider test, which uses
/// `useIsolatedSettingsStorage()` — the same real-storage isolation seam
/// every other persistence test in this repo already uses.
void main() {
  final a = SurfaceRegistry.all[0];
  final b = SurfaceRegistry.all[1];

  group('WorkspaceTabsController persistence (in-memory fake storage)', () {
    test('1. empty storage produces empty/default Workspace state', () async {
      final storage = _FakeWorkspaceTabsStorage();
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.tabs, isEmpty);
      expect(controller.activeId, isNull);
    });

    test('2/3. persisting opened Surfaces restores them in the same order, with the same active Surface', () async {
      final storage = _FakeWorkspaceTabsStorage();
      final writer = WorkspaceTabsController(storage: storage);
      writer.openSurface(a.id);
      writer.openSurface(b.id);
      // AP-OEP-WORKSPACE-RESTORATION-001 — writes are now queued
      // (serialized in call order, § the write-ordering test below),
      // not applied synchronously the instant `openSurface` returns;
      // let the queue actually drain before reading it back.
      await pumpEventQueue();

      final reader = WorkspaceTabsController(storage: storage);
      await reader.restore();

      expect(reader.tabs.map((t) => t.surfaceId).toList(), [a.id, b.id]);
      expect(reader.active!.surfaceId, b.id, reason: 'b was opened last and therefore active at persist time');
    });

    test('4. closing a Surface persists the updated list', () async {
      final storage = _FakeWorkspaceTabsStorage();
      final controller = WorkspaceTabsController(storage: storage);
      final aId = controller.openSurface(a.id);
      controller.openSurface(b.id);

      controller.close(aId);
      await pumpEventQueue();

      expect(storage.tabs.map((t) => t.surfaceId).toList(), [b.id]);
    });

    test('5. activating a Surface persists the active id', () async {
      final storage = _FakeWorkspaceTabsStorage();
      final controller = WorkspaceTabsController(storage: storage);
      final aId = controller.openSurface(a.id);
      controller.openSurface(b.id);

      controller.activate(aId);
      await pumpEventQueue();

      expect(storage.activeId, aId);
    });

    test('6. duplicate tab ids in the persisted file are not restored as duplicate tabs', () async {
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-${a.id}', surfaceId: a.id), (id: 'workspace-tab-${a.id}', surfaceId: a.id), (id: 'workspace-tab-${b.id}', surfaceId: b.id)];
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.tabs.map((t) => t.surfaceId).toList(), [a.id, b.id]);
    });

    test('7. invalid/stale Surface IDs are ignored, never fabricated into a tab', () async {
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-no-such-surface', surfaceId: 'no-such-surface'), (id: 'workspace-tab-${a.id}', surfaceId: a.id)];
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.surfaceId, a.id);
    });

    test('8. an invalid active id falls back deterministically to the first restored tab', () async {
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-${a.id}', surfaceId: a.id), (id: 'workspace-tab-${b.id}', surfaceId: b.id)]
        ..activeId = 'no-such-tab-id';
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.active!.surfaceId, a.id);
    });

    test('9. a persisted Diagram Surface restores correctly using the reserved diagram surfaceId', () async {
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-${WorkspaceTab.diagramSurfaceId}', surfaceId: WorkspaceTab.diagramSurfaceId)]
        ..activeId = 'workspace-tab-${WorkspaceTab.diagramSurfaceId}';
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.isDiagram, isTrue);
      expect(controller.active!.isDiagram, isTrue);
    });

    test('10. all-invalid persisted state produces a valid empty/default Workspace, and the stale file self-heals', () async {
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-bogus-1', surfaceId: 'bogus-1'), (id: 'workspace-tab-bogus-2', surfaceId: 'bogus-2')]
        ..activeId = 'workspace-tab-bogus-1';
      final controller = WorkspaceTabsController(storage: storage);

      await controller.restore();

      expect(controller.tabs, isEmpty);
      expect(controller.activeId, isNull);
      // The invalid ids are not left to linger in the file forever —
      // restoration re-persists the cleaned (now-empty) state, per this
      // package's own "restoring state if restoration changes the
      // effective state" persistence trigger.
      expect(storage.tabs, isEmpty);
      expect(storage.saveCount, greaterThan(0));
    });

    test('11. restoration occurs only once per controller initialization', () async {
      final storage = _FakeWorkspaceTabsStorage()..tabs = [(id: 'workspace-tab-${a.id}', surfaceId: a.id)];

      final controller = WorkspaceTabsController(storage: storage);
      await controller.restore();
      await controller.restore(); // a second, accidental call

      expect(storage.loadCount, 1);
      expect(controller.tabs, hasLength(1), reason: 'no double-restore duplication either');
    });

    test('avoids redundant writes when the serialized state has not changed', () async {
      final storage = _FakeWorkspaceTabsStorage();
      final controller = WorkspaceTabsController(storage: storage);
      final id = controller.openSurface(a.id);
      await pumpEventQueue();
      final countAfterOpen = storage.saveCount;

      // Re-activating the tab that is *already* active is not an
      // effective change.
      controller.activate(id);
      await pumpEventQueue();

      expect(storage.saveCount, countAfterOpen, reason: 'no new write for a no-op activation');
    });

    test(
        'AP-OEP-WORKSPACE-RESTORATION-001: writes are serialized — a slow first write never overwrites a later, faster second write',
        () async {
      final storage = _SlowFirstWriteStorage();
      final controller = WorkspaceTabsController(storage: storage);

      // Two mutations issued back-to-back with no `await` between them —
      // exactly the burst `_writeChain` exists to protect against. The
      // first save is artificially slow; without serialization its
      // eventual completion could clobber the second (correct, final)
      // state with stale single-tab content.
      controller.openSurface(a.id);
      controller.openSurface(b.id);

      await storage.firstSaveStarted;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      storage.completeFirstSave();
      await pumpEventQueue();

      expect(storage.tabs.map((t) => t.surfaceId).toList(), [a.id, b.id],
          reason: 'the later call must win on disk, regardless of per-write latency');
    });

    test('13. persistence never mutates SurfaceRegistry', () async {
      final before = SurfaceRegistry.all.map((s) => s.id).toList();
      final storage = _FakeWorkspaceTabsStorage()
        ..tabs = [(id: 'workspace-tab-${a.id}', surfaceId: a.id), (id: 'workspace-tab-${b.id}', surfaceId: b.id)];
      final controller = WorkspaceTabsController(storage: storage);
      await controller.restore();
      controller.openSurface(a.id);
      controller.close(controller.tabs.first.id);

      expect(SurfaceRegistry.all.map((s) => s.id).toList(), before);
    });

    group('AP-OEP-WORKSPACE-MULTI-INSTANCE-001', () {
      // `restore()` validates each persisted surfaceId against
      // SurfaceRegistry/the reserved sentinels (existing, preserved
      // behavior — § tests 7/10 above), so these persistence-focused
      // tests use a real registered surfaceId rather than the harmless
      // unregistered one the pure-controller tests use — `openNewInstance`
      // itself still never consults SurfaceRegistry/allowsMultipleInstances
      // (§ that method's own doc comment); this is purely to survive the
      // restore-time validation step being exercised here.
      final multiInstanceSurfaceId = a.id;

      test('L. persistence restores multiple instances of the same surfaceId, distinguished by id', () async {
        final storage = _FakeWorkspaceTabsStorage();
        final writer = WorkspaceTabsController(storage: storage);
        final instance1Id = writer.openNewInstance(multiInstanceSurfaceId);
        final instance2Id = writer.openNewInstance(multiInstanceSurfaceId);
        await pumpEventQueue();

        final reader = WorkspaceTabsController(storage: storage);
        await reader.restore();

        expect(reader.tabs.map((t) => t.id).toList(), [instance1Id, instance2Id]);
        expect(reader.tabs.map((t) => t.surfaceId).toList(), [multiInstanceSurfaceId, multiInstanceSurfaceId]);
        expect(reader.active!.id, instance2Id, reason: 'instance 2 was opened last and therefore active at persist time');
      });

      test('a freshly restored session never mints a colliding instance id', () async {
        final storage = _FakeWorkspaceTabsStorage();
        final writer = WorkspaceTabsController(storage: storage);
        writer.openNewInstance(multiInstanceSurfaceId);
        writer.openNewInstance(multiInstanceSurfaceId);
        await pumpEventQueue();
        final persistedIds = storage.tabs.map((t) => t.id).toSet();

        final reader = WorkspaceTabsController(storage: storage);
        await reader.restore();
        final newId = reader.openNewInstance(multiInstanceSurfaceId);

        expect(persistedIds.contains(newId), isFalse);
        expect(reader.tabs.map((t) => t.id).toSet().length, reader.tabs.length, reason: 'no id collision among any restored+new tab');
      });

      test('M. legacy {surfaces, activeId} persistence format still restores correctly', () async {
        final storage = _LegacyFormatStorage()
          ..surfaces = [a.id, b.id]
          ..legacyActiveId = b.id;
        final controller = WorkspaceTabsController(storage: storage);

        await controller.restore();

        expect(controller.tabs.map((t) => t.surfaceId).toList(), [a.id, b.id]);
        expect(controller.active!.surfaceId, b.id);
      });

      test('N. invalid persisted tab ids/surfaceIds are dropped, never fabricated', () async {
        final storage = _FakeWorkspaceTabsStorage()
          ..tabs = [
            (id: 'workspace-tab-${a.id}', surfaceId: a.id),
            (id: 'workspace-tab-${a.id}', surfaceId: a.id), // corrupt duplicate id
            (id: 'workspace-tab-bogus', surfaceId: 'bogus-surface'), // unknown surfaceId
          ]
          ..activeId = 'workspace-tab-bogus';
        final controller = WorkspaceTabsController(storage: storage);

        await controller.restore();

        expect(controller.tabs, hasLength(1));
        expect(controller.tabs.single.surfaceId, a.id);
        expect(controller.active!.surfaceId, a.id, reason: 'invalid active id falls back to the first surviving tab');
      });

      test('O. no-op activation still produces no unnecessary notification with multi-instance tabs present', () async {
        final storage = _FakeWorkspaceTabsStorage();
        final controller = WorkspaceTabsController(storage: storage);
        final instanceId = controller.openNewInstance(multiInstanceSurfaceId);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.activate(instanceId); // already active

        expect(notifications, 0);
      });
    });
  });

  group('workspaceTabsControllerProvider end-to-end restoration (real, isolated storage)', () {
    test('a Surface persisted by one container is restored by a fresh one, exactly once', () async {
      useIsolatedSettingsStorage();

      final firstContainer = ProviderContainer();
      final writer = firstContainer.read(workspaceTabsControllerProvider);
      // The provider's own create callback already kicked off `restore()`
      // (unawaited) the moment it was read above; let that initial,
      // empty-file load actually finish before opening a real tab, so
      // this test isn't racing its own setup.
      await pumpEventQueue();
      writer.openSurface(a.id);
      // A real, unawaited `dart:io` file write is in flight (by design
      // — the controller's public API stays synchronous); a genuine
      // timer delay, not just a microtask-queue drain, is needed to let
      // it actually land on disk before the next container reads it
      // back.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      final reader = secondContainer.read(workspaceTabsControllerProvider);
      // The provider's own create callback already kicked off `restore()`
      // (unawaited) the moment `read` above ran; a direct `await
      // reader.restore()` here would be a same-tick no-op (the internal
      // `_restored` guard is set synchronously, before the real load
      // even starts) — waiting for that already-in-flight load instead.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(reader.tabs, hasLength(1));
      expect(reader.tabs.single.surfaceId, a.id);
    });
  });
}

class _FakeWorkspaceTabsStorage extends WorkspaceTabsStorage {
  List<PersistedWorkspaceTab> tabs = [];
  String? activeId;
  int saveCount = 0;
  int loadCount = 0;

  @override
  Future<({List<PersistedWorkspaceTab> tabs, String? activeId})> load() async {
    loadCount++;
    return (tabs: List.of(tabs), activeId: activeId);
  }

  @override
  Future<void> save({required List<PersistedWorkspaceTab> tabs, required String? activeId}) async {
    saveCount++;
    this.tabs = List.of(tabs);
    this.activeId = activeId;
  }
}

/// A storage fake that only ever produces the pre-AP-OEP-WORKSPACE-
/// MULTI-INSTANCE-001 `{surfaces, activeId}` shape from [load] — proving
/// [WorkspaceTabsController] restores correctly against a file it never
/// itself wrote in the new shape (a genuinely pre-existing user file).
class _LegacyFormatStorage extends WorkspaceTabsStorage {
  List<String> surfaces = [];
  String? legacyActiveId;

  @override
  Future<({List<PersistedWorkspaceTab> tabs, String? activeId})> load() async {
    final tabs = [for (final surfaceId in surfaces) (id: 'workspace-tab-$surfaceId', surfaceId: surfaceId)];
    final activeId = legacyActiveId == null ? null : 'workspace-tab-$legacyActiveId';
    return (tabs: tabs, activeId: activeId);
  }

  @override
  Future<void> save({required List<PersistedWorkspaceTab> tabs, required String? activeId}) async {
    // Not exercised by the one test using this fake (restore-only).
  }
}

/// AP-OEP-WORKSPACE-RESTORATION-001 — a storage fake whose *first* call
/// to [save] blocks (via [_firstSaveGate]) until the test explicitly
/// releases it with [completeFirstSave], while every later call resolves
/// immediately. Used to prove [WorkspaceTabsController]'s write queue
/// serializes saves in call order rather than in whichever-finishes-first
/// order.
class _SlowFirstWriteStorage extends WorkspaceTabsStorage {
  List<PersistedWorkspaceTab> tabs = [];
  String? activeId;

  final Completer<void> _firstSaveGate = Completer<void>();
  final Completer<void> _firstSaveStarted = Completer<void>();
  bool _sawFirstCall = false;

  Future<void> get firstSaveStarted => _firstSaveStarted.future;

  void completeFirstSave() => _firstSaveGate.complete();

  @override
  Future<void> save({required List<PersistedWorkspaceTab> tabs, required String? activeId}) async {
    if (!_sawFirstCall) {
      _sawFirstCall = true;
      _firstSaveStarted.complete();
      await _firstSaveGate.future;
    }
    this.tabs = List.of(tabs);
    this.activeId = activeId;
  }
}
