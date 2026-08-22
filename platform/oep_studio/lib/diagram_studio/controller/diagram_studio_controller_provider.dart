import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagram_studio_controller.dart';

/// The provider-hosted lifetime for [DiagramStudioController] (WAVE 2
/// Stage A, AP-DIAGRAM-W2-A — see
/// `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` entry 3, and §29 item 1
/// for the hazard this closes).
///
/// **Scope, and why:** app-wide, matching `engineeringProjectServiceProvider`
/// (`core/services/engineering_project_service.dart`) — the same Engine
/// instance this controller wraps already outlives `DiagramStudioPage`'s
/// own mount/unmount (WORK_PACKAGE_025), so a controller that is
/// recreated on every mount was already a lifetime mismatch with the
/// thing it wraps. There is exactly one Diagram Studio workspace and
/// exactly one shared Engine per app session — a narrower (route- or
/// tab-scoped) provider would only reintroduce the mismatch this Wave
/// closes, and a broader one is not needed because nothing outside
/// Diagram Studio's own widget tree reads this provider today.
///
/// **`build()` is the single production construction path.** It runs
/// [DiagramStudioController.bootstrap] — the full, unchanged engine/tab/
/// document bootstrap sequence — exactly once per app session (Riverpod
/// only re-invokes a `Notifier.build()` when the provider itself is
/// rebuilt/invalidated, never merely because a consuming widget rebuilds
/// or remounts). `DiagramStudioPage` must never call
/// `DiagramStudioController.bootstrap` or the `DiagramStudioController(...)`
/// constructor itself — it awaits [diagramStudioControllerProvider] and
/// receives the same cached instance on every mount, including a revisit
/// after navigating away. This is what makes the `isFirstStart` guard
/// inside `bootstrap` unconditionally safe now: that guard only needed to
/// distinguish "first ever start" from "revisit" because bootstrap used
/// to run on every mount. Now bootstrap runs once, full stop, so the
/// guard can never observe a revisit at all.
///
/// **What this provider does not own.** The loaded `DiagramWorkspaceState`
/// returned by `bootstrap` (panel visibility/width UI fields) is
/// deliberately discarded here, not cached — those fields stay
/// `DiagramStudioPage` `State` fields (Wave 2 Stage A does not migrate
/// them; see the Stage A brief and composition boundary entries 27–29),
/// and the page re-reads `WorkspaceStateStorage.load()` itself on every
/// mount so a revisit still re-applies whatever was last persisted,
/// exactly as it did before this change. The one-time redundant load
/// this causes on the very first mount (once inside `bootstrap`, once by
/// the page) is a deliberate, low-cost trade-off against a larger change
/// to `bootstrap`'s signature.
class DiagramStudioControllerNotifier extends AsyncNotifier<DiagramStudioController> {
  @override
  Future<DiagramStudioController> build() async {
    final (controller, _) = await DiagramStudioController.bootstrap(ref: ref);
    return controller;
  }
}

final diagramStudioControllerProvider = AsyncNotifierProvider<DiagramStudioControllerNotifier, DiagramStudioController>(
  DiagramStudioControllerNotifier.new,
);
