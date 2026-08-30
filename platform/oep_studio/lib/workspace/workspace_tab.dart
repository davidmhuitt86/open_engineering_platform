import 'package:flutter/material.dart';

import '../core/routing/studio_destination.dart';
import '../core/surfaces/surface_definition.dart';
import '../core/surfaces/surface_registry.dart';

/// AP-OEP-WORKSPACE-SHELL-001 — the minimum tab model for the new
/// OEP-wide workspace shell (`EngineeringWorkspacePage`). Deliberately
/// UI/session state only: a tab holds an `id` and a `surfaceId`,
/// nothing else. `title`/`icon` are **not** stored fields — they are
/// computed getters that resolve live through `SurfaceRegistry`, so
/// there is no second copy of a label/icon anywhere (the exact
/// duplication this task's own Phase 4 explicitly forbids). Engineering
/// data is never held here — it lives in the Engine/
/// `EngineeringProjectService`, exactly as it already does for every
/// existing tab system (`WebSurface`, `_NativeTab`, `DiagramTab`).
///
/// AP-OEP-WORKSPACE-MULTI-INSTANCE-001 — [id] and [surfaceId] are two
/// genuinely independent identities, not a 1:1 pair: [surfaceId] names
/// the Surface *type* (`SurfaceDefinition`/reserved sentinel), while
/// [id] names *this specific tab instance*. Two [WorkspaceTab]s may
/// legitimately share one [surfaceId] (e.g. two Diagram tabs, in a
/// later package) as long as their [id]s differ — nothing in this class
/// assumes or requires [id] to be derived from [surfaceId]; that was
/// only ever an implementation detail of how
/// `WorkspaceTabsController` happened to generate ids for the
/// (previously always-singleton) case, not a rule this class enforces.
///
/// [surfaceId] is a `StudioDestination.name` for every current native
/// Surface, or the reserved value [WorkspaceTab.diagramSurfaceId] for
/// the one special case `SurfaceRegistry` deliberately excludes
/// (Diagram Studio — § `SurfaceRegistry`'s own doc comment, unchanged by
/// this package). This mirrors, rather than reinvents, the same
/// documented exception `WorkbenchSidebar`'s STUDIOS section and
/// `WebSurfacesHostPage`'s own "+" menu both already carry.
class WorkspaceTab {
  WorkspaceTab({required this.id, required this.surfaceId});

  /// Reserved [surfaceId] for the Diagram Studio tab — not a real
  /// `SurfaceDefinition` id (none exists for Diagram, by design), just a
  /// stable sentinel this shell's own content-builder switches on.
  static const String diagramSurfaceId = 'diagram';

  /// AP-OEP-DIAGRAM-COMPARE-002 — reserved [surfaceId] for a second,
  /// fully independent diagram tab, backed by the same
  /// `compareDiagramControllerProvider`/`CompareDiagramController`
  /// engine the split-pane "Compare Diagrams" pane already uses (§
  /// `CompareLegacyV2WebViewPage`'s own doc comment) — this just gives
  /// that same second engine its own full-width tab, in addition to the
  /// split view, rather than a third independent document. Reuses
  /// [WorkspaceTabsController.openSurface]'s existing generic
  /// one-tab-per-surfaceId dedup/persistence, exactly like
  /// [diagramSurfaceId] — no controller changes needed.
  static const String diagram2SurfaceId = 'diagram-2';

  final String id;
  final String surfaceId;

  bool get isDiagram => surfaceId == diagramSurfaceId;

  bool get isDiagram2 => surfaceId == diagram2SurfaceId;

  /// `null` only if [surfaceId] refers to a Surface that has since been
  /// removed from the registry — not expected in practice (Surfaces are
  /// a static, compile-time list today), but callers should not assume
  /// non-null blindly.
  SurfaceDefinition? get _surface => (isDiagram || isDiagram2) ? null : SurfaceRegistry.forId(surfaceId);

  String get title =>
      isDiagram ? StudioDestination.diagram.label : isDiagram2 ? 'Diagram Studio (2)' : (_surface?.title ?? surfaceId);

  IconData get icon => (isDiagram || isDiagram2) ? StudioDestination.diagram.icon : (_surface?.icon ?? Icons.help_outline);
}
