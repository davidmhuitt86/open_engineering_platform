import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Paints ephemeral smart-alignment guides computed by
/// [AlignmentGuideComputer] while a node is being dragged
/// (WORK_PACKAGE_022, ENGINE-TASK-000091). Purely visual — these lines
/// never persist and are recomputed fresh on every drag frame.
class GuidesPainter extends CustomPainter {
  final List<AlignmentGuide> guides;
  final double width;
  final double height;

  GuidesPainter(this.guides, {required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 1;
    for (final guide in guides) {
      if (guide.axis == GridAxis.vertical) {
        canvas.drawLine(Offset(guide.position, 0), Offset(guide.position, height), paint);
      } else {
        canvas.drawLine(Offset(0, guide.position), Offset(width, guide.position), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidesPainter oldDelegate) => oldDelegate.guides != guides;
}
