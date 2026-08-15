import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'dock_manager.dart';
import 'dock_panel_client.dart';
import 'dock_state.dart';

/// WP-DS-006 Engineering Workbench — Dock Manager's own generic rendering:
/// a side-agnostic dock region (Left/Right/Bottom/Floating/Hidden,
/// Auto-hide, Resize, Tabbed docks), driven entirely by [DockManager] +
/// [DockPanelClientRegistry] — no engineering logic, no knowledge of what
/// a given [DockPanelClient] actually shows.
///
/// Generalizes WP-DS-005A's `InstrumentDock` widget (bottom + floating +
/// resize + auto-hide + tabs + persistence) to also support left/right
/// docking for real (rather than the disclosed "left/right persisted but
/// rendered as bottom" boundary that widget still has — that boundary is
/// WP-DS-005A's own, unchanged; this is a fresh, independent widget).
///
/// Same disclosed boundary as `InstrumentDock` for "floating window": an
/// in-app movable/resizable [Positioned] surface, not a real second OS
/// window — Flutter desktop multi-window isn't wired into this Studio
/// anywhere.
class DockRegion extends StatelessWidget {
  const DockRegion({super.key, required this.manager, required this.registry});

  final DockManager manager;
  final DockPanelClientRegistry registry;

  static const double _tabBarHeight = 36;
  static const double _titleBarHeight = 28;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([manager, registry]),
      builder: (context, _) {
        final state = manager.state;
        if (!state.visible || state.side == DockSide.hidden || registry.isEmpty) return const SizedBox.shrink();
        final active = registry.byId(state.activeClientId ?? '') ?? registry.all.first;

        if (state.side == DockSide.floating) {
          return Positioned(
            left: state.floatingLeft,
            top: state.floatingTop,
            width: state.floatingWidth,
            height: state.floatingHeight,
            child: _FloatingFrame(manager: manager, registry: registry, active: active),
          );
        }

        return _DockedStrip(manager: manager, registry: registry, active: active, tabBarHeight: _tabBarHeight);
      },
    );
  }
}

class _DockedStrip extends StatefulWidget {
  const _DockedStrip({required this.manager, required this.registry, required this.active, required this.tabBarHeight});

  final DockManager manager;
  final DockPanelClientRegistry registry;
  final DockPanelClient active;
  final double tabBarHeight;

  @override
  State<_DockedStrip> createState() => _DockedStripState();
}

class _DockedStripState extends State<_DockedStrip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.manager.state;
    final collapsed = state.autoHide && !_hovered;
    final vertical = state.side == DockSide.bottom;
    final extent = collapsed ? widget.tabBarHeight : state.size;

    final content = Column(
      children: [
        if (!collapsed && vertical) _ResizeGrip(vertical: true, onDrag: (d) => widget.manager.setSize(state.size - d)),
        _DockTabBar(manager: widget.manager, registry: widget.registry),
        if (!collapsed)
          Expanded(
            child: Padding(padding: const EdgeInsets.all(8), child: widget.active.buildPanel(context)),
          ),
      ],
    );

    // The strip's own sized box: bounded in the dock's "extent" axis
    // (height for a bottom dock, width for a left/right dock) and left
    // unconstrained in the other axis, which is instead bounded by
    // whatever ancestor Positioned/Row gives it. For a left/right dock,
    // `content` is handed to this box directly (no Row/Expanded wrapper
    // inside it) — nesting an Expanded inside a Container that only
    // constrains *width* left the Row's own width unbounded (the
    // Positioned ancestor for left/right supplies no width), which
    // crashed layout ("RenderFlex children have non-zero flex but
    // incoming width constraints are unbounded"). Left/right resize
    // grips are placed in a `mainAxisSize: MainAxisSize.min` Row
    // *outside* this box instead, in the switch below, so nothing here
    // needs to guess at an unbounded axis.
    final decorated = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: vertical ? null : extent,
        height: vertical ? extent : null,
        decoration: BoxDecoration(
          color: StudioColors.surface,
          border: Border(
            top: vertical ? const BorderSide(color: StudioColors.border) : BorderSide.none,
            left: state.side == DockSide.right ? const BorderSide(color: StudioColors.border) : BorderSide.none,
            right: state.side == DockSide.left ? const BorderSide(color: StudioColors.border) : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );

    switch (state.side) {
      case DockSide.bottom:
        return Positioned(left: 0, right: 0, bottom: 0, child: decorated);
      case DockSide.left:
        return Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Stretch: gives `decorated` (and its Column of tab bar +
            // Expanded panel content) a tight height matching the full
            // dock height, rather than the Row's default loose
            // (shrink-to-content) cross-axis sizing, which would leave
            // the Column's own Expanded panel with no bound to expand
            // into.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              decorated,
              if (!collapsed) _ResizeGrip(vertical: false, onDrag: (d) => widget.manager.setSize(state.size + d)),
            ],
          ),
        );
      case DockSide.right:
        return Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!collapsed) _ResizeGrip(vertical: false, onDrag: (d) => widget.manager.setSize(state.size - d)),
              decorated,
            ],
          ),
        );
      case DockSide.floating:
      case DockSide.hidden:
        return const SizedBox.shrink();
    }
  }
}

class _FloatingFrame extends StatelessWidget {
  const _FloatingFrame({required this.manager, required this.registry, required this.active});

  final DockManager manager;
  final DockPanelClientRegistry registry;
  final DockPanelClient active;

  @override
  Widget build(BuildContext context) {
    final state = manager.state;
    return Container(
      decoration: BoxDecoration(
        color: StudioColors.surface,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onPanUpdate: (d) => manager.setFloatingBounds(
              left: state.floatingLeft + d.delta.dx,
              top: state.floatingTop + d.delta.dy,
            ),
            child: Container(
              height: DockRegion._titleBarHeight,
              color: StudioColors.surfaceRaised,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(active.icon, size: 14, color: StudioColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(active.title, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.dock_outlined, size: 14),
                    tooltip: 'Dock to bottom',
                    color: StudioColors.textSecondary,
                    onPressed: () => manager.setSide(DockSide.bottom),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Hide',
                    color: StudioColors.textSecondary,
                    onPressed: manager.hide,
                  ),
                ],
              ),
            ),
          ),
          _DockTabBar(manager: manager, registry: registry),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: active.buildPanel(context))),
          GestureDetector(
            onPanUpdate: (d) => manager.setFloatingBounds(
              width: state.floatingWidth + d.delta.dx,
              height: state.floatingHeight + d.delta.dy,
            ),
            child: const SizedBox(
              width: double.infinity,
              height: 14,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Align(alignment: Alignment.bottomRight, child: Icon(Icons.drag_indicator, size: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockTabBar extends StatelessWidget {
  const _DockTabBar({required this.manager, required this.registry});

  final DockManager manager;
  final DockPanelClientRegistry registry;

  @override
  Widget build(BuildContext context) {
    final state = manager.state;
    final activeId = state.activeClientId ?? registry.all.first.id;
    return Container(
      height: 32,
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final client in registry.all)
                  _DockTab(client: client, selected: client.id == activeId, onTap: () => manager.selectClient(client.id)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(state.autoHide ? Icons.push_pin : Icons.push_pin_outlined, size: 14),
            tooltip: state.autoHide ? 'Disable auto-hide' : 'Enable auto-hide',
            color: StudioColors.textSecondary,
            onPressed: () => manager.setAutoHide(!state.autoHide),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 14),
            tooltip: state.side == DockSide.floating ? 'Dock to bottom' : 'Float',
            color: StudioColors.textSecondary,
            onPressed: () => manager.setSide(state.side == DockSide.floating ? DockSide.bottom : DockSide.floating),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            tooltip: 'Hide',
            color: StudioColors.textSecondary,
            onPressed: manager.hide,
          ),
        ],
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.client, required this.selected, required this.onTap});

  final DockPanelClient client;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? StudioColors.selection : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(client.icon, size: 14, color: selected ? StudioColors.textPrimary : StudioColors.textSecondary),
            const SizedBox(width: 6),
            Text(client.title, style: TextStyle(fontSize: 12, color: selected ? StudioColors.textPrimary : StudioColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ResizeGrip extends StatelessWidget {
  const _ResizeGrip({required this.vertical, required this.onDrag});

  /// `true` for a horizontal grip (drags height, bottom dock); `false` for
  /// a vertical grip (drags width, left/right dock).
  final bool vertical;
  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => onDrag(vertical ? d.delta.dy : d.delta.dx),
      child: MouseRegion(
        cursor: vertical ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight,
        child: SizedBox(height: vertical ? 6 : double.infinity, width: vertical ? double.infinity : 6),
      ),
    );
  }
}
