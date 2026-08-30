import 'package:go_router/go_router.dart';

import '../../app/studio_shell.dart';
import 'studio_destination.dart';
import 'studio_registry.dart';

/// Studio's route table (SDD-003 Navigation Framework).
///
/// One route per navigation destination, all rendered inside the single
/// persistent [StudioShell] — Studio never routes to a floating window.
/// The route list itself is built by [StudioRegistry.buildRoutes]
/// (WP-STUDIO-021) rather than hand-listed here — this file now only
/// owns the one thing that isn't per-destination: the [ShellRoute]
/// wrapper every destination renders inside.
final appRouter = GoRouter(
  // AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — the tabbed Workspace is now the
  // app's entire UI (see `StudioShell`'s own doc comment), so the app
  // boots directly into it rather than Dashboard. `/diagram` remains
  // unsuitable as a default for the same reason noted historically here
  // (its real Legacy V2 WebView2 surface can't initialize under
  // `flutter test`'s headless environment) — moot now anyway, since
  // Workspace's own Diagram tab (`DiagramWithComparePane`), not the
  // standalone `/diagram` route, is how Diagram content is normally
  // reached.
  initialLocation: StudioDestination.workspace.path,
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final selected = StudioDestination.fromPath(state.uri.path);
        return StudioShell(
          selected: selected,
          onSelect: (destination) => context.go(destination.path),
          child: child,
        );
      },
      routes: StudioRegistry.defaultRegistry.buildRoutes(),
    ),
  ],
);
