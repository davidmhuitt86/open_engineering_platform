import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Paints [GridLine]s computed by the engine's [GridComputer] — this
/// class only draws; it never decides where lines go (WORK_PACKAGE_022,
/// ENGINE-TASK-000090: "The Engine computes grid geometry. The
/// Demonstration Host renders it.").
class GridPainter extends CustomPainter {
  final List<GridLine> lines;
  final double width;
  final double height;

  GridPainter(this.lines, {required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.isMajor ? Colors.black26 : Colors.black12
        ..strokeWidth = line.isMajor ? 1.0 : 0.5;
      if (line.axis == GridAxis.vertical) {
        canvas.drawLine(Offset(line.position, 0), Offset(line.position, height), paint);
      } else {
        canvas.drawLine(Offset(0, line.position), Offset(width, line.position), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.lines != lines;
}
