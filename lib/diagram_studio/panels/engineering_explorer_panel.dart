import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';
import 'intelligence_panel_shared.dart';

/// AP-DS-003 Engineering Explorer panel: navigation of Engineering
/// Objects/Relationships/Packages/Knowledge Domains/object metadata for
/// the currently-selected canvas node, embedded directly into Diagram
/// Studio per the spec's own "Embed Engineering Explorer directly into
/// Diagram Studio" requirement. Sourced exclusively from
/// [DiagramIntelligenceService.inspect] -- no metadata/relationship
/// traversal logic lives here.
class EngineeringExplorerPanel extends StatefulWidget {
  const EngineeringExplorerPanel({
    super.key,
    required this.intelligence,
    required this.onSelectNode,
    this.selectedNodeId,
  });

  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;
  final String? selectedNodeId;

  @override
  State<EngineeringExplorerPanel> createState() => _EngineeringExplorerPanelState();
}

class _EngineeringExplorerPanelState extends State<EngineeringExplorerPanel> {
  bool _busy = false;
  String? _error;
  String? _inspectedForNodeId;
  ({OepWorkflowResult result, List<String> objectIds})? _last;

  @override
  void didUpdateWidget(EngineeringExplorerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNodeId != widget.selectedNodeId && widget.selectedNodeId != null) {
      unawaited(_inspect());
    }
  }

  Future<void> _inspect() async {
    final nodeId = widget.selectedNodeId;
    if (nodeId == null) return;
    final objectId = widget.intelligence.objectIdFor(nodeId);
    if (objectId == null) {
      setState(() {
        _error = 'Node "$nodeId" has not synced to the repository yet.';
        _last = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.intelligence.inspect(InspectionTargetKind.object, objectId);
      if (!mounted) return;
      setState(() {
        _last = outcome;
        _inspectedForNodeId = nodeId;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  nodeId == null ? 'No node selected' : 'Selected: $nodeId',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                iconSize: 16,
                onPressed: _busy || nodeId == null ? null : _inspect,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          IntelligenceBusyBar(busy: _busy),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_last != null && _inspectedForNodeId == nodeId) ...[
            const SizedBox(height: 8),
            IntelligenceResultSummary(result: _last!.result),
            const SizedBox(height: 10),
            const Text(
              'Related Engineering Objects / Relationships',
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
              icon: Icons.account_tree_outlined,
              message:
                  'Select a node on the canvas to inspect its Engineering Object metadata, relationships, and package/domain membership.',
            ),
        ],
      ),
    );
  }
}
