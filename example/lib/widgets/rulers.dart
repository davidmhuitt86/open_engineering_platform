import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Horizontal/vertical drafting rulers (WORK_PACKAGE_022,
/// ENGINE-TASK-000096). Screen-space widgets — they read [viewState] to
/// map scene positions (from [GridComputer]) to screen pixels themselves;
/// the engine only ever computes scene-space grid geometry.
class HorizontalRuler extends StatelessWidget {
  final ViewState viewState;
  final double width;

  const HorizontalRuler({super.key, required this.viewState, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 20,
      child: CustomPaint(painter: _RulerPainter(viewState: viewState, horizontal: true)),
    );
  }
}

class VerticalRuler extends StatelessWidget {
  final ViewState viewState;
  final double height;

  const VerticalRuler({super.key, required this.viewState, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: height,
      child: CustomPaint(painter: _RulerPainter(viewState: viewState, horizontal: false)),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final ViewState viewState;
  final bool horizontal;

  _RulerPainter({required this.viewState, required this.horizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = viewState.zoom == 0 ? 1.0 : viewState.zoom;
    final pan = horizontal ? viewState.pan.dx : viewState.pan.dy;
    final extent = horizontal ? size.width : size.height;

    final sceneStart = -pan / zoom;
    final sceneEnd = (extent - pan) / zoom;
    final bounds = horizontal
        ? Rect2D(left: sceneStart, top: 0, right: sceneEnd, bottom: 0)
        : Rect2D(left: 0, top: sceneStart, right: 0, bottom: sceneEnd);

    final lines = GridComputer.computeLines(viewState.grid, bounds)
        .where((l) => horizontal ? l.axis == GridAxis.vertical : l.axis == GridAxis.horizontal);

    final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final tickPaint = Paint()..color = Colors.black45;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final line in lines) {
      final screenPos = line.position * zoom + pan;
      if (screenPos < 0 || screenPos > extent) continue;
      final tickLength = line.isMajor ? 8.0 : 4.0;
      if (horizontal) {
        canvas.drawLine(
          Offset(screenPos, size.height - tickLength),
          Offset(screenPos, size.height),
          tickPaint,
        );
      } else {
        canvas.drawLine(
          Offset(size.width - tickLength, screenPos),
          Offset(size.width, screenPos),
          tickPaint,
        );
      }
      if (line.isMajor) {
        textPainter.text = TextSpan(
          text: line.position.round().toString(),
          style: const TextStyle(color: Colors.black54, fontSize: 9),
        );
        textPainter.layout();
        if (horizontal) {
          textPainter.paint(canvas, Offset(screenPos + 2, 2));
        } else {
          textPainter.paint(canvas, Offset(2, screenPos + 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.viewState.zoom != viewState.zoom || oldDelegate.viewState.pan != viewState.pan;
}
