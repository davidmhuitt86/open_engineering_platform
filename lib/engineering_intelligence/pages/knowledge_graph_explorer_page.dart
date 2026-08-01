import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Knowledge Graph Explorer (WP-EKE-008): a read-only visualization of
/// the Knowledge Graph built by the Engineering Knowledge Graph Engine
/// (WP-EKE-002). No graph editing anywhere — selection only changes
/// which node is highlighted/inspected, never the graph's data.
///
/// This project has no existing graph-drawing dependency (checked
/// `pubspec.yaml` and the `diagram_studio`/`knowledge` features before
/// writing this — neither pulls in a node-link visualization package),
/// so rendering uses a simple radial layout drawn with a
/// [CustomPainter], panned/zoomed via the stock [InteractiveViewer]
/// widget — no new pub.dev dependency added, per this Work Package's
/// "minimal dependencies" instruction.
class KnowledgeGraphExplorerPage extends ConsumerStatefulWidget {
  const KnowledgeGraphExplorerPage({super.key});

  @override
  ConsumerState<KnowledgeGraphExplorerPage> createState() => _KnowledgeGraphExplorerPageState();
}

class _KnowledgeGraphExplorerPageState extends ConsumerState<KnowledgeGraphExplorerPage> {
  bool _built = false;
  bool _building = false;
  String? _error;
  OepGraphStatistics? _stats;
  List<List<String>>? _components;
  List<String> _objectIds = const [];
  List<String> _relationshipIds = const [];
  String? _selectedObjectId;
  final Set<String> _collapsed = {};

  Future<void> _build() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _building = true;
      _error = null;
    });
    try {
      bridge.buildKnowledgeGraph();
      final stats = bridge.knowledgeGraphStatistics();
      final components = bridge.connectedComponents();
      final objects = ref.read(foundationRuntimeServiceProvider).objectList ?? const [];
      // Induced subgraph over every known object id gives us the full
      // edge set the Knowledge Graph Engine currently holds.
      final objectIds = [for (final o in objects) o.objectId];
      final subgraph = bridge.knowledgeGraphSubgraph(objectIds);
      setState(() {
        _built = true;
        _stats = stats;
        _components = components;
        _objectIds = subgraph.objectIds;
        _relationshipIds = subgraph.relationshipIds;
      });
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final objects = foundation.objectList ?? const [];
    final relationships = foundation.relationshipList ?? const [];
    final byId = {for (final o in objects) o.objectId: o};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _building ? null : _build,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(_built ? 'Rebuild Graph' : 'Build Knowledge Graph'),
                    ),
                    const SizedBox(width: 12),
                    if (_building) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const Spacer(),
                    const Text('Read-only — pan/zoom to explore', style: TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
                  ],
                ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: EiErrorBanner(message: _error!)),
              if (_collapsed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      const Text('Collapsed:', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                      for (final id in _collapsed)
                        InkWell(
                          onTap: () => setState(() => _collapsed.remove(id)),
                          child: EiChip('${byId[id]?.name ?? id} ×', color: StudioColors.inactive),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: !_built
                    ? const EiEmptyState(icon: Icons.account_tree_outlined, message: 'Build the Knowledge Graph to visualize it.')
                    : _objectIds.isEmpty
                        ? const EiEmptyState(icon: Icons.account_tree_outlined, message: 'Knowledge Graph is empty.')
                        : InteractiveViewer(
                            minScale: 0.2,
                            maxScale: 4,
                            constrained: false,
                            boundaryMargin: const EdgeInsets.all(400),
                            child: SizedBox(
                              width: 1400,
                              height: 1000,
                              child: _GraphCanvas(
                                objectIds: _objectIds,
                                relationships: relationships
                                    .where((r) => !_collapsed.contains(r.sourceObjectId) && !_collapsed.contains(r.targetObjectId))
                                    .toList(),
                                labelOf: (id) => byId[id]?.name ?? id,
                                selectedId: _selectedObjectId,
                                onTapNode: (id) => setState(() => _selectedObjectId = id),
                                onToggleCollapse: (id) => setState(() {
                                  if (_collapsed.contains(id)) {
                                    _collapsed.remove(id);
                                  } else {
                                    _collapsed.add(id);
                                  }
                                }),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stats != null)
                    EiSectionCard(
                      title: 'Graph Statistics',
                      icon: Icons.bar_chart_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EiKeyValueRow('Objects', '${_stats!.objectCount}'),
                          EiKeyValueRow('Relationships', '${_stats!.relationshipCount}'),
                          EiKeyValueRow('Rendered Objects', '${_objectIds.length}'),
                          EiKeyValueRow('Rendered Relationships', '${_relationshipIds.length}'),
                          EiKeyValueRow('Connected Components', '${_stats!.connectedComponentCount}'),
                          EiKeyValueRow('Density', _stats!.density.toStringAsFixed(4)),
                          EiKeyValueRow('Maximum Depth', '${_stats!.maximumDepth}'),
                          EiKeyValueRow('Average Degree', _stats!.averageDegree.toStringAsFixed(2)),
                        ],
                      ),
                    ),
                  if (_components != null)
                    EiSectionCard(
                      title: 'Connected Components (${_components!.length})',
                      icon: Icons.scatter_plot_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _components!.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('Component $i — ${_components![i].length} object(s)',
                                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  if (_selectedObjectId != null)
                    EiSectionCard(
                      title: byId[_selectedObjectId]?.name ?? _selectedObjectId!,
                      icon: Icons.info_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EiKeyValueRow('Object ID', _selectedObjectId!),
                          if (byId[_selectedObjectId] != null) ...[
                            EiKeyValueRow('Type', byId[_selectedObjectId]!.category.label),
                            EiKeyValueRow('Author', byId[_selectedObjectId]!.author),
                          ],
                          EiKeyValueRow(
                            'Degree',
                            '${relationships.where((r) => r.sourceObjectId == _selectedObjectId || r.targetObjectId == _selectedObjectId).length}',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphCanvas extends StatelessWidget {
  const _GraphCanvas({
    required this.objectIds,
    required this.relationships,
    required this.labelOf,
    required this.selectedId,
    required this.onTapNode,
    required this.onToggleCollapse,
  });

  final List<String> objectIds;
  final List<RelationshipSummary> relationships;
  final String Function(String id) labelOf;
  final String? selectedId;
  final void Function(String id) onTapNode;
  final void Function(String id) onToggleCollapse;

  Map<String, Offset> _layout(Size size) {
    final positions = <String, Offset>{};
    final center = Offset(size.width / 2, size.height / 2);
    final n = objectIds.length;
    if (n == 0) return positions;
    if (n == 1) {
      positions[objectIds.first] = center;
      return positions;
    }
    final radius = math.min(size.width, size.height) / 2 - 60;
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      positions[objectIds[i]] = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
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
    const size = Size(1400, 1000);
    final positions = _layout(size);
    return GestureDetector(
      onTapUp: (details) {
        final closest = _closestNode(details.localPosition, positions);
        if (closest != null) onTapNode(closest);
      },
      onLongPressStart: (details) {
        final closest = _closestNode(details.localPosition, positions);
        if (closest != null) onToggleCollapse(closest);
      },
      child: CustomPaint(
        size: size,
        painter: _GraphPainter(
          positions: positions,
          relationships: relationships,
          labelOf: labelOf,
          selectedId: selectedId,
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.positions, required this.relationships, required this.labelOf, required this.selectedId});

  final Map<String, Offset> positions;
  final List<RelationshipSummary> relationships;
  final String Function(String id) labelOf;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = StudioColors.border
      ..strokeWidth = 1;
    final highlightPaint = Paint()
      ..color = StudioColors.selection
      ..strokeWidth = 2;

    for (final r in relationships) {
      final from = positions[r.sourceObjectId];
      final to = positions[r.targetObjectId];
      if (from == null || to == null) continue;
      final highlighted = selectedId != null && (r.sourceObjectId == selectedId || r.targetObjectId == selectedId);
      canvas.drawLine(from, to, highlighted ? highlightPaint : edgePaint);
    }

    for (final entry in positions.entries) {
      final isSelected = entry.key == selectedId;
      final nodePaint = Paint()..color = isSelected ? StudioColors.selection : StudioColors.surfaceRaised;
      final borderPaint = Paint()
        ..color = isSelected ? StudioColors.selection : StudioColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(entry.value, 10, nodePaint);
      canvas.drawCircle(entry.value, 10, borderPaint);

      final label = labelOf(entry.key);
      final painter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      painter.paint(canvas, entry.value + const Offset(12, -6));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.selectedId != selectedId || oldDelegate.relationships != relationships;
  }
}
