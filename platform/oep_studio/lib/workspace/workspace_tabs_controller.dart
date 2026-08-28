import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surfaces/surface_registry.dart';
import 'workspace_tab.dart';
import 'workspace_tabs_storage.dart';

/// AP-OEP-WORKSPACE-SHELL-001/AP-OEP-WORKSPACE-UX-001/
/// AP-OEP-WORKSPACE-PERSISTENCE-001 — the smallest controller for the
/// new OEP-wide workspace shell: open/activate/close, plus (this
/// package) persistence of exactly the open-Surface identity — nothing
/// else. No pin, no duplicate, no recently-closed, no reorder — none of
/// those exist in the current infrastructure this generalizes from
/// without real additional architectural work, so none are added here.
///
/// **Now a `ChangeNotifier`, provided via [workspaceTabsControllerProvider]**
/// — AP-OEP-WORKSPACE-UX-001's own Phase 3 requires the sidebar (a
/// sibling of [EngineeringWorkspacePage] in the widget tree, not an
/// ancestor/descendant of it) to read and mutate the *same* tab state
/// the workspace page renders, so a page-local field (this class's
/// previous AP-OEP-WORKSPACE-SHELL-001 shape) can no longer be the sole
/// instance — it must be reachable from both. This is still "the sole
/// workspace tab-state authority" (unchanged): there is exactly one
/// provider, one instance, no second controller anywhere.
///
/// **Persistence** (AP-OEP-WORKSPACE-PERSISTENCE-001): plain Dart, no
/// Engine/Foundation knowledge, exactly as before — [WorkspaceTabsStorage]
/// is the only thing this class talks to, and it only ever exchanges
/// surfaceId strings with it, per `docs/OEP_WORKSPACE_STATE_ARCHITECTURE.md`'s
/// own minimal-schema conclusion. Restoration is validated against
/// [SurfaceRegistry] (plus the one reserved Diagram sentinel,
/// [WorkspaceTab.diagramSurfaceId]) — the existing, sole canonical
/// Surface source; no second Surface list is introduced.
class WorkspaceTabsController extends ChangeNotifier {
  WorkspaceTabsController({WorkspaceTabsStorage storage = const WorkspaceTabsStorage()}) : _storage = storage;

  final WorkspaceTabsStorage _storage;
  final List<WorkspaceTab> _tabs = [];
  String? _activeId;

  bool _restored = false;
  List<String>? _lastPersistedSurfaces;
  String? _lastPersistedActiveSurfaceId;
  bool _lastPersistedSentinel = false;

  /// AP-OEP-WORKSPACE-RESTORATION-001 — every write chains onto this
  /// Future instead of firing independently. `_persistIfChanged`'s
  /// `unawaited(_storage.save(...))` calls are fire-and-forget by
  /// design (the controller's public API stays synchronous), but two
  /// such calls issued in quick succession (e.g. two `openSurface`
  /// calls in the same synchronous caller, with no `await` between
  /// them) have no inherent ordering guarantee once they're both
  /// in-flight `dart:io` operations — without this chain, whichever
  /// write's OS-level completion lands last would win, which is not
  /// necessarily the *later* call, silently persisting stale state.
  /// Chaining guarantees writes land on disk in the same order they
  /// were requested, with zero change to what's written or when the
  /// first write in a burst starts.
  Future<void> _writeChain = Future<void>.value();

  List<WorkspaceTab> get tabs => List.unmodifiable(_tabs);
  String? get activeId => _activeId;
  WorkspaceTab? get active => _activeId == null ? null : _tabs.where((t) => t.id == _activeId).firstOrNull;

  /// Opens [surfaceId] as a new tab, or focuses it if already open —
  /// the same reuse-if-open semantics `WebSurfacesHostPage._openLegacyV2`
  /// / `_openNativeTab` already use, not a new policy invented here.
  /// This is also AP-OEP-WORKSPACE-UX-001's Phase 4 duplicate-tab
  /// policy in full: exactly one tab per Surface id, always. Returns
  /// the id of the (possibly pre-existing) tab.
  String openSurface(String surfaceId) {
    final existing = _tabs.where((t) => t.surfaceId == surfaceId).firstOrNull;
    if (existing != null) {
      // AP-OEP-WORKSPACE-UX-002 — re-selecting the tab that's already
      // active is a genuine no-op (nothing about "what's open" or
      // "what's active" changes); skip the rebuild/persist-check churn
      // rather than announcing a change that didn't happen.
      if (existing.id != _activeId) {
        _activeId = existing.id;
        notifyListeners();
        _persistIfChanged();
      }
      return existing.id;
    }
    // A deterministic id (`surfaceId` itself, prefixed), not a
    // timestamp: reuse-if-open already means at most one tab per
    // `surfaceId` can ever exist, so this is not a loss of uniqueness —
    // and it avoids a real, observed bug a timestamp-based id had
    // (`DateTime.now().microsecondsSinceEpoch` is not guaranteed unique
    // across two calls issued in the same microsecond, which a fast
    // test — or a fast double-click — can genuinely trigger, silently
    // merging two different Surfaces' tabs under one colliding id).
    final tab = WorkspaceTab(id: 'workspace-tab-$surfaceId', surfaceId: surfaceId);
    _tabs.add(tab);
    _activeId = tab.id;
    notifyListeners();
    _persistIfChanged();
    return tab.id;
  }

  void activate(String id) {
    // AP-OEP-WORKSPACE-UX-002 — same no-op guard as [openSurface]'s
    // reuse-if-open branch: activating the tab that's already active
    // changes nothing.
    if (id == _activeId) return;
    if (_tabs.any((t) => t.id == id)) {
      _activeId = id;
      notifyListeners();
      _persistIfChanged();
    }
  }

  /// Removes [id]. If it was active, activates the tab immediately
  /// before it in the list (or the new last tab, or none) — the same
  /// "activate a neighbor" behavior `WebSurfaceTabsController.close`/
  /// `DiagramTabsNotifier.closeTab` already use.
  void close(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final wasActive = _activeId == id;
    _tabs.removeAt(index);
    if (wasActive) {
      _activeId = _tabs.isEmpty ? null : _tabs[index > 0 ? index - 1 : 0].id;
    }
    notifyListeners();
    _persistIfChanged();
  }

  /// Loads persisted Workspace tab identity and restores it — called
  /// exactly once, from [workspaceTabsControllerProvider]'s own create
  /// callback, so it runs once per controller/session lifetime (the
  /// provider itself is created at most once per `ProviderContainer`,
  /// per Riverpod's own lifecycle guarantee; [_restored] is a defensive
  /// second guard against any accidental re-entrant call).
  ///
  /// Every stored surfaceId is validated against [SurfaceRegistry] (or
  /// the reserved [WorkspaceTab.diagramSurfaceId] sentinel) before being
  /// restored — a stale/unknown id (e.g. from an older build whose
  /// Surface list has since changed) is silently dropped, never
  /// fabricated into a placeholder tab. Order is preserved among the
  /// surviving ids. The stored active id is restored only if it's one
  /// of the surviving ids; otherwise the first surviving tab becomes
  /// active (a deterministic fallback), or none if nothing survived.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final loaded = await _storage.load();
    final validSurfaceIds = <String>[];
    for (final surfaceId in loaded.surfaces) {
      if (validSurfaceIds.contains(surfaceId)) continue; // no duplicate tabs
      if (_isKnownSurfaceId(surfaceId)) validSurfaceIds.add(surfaceId);
    }

    // Defensive against the (unlikely) race of a real `openSurface`/
    // sidebar click landing between provider creation and this async
    // load resolving: never add a surfaceId that's already open by the
    // time restoration actually runs — the one-tab-per-surfaceId rule
    // must hold no matter which path opened it first.
    for (final surfaceId in validSurfaceIds) {
      if (_tabs.any((t) => t.surfaceId == surfaceId)) continue;
      _tabs.add(WorkspaceTab(id: 'workspace-tab-$surfaceId', surfaceId: surfaceId));
    }

    // Same race guard as above: if something already activated a tab
    // for real before this load resolved, that real choice wins — this
    // only ever sets the active tab from a clean slate.
    if (_activeId == null) {
      final restoredActiveId = (loaded.activeId != null && validSurfaceIds.contains(loaded.activeId))
          ? 'workspace-tab-${loaded.activeId}'
          : (_tabs.isEmpty ? null : _tabs.first.id);
      _activeId = restoredActiveId;
    }

    // Only re-persist if restoration actually changed the effective
    // state (dropped stale ids, deduped, or fell back to a different
    // active id) — an already-clean file is left untouched, per this
    // package's own "avoid unnecessary writes" requirement.
    final effectiveActiveSurfaceId = active?.surfaceId;
    final changed = !listEquals(loaded.surfaces, validSurfaceIds) || loaded.activeId != effectiveActiveSurfaceId;

    notifyListeners();
    if (changed) {
      await _persist();
    } else {
      _rememberLastPersisted(validSurfaceIds, effectiveActiveSurfaceId);
    }
  }

  bool _isKnownSurfaceId(String surfaceId) =>
      surfaceId == WorkspaceTab.diagramSurfaceId ||
      surfaceId == WorkspaceTab.diagram2SurfaceId ||
      SurfaceRegistry.forId(surfaceId) != null;

  void _rememberLastPersisted(List<String> surfaces, String? activeSurfaceId) {
    _lastPersistedSurfaces = List.of(surfaces);
    _lastPersistedActiveSurfaceId = activeSurfaceId;
    _lastPersistedSentinel = true;
  }

  void _persistIfChanged() {
    final surfaces = [for (final tab in _tabs) tab.surfaceId];
    final activeSurfaceId = active?.surfaceId;
    if (_lastPersistedSentinel &&
        listEquals(_lastPersistedSurfaces, surfaces) &&
        _lastPersistedActiveSurfaceId == activeSurfaceId) {
      return;
    }
    _rememberLastPersisted(surfaces, activeSurfaceId);
    _enqueueSave(surfaces, activeSurfaceId);
  }

  Future<void> _persist() async {
    final surfaces = [for (final tab in _tabs) tab.surfaceId];
    final activeSurfaceId = active?.surfaceId;
    _rememberLastPersisted(surfaces, activeSurfaceId);
    await _enqueueSave(surfaces, activeSurfaceId);
  }

  Future<void> _enqueueSave(List<String> surfaces, String? activeSurfaceId) {
    final next = _writeChain.then((_) => _storage.save(surfaces: surfaces, activeId: activeSurfaceId));
    _writeChain = next;
    return next;
  }
}

/// One shared instance for the whole app's lifetime — read by
/// [EngineeringWorkspacePage] to render tabs, and by `WorkbenchSidebar`'s
/// host (`StudioShell`, which passes a callback down — `WorkbenchSidebar`
/// itself never reads this provider directly, § its own doc comment on
/// why) to open/activate a Surface as a workspace tab from a sidebar
/// click, per AP-OEP-WORKSPACE-UX-001's Phase 3.
///
/// AP-OEP-WORKSPACE-PERSISTENCE-001 — `restore()` is kicked off here,
/// once, the moment the provider is first read (Riverpod creates a
/// `ChangeNotifierProvider`'s value at most once per container). It is
/// deliberately not awaited: the controller starts empty (today's
/// existing default), then repopulates itself and calls
/// `notifyListeners()` once the persisted state has loaded, the same
/// "start empty, restore asynchronously" shape `WebSurfacesHostPage`'s
/// own `_restoreTabs()` already established for its internal tab host.
final workspaceTabsControllerProvider = ChangeNotifierProvider<WorkspaceTabsController>(
  (ref) {
    final controller = WorkspaceTabsController();
    unawaited(controller.restore());
    return controller;
  },
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
