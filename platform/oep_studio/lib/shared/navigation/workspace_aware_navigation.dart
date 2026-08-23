import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/studio_destination.dart';
import '../../workspace/workspace_tab.dart';
import '../../workspace/workspace_tabs_controller.dart';

/// AP-OEP-WORKSPACE-CONTEXT-001/002 — the one workspace-aware navigation
/// primitive every cross-Surface navigation function in
/// `unified_navigation.dart`/`explorer_navigation.dart` now goes through
/// for its final "switch to the destination Studio" step.
///
/// Lives in its own file (not inside either navigation file) because
/// `unified_navigation.dart` already imports `explorer_navigation.dart`
/// — putting this helper in either would risk a circular import once
/// both need it.
///
/// Whatever selection/state mutation happens before calling this
/// (already each function's own existing, authoritative mechanism — an
/// `EngineeringObjectRuntime` lookup, `engine.registry.selection`, a
/// runtime notifier's `select*` call) is untouched; this only decides
/// *how* the destination becomes visible. Reuses [WorkspaceTabsController]
/// (the sole existing tab authority) — no second tab controller, no
/// second Surface registry, no global context object. Outside the
/// Workspace this is byte-for-byte the original
/// `context.go(destination.path)` every one of these functions used
/// before AP-OEP-WORKSPACE-CONTEXT-001.
void openOrActivateDestination(BuildContext context, WidgetRef ref, StudioDestination destination) {
  final onWorkspace = StudioDestination.fromPath(GoRouterState.of(context).uri.path) == StudioDestination.workspace;
  if (onWorkspace) {
    // Diagram has no `SurfaceRegistry` entry of its own (self-reference
    // avoidance, `surface_registry.dart`'s own doc comment) — it uses the
    // one reserved sentinel surfaceId every other package in this series
    // already established. Every other destination's surfaceId is just
    // its own `StudioDestination.name`, exactly as `SurfaceRegistry._build`
    // constructs it.
    final surfaceId = destination == StudioDestination.diagram ? WorkspaceTab.diagramSurfaceId : destination.name;
    ref.read(workspaceTabsControllerProvider).openSurface(surfaceId);
  } else {
    context.go(destination.path);
  }
}
