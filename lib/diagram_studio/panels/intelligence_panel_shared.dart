import 'package:flutter/material.dart';

import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';

/// AP-DS-003: shared rendering pieces for Diagram Studio's Engineering
/// Intelligence panels (Recommendation / Engineering Explorer / Knowledge
/// Graph / Query Console / Knowledge Sessions) -- kept dependency-free
/// like `engineering_intelligence/widgets/ei_widgets.dart` itself (which
/// this reuses, per "adapt what's already proven" rather than reinventing
/// result/chip/loading rendering per panel), and used by every panel file
/// so "tap an object chip -> canvas selects/frames the node" is
/// implemented exactly once.
class IntelligenceResultSummary extends StatelessWidget {
  const IntelligenceResultSummary({super.key, required this.result});

  final OepWorkflowResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            EiChip(
              result.success ? 'Success' : 'Failed',
              color: result.success ? StudioColors.success : StudioColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              '${result.executionTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(result.summary, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
      ],
    );
  }
}

/// Tappable chips for a workflow's affected Foundation object ids --
/// translated to canvas node ids via [DiagramIntelligenceService.nodeIdFor]
/// (AP-DS-003's only id-space translation point). An object id that isn't
/// a decomposed diagram node (the Diagram object itself, an object from a
/// different diagram the query touched, etc.) renders as a disabled chip
/// rather than being silently dropped, so the visible count always
/// matches what the Engineering Intelligence Platform actually returned.
class IntelligenceObjectChips extends StatelessWidget {
  const IntelligenceObjectChips({
    super.key,
    required this.objectIds,
    required this.intelligence,
    required this.onSelectNode,
  });

  final List<String> objectIds;
  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;

  @override
  Widget build(BuildContext context) {
    if (objectIds.isEmpty) {
      return const Text(
        'No related Engineering Objects.',
        style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final objectId in objectIds) _chip(objectId, intelligence.nodeIdFor(objectId))],
    );
  }

  Widget _chip(String objectId, String? nodeId) {
    return ActionChip(
      label: Text(nodeId ?? objectId, style: const TextStyle(fontSize: 11)),
      backgroundColor:
          nodeId == null ? StudioColors.surfaceRaised : StudioColors.selection.withValues(alpha: 0.12),
      onPressed: nodeId == null ? null : () => onSelectNode(nodeId),
    );
  }
}

class IntelligenceBusyBar extends StatelessWidget {
  const IntelligenceBusyBar({super.key, required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!busy) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
    );
  }
}
