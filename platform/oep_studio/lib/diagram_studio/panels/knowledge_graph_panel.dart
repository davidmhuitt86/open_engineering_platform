import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';
import 'intelligence_panel_shared.dart';

/// AP-DS-003 Knowledge Graph panel: neighborhood/dependency
/// visualization for the currently-selected canvas node -- "Highlight
/// connected objects", "Dependency visualization", "Neighborhood
/// visualization" (the spec's own bullets), rendered here as the
/// connected-object chip list every other Intelligence panel uses,
/// consistent with "Diagram Studio never duplicates engineering logic":
/// the actual graph traversal is entirely
/// [DiagramIntelligenceService.query] (Foundation's Knowledge Graph),
/// not a Studio-side reimplementation. "Canvas selection and graph
/// selection remain synchronized" is satisfied by [onSelectNode] --
/// tapping a chip drives the same canvas select+frame path the host page
/// uses for search results.
class KnowledgeGraphPanel extends StatefulWidget {
  const KnowledgeGraphPanel({
    super.key,
    required this.intelligence,
    required this.onSelectNode,
    this.selectedNodeId,
  });

  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;
  final String? selectedNodeId;

  @override
  State<KnowledgeGraphPanel> createState() => _KnowledgeGraphPanelState();
}

class _KnowledgeGraphPanelState extends State<KnowledgeGraphPanel> {
  QueryCategory _category = QueryCategory.neighborhood;
  bool _busy = false;
  String? _error;
  String? _queriedForNodeId;
  ({OepWorkflowResult result, List<String> objectIds})? _last;

  @override
  void didUpdateWidget(KnowledgeGraphPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNodeId != widget.selectedNodeId) {
      setState(() {
        _last = null;
        _error = null;
      });
    }
  }

  Future<void> _run() async {
    final nodeId = widget.selectedNodeId;
    if (nodeId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.intelligence.query(_category, nodeId);
      if (!mounted) return;
      setState(() {
        _last = outcome;
        _queriedForNodeId = nodeId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeId = widget.selectedNodeId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nodeId == null ? 'No node selected' : 'Selected: $nodeId',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<QueryCategory>(
                  initialValue: _category,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Traversal', isDense: true),
                  items: [
                    for (final c in QueryCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy || nodeId == null ? null : _run,
                icon: const Icon(Icons.hub_outlined, size: 15),
                label: const Text('Visualize'),
              ),
            ],
          ),
          IntelligenceBusyBar(busy: _busy),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_last != null && _queriedForNodeId == nodeId) ...[
            const SizedBox(height: 8),
            IntelligenceResultSummary(result: _last!.result),
            const SizedBox(height: 10),
            Text(
              'Connected Objects (${_last!.objectIds.length})',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (_last!.objectIds.isNotEmpty)
              KnowledgeGraphRadialView(
                centerId: nodeId!,
                connectedIds: _last!.objectIds,
                labelOf: (id) => widget.intelligence.nodeIdFor(id) ?? id,
                onTapNode: (id) {
                  final resolvedNodeId = id == nodeId ? null : widget.intelligence.nodeIdFor(id);
                  if (resolvedNodeId != null) widget.onSelectNode(resolvedNodeId);
                },
              ),
            const SizedBox(height: 8),
            IntelligenceObjectChips(
              objectIds: _last!.objectIds,
              intelligence: widget.intelligence,
              onSelectNode: widget.onSelectNode,
            ),
          ] else if (!_busy)
            const EiEmptyState(
              icon: Icons.hub_outlined,
              message:
                  'Select a node and a traversal to highlight connected objects, dependencies, and neighborhoods from the Knowledge Graph.',
            ),
        ],
      ),
    );
  }
}

/// Radial visualization of a query's center object and the connected
/// object ids it returned, panned/zoomed via the stock
/// [InteractiveViewer], drawn with a [CustomPainter] -- the same
/// dependency-free approach `knowledge_graph_explorer_page.dart` (the
/// read-only WP-EKE-008 reference page) already uses, adapted here to
/// the single center-node star topology [DiagramIntelligenceService.query]
/// actually returns (a flat object-id list, not an edge list) rather
/// than inventing relationship data this panel has no source for.
class KnowledgeGraphRadialView extends StatelessWidget {
  const KnowledgeGraphRadialView({
    super.key,
    required this.centerId,
    required this.connectedIds,
    required this.labelOf,
    required this.onTapNode,
  });

  final String centerId;
  final List<String> connectedIds;
  final String Function(String id) labelOf;
  final void Function(String id) onTapNode;

  @override
  Widget build(BuildContext context) {
    const size = Size(700, 500);
    return Container(
      height: 260,
      decoration: BoxDecoration(border: Border.all(color: StudioColors.border), borderRadius: BorderRadius.circular(4)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: InteractiveViewer(
          minScale: 0.3,
          maxScale: 4,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(200),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: _RadialGraphCanvas(centerId: centerId, connectedIds: connectedIds, labelOf: labelOf, onTapNode: onTapNode),
          ),
        ),
      ),
    );
  }
}

class _RadialGraphCanvas extends StatelessWidget {
  const _RadialGraphCanvas({required this.centerId, required this.connectedIds, required this.labelOf, required this.onTapNode});

  final String centerId;
  final List<String> connectedIds;
  final String Function(String id) labelOf;
  final void Function(String id) onTapNode;

  Map<String, Offset> _layout(Size size) {
    final positions = <String, Offset>{centerId: Offset(size.width / 2, size.height / 2)};
    final n = connectedIds.length;
    if (n == 0) return positions;
    final radius = math.min(size.width, size.height) / 2 - 60;
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      positions[connectedIds[i]] = positions[centerId]! + Offset(radius * math.cos(angle), radius * math.sin(angle));
    }
    return positions;
  }

  String? _closestNode(Offset local, Map<String, Offset> positions) {
    String? closest;
    double closestDist = 22;
    for (final entry in positions.entries) {
      final d = (entry.value - local).distance;
      if (d < closestDist) {
        closestDist = d;
        closest = entry.key;
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    const size = Size(700, 500);
    final positions = _layout(size);
    return GestureDetector(
      onTapUp: (details) {
        final closest = _closestNode(details.localPosition, positions);
        if (closest != null) onTapNode(closest);
      },
      child: CustomPaint(
        size: size,
        painter: _RadialGraphPainter(positions: positions, centerId: centerId, labelOf: labelOf),
      ),
    );
  }
}

class _RadialGraphPainter extends CustomPainter {
  _RadialGraphPainter({required this.positions, required this.centerId, required this.labelOf});

  final Map<String, Offset> positions;
  final String centerId;
  final String Function(String id) labelOf;

  @override
  void paint(Canvas canvas, Size size) {
    final center = positions[centerId];
    final edgePaint = Paint()
      ..color = StudioColors.selection.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    if (center != null) {
      for (final entry in positions.entries) {
        if (entry.key == centerId) continue;
        canvas.drawLine(center, entry.value, edgePaint);
      }
    }

    for (final entry in positions.entries) {
      final isCenter = entry.key == centerId;
      final nodePaint = Paint()..color = isCenter ? StudioColors.selection : StudioColors.surfaceRaised;
      final borderPaint = Paint()
        ..color = isCenter ? StudioColors.selection : StudioColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(entry.value, isCenter ? 12 : 9, nodePaint);
      canvas.drawCircle(entry.value, isCenter ? 12 : 9, borderPaint);

      final painter = TextPainter(
        text: TextSpan(text: labelOf(entry.key), style: const TextStyle(color: StudioColors.textPrimary, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 110);
      painter.paint(canvas, entry.value + const Offset(12, -6));
    }
  }

  @override
  bool shouldRepaint(covariant _RadialGraphPainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.centerId != centerId;
  }
}
