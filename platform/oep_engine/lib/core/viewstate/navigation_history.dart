import 'viewport_math.dart';

/// Back/forward stack of prior viewport snapshots (WORK_PACKAGE_022,
/// ENGINE-TASK-000095: "Navigation History"). Lives alongside
/// `ViewStateService` — not part of the undo/redo command system (viewport
/// state is never an engineering edit).
class NavigationHistory {
  final int maxDepth;
  final List<ViewportTarget> _back = [];
  final List<ViewportTarget> _forward = [];

  NavigationHistory({this.maxDepth = 50});

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;

  /// Records [current] as a step to return to before navigating away from it.
  void push(ViewportTarget current) {
    _back.add(current);
    if (_back.length > maxDepth) _back.removeAt(0);
    _forward.clear();
  }

  /// Pops the previous viewport, pushing [current] onto the forward stack.
  ViewportTarget? goBack(ViewportTarget current) {
    if (_back.isEmpty) return null;
    final previous = _back.removeLast();
    _forward.add(current);
    return previous;
  }

  /// Pops the next viewport, pushing [current] back onto the back stack.
  ViewportTarget? goForward(ViewportTarget current) {
    if (_forward.isEmpty) return null;
    final next = _forward.removeLast();
    _back.add(current);
    return next;
  }

  void clear() {
    _back.clear();
    _forward.clear();
  }
}
