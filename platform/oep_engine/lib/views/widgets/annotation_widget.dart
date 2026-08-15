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

  /// A right-click (secondary-button tap) on this annotation (OEP
  /// Diagram Studio -- Phase 4, Part 6): reuses this widget's own real,
  /// already-rendered `GestureDetector` hit region -- the same one
  /// `onTap` uses -- rather than a separately computed approximation
  /// of the annotation's text-dependent bounds (no such bounds are
  /// stored on `DiagramAnnotation` itself). `null` for callers that
  /// don't need contextual-menu targeting.
  final void Function(Offset globalPosition)? onSecondaryTapUp;

  const AnnotationWidget({
    super.key,
    required this.annotation,
    required this.selected,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onEditRequested,
    this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    if (annotation.type == AnnotationType.portLabel) return _buildPortLabel();
    return Positioned(
      left: annotation.position.dx,
      top: annotation.position.dy,
      // RepaintBoundary goes *inside* Positioned (AP-DS-001B fix): this
      // widget is placed directly as a Stack child by GraphViewPanel, and
      // Positioned must be the direct Stack child for Flutter's
      // ParentDataWidget matching to work — wrapping this whole widget in
      // an outer RepaintBoundary (as GraphViewPanel previously did)
      // interposes a RenderObject between Stack and Positioned and throws
      // "Incorrect use of ParentDataWidget" for every annotation at
      // runtime. Isolating repaint at this inner boundary still gets the
      // performance benefit (this annotation's own subtree repaints
      // independently of its siblings) without breaking Positioned's
      // required adjacency to Stack.
      child: RepaintBoundary(
        child: Transform.rotate(
        angle: annotation.rotation * 3.1415926535 / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onEditRequested,
          onSecondaryTapUp: onSecondaryTapUp == null ? null : (details) => onSecondaryTapUp!(details.globalPosition),
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
      ),
    );
  }

  /// (User-requested: a pin/port label should render like the
  /// reference screenshot -- small plain caps text sitting right at
  /// the pin, no bordered box.) Same tap/drag/edit gestures as the
  /// boxed style above, just without [_backgroundFor]'s
  /// `Container`/`Border` -- a real terminal name on a wiring diagram
  /// isn't drawn as a sticky note.
  Widget _buildPortLabel() {
    return Positioned(
      left: annotation.position.dx,
      top: annotation.position.dy,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onEditRequested,
          onSecondaryTapUp: onSecondaryTapUp == null ? null : (details) => onSecondaryTapUp!(details.globalPosition),
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (details) => onDragUpdate(details.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: selected ? BoxDecoration(border: Border.all(color: Colors.blue, width: 1)) : null,
            child: Text(
              annotation.text.isEmpty ? '(empty)' : annotation.text,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.black87,
              ),
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
