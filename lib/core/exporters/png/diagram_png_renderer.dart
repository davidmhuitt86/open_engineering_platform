import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../graph/models/engineering_graph.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../../views/diagram/diagram_scene.dart';
import '../shared/diagram_print_scene.dart';

/// AP-DS-004: rasterizes one diagram sheet to a PNG at a configurable DPI,
/// using `dart:ui`'s offscreen `PictureRecorder` (this package already
/// requires a Flutter binding for `flutter_svg`, so this is not a new
/// platform dependency the way adding `image` as a direct dependency
/// would be — `image` is already pulled in transitively by `pdf`, per
/// pubspec.lock, but is not needed here since `dart:ui` already covers
/// "draw shapes/text, encode PNG" without it).
///
/// Same scope note as the PDF/SVG renderers: nodes are drawn as bordered
/// boxes with a text label, not resolved Symbol Library artwork.
class DiagramPngRenderer {
  /// [dpi] scales the base 96-dpi layout unit -> pixel mapping (96 dpi is
  /// treated as "1 layout unit = 1 px", matching how the on-screen canvas
  /// and the PDF/SVG renderers already treat [DiagramLayoutState]
  /// coordinates as points/px at 1:1).
  static Future<Uint8List> render(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    SymbolProvider? symbols,
    RoutingProvider? routing,
    double dpi = 96,
    double padding = 24,
  }) async {
    final scene = computePrintScene(graph, layout: layout, symbols: symbols, routing: routing);
    final scale = dpi / 96.0;

    final width = ((scene.contentWidth + padding * 2) * scale).clamp(1.0, double.infinity);
    final height = ((scene.contentHeight + padding * 2) * scale).clamp(1.0, double.infinity);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.translate(padding * scale, padding * scale);
    canvas.scale(scale, scale);

    _paintScene(canvas, scene);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode diagram PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  static void _paintScene(ui.Canvas canvas, DiagramScene scene) {
    for (final wire in scene.wires) {
      if (wire.points.length < 2) continue;
      final paint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = wire.highlighted || wire.selected ? 2 : 1
        ..color = wire.highlighted
            ? const ui.Color(0xFFE67E22)
            : (wire.selected ? const ui.Color(0xFF2980FF) : const ui.Color(0xFF333333));
      final path = ui.Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
      for (final point in wire.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final node in scene.nodes) {
      final rect = ui.Rect.fromLTWH(node.position.dx, node.position.dy, node.width, node.height);
      final paint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = node.highlighted
            ? const ui.Color(0xFFE67E22)
            : (node.selected ? const ui.Color(0xFF2980FF) : const ui.Color(0xFF555555));
      canvas.drawRect(rect, paint);

      final label = node.symbolId ?? node.nodeId;
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 7, textAlign: ui.TextAlign.left),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF111111)))
        ..addText(label);
      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: node.width));
      canvas.drawParagraph(paragraph, ui.Offset(node.position.dx + 2, node.position.dy + node.height - 10));
    }
  }
}
