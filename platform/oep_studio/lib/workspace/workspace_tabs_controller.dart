import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspace_tab.dart';

/// AP-OEP-WORKSPACE-SHELL-001/AP-OEP-WORKSPACE-UX-001 — the smallest
/// controller for the new OEP-wide workspace shell: open/activate/close,
/// nothing else. The exact same shape `WebSurfaceTabsController` already
/// established for Diagram Studio's own tab strip, generalized one
/// level up. No persistence, no pin, no duplicate, no recently-closed,
/// no reorder — none of those exist in the current infrastructure this
/// generalizes from without real additional architectural work, so none
/// are added here.
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
class WorkspaceTabsController extends ChangeNotifier {
  final List<WorkspaceTab> _tabs = [];
  String? _activeId;

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
      _activeId = existing.id;
      notifyListeners();
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
    return tab.id;
  }

  void activate(String id) {
    if (_tabs.any((t) => t.id == id)) {
      _activeId = id;
      notifyListeners();
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
  }
}

/// One shared instance for the whole app's lifetime — read by
/// [EngineeringWorkspacePage] to render tabs, and by `WorkbenchSidebar`'s
/// host (`StudioShell`, which passes a callback down — `WorkbenchSidebar`
/// itself never reads this provider directly, § its own doc comment on
/// why) to open/activate a Surface as a workspace tab from a sidebar
/// click, per AP-OEP-WORKSPACE-UX-001's Phase 3.
final workspaceTabsControllerProvider = ChangeNotifierProvider<WorkspaceTabsController>(
  (ref) => WorkspaceTabsController(),
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
