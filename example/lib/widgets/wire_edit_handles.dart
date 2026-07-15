import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart' show Point2D;

/// Draggable vertex/segment handles for "Edit Route" mode
/// (WORK_PACKAGE_023, ENGINE-TASK-000099/000106). Corner handles (one per
/// point) support Drag Corner and tap-to-select (for Remove Vertex);
/// segment midpoint handles support Drag Segment. The two end points are
/// rendered but not draggable — they're the fixed port anchors
/// `WireEditing` never moves.
class WireEditHandles extends StatelessWidget {
  final List<Point2D> points;
  final int? selectedVertexIndex;
  final void Function(int index) onVertexTap;
  final void Function(int index) onCornerDragStart;
  final void Function(Offset delta) onCornerDragUpdate;
  final VoidCallback onCornerDragEnd;
  final void Function(int segmentIndex) onSegmentDragStart;
  final void Function(Offset delta) onSegmentDragUpdate;
  final VoidCallback onSegmentDragEnd;

  const WireEditHandles({
    super.key,
    required this.points,
    required this.selectedVertexIndex,
    required this.onVertexTap,
    required this.onCornerDragStart,
    required this.onCornerDragUpdate,
    required this.onCornerDragEnd,
    required this.onSegmentDragStart,
    required this.onSegmentDragUpdate,
    required this.onSegmentDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < points.length - 1; i++)
          _midpointHandle(i),
        for (var i = 0; i < points.length; i++) _cornerHandle(i),
      ],
    );
  }

  Widget _cornerHandle(int index) {
    final isAnchor = index == 0 || index == points.length - 1;
    final point = points[index];
    return Positioned(
      left: point.dx - 5,
      top: point.dy - 5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onVertexTap(index),
        onPanStart: isAnchor ? null : (_) => onCornerDragStart(index),
        onPanUpdate: isAnchor ? null : (details) => onCornerDragUpdate(details.delta),
        onPanEnd: isAnchor ? null : (_) => onCornerDragEnd(),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: isAnchor ? BoxShape.circle : BoxShape.rectangle,
            color: selectedVertexIndex == index ? Colors.orange : Colors.deepPurple,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _midpointHandle(int segmentIndex) {
    final a = points[segmentIndex];
    final b = points[segmentIndex + 1];
    final mid = Point2D((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    return Positioned(
      left: mid.dx - 4,
      top: mid.dy - 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onSegmentDragStart(segmentIndex),
        onPanUpdate: (details) => onSegmentDragUpdate(details.delta),
        onPanEnd: (_) => onSegmentDragEnd(),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.6),
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }
}
