import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surfaces/surface_registry.dart';
import 'workspace_tab.dart';
import 'workspace_tabs_storage.dart';

/// AP-OEP-WORKSPACE-SHELL-001/AP-OEP-WORKSPACE-UX-001/
/// AP-OEP-WORKSPACE-PERSISTENCE-001/AP-OEP-WORKSPACE-MULTI-INSTANCE-001
/// — the smallest controller for the OEP-wide workspace shell: open/
/// activate/close, persistence of tab identity, and (this package) a
/// second, explicit way to open a tab that always creates a new
/// instance rather than reusing one — nothing else. No pin, no
/// recently-closed, no reorder — none of those exist in the current
/// infrastructure this generalizes from without real additional
/// architectural work, so none are added here.
///
/// **Now a `ChangeNotifier`, provided via [workspaceTabsControllerProvider]**
/// — AP-OEP-WORKSPACE-UX-001's own Phase 3 requires the sidebar (a
/// sibling of `EngineeringWorkspacePage` in the widget tree, not an
/// ancestor/descendant of it) to read and mutate the *same* tab state
/// the workspace page renders, so a page-local field (this class's
/// previous AP-OEP-WORKSPACE-SHELL-001 shape) can no longer be the sole
/// instance — it must be reachable from both. This is still "the sole
/// workspace tab-state authority" (unchanged): there is exactly one
/// provider, one instance, no second controller anywhere.
///
/// **Multi-instance (AP-OEP-WORKSPACE-MULTI-INSTANCE-001)**: [openSurface]
/// keeps its original, unchanged contract — exactly one tab per
/// `surfaceId`, open-or-focus — for every Surface, singleton or not.
/// [openNewInstance] is the one new, additive operation: it always
/// creates a fresh [WorkspaceTab] with a freshly-generated, independent
/// `id`, never deduping by `surfaceId`. Nothing here hardcodes which
/// Surfaces are multi-instance (no `if (surfaceId == 'diagram')`
/// anywhere) — that policy lives on `SurfaceDefinition.allowsMultipleInstances`
/// and is a *caller's* decision (which method to call), not this
/// controller's.
///
/// **Persistence** (AP-OEP-WORKSPACE-PERSISTENCE-001, extended by
/// AP-OEP-WORKSPACE-MULTI-INSTANCE-001): plain Dart, no Engine/
/// Foundation knowledge — [WorkspaceTabsStorage] is the only thing this
/// class talks to, and it only ever exchanges `{id, surfaceId}` tab
/// records with it (previously bare surfaceId strings; see
/// [WorkspaceTabsStorage]'s own doc comment for the backward-compatible
/// schema migration). Restoration is validated against [SurfaceRegistry]
/// (plus the one reserved Diagram sentinel, [WorkspaceTab.diagramSurfaceId])
/// — the existing, sole canonical Surface source; no second Surface list
/// is introduced.
class WorkspaceTabsController extends ChangeNotifier {
  WorkspaceTabsController({WorkspaceTabsStorage storage = const WorkspaceTabsStorage()}) : _storage = storage;

  final WorkspaceTabsStorage _storage;
  final List<WorkspaceTab> _tabs = [];
  String? _activeId;

  /// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — the *entire* split-view state:
  /// which second [WorkspaceTab.id] (if any) is shown alongside
  /// [activeId]. `null` means single-tab mode. Deliberately not a
  /// `{enabled, primaryTabId, ...}` struct (see the approved audit's
  /// Part 3) — `activeId` already is the primary/left pane, and
  /// "enabled" is fully redundant with this field being non-null.
  String? _secondTabId;

  bool _restored = false;
  List<String>? _lastPersistedTabKeys;
  String? _lastPersistedActiveId;
  String? _lastPersistedSecondTabId;
  bool _lastPersistedSentinel = false;

  /// Monotonic, in-process counter backing [openNewInstance]'s id
  /// generation — see that method's own doc comment for why a counter
  /// was chosen over a timestamp.
  int _instanceSeq = 0;

  static final RegExp _instanceIdSuffix = RegExp(r'-instance-(\d+)$');

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

  /// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — the second (right) pane's tab id,
  /// or `null` if the Workspace is in ordinary single-tab mode.
  String? get secondTabId => _secondTabId;
  WorkspaceTab? get second => _secondTabId == null ? null : _tabs.where((t) => t.id == _secondTabId).firstOrNull;

  /// Shows [tabId] alongside [activeId] in a split view. A no-op if
  /// [tabId] does not name a currently-open tab (never fabricates one),
  /// or if it is already [secondTabId] — matching every other mutator's
  /// existing "changing nothing is not a change" convention
  /// (§ [activate]/[openSurface]'s own no-op guards). Explicitly permits
  /// [tabId] to equal [activeId] — the approved audit found no evidence
  /// that showing the same tab in both panes should be prohibited, and
  /// nothing here needs a second identity to represent it (both panes
  /// simply resolve the same [WorkspaceTab.id] to two independent
  /// widget instances, exactly as `_buildTabContent` already does for
  /// any tab).
  void splitWith(String tabId) {
    if (tabId == _secondTabId) return;
    if (!_tabs.any((t) => t.id == tabId)) return;
    _secondTabId = tabId;
    notifyListeners();
    _persistIfChanged();
  }

  /// Collapses back to single-tab mode. A no-op if not currently split.
  void closeSplit() {
    if (_secondTabId == null) return;
    _secondTabId = null;
    notifyListeners();
    _persistIfChanged();
  }

  /// Opens [surfaceId] as a new tab, or focuses it if already open —
  /// the same reuse-if-open semantics `WebSurfacesHostPage._openLegacyV2`
  /// / `_openNativeTab` already use, not a new policy invented here.
  /// This is also AP-OEP-WORKSPACE-UX-001's Phase 4 duplicate-tab
  /// policy in full: exactly one tab per Surface id, always — unchanged
  /// by AP-OEP-WORKSPACE-MULTI-INSTANCE-001, including for Surfaces that
  /// declare `allowsMultipleInstances: true` (a caller wanting a
  /// *second* instance of one of those must call [openNewInstance]
  /// instead; this method's contract does not change). Returns the id
  /// of the (possibly pre-existing) tab.
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
    // generated one: reuse-if-open already means at most one
    // `openSurface`-created tab per `surfaceId` can ever exist, so this
    // remains a stable, predictable id (also what a legacy-format
    // restore synthesizes, § `WorkspaceTabsStorage`'s own doc comment)
    // — [openNewInstance] below is the one path that needs a genuinely
    // generated id, since it deliberately does not have this
    // one-per-surfaceId guarantee to lean on.
    final tab = WorkspaceTab(id: 'workspace-tab-$surfaceId', surfaceId: surfaceId);
    _tabs.add(tab);
    _activeId = tab.id;
    notifyListeners();
    _persistIfChanged();
    return tab.id;
  }

  /// AP-OEP-WORKSPACE-MULTI-INSTANCE-001 — always creates a genuinely
  /// new [WorkspaceTab] for [surfaceId], never reusing an existing one,
  /// for Surfaces that declare `SurfaceDefinition.allowsMultipleInstances`.
  /// This controller does not itself check that flag (see class doc
  /// comment) — it trusts the caller, exactly the way [openSurface] has
  /// always trusted callers to pass a real `surfaceId`. The new tab is
  /// appended (preserving append-order, § existing `openSurface`
  /// behavior) and activated. Returns the new tab's id.
  String openNewInstance(String surfaceId) {
    final tab = WorkspaceTab(id: _nextInstanceId(surfaceId), surfaceId: surfaceId);
    _tabs.add(tab);
    _activeId = tab.id;
    notifyListeners();
    _persistIfChanged();
    return tab.id;
  }

  /// The identity decision for multi-instance tabs: `surfaceId` plus a
  /// monotonic, in-process sequence number, e.g.
  /// `'workspace-tab-diagram-instance-0'`, `'...-instance-1'`. A plain
  /// timestamp (`DateTime.now().microsecondsSinceEpoch`) was considered
  /// and rejected — this exact pattern already caused a real,
  /// documented bug elsewhere in this codebase (two calls issued in the
  /// same microsecond can collide) — and no id-generator package is a
  /// dependency of this project, so a counter is the smallest
  /// dependency-free mechanism that is unconditionally collision-free
  /// within one controller's lifetime. [restore] seeds [_instanceSeq]
  /// past the highest suffix found among restored ids so a freshly
  /// launched session never re-mints an id a previous session already
  /// persisted (see [_seedInstanceSeqFromRestoredTabs]).
  String _nextInstanceId(String surfaceId) => 'workspace-tab-$surfaceId-instance-${_instanceSeq++}';

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
  /// `DiagramTabsNotifier.closeTab` already use. Operates purely on
  /// `id`, exactly as before — closing one instance of a multi-instance
  /// Surface never affects any other tab, including another instance of
  /// the same `surfaceId`, since nothing here ever matches by `surfaceId`.
  ///
  /// AP-OEP-WORKSPACE-SPLIT-VIEW-001 — [secondTabId] is kept consistent
  /// with whatever remains open: closing the tab it names collapses the
  /// split (never leaves a dangling reference to a closed tab); closing
  /// any other tab, including [activeId], leaves it untouched. The one
  /// extra case: if closing [activeId] causes the neighbor-selection
  /// fallback to land on the very tab [secondTabId] already names, the
  /// split is collapsed rather than silently showing that tab in both
  /// panes as an accident of which neighbor happened to be next in line
  /// — a real, explicit `splitWith(activeId)` call still allows this
  /// (§ that method's own doc comment); only this *unintended* collision
  /// is resolved here.
  void close(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final wasActive = _activeId == id;
    _tabs.removeAt(index);
    if (id == _secondTabId) _secondTabId = null;
    if (wasActive) {
      _activeId = _tabs.isEmpty ? null : _tabs[index > 0 ? index - 1 : 0].id;
      if (_secondTabId != null && _secondTabId == _activeId) _secondTabId = null;
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
  /// Every stored tab's `surfaceId` is validated against
  /// [SurfaceRegistry] (or the reserved [WorkspaceTab.diagramSurfaceId]
  /// sentinel) before being restored — a stale/unknown id (e.g. from an
  /// older build whose Surface list has since changed) is silently
  /// dropped, never fabricated into a placeholder tab. Order is
  /// preserved among the surviving tabs.
  ///
  /// AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001 — a record persisted by a
  /// build that still had the removed `'diagram-2'` sentinel (the
  /// transitional "Diagram Studio (2)" Compare-engine tab) is migrated
  /// in place to an ordinary Diagram tab (§ [_migrateLegacyDiagram2]),
  /// never dropped: the user had a second Diagram-labeled tab open, and
  /// this preserves "a second Diagram tab was open" continuity even
  /// though that tab's *content* is necessarily different now (a real,
  /// independent Diagram document instead of the shared Compare engine —
  /// there is no lossless mapping from the old content to the new
  /// architecture, only from the fact that a tab existed).
  /// Duplicate tab *ids* in the persisted file are dropped (a
  /// corruption case, not a legitimate multi-instance one — two
  /// legitimate instances always have different ids by construction);
  /// duplicate `surfaceId`s across different tab ids are perfectly
  /// legitimate now and are never deduped. The stored active id is
  /// restored only if it names one of the surviving tabs; otherwise the
  /// first surviving tab becomes active (a deterministic fallback), or
  /// none if nothing survived.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final loaded = await _storage.load();
    final validTabs = <PersistedWorkspaceTab>[];
    final seenIds = <String>{};
    for (final record in loaded.tabs) {
      if (!seenIds.add(record.id)) continue; // corrupt duplicate id, never legitimate
      final migrated = _migrateLegacyDiagram2(record);
      if (_isKnownSurfaceId(migrated.surfaceId)) validTabs.add(migrated);
    }

    // Defensive against the (unlikely) race of a real `openSurface`/
    // `openNewInstance`/sidebar click landing between provider creation
    // and this async load resolving: never add a tab id that's already
    // open by the time restoration actually runs.
    for (final record in validTabs) {
      if (_tabs.any((t) => t.id == record.id)) continue;
      _tabs.add(WorkspaceTab(id: record.id, surfaceId: record.surfaceId));
    }
    _seedInstanceSeqFromRestoredTabs();

    // Same race guard as above: if something already activated a tab
    // for real before this load resolved, that real choice wins — this
    // only ever sets the active tab from a clean slate.
    if (_activeId == null) {
      final restoredActiveId = (loaded.activeId != null && validTabs.any((r) => r.id == loaded.activeId))
          ? loaded.activeId
          : (_tabs.isEmpty ? null : _tabs.first.id);
      _activeId = restoredActiveId;
    }

    // AP-OEP-WORKSPACE-SPLIT-VIEW-001 — restored only if it still names
    // one of the tabs that actually survived restoration; an invalid or
    // stale id (e.g. the file named a tab that was itself dropped as
    // unknown/corrupt above) falls back to "no split" rather than
    // fabricating or reassigning it to an unrelated tab. Same race
    // guard as `activeId` above: a real `splitWith`/`closeSplit` call
    // landing before this resolves wins over the persisted value.
    _secondTabId ??= (loaded.secondTabId != null && _tabs.any((t) => t.id == loaded.secondTabId)) ? loaded.secondTabId : null;

    // Only re-persist if restoration actually changed the effective
    // state (dropped stale/corrupt entries, or fell back to a different
    // active id) — an already-clean file is left untouched, per this
    // package's own "avoid unnecessary writes" requirement.
    final effectiveTabs = [for (final tab in _tabs) (id: tab.id, surfaceId: tab.surfaceId)];
    final changed =
        !listEquals(_tabKeys(loaded.tabs), _tabKeys(effectiveTabs)) || loaded.activeId != active?.id || loaded.secondTabId != _secondTabId;

    notifyListeners();
    if (changed) {
      await _persist();
    } else {
      _rememberLastPersisted(_tabKeys(effectiveTabs), active?.id, _secondTabId);
    }
  }

  /// Advances [_instanceSeq] past the highest `-instance-<n>` suffix
  /// found among the tabs just restored, regardless of which
  /// `surfaceId` it belongs to (one shared counter is simpler than a
  /// per-surfaceId one and is just as collision-free, since the
  /// `surfaceId` is already part of the generated id string) — so a
  /// freshly restored session's first [openNewInstance] call can never
  /// mint an id that collides with one this file already persisted.
  void _seedInstanceSeqFromRestoredTabs() {
    var highest = -1;
    for (final tab in _tabs) {
      final match = _instanceIdSuffix.firstMatch(tab.id);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > highest) highest = n;
    }
    if (highest + 1 > _instanceSeq) _instanceSeq = highest + 1;
  }

  /// The removed `'diagram-2'` sentinel's literal value, kept only as a
  /// migration target for [_migrateLegacyDiagram2] — not re-exposed on
  /// [WorkspaceTab] (the mechanism itself is gone, per
  /// AP-OEP-DIAGRAM-MULTI-INSTANCE-UI-001), just remembered here long
  /// enough to recognize a record an older build persisted.
  static const String _legacyDiagram2SurfaceId = 'diagram-2';

  /// Rewrites a persisted `'diagram-2'` record into an ordinary Diagram
  /// tab (`surfaceId: WorkspaceTab.diagramSurfaceId`, same `id`) — see
  /// [restore]'s own doc comment for why the `id` is kept as-is rather
  /// than re-minted through [_nextInstanceId]: it is already a stable,
  /// unique string that never collides with a future `-instance-<n>` id
  /// (§ [_instanceIdSuffix]), so reusing it needs no interaction with
  /// [_instanceSeq]/seeding at all. Every other record passes through
  /// unchanged.
  PersistedWorkspaceTab _migrateLegacyDiagram2(PersistedWorkspaceTab record) =>
      record.surfaceId == _legacyDiagram2SurfaceId ? (id: record.id, surfaceId: WorkspaceTab.diagramSurfaceId) : record;

  bool _isKnownSurfaceId(String surfaceId) => surfaceId == WorkspaceTab.diagramSurfaceId || SurfaceRegistry.forId(surfaceId) != null;

  List<String> _tabKeys(List<PersistedWorkspaceTab> tabs) => [for (final t in tabs) '${t.id} ${t.surfaceId}'];

  void _rememberLastPersisted(List<String> tabKeys, String? activeId, String? secondTabId) {
    _lastPersistedTabKeys = List.of(tabKeys);
    _lastPersistedActiveId = activeId;
    _lastPersistedSecondTabId = secondTabId;
    _lastPersistedSentinel = true;
  }

  void _persistIfChanged() {
    final tabs = [for (final tab in _tabs) (id: tab.id, surfaceId: tab.surfaceId)];
    final tabKeys = _tabKeys(tabs);
    if (_lastPersistedSentinel &&
        listEquals(_lastPersistedTabKeys, tabKeys) &&
        _lastPersistedActiveId == _activeId &&
        _lastPersistedSecondTabId == _secondTabId) {
      return;
    }
    _rememberLastPersisted(tabKeys, _activeId, _secondTabId);
    _enqueueSave(tabs, _activeId, _secondTabId);
  }

  Future<void> _persist() async {
    final tabs = [for (final tab in _tabs) (id: tab.id, surfaceId: tab.surfaceId)];
    _rememberLastPersisted(_tabKeys(tabs), _activeId, _secondTabId);
    await _enqueueSave(tabs, _activeId, _secondTabId);
  }

  Future<void> _enqueueSave(List<PersistedWorkspaceTab> tabs, String? activeId, String? secondTabId) {
    final next = _writeChain.then((_) => _storage.save(tabs: tabs, activeId: activeId, secondTabId: secondTabId));
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
