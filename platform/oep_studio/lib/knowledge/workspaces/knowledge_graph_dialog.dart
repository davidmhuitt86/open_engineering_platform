import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/knowledge_graph_edge.dart';
import '../models/knowledge_graph_node.dart';
import '../models/knowledge_session_graph.dart';
import '../widgets/knowledge_placeholder.dart';

const _nodeWidth = 168.0;
const _nodeHeight = 46.0;
const _columnSpacing = 260.0;
const _rowSpacing = 68.0;
const _canvasPadding = 80.0;

/// The Knowledge Session Graph (Work Package 011 STUDIO-TASK-000026):
/// "Provide a visual graph of the active Knowledge Curation Session
/// ... completely independent of Foundation Graph." A dialog, not a
/// new panel — SDD-016's seven-panel Knowledge Studio layout stays
/// frozen, the same "dedicated dialog for a substantial new
/// interactive surface" precedent Work Package 010 established for the
/// Procedure Builder and Specification Editor.
///
/// Built entirely on Flutter framework widgets (`InteractiveViewer` for
/// pan/zoom, `CustomPaint` for edges, `Positioned` for nodes) — no new
/// package dependency. See `docs/KNOWLEDGE_GRAPH.md` § Flutter Package
/// Decision for the evaluation.
Future<void> showKnowledgeGraphDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _KnowledgeGraphDialog());
}

class _KnowledgeGraphDialog extends StatelessWidget {
  const _KnowledgeGraphDialog();

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      child: SizedBox(
        width: math.min(1100, screen.width * 0.9),
        height: math.min(760, screen.height * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Knowledge Session Graph',
                      style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(child: KnowledgeGraphView()),
          ],
        ),
      ),
    );
  }
}

/// The graph's interactive canvas — extracted from the dialog so it
/// could, in principle, be reused elsewhere without dragging the
/// dialog chrome along; only [showKnowledgeGraphDialog] currently
/// embeds it, per this work package's own scope.
class KnowledgeGraphView extends ConsumerStatefulWidget {
  const KnowledgeGraphView({super.key});

  @override
  ConsumerState<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends ConsumerState<KnowledgeGraphView> {
  final _transformationController = TransformationController();
  Map<String, Offset> _positions = const {};
  Size _canvasSize = const Size(400, 400);
  Size _viewportSize = Size.zero;
  bool _didInitialFit = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Deterministic layered layout — Source Material, Evidence Regions,
  /// and Knowledge Candidates each get their own column, left to right,
  /// mirroring the Provenance Explorer's Source Material → Evidence
  /// Region → Knowledge Candidate reading direction. Visual layout is
  /// widget-layer concern, not "graph construction" (which
  /// `KnowledgeGraphService` already owns) — the same split
  /// `pdf_source_viewer.dart` already draws between Evidence Region
  /// *creation* (service) and its on-screen pixel geometry (widget).
  /// Recomputes [_positions]/[_canvasSize] and assigns them directly
  /// (no `setState`) — called synchronously at the top of `build()`,
  /// so the values are current for the same build pass that uses them;
  /// a `setState` here would both be redundant (already mid-rebuild)
  /// and throw ("setState() called during build").
  void _layout(KnowledgeSessionGraph graph) {
    final columns = <KnowledgeGraphNodeKind, List<KnowledgeGraphNode>>{
      KnowledgeGraphNodeKind.sourceMaterial: [],
      KnowledgeGraphNodeKind.evidenceRegion: [],
      KnowledgeGraphNodeKind.candidate: [],
    };
    for (final node in graph.nodes) {
      columns[node.kind]!.add(node);
    }

    final positions = <String, Offset>{};
    var columnIndex = 0;
    var maxRows = 1;
    for (final kind in [
      KnowledgeGraphNodeKind.sourceMaterial,
      KnowledgeGraphNodeKind.evidenceRegion,
      KnowledgeGraphNodeKind.candidate,
    ]) {
      final nodes = columns[kind]!;
      maxRows = math.max(maxRows, nodes.length);
      final x = _canvasPadding + columnIndex * _columnSpacing + _nodeWidth / 2;
      for (var row = 0; row < nodes.length; row++) {
        final y = _canvasPadding + row * _rowSpacing + _nodeHeight / 2;
        positions[nodes[row].id] = Offset(x, y);
      }
      columnIndex++;
    }

    _positions = positions;
    _canvasSize = Size(
      _canvasPadding * 2 + (columnIndex - 1) * _columnSpacing + _nodeWidth,
      _canvasPadding * 2 + maxRows * _rowSpacing,
    );
  }

  void _fitAll() {
    if (_viewportSize.isEmpty || _positions.isEmpty) return;
    final scaleX = _viewportSize.width / _canvasSize.width;
    final scaleY = _viewportSize.height / _canvasSize.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 1.5) * 0.92;
    final dx = (_viewportSize.width - _canvasSize.width * scale) / 2;
    final dy = (_viewportSize.height - _canvasSize.height * scale) / 2;
    // `TransformationController` is itself a `ValueNotifier` — assigning
    // `.value` already notifies `InteractiveViewer` without a `setState`.
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _centerOn(String nodeId) {
    final target = _positions[nodeId];
    if (target == null || _viewportSize.isEmpty) return;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final dx = _viewportSize.width / 2 - target.dx * scale;
    final dy = _viewportSize.height / 2 - target.dy * scale;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final session = foundation.knowledgeSession;

    if (session == null) {
      return const KnowledgePlaceholder(message: 'Create a Knowledge Curation Session to visualize its graph.');
    }

    final graph = foundation.knowledgeSessionGraph!;
    if (graph.isEmpty) {
      return const KnowledgePlaceholder(
        message: 'This session has no Knowledge Candidates, Evidence Regions, or Source Material yet.',
      );
    }

    _layout(graph);
    // Mutually exclusive by construction (Connection Manager's
    // existing selection model) — at most one of these is non-null.
    final selectedId =
        foundation.selectedCandidate?.id ?? foundation.selectedEvidenceRegion?.id ?? foundation.selectedSourceMaterial?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _fitAll,
                icon: const Icon(Icons.fit_screen, size: 14),
                label: const Text('Fit All'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: selectedId == null ? null : () => _centerOn(selectedId),
                icon: const Icon(Icons.center_focus_strong, size: 14),
                label: const Text('Center Selection'),
              ),
              const Spacer(),
              const _GraphLegend(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              if (viewport != _viewportSize) {
                _viewportSize = viewport;
                if (!_didInitialFit) {
                  _didInitialFit = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
                }
              }
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(600),
                  minScale: 0.1,
                  maxScale: 3,
                  child: SizedBox(
                    width: _canvasSize.width,
                    height: _canvasSize.height,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: _canvasSize,
                          painter: _GraphEdgePainter(edges: graph.edges, positions: _positions),
                        ),
                        for (final node in graph.nodes)
                          if (_positions[node.id] != null)
                            Positioned(
                              left: _positions[node.id]!.dx - _nodeWidth / 2,
                              top: _positions[node.id]!.dy - _nodeHeight / 2,
                              width: _nodeWidth,
                              height: _nodeHeight,
                              child: _GraphNodeChip(
                                node: node,
                                selected: node.id == selectedId,
                                onTap: () => notifier.selectGraphNode(node),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({required this.node, required this.selected, required this.onTap});

  final KnowledgeGraphNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? StudioColors.selection : StudioColors.border;
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.14) : StudioColors.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(node.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  _GraphEdgePainter({required this.edges, required this.positions});

  final List<KnowledgeGraphEdge> edges;
  final Map<String, Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = positions[edge.sourceNodeId];
      final to = positions[edge.targetNodeId];
      if (from == null || to == null) continue;
      final paint = Paint()
        ..color = _colorFor(edge.kind).withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(from, to, paint);
    }
  }

  Color _colorFor(KnowledgeGraphEdgeKind kind) => switch (kind) {
    KnowledgeGraphEdgeKind.relationshipCandidate => StudioColors.selection,
    KnowledgeGraphEdgeKind.evidenceLink => StudioColors.warning,
    KnowledgeGraphEdgeKind.sourceContainsRegion => StudioColors.textSecondary,
    KnowledgeGraphEdgeKind.procedureReference => StudioColors.success,
  };

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.positions != positions;
}

class _GraphLegend extends StatelessWidget {
  const _GraphLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _swatch(StudioColors.selection, 'Relationship'),
        _swatch(StudioColors.warning, 'Evidence Link'),
        _swatch(StudioColors.textSecondary, 'Contains'),
        _swatch(StudioColors.success, 'Procedure Ref'),
      ],
    );
  }

  Widget _swatch(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 2, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5)),
        ],
      ),
    );
  }
}
