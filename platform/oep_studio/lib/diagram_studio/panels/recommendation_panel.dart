import 'package:flutter/material.dart';

import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';
import 'intelligence_panel_shared.dart';

/// AP-DS-003 Recommendation Panel: live Engineering Recommendations
/// (missing connection, invalid connector, recommended splice, fuse
/// sizing guidance, grounding recommendations, documentation
/// recommendations -- the spec's own examples) for the currently
/// selected canvas node, sourced exclusively from
/// [DiagramIntelligenceService.recommendForNode] -- no recommendation
/// logic lives here.
class RecommendationPanel extends StatefulWidget {
  const RecommendationPanel({
    super.key,
    required this.intelligence,
    required this.onSelectNode,
    this.selectedNodeId,
  });

  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;

  /// The single currently-selected canvas node id, or `null` when the
  /// selection is empty/multi -- the host page keeps this in sync with
  /// `engine.registry.selection` (selection-synchronization, item 3).
  final String? selectedNodeId;

  @override
  State<RecommendationPanel> createState() => _RecommendationPanelState();
}

class _RecommendationPanelState extends State<RecommendationPanel> {
  bool _busy = false;
  String? _error;
  ({OepWorkflowResult result, List<String> objectIds})? _last;

  @override
  void didUpdateWidget(RecommendationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNodeId != widget.selectedNodeId) {
      // Stale recommendations for a since-deselected node would be
      // misleading if left on screen — clear them on every selection
      // change rather than requiring a manual re-trigger to notice.
      setState(() {
        _last = null;
        _error = null;
      });
    }
  }

  Future<void> _recommend() async {
    final nodeId = widget.selectedNodeId;
    if (nodeId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.intelligence.recommendForNode(nodeId);
      if (!mounted) return;
      setState(() => _last = outcome);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  nodeId == null ? 'No node selected' : 'Selected: $nodeId',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _busy || nodeId == null ? null : _recommend,
                icon: const Icon(Icons.lightbulb_outline, size: 15),
                label: const Text('Recommend'),
              ),
            ],
          ),
          IntelligenceBusyBar(busy: _busy),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_last != null) ...[
            const SizedBox(height: 8),
            IntelligenceResultSummary(result: _last!.result),
            const SizedBox(height: 10),
            const Text(
              'Related Engineering Objects',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            IntelligenceObjectChips(
              objectIds: _last!.objectIds,
              intelligence: widget.intelligence,
              onSelectNode: widget.onSelectNode,
            ),
          ] else if (!_busy)
            const EiEmptyState(
              icon: Icons.lightbulb_outline,
              message:
                  'Select a node on the canvas and press Recommend for live Engineering Recommendations from the Engineering Intelligence Platform.',
            ),
        ],
      ),
    );
  }
}
