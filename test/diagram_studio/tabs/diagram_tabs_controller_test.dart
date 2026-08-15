import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/context/engineering_interaction_context.dart';
import 'package:oep_studio/diagram_studio/tabs/diagram_tabs_controller.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// OEP Diagram Studio -- Phase 5: unit tests for the pure tab-list/
/// history state (`DiagramTabsNotifier`), independent of the widget
/// layer (Part 13's "use the lowest appropriate testing layer").
/// `DiagramStudioPage`'s own document-lifecycle orchestration around
/// this controller is covered separately at the widget layer.
///
/// `DiagramTabsStorage` persists to a real file under
/// `SettingsStorage.root()` (the same established pattern
/// `RecentFilesStorage`/`WorkspaceStateStorage` already use, not test-
/// isolated) -- each test deletes that one file first so runs don't
/// leak state into each other.
void main() {
  File tabsFile() => File('${SettingsStorage.root().path}${Platform.pathSeparator}diagram_studio_tabs.json');

  setUp(() {
    final file = tabsFile();
    if (file.existsSync()) file.deleteSync();
  });

  // Persistence writes (`DiagramTabsNotifier._persist`) are deliberately
  // fire-and-forget (matching production call sites, which never await
  // tab-state mutations) -- a write from one test can otherwise land on
  // disk *after* the next test's `setUp` already deleted the file,
  // leaking stale tab state into that next test's `ensureRestored()`
  // read. Draining the microtask/timer queue and deleting again after
  // each test closes that race.
  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final file = tabsFile();
    if (file.existsSync()) file.deleteSync();
  });

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('Test A -- Tab creation', () {
    test('openTab creates a new tab and makes it active', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final id = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      final state = container_.read(diagramTabsProvider);

      expect(state.tabs, hasLength(1));
      expect(state.tabs.single.id, id);
      expect(state.tabs.single.path, '/tmp/a.json');
      expect(state.activeTabId, id);
    });

    test('opening the same path twice reuses the existing tab, not a duplicate', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final firstId = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      notifier.openTab(path: '/tmp/b.json', title: 'b.json');
      final reopenedId = notifier.openTab(path: '/tmp/a.json', title: 'a.json');

      final state = container_.read(diagramTabsProvider);
      expect(state.tabs, hasLength(2), reason: 'no duplicate tab for the same real document path');
      expect(reopenedId, firstId);
      expect(state.activeTabId, firstId, reason: 'reopening an already-open document activates its existing tab');
    });
  });

  group('Test B -- Tab switching', () {
    test('activate() changes which tab is active', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      final b = notifier.openTab(path: '/tmp/b.json', title: 'b.json');
      expect(container_.read(diagramTabsProvider).activeTabId, b);

      notifier.activate(a);
      expect(container_.read(diagramTabsProvider).activeTabId, a);
      expect(container_.read(diagramTabsProvider).activeTab!.path, '/tmp/a.json');
    });
  });

  group('Test C -- Tab closing', () {
    test('closeTab removes the tab and activates the next remaining one', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      final b = notifier.openTab(path: '/tmp/b.json', title: 'b.json');
      expect(container_.read(diagramTabsProvider).tabs, hasLength(2));

      notifier.closeTab(b);
      final state = container_.read(diagramTabsProvider);
      expect(state.tabs.map((t) => t.id), [a]);
      expect(state.tabs.any((t) => t.id == b), isFalse);
      expect(state.activeTabId, a, reason: 'closing the active tab activates a remaining one');
    });

    test('closing the only tab leaves no active tab', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      notifier.closeTab(a);

      final state = container_.read(diagramTabsProvider);
      expect(state.tabs, isEmpty);
      expect(state.activeTabId, isNull);
    });
  });

  group('Test D -- Recently closed', () {
    test('closing a tab records it in recentlyClosed; removeFromRecentlyClosed clears the entry', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      notifier.closeTab(a);

      final afterClose = container_.read(diagramTabsProvider);
      expect(afterClose.recentlyClosed, hasLength(1));
      expect(afterClose.recentlyClosed.single.path, '/tmp/a.json');

      notifier.removeFromRecentlyClosed(afterClose.recentlyClosed.single.id);
      expect(container_.read(diagramTabsProvider).recentlyClosed, isEmpty);
    });

    test('recentlyClosed is bounded (does not grow without limit)', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      for (var i = 0; i < 15; i++) {
        final id = notifier.openTab(path: '/tmp/doc$i.json', title: 'doc$i.json');
        notifier.closeTab(id);
      }
      expect(container_.read(diagramTabsProvider).recentlyClosed.length, lessThanOrEqualTo(10));
    });
  });

  group('Test E -- Pin', () {
    test('togglePin flips the pinned flag without affecting other tab fields', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      expect(container_.read(diagramTabsProvider).tabs.single.pinned, isFalse);

      notifier.togglePin(a);
      expect(container_.read(diagramTabsProvider).tabs.single.pinned, isTrue);
      expect(container_.read(diagramTabsProvider).tabs.single.path, '/tmp/a.json');

      notifier.togglePin(a);
      expect(container_.read(diagramTabsProvider).tabs.single.pinned, isFalse);
    });

    test('a pinned tab can still be closed intentionally -- pinned does not mean immutable', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      notifier.togglePin(a);
      notifier.closeTab(a);

      expect(container_.read(diagramTabsProvider).tabs, isEmpty);
    });
  });

  group('Test G -- Mode persistence per tab', () {
    test('each tab remembers its own mode independently', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: '/tmp/a.json', title: 'a.json');
      final b = notifier.openTab(path: '/tmp/b.json', title: 'b.json');

      notifier.setMode(a, DiagramStudioMode.edit);
      notifier.setMode(b, DiagramStudioMode.simulate);

      final state = container_.read(diagramTabsProvider);
      expect(state.tabs.firstWhere((t) => t.id == a).mode, DiagramStudioMode.edit);
      expect(state.tabs.firstWhere((t) => t.id == b).mode, DiagramStudioMode.simulate);

      notifier.activate(a);
      expect(container_.read(diagramTabsProvider).activeTab!.mode, DiagramStudioMode.edit);
      notifier.activate(b);
      expect(container_.read(diagramTabsProvider).activeTab!.mode, DiagramStudioMode.simulate);
    });

    test('a new tab defaults to Edit mode -- today\'s pre-Phase-5 behavior, preserved', () async {
      final container_ = container();
      final notifier = container_.read(diagramTabsProvider.notifier);
      await notifier.ensureRestored();

      final a = notifier.openTab(path: null, title: 'Untitled Diagram');
      expect(container_.read(diagramTabsProvider).tabs.single.mode, DiagramStudioMode.edit);
      expect(a, isNotEmpty);
    });
  });
}
