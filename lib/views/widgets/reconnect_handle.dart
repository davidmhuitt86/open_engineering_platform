import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart' show Point2D;

/// A draggable handle at one end of a selected relationship's wire
/// (WORK_PACKAGE_022, ENGINE-TASK-000093: "Drag to Reconnect"). Dragging
/// it to a different node and releasing commits a
/// `ReconnectRelationshipCommand` — the caller decides that; this widget
/// only reports drag deltas.
class ReconnectHandle extends StatelessWidget {
  final Point2D position;
  final bool isSourceEnd;
  final void Function(bool isSourceEnd) onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;

  const ReconnectHandle({
    super.key,
    required this.position,
    required this.isSourceEnd,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 6,
      top: position.dy - 6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onDragStart(isSourceEnd),
        onPanUpdate: (details) => onDragUpdate(details.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }
}
