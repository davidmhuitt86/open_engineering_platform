import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart' show Point2D;

/// Live preview line while dragging a new/reconnected connection
/// (WORK_PACKAGE_022, ENGINE-TASK-000093: "Connection Preview", "Invalid
/// Connection Preview"). Green while [valid], red otherwise.
class ConnectionPreviewPainter extends CustomPainter {
  final Point2D from;
  final Point2D to;
  final bool valid;

  ConnectionPreviewPainter({required this.from, required this.to, required this.valid});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = valid ? Colors.green : Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(from.dx, from.dy), Offset(to.dx, to.dy), paint);
    canvas.drawCircle(Offset(to.dx, to.dy), 5, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant ConnectionPreviewPainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to || oldDelegate.valid != valid;
}
