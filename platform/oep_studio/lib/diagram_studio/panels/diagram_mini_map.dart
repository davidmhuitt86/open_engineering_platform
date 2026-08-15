import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// The Mini Map (Phase 3, OEP Design System `03_Engineering_Workspace.png`
/// / `05_Interactive_Wiring_Diagram_Editor.png`; ODS-C015 Engineering
/// Canvas § 5 "Viewport Model" lists "Minimap integration" as a
/// supported viewport feature).
///
/// A real thumbnail of the actual rendered [scene] -- every node's true
/// position and size, scaled to fit -- with the current viewport drawn
/// as an overlay rectangle. Nothing here is illustrative; a diagram
/// with zero nodes renders an honest empty box, not a placeholder
/// graphic.
class DiagramMiniMap extends StatelessWidget {
  const DiagramMiniMap({
    required this.scene,
    required this.pan,
    required this.zoom,
    required this.viewportWidth,
    required this.viewportHeight,
    super.key,
  });

  final DiagramScene scene;
  final Point2D pan;
  final double zoom;
  final double viewportWidth;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 120,
      // No border (user-requested: the Minimap "can be the only
      // 'floating' panel with no border").
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: scene.nodes.isEmpty
          ? const Center(
              child: Text('No nodes to map', style: TextStyle(color: StudioColors.textDisabled, fontSize: 10)),
            )
          : CustomPaint(
              painter: _MiniMapPainter(
                scene: scene,
                pan: pan,
                zoom: zoom,
                viewportWidth: viewportWidth,
                viewportHeight: viewportHeight,
              ),
              size: Size.infinite,
            ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.scene,
    required this.pan,
    required this.zoom,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  final DiagramScene scene;
  final Point2D pan;
  final double zoom;
  final double viewportWidth;
  final double viewportHeight;

  @override
  void paint(Canvas canvas, Size size) {
    var left = scene.nodes.first.position.dx;
    var top = scene.nodes.first.position.dy;
    var right = left + scene.nodes.first.width;
    var bottom = top + scene.nodes.first.height;
    for (final node in scene.nodes.skip(1)) {
      left = left < node.position.dx ? left : node.position.dx;
      top = top < node.position.dy ? top : node.position.dy;
      right = right > node.position.dx + node.width ? right : node.position.dx + node.width;
      bottom = bottom > node.position.dy + node.height ? bottom : node.position.dy + node.height;
    }

    // The visible viewport in scene space, matching the canvas's own
    // pan/zoom convention (screen = scene * zoom + pan).
    final viewportLeft = -pan.dx / zoom;
    final viewportTop = -pan.dy / zoom;
    final viewportRight = viewportLeft + viewportWidth / zoom;
    final viewportBottom = viewportTop + viewportHeight / zoom;

    left = left < viewportLeft ? left : viewportLeft;
    top = top < viewportTop ? top : viewportTop;
    right = right > viewportRight ? right : viewportRight;
    bottom = bottom > viewportBottom ? bottom : viewportBottom;

    const padding = 8.0;
    final contentWidth = (right - left).clamp(1.0, double.infinity);
    final contentHeight = (bottom - top).clamp(1.0, double.infinity);
    final scale = ((size.width - padding * 2) / contentWidth).clamp(0.0, (size.height - padding * 2) / contentHeight);

    Offset toMiniMap(double x, double y) => Offset(
          padding + (x - left) * scale,
          padding + (y - top) * scale,
        );

    final nodePaint = Paint()..color = StudioColors.textSecondary;
    for (final node in scene.nodes) {
      final topLeft = toMiniMap(node.position.dx, node.position.dy);
      canvas.drawRect(
        Rect.fromLTWH(topLeft.dx, topLeft.dy, node.width * scale, node.height * scale),
        nodePaint,
      );
    }

    final viewportPaint = Paint()
      ..color = StudioColors.selection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final viewportTopLeft = toMiniMap(viewportLeft, viewportTop);
    canvas.drawRect(
      Rect.fromLTWH(
        viewportTopLeft.dx,
        viewportTopLeft.dy,
        (viewportRight - viewportLeft) * scale,
        (viewportBottom - viewportTop) * scale,
      ),
      viewportPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.pan != pan ||
      oldDelegate.zoom != zoom ||
      oldDelegate.viewportWidth != viewportWidth ||
      oldDelegate.viewportHeight != viewportHeight;
}
