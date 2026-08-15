import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/studio_colors.dart';
import 'perspective/perspective.dart';
import 'perspective/perspective_manager.dart';
import 'layout/workbench_layout_manager.dart';
import 'widgets/workbench_sidebar.dart';
import 'widgets/workbench_status_bar.dart';

/// WP-DS-006 Engineering Workbench — the application shell.
///
/// Implements the governing spec's Window Structure exactly:
///
/// ```
/// Workbench
///  ├── Menu                  (reuses StudioShell's existing AppBar/menu —
///  │                           see class doc below for why this page does
///  │                           not duplicate it)
///  ├── Perspective Selector   (WorkbenchSidebar — a left sidebar, not a
///  │                           top row; superseded the original
///  │                           horizontal PerspectiveSelector design)
///  ├── Global Toolbar         (the active Perspective's toolbarProvider)
///  ├── Left Dock              (the active Perspective's leftPanelProvider)
///  ├── Center Workspace       (the active Perspective's centerBuilder)
///  ├── Right Dock             (the active Perspective's rightPanelProvider)
///  ├── Bottom Dock            (the active Perspective's bottomPanelProvider)
///  └── Status Bar             (WorkbenchStatusBar)
/// ```
///
/// **"Menu" and "Global Toolbar"**: `StudioShell` (the app-wide shell this
/// page is hosted inside, per this Work Package's own scope decision — see
/// `docs/architecture/diagram_studio/ENGINEERING_WORKBENCH.md`) already
/// owns one `AppBar`/menu and one global toolbar for the whole app
/// (`StudioToolbar`). This page does not duplicate that chrome — its own
/// "Global Toolbar" region is the active Perspective's own
/// [Perspective.toolbarProvider], rendered as a second, Workbench-scoped
/// toolbar strip directly below `StudioShell`'s app-wide one, exactly the
/// way `DiagramStudioPage`'s own toolbar already coexists with
/// `StudioShell`'s.
///
/// **No perspective switch statements** (the governing spec's own explicit
/// constraint): every region below reads [PerspectiveManager.active] and
/// calls whatever provider that [Perspective] supplies — adding an
/// eleventh Perspective requires no edit to this file.
class EngineeringWorkbenchPage extends StatefulWidget {
  const EngineeringWorkbenchPage({
    super.key,
    required this.perspectives,
    PerspectiveManager? perspectiveManager,
    WorkbenchLayoutManager? layoutManager,
    this.showSidebar = true,
  })  : _perspectiveManager = perspectiveManager,
        _layoutManager = layoutManager;

  /// The fixed list of Perspectives this Workbench instance registers —
  /// normally `workbenchPerspectives` from `perspectives/`. Injectable so
  /// tests can register a small fixture set instead.
  final List<Perspective> perspectives;

  /// False when a caller already renders its own `WorkbenchSidebar` one
  /// level up and sharing [PerspectiveManager.instance] with it (as
  /// `StudioShell` now does, per its own doc comment) — avoids mounting
  /// this Perspective-switching sidebar a second time, side-by-side with
  /// itself. Defaults to `true` so every existing caller/test keeps
  /// exactly the behavior it already had.
  final bool showSidebar;

  final PerspectiveManager? _perspectiveManager;
  final WorkbenchLayoutManager? _layoutManager;

  @override
  State<EngineeringWorkbenchPage> createState() => _EngineeringWorkbenchPageState();
}

class _EngineeringWorkbenchPageState extends State<EngineeringWorkbenchPage> {
  late final PerspectiveManager _perspectives = widget._perspectiveManager ?? PerspectiveManager();
  late final WorkbenchLayoutManager _layouts = widget._layoutManager ?? WorkbenchLayoutManager();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_perspectives.perspectives.isEmpty) {
      // `_perspectives` may now be the shared `PerspectiveManager.instance`
      // that `WorkbenchSidebar` (hoisted into `StudioShell`) already
      // listens to. Calling `registerAll` -- which notifies listeners --
      // synchronously here, inside `initState`, can fire while that
      // sidebar's own `AnimatedBuilder` is still partway through building
      // this very frame (this page mounts as a route change caused by a
      // tap inside that sidebar), which throws
      // "setState() called during build". Deferring one frame lets the
      // framework finish the current build pass first.
      final registered = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_perspectives.perspectives.isEmpty) _perspectives.registerAll(widget.perspectives);
        registered.complete();
      });
      await registered.future;
    }
    await _perspectives.restoreLastPerspective();
    final active = _perspectives.active;
    if (active != null) await _layouts.load(active);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return AnimatedBuilder(
      animation: Listenable.merge([_perspectives, _layouts]),
      builder: (context, _) {
        final active = _perspectives.active;
        if (active == null) {
          return const Center(child: Text('No Perspective registered.', style: TextStyle(color: StudioColors.textSecondary)));
        }
        final layout = _layouts.layoutFor(active);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showSidebar)
              WorkbenchSidebar(
                perspectiveManager: _perspectives,
              ),
            Expanded(
              child: Column(
                children: [
                  if (active.toolbarProvider != null)
                    Container(
                      color: StudioColors.surfaceRaised,
                      child: active.toolbarProvider!(context),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (layout.leftVisible && active.leftPanelProvider != null)
                          SizedBox(
                            width: layout.leftWidth,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: StudioColors.surface,
                                border: Border(right: BorderSide(color: StudioColors.border)),
                              ),
                              child: active.leftPanelProvider!(context),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: active.centerBuilder(context)),
                              if (layout.bottomVisible && active.bottomPanelProvider != null)
                                SizedBox(
                                  height: layout.bottomHeight,
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      color: StudioColors.surface,
                                      border: Border(top: BorderSide(color: StudioColors.border)),
                                    ),
                                    child: active.bottomPanelProvider!(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (layout.rightVisible && active.rightPanelProvider != null)
                          SizedBox(
                            width: layout.rightWidth,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: StudioColors.surface,
                                border: Border(left: BorderSide(color: StudioColors.border)),
                              ),
                              child: active.rightPanelProvider!(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!active.suppressWorkbenchStatusBar) WorkbenchStatusBar(perspective: active),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
