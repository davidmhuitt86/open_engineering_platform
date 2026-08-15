import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../core/engineering_instrument.dart';
import 'instrument_dock_controller.dart';
import 'instrument_dock_state.dart';

/// WP-DS-005A Instrument Dock — the permanent dockable panel that hosts
/// every registered [EngineeringInstrument].
///
/// **Disclosed scope boundary.** The governing spec's "Instrument Dock"
/// section lists six placements (bottom, floating window, dock left, dock
/// right, auto-hide, resize) plus tabs and layout persistence. This
/// widget implements bottom dock, floating window, resize, auto-hide,
/// multi-instrument tabs, and layout persistence for real. `dock left`/
/// `dock right` are modeled in [InstrumentDockState]/[DockPosition] (so
/// persisted state and the toolbar's position picker already carry them)
/// but this widget renders `DockPosition.left`/`.right` as the bottom
/// dock today rather than a half-built side-dock layout — real subset
/// over a half-working everything, per the work package's own stated
/// philosophy.
///
/// The "floating window" requirement is implemented as an in-app movable/
/// resizable [Positioned] surface (drag the title bar, drag the resize
/// grip), not a real separate OS window — Flutter's desktop multi-window
/// support is not wired into this Studio anywhere else, so a real second
/// platform window is out of scope here; this is disclosed, not silently
/// approximated as "the same thing."
class InstrumentDock extends StatelessWidget {
  const InstrumentDock({
    super.key,
    required this.controller,
    required this.registry,
  });

  final InstrumentDockController controller;
  final InstrumentRegistry registry;

  static const double _tabBarHeight = 36;
  static const double _titleBarHeight = 28;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, registry]),
      builder: (context, _) {
        final state = controller.state;
        if (!state.visible || registry.isEmpty) return const SizedBox.shrink();
        final active = registry.byId(state.activeInstrumentId ?? '') ?? registry.all.first;

        if (state.position == DockPosition.floating) {
          return Positioned(
            left: state.floatingLeft,
            top: state.floatingTop,
            width: state.floatingWidth,
            height: state.floatingHeight,
            child: _FloatingFrame(controller: controller, registry: registry, active: active),
          );
        }

        // Bottom dock (also used for the disclosed left/right fallback).
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _AutoHideStrip(
            controller: controller,
            registry: registry,
            active: active,
            tabBarHeight: _tabBarHeight,
          ),
        );
      },
    );
  }
}

class _AutoHideStrip extends StatefulWidget {
  const _AutoHideStrip({
    required this.controller,
    required this.registry,
    required this.active,
    required this.tabBarHeight,
  });

  final InstrumentDockController controller;
  final InstrumentRegistry registry;
  final EngineeringInstrument active;
  final double tabBarHeight;

  @override
  State<_AutoHideStrip> createState() => _AutoHideStripState();
}

class _AutoHideStripState extends State<_AutoHideStrip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final collapsed = state.autoHide && !_hovered;
    final height = collapsed ? widget.tabBarHeight : state.size;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: height,
        decoration: const BoxDecoration(
          color: StudioColors.surface,
          border: Border(top: BorderSide(color: StudioColors.border)),
        ),
        child: Column(
          children: [
            if (!collapsed)
              _ResizeGrip(
                onDrag: (dy) => widget.controller.setSize(state.size - dy),
              ),
            _DockTabBar(controller: widget.controller, registry: widget.registry),
            if (!collapsed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: widget.active.buildPanel(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingFrame extends StatelessWidget {
  const _FloatingFrame({required this.controller, required this.registry, required this.active});

  final InstrumentDockController controller;
  final InstrumentRegistry registry;
  final EngineeringInstrument active;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
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
            onPanUpdate: (d) => controller.setFloatingBounds(
              left: state.floatingLeft + d.delta.dx,
              top: state.floatingTop + d.delta.dy,
            ),
            child: Container(
              height: InstrumentDock._titleBarHeight,
              color: StudioColors.surfaceRaised,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(active.icon, size: 14, color: StudioColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(active.title,
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.dock_outlined, size: 14),
                    tooltip: 'Dock to bottom',
                    color: StudioColors.textSecondary,
                    onPressed: () => controller.setPosition(DockPosition.bottom),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Hide instrument dock',
                    color: StudioColors.textSecondary,
                    onPressed: controller.hide,
                  ),
                ],
              ),
            ),
          ),
          _DockTabBar(controller: controller, registry: registry),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: active.buildPanel(context))),
          GestureDetector(
            onPanUpdate: (d) => controller.setFloatingBounds(
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
  const _DockTabBar({required this.controller, required this.registry});

  final InstrumentDockController controller;
  final InstrumentRegistry registry;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final activeId = state.activeInstrumentId ?? registry.all.first.id;
    return Container(
      height: 32,
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final instrument in registry.all)
                  _DockTab(
                    instrument: instrument,
                    selected: instrument.id == activeId,
                    onTap: () => controller.selectInstrument(instrument.id),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(state.autoHide ? Icons.push_pin : Icons.push_pin_outlined, size: 14),
            tooltip: state.autoHide ? 'Disable auto-hide' : 'Enable auto-hide',
            color: StudioColors.textSecondary,
            onPressed: () => controller.setAutoHide(!state.autoHide),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 14),
            tooltip: state.position == DockPosition.floating ? 'Dock to bottom' : 'Float',
            color: StudioColors.textSecondary,
            onPressed: () => controller.setPosition(
              state.position == DockPosition.floating ? DockPosition.bottom : DockPosition.floating,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            tooltip: 'Hide instrument dock',
            color: StudioColors.textSecondary,
            onPressed: controller.hide,
          ),
        ],
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.instrument, required this.selected, required this.onTap});

  final EngineeringInstrument instrument;
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
            Icon(instrument.icon, size: 14, color: selected ? StudioColors.textPrimary : StudioColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              instrument.title,
              style: TextStyle(
                fontSize: 12,
                color: selected ? StudioColors.textPrimary : StudioColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizeGrip extends StatelessWidget {
  const _ResizeGrip({required this.onDrag});

  final void Function(double dy) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => onDrag(d.delta.dy),
      child: const MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: SizedBox(height: 6, width: double.infinity),
      ),
    );
  }
}
