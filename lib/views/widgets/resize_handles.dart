import 'package:flutter/material.dart';

/// Which corner/edge a resize handle drags (AP-DS-001A: "Resize
/// support" — corner/edge handles when a single node is selected).
enum ResizeHandleKind { topLeft, topRight, bottomLeft, bottomRight }

/// Four corner resize handles drawn around a node's current
/// position/size, shown only while exactly one node is selected — the
/// same "handles overlay a Stack-positioned rect" pattern as
/// [WireEditHandles]/`ReconnectHandle`, kept in the Engine package
/// alongside them since it's rendering-model, not Studio chrome.
class ResizeHandles extends StatelessWidget {
  final Offset position;
  final Size size;
  final void Function(ResizeHandleKind handle) onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;

  const ResizeHandles({
    super.key,
    required this.position,
    required this.size,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _handle(ResizeHandleKind.topLeft, Offset(position.dx, position.dy)),
        _handle(ResizeHandleKind.topRight, Offset(position.dx + size.width, position.dy)),
        _handle(ResizeHandleKind.bottomLeft, Offset(position.dx, position.dy + size.height)),
        _handle(ResizeHandleKind.bottomRight,
            Offset(position.dx + size.width, position.dy + size.height)),
      ],
    );
  }

  Widget _handle(ResizeHandleKind kind, Offset point) {
    final cursor = switch (kind) {
      ResizeHandleKind.topLeft || ResizeHandleKind.bottomRight =>
        SystemMouseCursors.resizeUpLeftDownRight,
      ResizeHandleKind.topRight || ResizeHandleKind.bottomLeft =>
        SystemMouseCursors.resizeUpRightDownLeft,
    };
    return Positioned(
      left: point.dx - 5,
      top: point.dy - 5,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onDragStart(kind),
          onPanUpdate: (details) => onDragUpdate(details.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 1.5),
              shape: BoxShape.rectangle,
            ),
          ),
        ),
      ),
    );
  }
}
