import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Real browser-style Back/Forward history over the app's actual
/// navigation (ODS-S004 Navigation Standard § 5 "Back / Forward
/// History", § 8 "History: Back, Forward"). Every route change in this
/// app already goes through `context.go(path)` (`WorkbenchSidebar`,
/// `StudioMenuBar`, the future Breadcrumb Bar); `GoRouter` itself is a
/// [Listenable] that fires on every one of those changes regardless of
/// call site, so this service attaches once to [appRouter] rather than
/// requiring every navigation call site to also report itself — there
/// is exactly one navigation system, this only observes it.
///
/// `go_router`'s own `.go()` calls are location *replacements*, not a
/// push-based stack (that's `.push()`, unused anywhere in this app —
/// see WP-STUDIO-021's routing table, one `ShellRoute` with flat
/// destinations), so `GoRouter` itself keeps no back/forward history of
/// its own to delegate to. This is the "minimum clean implementation"
/// for Phase 2: a plain visited-locations list with a cursor, the same
/// shape as a browser's own history stack.
class NavigationHistoryState {
  const NavigationHistoryState({required this.locations, required this.index});

  const NavigationHistoryState.initial() : locations = const [], index = -1;

  /// Visited locations in order, oldest first. Forward entries (beyond
  /// [index]) are kept until the next *new* (non back/forward)
  /// navigation truncates them — standard browser semantics.
  final List<String> locations;

  /// Index of the current location within [locations]; `-1` before the
  /// first navigation is observed.
  final int index;

  bool get canGoBack => index > 0;
  bool get canGoForward => index >= 0 && index < locations.length - 1;

  String? get current => index >= 0 && index < locations.length ? locations[index] : null;
}

class NavigationHistoryNotifier extends Notifier<NavigationHistoryState> {
  GoRouter? _router;
  bool _navigatingProgrammatically = false;

  @override
  NavigationHistoryState build() {
    final router = appRouter;
    _router = router;
    router.routerDelegate.addListener(_onRouteChanged);
    ref.onDispose(() => router.routerDelegate.removeListener(_onRouteChanged));
    final initialLocation = router.routerDelegate.currentConfiguration.uri.path;
    return NavigationHistoryState(locations: [initialLocation], index: 0);
  }

  void _onRouteChanged() {
    final router = _router;
    if (router == null) return;
    final location = router.routerDelegate.currentConfiguration.uri.path;

    if (_navigatingProgrammatically) {
      // A `goBack`/`goForward` call already moved `index` to point at
      // this exact location — nothing further to record.
      _navigatingProgrammatically = false;
      return;
    }

    if (location == state.current) return;

    final truncated = state.index >= 0 ? state.locations.sublist(0, state.index + 1) : <String>[];
    state = NavigationHistoryState(locations: [...truncated, location], index: truncated.length);
  }

  void goBack(BuildContext context) {
    if (!state.canGoBack) return;
    final newIndex = state.index - 1;
    _navigatingProgrammatically = true;
    state = NavigationHistoryState(locations: state.locations, index: newIndex);
    context.go(state.locations[newIndex]);
  }

  void goForward(BuildContext context) {
    if (!state.canGoForward) return;
    final newIndex = state.index + 1;
    _navigatingProgrammatically = true;
    state = NavigationHistoryState(locations: state.locations, index: newIndex);
    context.go(state.locations[newIndex]);
  }
}

final navigationHistoryProvider = NotifierProvider<NavigationHistoryNotifier, NavigationHistoryState>(
  NavigationHistoryNotifier.new,
);
