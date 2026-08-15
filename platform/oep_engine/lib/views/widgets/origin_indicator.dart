import 'package:flutter/material.dart';

/// A small crosshair marker at scene (0,0) (WORK_PACKAGE_022,
/// ENGINE-TASK-000096: "Origin Indicator").
class OriginIndicator extends StatelessWidget {
  const OriginIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: -10,
      top: -10,
      child: IgnorePointer(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(painter: _CrosshairPainter()),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) => false;
}
