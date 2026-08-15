import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../simulation/diagram_simulation_service.dart';

/// The nine Diagram Studio toolbar groups (WORK_PACKAGE_024,
/// ENGINE-TASK-000113) — Studio-styled ports of the Demonstration
/// Host's `DemoToolbar`/`SecondaryToolbar` behavior, calling the same
/// Engine APIs. Each group is a small, independent row living inside
/// `DiagramStudioPage`'s own content area, never the global
/// `StudioToolbar` (Diagram Studio's toolbars are workspace-local, the
/// same way Knowledge Studio's panels never touch the global toolbar).
class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({required this.icon, required this.tooltip, this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Phase 14 (UI Layout Ratification) -- density pass: Material's
    // default `IconButton` tap target (48x48) is what made every
    // toolbar row tall/loose despite an 18px icon. Shrinking the
    // constraints/padding here (not the icon itself, and not removing
    // any command) tightens every existing toolbar group toward the
    // reference's own dense single-row look, without deciding which
    // commands are "low frequency enough" to cut -- that Command-
    // Palette-parity decision is explicitly out of scope for this pass.
    return IconButton(
      iconSize: 16,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: active ? StudioColors.selection : null),
      color: onPressed == null ? StudioColors.textDisabled : StudioColors.textPrimary,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Selection group: bulk selection/grouping actions.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onGroup,
    required this.onUngroup,
    super.key,
  });

  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.select_all, tooltip: 'Select all (Ctrl+A)', onPressed: onSelectAll),
      _ToolbarIcon(icon: Icons.deselect, tooltip: 'Deselect all (Esc)', onPressed: onDeselectAll),
      _ToolbarIcon(icon: Icons.group_work_outlined, tooltip: 'Group', onPressed: onGroup),
      _ToolbarIcon(icon: Icons.group_off_outlined, tooltip: 'Ungroup', onPressed: onUngroup),
    ]);
  }
}

/// Edit Actions group: Undo/Redo/Cut/Copy/Paste/Duplicate/Delete —
/// previously reachable only via `CallbackShortcuts` keyboard bindings
/// in `diagram_studio_page.dart`, with no toolbar affordance at all
/// (AP-DS-001B Toolbar Audit finding: these are the most frequently
/// used editing actions in the whole workspace and had zero
/// discoverable UI entry point). Tooltips document the matching
/// shortcut so the two stay legible as one system.
class EditActionsToolbar extends StatelessWidget {
  const EditActionsToolbar({
    required this.onUndo,
    required this.onRedo,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.undo, tooltip: 'Undo (Ctrl+Z)', onPressed: onUndo),
      _ToolbarIcon(icon: Icons.redo, tooltip: 'Redo (Ctrl+Y)', onPressed: onRedo),
      _ToolbarIcon(icon: Icons.content_cut, tooltip: 'Cut (Ctrl+X)', onPressed: onCut),
      _ToolbarIcon(icon: Icons.content_copy, tooltip: 'Copy (Ctrl+C)', onPressed: onCopy),
      _ToolbarIcon(icon: Icons.content_paste, tooltip: 'Paste (Ctrl+V)', onPressed: onPaste),
      _ToolbarIcon(icon: Icons.copy_all_outlined, tooltip: 'Duplicate (Ctrl+D)', onPressed: onDuplicate),
      _ToolbarIcon(icon: Icons.delete_outline, tooltip: 'Delete (Del)', onPressed: onDelete),
    ]);
  }
}

/// Navigation group: viewport fit/center/history/reset. Named
/// `DiagramNavigationToolbar` (not `NavigationToolbar`) to avoid
/// colliding with Flutter's own `widgets.NavigationToolbar`.
class DiagramNavigationToolbar extends StatelessWidget {
  const DiagramNavigationToolbar({
    required this.onFitAll,
    required this.onFitSelection,
    required this.onCenterSelection,
    required this.onGoBack,
    required this.onGoForward,
    required this.onResetView,
    super.key,
  });

  final VoidCallback onFitAll;
  final VoidCallback? onFitSelection;
  final VoidCallback? onCenterSelection;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;
  final VoidCallback onResetView;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.fit_screen_outlined, tooltip: 'Fit all', onPressed: onFitAll),
      _ToolbarIcon(icon: Icons.crop_free, tooltip: 'Fit selection', onPressed: onFitSelection),
      _ToolbarIcon(icon: Icons.center_focus_strong_outlined, tooltip: 'Center selection', onPressed: onCenterSelection),
      _ToolbarIcon(icon: Icons.arrow_back, tooltip: 'Navigate back', onPressed: onGoBack),
      _ToolbarIcon(icon: Icons.arrow_forward, tooltip: 'Navigate forward', onPressed: onGoForward),
      _ToolbarIcon(icon: Icons.filter_center_focus_outlined, tooltip: 'Reset view (Ctrl+0)', onPressed: onResetView),
    ]);
  }
}

/// Align/Distribute group (AP-DS-001A): triggers the pre-existing
/// `AlignNodesCommand`/`DistributeNodesCommand` — engine-side logic was
/// already complete, this toolbar was the missing UI entry point.
class AlignDistributeToolbar extends StatelessWidget {
  const AlignDistributeToolbar({
    required this.onAlign,
    required this.onDistribute,
    super.key,
  });

  final void Function(AlignmentMode mode)? onAlign;
  final void Function(DistributionAxis axis)? onDistribute;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.align_horizontal_left, tooltip: 'Align left', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.left)),
      _ToolbarIcon(icon: Icons.align_horizontal_center, tooltip: 'Align center', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.center)),
      _ToolbarIcon(icon: Icons.align_horizontal_right, tooltip: 'Align right', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.right)),
      _ToolbarIcon(icon: Icons.align_vertical_top, tooltip: 'Align top', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.top)),
      _ToolbarIcon(icon: Icons.align_vertical_center, tooltip: 'Align middle', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.middle)),
      _ToolbarIcon(icon: Icons.align_vertical_bottom, tooltip: 'Align bottom', onPressed: onAlign == null ? null : () => onAlign!(AlignmentMode.bottom)),
      _ToolbarIcon(icon: Icons.view_column_outlined, tooltip: 'Distribute horizontally', onPressed: onDistribute == null ? null : () => onDistribute!(DistributionAxis.horizontal)),
      _ToolbarIcon(icon: Icons.table_rows_outlined, tooltip: 'Distribute vertically', onPressed: onDistribute == null ? null : () => onDistribute!(DistributionAxis.vertical)),
    ]);
  }
}

/// Placement group: add node, rotate/mirror/array/replace symbol.
class PlacementToolbar extends StatelessWidget {
  const PlacementToolbar({
    required this.symbolChoices,
    required this.resolveSymbolName,
    required this.onAddNode,
    required this.onRotate90,
    required this.onRotate180,
    required this.onRotateArbitrary,
    required this.onMirrorHorizontal,
    required this.onMirrorVertical,
    required this.onArrayPlace,
    required this.onReplaceSymbol,
    super.key,
  });

  final List<String> symbolChoices;
  final String Function(String symbolId) resolveSymbolName;
  final void Function(String symbolId) onAddNode;
  final VoidCallback? onRotate90;
  final VoidCallback? onRotate180;
  final void Function(double degrees)? onRotateArbitrary;
  final VoidCallback? onMirrorHorizontal;
  final VoidCallback? onMirrorVertical;
  final VoidCallback? onArrayPlace;
  final void Function(String symbolId)? onReplaceSymbol;

  Future<void> _promptAngle(BuildContext context) async {
    final controller = TextEditingController(text: '15');
    final degrees = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rotate by angle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Degrees'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (degrees != null) onRotateArbitrary?.call(degrees);
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<String>(
        tooltip: 'Add node',
        onSelected: onAddNode,
        itemBuilder: (context) => symbolChoices
            .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.add_box_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
      _ToolbarIcon(icon: Icons.rotate_90_degrees_ccw, tooltip: 'Rotate 90°', onPressed: onRotate90),
      _ToolbarIcon(icon: Icons.rotate_left, tooltip: 'Rotate 180°', onPressed: onRotate180),
      _ToolbarIcon(
        icon: Icons.explore_outlined,
        tooltip: 'Rotate arbitrary angle…',
        onPressed: onRotateArbitrary == null ? null : () => _promptAngle(context),
      ),
      _ToolbarIcon(icon: Icons.flip, tooltip: 'Mirror horizontal', onPressed: onMirrorHorizontal),
      _ToolbarIcon(icon: Icons.flip_camera_android_outlined, tooltip: 'Mirror vertical', onPressed: onMirrorVertical),
      _ToolbarIcon(icon: Icons.grid_on_outlined, tooltip: 'Array placement…', onPressed: onArrayPlace),
      PopupMenuButton<String>(
        tooltip: 'Replace symbol',
        enabled: onReplaceSymbol != null,
        onSelected: onReplaceSymbol,
        itemBuilder: (context) => symbolChoices
            .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.find_replace_outlined,
            size: 18,
            color: onReplaceSymbol == null ? StudioColors.textDisabled : StudioColors.textPrimary,
          ),
        ),
      ),
    ]);
  }
}

/// Wire Editing group: "Edit Route" mode + vertex tools.
class WireEditingToolbar extends StatelessWidget {
  const WireEditingToolbar({
    required this.wireEditModeActive,
    required this.onToggleWireEditMode,
    required this.onInsertVertex,
    required this.onRemoveVertex,
    required this.onRestoreAutomaticRouting,
    this.wireCreateModeActive = false,
    this.onToggleWireCreateMode,
    super.key,
  });

  final bool wireEditModeActive;
  final VoidCallback? onToggleWireEditMode;
  final VoidCallback? onInsertVertex;
  final VoidCallback? onRemoveVertex;
  final VoidCallback? onRestoreAutomaticRouting;

  /// (Phase 14 -- UI Layout Ratification, § 5.) The "Wire" persistent
  /// Edit-mode control the ratified spec calls for -- a real toggle
  /// enabling click-a-port/click-a-port wire creation, distinct from
  /// [wireEditModeActive] (which only edits an EXISTING, already-
  /// selected wire's route). Optional so existing callers/tests that
  /// don't yet wire it are unaffected.
  final bool wireCreateModeActive;
  final VoidCallback? onToggleWireCreateMode;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      if (onToggleWireCreateMode != null)
        _ToolbarIcon(
          icon: wireCreateModeActive ? Icons.electrical_services : Icons.electrical_services_outlined,
          tooltip: wireCreateModeActive ? 'Wire mode active -- click a port, then another port' : 'Wire: click two ports to connect them',
          onPressed: onToggleWireCreateMode,
          active: wireCreateModeActive,
        ),
      _ToolbarIcon(
        icon: wireEditModeActive ? Icons.polyline : Icons.polyline_outlined,
        tooltip: 'Edit route',
        onPressed: onToggleWireEditMode,
        active: wireEditModeActive,
      ),
      _ToolbarIcon(icon: Icons.add_circle_outline, tooltip: 'Insert vertex', onPressed: onInsertVertex),
      _ToolbarIcon(icon: Icons.remove_circle_outline, tooltip: 'Remove vertex', onPressed: onRemoveVertex),
      _ToolbarIcon(icon: Icons.auto_fix_high_outlined, tooltip: 'Restore automatic routing', onPressed: onRestoreAutomaticRouting),
    ]);
  }
}

/// Layers group: quick "new layer" + toggle the docked Layer panel.
class LayersToolbar extends StatelessWidget {
  const LayersToolbar({required this.onToggleLayerPanel, required this.onCreateLayer, super.key});

  final VoidCallback onToggleLayerPanel;
  final VoidCallback onCreateLayer;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.layers_outlined, tooltip: 'Toggle Layer panel', onPressed: onToggleLayerPanel),
      _ToolbarIcon(icon: Icons.add_to_photos_outlined, tooltip: 'New layer', onPressed: onCreateLayer),
    ]);
  }
}

/// (OEP Diagram Studio -- Phase 6, Part 4/21.) Visibility toggles for
/// the three secondary panels that previously rendered unconditionally
/// with no toggle at all (Object Explorer, Annotations list, Recent
/// Commands) -- real clutter contributors in View mode. Matches
/// `LayersToolbar`'s own toggle-icon convention exactly.
class PanelsToolbar extends StatelessWidget {
  const PanelsToolbar({
    required this.onToggleObjectExplorer,
    required this.onToggleAnnotationsPanel,
    required this.onToggleRecentCommandsPanel,
    this.onToggleLegend,
    this.onToggleMiniMap,
    super.key,
  });

  final VoidCallback onToggleObjectExplorer;
  final VoidCallback onToggleAnnotationsPanel;
  final VoidCallback onToggleRecentCommandsPanel;

  /// (Phase 14 -- UI Layout Ratification.) Toggles the bottom-left
  /// category-color Legend panel, modeled on
  /// `legacy_wiring_sim_v2`'s own `☰ Legend` toolbar button
  /// (`index.html:64`). Optional so existing callers/tests that don't
  /// yet wire a legend toggle are unaffected.
  final VoidCallback? onToggleLegend;

  /// (User-requested: Minimap "need[s] to be...able to be toggle[d] on
  /// and off.") Optional, same reasoning as [onToggleLegend].
  final VoidCallback? onToggleMiniMap;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.account_tree_outlined, tooltip: 'Toggle Object Explorer', onPressed: onToggleObjectExplorer),
      _ToolbarIcon(icon: Icons.sticky_note_2_outlined, tooltip: 'Toggle Annotations panel', onPressed: onToggleAnnotationsPanel),
      _ToolbarIcon(icon: Icons.history, tooltip: 'Toggle Recent Commands panel', onPressed: onToggleRecentCommandsPanel),
      if (onToggleLegend != null)
        _ToolbarIcon(icon: Icons.palette_outlined, tooltip: 'Toggle Legend', onPressed: onToggleLegend),
      if (onToggleMiniMap != null)
        _ToolbarIcon(icon: Icons.map_outlined, tooltip: 'Toggle Minimap', onPressed: onToggleMiniMap),
    ]);
  }
}

/// Annotations group: add a new annotation of a chosen type.
class AnnotationsToolbar extends StatelessWidget {
  const AnnotationsToolbar({required this.onAddAnnotation, super.key});

  final void Function(AnnotationType type) onAddAnnotation;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<AnnotationType>(
        tooltip: 'Add annotation',
        onSelected: onAddAnnotation,
        // `portLabel` is excluded here -- it needs a real port to
        // anchor to (`anchorPortId`/`anchorNodeId`), which this
        // toolbar's own `_addAnnotation(type)` has no way to supply
        // (only a cursor scene position). It's created exclusively via
        // the port right-click menu's own "Add Label" command
        // (`diagram.port.addLabel`), which does have a real port to
        // anchor to.
        itemBuilder: (context) => AnnotationType.values
            .where((t) => t != AnnotationType.portLabel)
            .map((t) => PopupMenuItem(value: t, child: Text(_labelFor(t))))
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.sticky_note_2_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
    ]);
  }

  static String _labelFor(AnnotationType type) {
    switch (type) {
      case AnnotationType.textLabel:
        return 'Text Label';
      case AnnotationType.leaderNote:
        return 'Leader Note';
      case AnnotationType.callout:
        return 'Callout';
      case AnnotationType.wireLabel:
        return 'Wire Label';
      case AnnotationType.componentLabel:
        return 'Component Label';
      case AnnotationType.freeText:
        return 'Free Text';
      case AnnotationType.revisionNote:
        return 'Revision Note';
      case AnnotationType.portLabel:
        // Unreachable from this toolbar (filtered out above) -- kept
        // only so this switch stays exhaustive.
        return 'Pin Label';
    }
  }
}

/// View group: grid/snap/guides toggles + grid settings + named layouts.
class ViewToolbar extends StatelessWidget {
  const ViewToolbar({
    required this.viewState,
    required this.onToggleGrid,
    required this.onToggleSnap,
    required this.onToggleGuides,
    required this.onOpenGridSettings,
    required this.onOpenNamedLayouts,
    super.key,
  });

  final ViewState viewState;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleSnap;
  final VoidCallback onToggleGuides;
  final VoidCallback onOpenGridSettings;
  final VoidCallback onOpenNamedLayouts;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<void>(
        tooltip: 'View',
        itemBuilder: (context) => [
          CheckedPopupMenuItem<void>(checked: viewState.grid.visible, onTap: onToggleGrid, child: const Text('Show Grid')),
          CheckedPopupMenuItem<void>(checked: viewState.grid.snapEnabled, onTap: onToggleSnap, child: const Text('Snap to Grid')),
          CheckedPopupMenuItem<void>(checked: viewState.guidesVisible, onTap: onToggleGuides, child: const Text('Show Guides')),
          PopupMenuItem<void>(onTap: onOpenGridSettings, child: const Text('Grid Settings…')),
          PopupMenuItem<void>(onTap: onOpenNamedLayouts, child: const Text('Named Layouts…')),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.visibility_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
    ]);
  }
}

/// Search group: toggle the docked Search panel.
class SearchToolbar extends StatelessWidget {
  const SearchToolbar({required this.onToggleSearchPanel, super.key});

  final VoidCallback onToggleSearchPanel;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.search, tooltip: 'Toggle Search panel', onPressed: onToggleSearchPanel),
    ]);
  }
}

/// Constraints group: orthogonal movement / axis lock / minimum wire length.
class ConstraintsToolbar extends StatelessWidget {
  const ConstraintsToolbar({required this.constraints, required this.onChanged, super.key});

  final EditingConstraints constraints;
  final void Function(EditingConstraints) onChanged;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      Tooltip(
        message: 'Orthogonal movement',
        child: Checkbox(
          value: constraints.orthogonalMovement,
          onChanged: (v) => onChanged(constraints.copyWith(orthogonalMovement: v ?? false)),
        ),
      ),
      DropdownButton<ConstraintAxis?>(
        value: constraints.axisLock,
        hint: const Text('Axis lock', style: TextStyle(fontSize: 12, color: StudioColors.textSecondary)),
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
        items: const [
          DropdownMenuItem(value: null, child: Text('No axis lock')),
          DropdownMenuItem(value: ConstraintAxis.x, child: Text('Lock X')),
          DropdownMenuItem(value: ConstraintAxis.y, child: Text('Lock Y')),
        ],
        onChanged: (axis) => onChanged(
          axis == null ? constraints.copyWith(clearAxisLock: true) : constraints.copyWith(axisLock: axis),
        ),
      ),
    ]);
  }
}

/// (OEP Diagram Studio -- Phase 8, Part 5/6/34.) A compact, immediately-
/// discoverable runtime control strip for Simulate mode -- Start/Pause-
/// Resume/Reset/Stop plus a status chip, all real calls against the
/// same shared [DiagramSimulationService] instance
/// `SimulationCenterDialog`'s own (unmodified, more advanced) playback
/// controls already use. Deliberately NOT a rewrite of
/// `SimulationPlaybackControls` (Play/timeline/speed/bookmarks) -- that
/// full surface remains one dialog away via the existing "Simulate"
/// action; this toolbar only exposes the four simplest, most-discoverable
/// real operations (`createSession`/`resume`/`pause`/`reset`/
/// `deleteSession`), matching Part 34's "immediately discoverable:
/// runtime state, start/stop/reset where real -- everything else can
/// remain contextual."
class SimulationControlsToolbar extends StatelessWidget {
  const SimulationControlsToolbar({
    required this.simulation,
    required this.graph,
    required this.onChanged,
    this.domainProfile,
    super.key,
  });

  final DiagramSimulationService simulation;
  final EngineeringGraph graph;
  final VoidCallback onChanged;

  /// (Phase 14 -- UI Layout Ratification.) The real, user-loaded domain
  /// profile this diagram's operating/input states come from, if any --
  /// threaded into `createSession` so the session that gets created
  /// here is the SAME one the KEY/SWITCHES row (`_KeySwitchesRow` in
  /// `diagram_studio_page.dart`) reads from, never a second session.
  /// `null` (no profile loaded yet) creates a session with no
  /// operating/input states, exactly as before this phase.
  final DomainProfile? domainProfile;

  @override
  Widget build(BuildContext context) {
    final session = simulation.currentSession;
    final label = session == null ? 'No Session' : (session.isPaused ? 'Paused' : 'Active');
    final color = session == null
        ? StudioColors.inactive
        : (session.isPaused ? StudioColors.warning : StudioColors.success);

    Future<void> run(Future<void> Function() action) async {
      await action();
      onChanged();
    }

    return _ToolbarGroup(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      _ToolbarIcon(
        icon: Icons.play_arrow,
        tooltip: session == null ? 'Start simulation' : 'Resume simulation',
        onPressed: session == null
            ? () => run(() => simulation.createSession(
                  graph,
                  availableOperatingStates: domainProfile?.operatingStates ?? const [],
                  availableInputStates: domainProfile?.inputStates ?? const [],
                ))
            : (session.isPaused ? () => run(simulation.resume) : null),
      ),
      _ToolbarIcon(
        icon: Icons.pause,
        tooltip: 'Pause simulation',
        onPressed: session != null && !session.isPaused ? () => run(simulation.pause) : null,
      ),
      _ToolbarIcon(
        icon: Icons.restart_alt,
        tooltip: 'Reset simulation',
        onPressed: session == null ? null : () => run(simulation.reset),
      ),
      _ToolbarIcon(
        icon: Icons.stop,
        tooltip: 'Stop simulation',
        onPressed: session == null ? null : () => run(() => simulation.deleteSession(session.id)),
      ),
      // Phase 9 Part 17: "a compact state control such as Operating
      // State: Key On / Engine Off [dropdown] ... Do not create a
      // large dashboard." Renders only when the real session actually
      // has real, caller-supplied operating states to choose from
      // (`session.availableOperatingStates`) -- this engine defines no
      // states of its own (Part 4), so on a session with no domain
      // profile supplied, this control is correctly and honestly
      // absent rather than showing a fabricated default.
      if (session != null && session.availableOperatingStates.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButton<String>(
            value: session.activeOperatingStateId,
            hint: const Text('Operating State', style: TextStyle(fontSize: 11.5)),
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 11.5),
            items: [
              for (final state in session.availableOperatingStates)
                DropdownMenuItem(value: state.id, child: Text(state.name)),
            ],
            onChanged: (stateId) {
              if (stateId != null) run(() => simulation.setOperatingState(stateId));
            },
          ),
        ),
    ]);
  }
}
