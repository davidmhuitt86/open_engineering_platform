import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context/engineering_interaction_context.dart';
import 'diagram_tab.dart';
import 'diagram_tabs_storage.dart';

/// (OEP Diagram Studio -- Phase 5, Part 2/Part 13/Part 14/Part 20.)
/// Pure tab-list/history state -- deliberately does NOT itself open,
/// close, save, or reload any document. `DiagramStudioPage` owns that
/// orchestration (dirty-check, `EngineeringProjectNotifier.openDocument`/
/// `closeDocument`, etc. -- all unchanged from before this phase) and
/// calls into this controller only to record/reflect the resulting tab
/// state. Keeping this controller document-lifecycle-agnostic is what
/// avoids creating a second document model (Part 1's explicit rule).
class DiagramTabsState {
  const DiagramTabsState({this.tabs = const [], this.activeTabId, this.recentlyClosed = const []});

  final List<DiagramTab> tabs;
  final String? activeTabId;
  final List<DiagramTab> recentlyClosed;

  DiagramTab? get activeTab {
    if (activeTabId == null) return null;
    for (final tab in tabs) {
      if (tab.id == activeTabId) return tab;
    }
    return null;
  }

  DiagramTabsState copyWith({List<DiagramTab>? tabs, String? activeTabId, bool clearActive = false, List<DiagramTab>? recentlyClosed}) =>
      DiagramTabsState(
        tabs: tabs ?? this.tabs,
        activeTabId: clearActive ? null : (activeTabId ?? this.activeTabId),
        recentlyClosed: recentlyClosed ?? this.recentlyClosed,
      );
}

class DiagramTabsNotifier extends Notifier<DiagramTabsState> {
  Future<void>? _restoreFuture;

  @override
  DiagramTabsState build() {
    _restoreFuture = _restore();
    return const DiagramTabsState();
  }

  /// Callers that need to seed a default tab (`DiagramStudioPage._bootstrap`)
  /// must await this first -- otherwise a persisted tab list loading
  /// asynchronously would silently overwrite a tab seeded in the race
  /// window before restoration finishes.
  Future<void> ensureRestored() => _restoreFuture ?? Future.value();

  Future<void> _restore() async {
    final loaded = await DiagramTabsStorage.load();
    if (loaded.tabs.isEmpty) return;
    state = DiagramTabsState(
      tabs: loaded.tabs,
      activeTabId: loaded.activeTabId,
      recentlyClosed: loaded.recentlyClosed,
    );
  }

  Future<void> _persist() => DiagramTabsStorage.save(
        tabs: state.tabs,
        activeTabId: state.activeTabId,
        recentlyClosed: state.recentlyClosed,
      );

  /// Creates a real tab entry and makes it the active one. Does not
  /// touch the underlying document/engine -- the caller is responsible
  /// for having already created/opened the real document this tab
  /// refers to.
  String openTab({String? path, required String title}) {
    // A tab already representing this exact path is reused, not
    // duplicated -- matches real browser-tab behavior.
    if (path != null) {
      for (final tab in state.tabs) {
        if (tab.path == path) {
          activate(tab.id);
          return tab.id;
        }
      }
    }
    final id = 'tab_${DateTime.now().microsecondsSinceEpoch}_${state.tabs.length}';
    final tab = DiagramTab(id: id, path: path, title: title);
    state = state.copyWith(tabs: [...state.tabs, tab], activeTabId: id);
    unawaited(_persist());
    return id;
  }

  void activate(String id) {
    if (state.activeTabId == id) return;
    state = state.copyWith(activeTabId: id);
    unawaited(_persist());
  }

  /// Removes [id] from the open tabs and records it in Recently Closed
  /// (Part 13). If it was the active tab, activates the most recently
  /// opened remaining tab (or none). The caller is responsible for the
  /// real close/dirty-check on the underlying document *before* calling
  /// this.
  void closeTab(String id) {
    final closing = state.tabs.where((t) => t.id == id).toList();
    if (closing.isEmpty) return;
    final remaining = state.tabs.where((t) => t.id != id).toList();
    final wasActive = state.activeTabId == id;
    state = state.copyWith(
      tabs: remaining,
      activeTabId: wasActive ? (remaining.isEmpty ? null : remaining.last.id) : null,
      clearActive: wasActive && remaining.isEmpty,
      recentlyClosed: [closing.single, ...state.recentlyClosed].take(DiagramTabsStorage.maxRecentlyClosed).toList(),
    );
    unawaited(_persist());
  }

  void togglePin(String id) {
    state = state.copyWith(
      tabs: [
        for (final tab in state.tabs)
          if (tab.id == id) tab.copyWith(pinned: !tab.pinned) else tab,
      ],
    );
    unawaited(_persist());
  }

  void setMode(String id, DiagramStudioMode mode) {
    state = state.copyWith(
      tabs: [
        for (final tab in state.tabs)
          if (tab.id == id) tab.copyWith(mode: mode) else tab,
      ],
    );
    unawaited(_persist());
  }

  void updateActiveTabDocument({String? path, String? title}) {
    final activeId = state.activeTabId;
    if (activeId == null) return;
    state = state.copyWith(
      tabs: [
        for (final tab in state.tabs)
          if (tab.id == activeId) tab.copyWith(path: path, clearPath: path == null, title: title) else tab,
      ],
    );
    unawaited(_persist());
  }

  /// Removes [id] from Recently Closed -- the caller reopens the real
  /// document (via the existing open pipeline) and calls [openTab]
  /// separately; this only clears the history entry.
  void removeFromRecentlyClosed(String id) {
    state = state.copyWith(recentlyClosed: state.recentlyClosed.where((t) => t.id != id).toList());
    unawaited(_persist());
  }

  void clearRecentlyClosed() {
    state = state.copyWith(recentlyClosed: const []);
    unawaited(_persist());
  }
}

final diagramTabsProvider = NotifierProvider<DiagramTabsNotifier, DiagramTabsState>(DiagramTabsNotifier.new);
