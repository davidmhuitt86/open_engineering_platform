import 'web_surface.dart';

/// AP-STUDIO-WEB-SURFACE-001 — pure tab-list state for the Web Surface
/// host (Phase 5/10): add/activate/close, nothing else. Deliberately
/// plain Dart, no Riverpod/Flutter dependency — same
/// "state class separate from the widget that renders it" shape as
/// `DiagramTabsController`'s own `DiagramTabsState`, but smaller (no
/// pinning/recently-closed list). Persistence (`WebSurfaceTabsStorage`)
/// is owned by `WebSurfacesHostPage`'s own `State`, not this class —
/// mirrors `DiagramTabsController` calling `DiagramTabsStorage` from the
/// notifier, not from `DiagramTabsState` itself.
///
/// **Does not itself own a `WebviewController`** — this is list/
/// selection bookkeeping only, exactly like `DiagramTabsState` doesn't
/// own an `EditingSession`. [WebSurfaceHostState] (the widget's own
/// `State`) is what actually keeps each tab's WebView alive.
class WebSurfaceTabsController {
  WebSurfaceTabsController({List<WebSurface>? initialSurfaces}) : _surfaces = List.of(initialSurfaces ?? const []) {
    if (_surfaces.isNotEmpty) _activeId = _surfaces.first.id;
  }

  final List<WebSurface> _surfaces;
  String? _activeId;

  List<WebSurface> get surfaces => List.unmodifiable(_surfaces);
  String? get activeId => _activeId;
  WebSurface? get active => _activeId == null ? null : _surfaces.where((s) => s.id == _activeId).firstOrNull;

  void add(WebSurface surface, {bool activate = true}) {
    _surfaces.add(surface);
    if (activate) _activeId = surface.id;
  }

  void activate(String id) {
    if (_surfaces.any((s) => s.id == id)) _activeId = id;
  }

  /// Removes [id]. If it was active, activates the tab immediately before
  /// it in the list (or the new last tab, or none) — same "activate a
  /// neighbor" behavior `DiagramTabsNotifier.closeTab` already uses.
  void close(String id) {
    final index = _surfaces.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final wasActive = _activeId == id;
    _surfaces.removeAt(index);
    if (!wasActive) return;
    if (_surfaces.isEmpty) {
      _activeId = null;
    } else {
      _activeId = _surfaces[index > 0 ? index - 1 : 0].id;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
