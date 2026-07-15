import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Renders one Diagram Layout annotation on the canvas (WORK_PACKAGE_023,
/// ENGINE-TASK-000100/000106) — draggable (Move), double-tap to edit
/// (Edit), tap to select. Rotation is applied as a `Transform.rotate`;
/// the engine tracks rotation in degrees, Flutter wants radians.
class AnnotationWidget extends StatelessWidget {
  final DiagramAnnotation annotation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onEditRequested;

  const AnnotationWidget({
    super.key,
    required this.annotation,
    required this.selected,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: annotation.position.dx,
      top: annotation.position.dy,
      child: Transform.rotate(
        angle: annotation.rotation * 3.1415926535 / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onEditRequested,
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (details) => onDragUpdate(details.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _backgroundFor(annotation.type),
              border: Border.all(color: selected ? Colors.blue : Colors.black26),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              annotation.text.isEmpty ? '(empty)' : annotation.text,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  static Color _backgroundFor(AnnotationType type) {
    switch (type) {
      case AnnotationType.revisionNote:
        return const Color(0xFFFFF3CD);
      case AnnotationType.callout:
        return const Color(0xFFE2F0FF);
      default:
        return Colors.white;
    }
  }
}
