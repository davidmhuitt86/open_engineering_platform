import '../../graph/models/engineering_graph.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../publishing/models/title_block.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../shared/diagram_print_scene.dart';

/// AP-DS-004: renders one diagram sheet to an SVG document string.
///
/// Hand-rolled XML string building — no SVG-writing package added, per
/// this platform's own dependency-skepticism (see `pubspec.yaml`'s
/// comment on why `pdf` specifically was justified). SVG's element model
/// is simple enough that a `StringBuffer` is a perfectly maintainable
/// implementation, unlike PDF's binary/object-graph format.
///
/// Same scope note as `DiagramPdfRenderer`: nodes are drawn as bordered
/// boxes with a text label (symbol id / node id), not the resolved Symbol
/// Library artwork — see that class's doc comment for why.
///
/// Performance: builds output via a single [StringBuffer] and writes each
/// element exactly once (no re-serialization/re-parsing pass), so memory
/// scales roughly linearly with element count rather than
/// quadratically — the specific "obviously memory-pathological pattern"
/// this phase's Performance requirement asks callers to avoid. This was
/// not benchmarked at the phase's stated 100,000-object target; see this
/// package's AP-DS-004 test suite and final report for what was and
/// was not verified at scale.
class DiagramSvgRenderer {
  static String render(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    SymbolProvider? symbols,
    RoutingProvider? routing,
    TitleBlock? titleBlock,
    double padding = 24,
  }) {
    final scene = computePrintScene(graph, layout: layout, symbols: symbols, routing: routing);

    final titleBlockHeight = titleBlock == null ? 0.0 : 90.0;
    final width = scene.contentWidth + padding * 2;
    final height = scene.contentHeight + padding * 2 + titleBlockHeight;

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" '
        'viewBox="0 0 $width $height" font-family="Helvetica, Arial, sans-serif">',
      )
      ..writeln('<rect x="0" y="0" width="$width" height="$height" fill="white"/>')
      ..writeln('<g transform="translate($padding, $padding)">');

    for (final wire in scene.wires) {
      if (wire.points.length < 2) continue;
      final color = wire.highlighted ? '#e67e22' : (wire.selected ? '#2980ff' : '#333333');
      final strokeWidth = wire.highlighted || wire.selected ? 2 : 1;
      final points = wire.points.map((p) => '${p.dx},${p.dy}').join(' ');
      buffer.writeln(
        '<polyline points="$points" fill="none" stroke="$color" stroke-width="$strokeWidth"/>',
      );
    }

    for (final node in scene.nodes) {
      final borderColor = node.highlighted ? '#e67e22' : (node.selected ? '#2980ff' : '#555555');
      final label = _escape(node.symbolId ?? node.nodeId);
      buffer.writeln(
        '<rect x="${node.position.dx}" y="${node.position.dy}" width="${node.width}" '
        'height="${node.height}" fill="none" stroke="$borderColor" stroke-width="1"/>',
      );
      buffer.writeln(
        '<text x="${node.position.dx + 2}" y="${node.position.dy + node.height - 4}" '
        'font-size="7" fill="#111111">$label</text>',
      );
    }

    buffer.writeln('</g>');

    if (titleBlock != null) {
      buffer.writeln(_renderTitleBlock(titleBlock, padding, scene.contentHeight + padding * 2, width - padding * 2));
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  static String _renderTitleBlock(TitleBlock block, double x, double y, double width) {
    final fields = <String, String>{
      'Company': block.company,
      'Project': block.project,
      'Drawing No.': block.drawingNumber,
      'Rev.': block.revision,
      'Engineer': block.engineer,
      'Approver': block.approver,
      'Date': block.date == null ? '' : block.date!.toIso8601String().split('T').first,
      'Scale': block.scale,
      'Sheet': block.sheet,
      'Classification': block.classification,
      ...block.customFields,
    };

    final buffer = StringBuffer()
      ..writeln('<g transform="translate($x, $y)">')
      ..writeln('<rect x="0" y="0" width="$width" height="80" fill="none" stroke="#111111" stroke-width="1"/>');

    final cellWidth = width / (fields.length.clamp(1, 4));
    var i = 0;
    for (final entry in fields.entries) {
      final col = i % 4;
      final row = i ~/ 4;
      final cx = col * cellWidth;
      final cy = row * 26.0;
      buffer.writeln(
        '<text x="${cx + 4}" y="${cy + 10}" font-size="5" fill="#666666">${_escape(entry.key)}</text>',
      );
      buffer.writeln(
        '<text x="${cx + 4}" y="${cy + 20}" font-size="7" fill="#111111">${_escape(entry.value)}</text>',
      );
      i++;
    }
    buffer.writeln('</g>');
    return buffer.toString();
  }

  static String _escape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
