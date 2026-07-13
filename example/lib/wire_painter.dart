import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart' show DiagramWireVisual;

/// Paints [DiagramWireVisual]s as straight polylines. Node symbols are
/// rendered as ordinary positioned widgets (see `main.dart`) so
/// `flutter_svg` can do the actual symbol drawing — this painter only
/// draws the connections between them.
class WirePainter extends CustomPainter {
  final List<DiagramWireVisual> wires;

  WirePainter(this.wires);

  @override
  void paint(Canvas canvas, Size size) {
    for (final wire in wires) {
      if (wire.points.length < 2) continue;
      final paint = Paint()
        ..color = wire.highlighted
            ? Colors.orange
            : (wire.selected ? Colors.blue : Colors.black87)
        ..strokeWidth = wire.highlighted || wire.selected ? 3 : 1.5
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
      for (final point in wire.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) => oldDelegate.wires != wires;
}
