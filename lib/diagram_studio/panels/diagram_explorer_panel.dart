import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// Object Explorer (Phase 3 restructuring of "Diagram Explorer" --
/// WORK_PACKAGE_024, ENGINE-TASK-000114; a Studio-styled port of the
/// Demonstration Host's `GraphExplorerPanel`).
///
/// The approved renders (`03_Engineering_Workspace.png`,
/// `05_Interactive_Wiring_Diagram_Editor.png`) show a Vehicle →
/// System/Subsystem → Diagram/Component hierarchy. This build has no
/// `Vehicle` domain model or repository anywhere (grepped, confirmed
/// absent) -- there is no real data to root a "Vehicle" level with, and
/// inventing one would violate this phase's own "do not fabricate
/// engineering data" instruction. What genuinely exists is each node's
/// [EngineeringNode.category], so this groups by that instead: a real,
/// two-level hierarchy (Category → Node) built entirely from data the
/// Engineering Graph already has, rather than a flat list or a fabricated
/// vehicle root. See `docs/ui_refactor/PHASE_3_NOTES.md` for the
/// Vehicle-hierarchy gap this leaves for `oep_design_system`/a future
/// Vehicle domain model to resolve.
class DiagramExplorerPanel extends StatelessWidget {
  const DiagramExplorerPanel({
    required this.graph,
    required this.selection,
    required this.onSelectNode,
    super.key,
  });

  final EngineeringGraph graph;
  final GraphSelection selection;
  final void Function(String nodeId) onSelectNode;

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No nodes yet. Add one from the Placement toolbar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final byCategory = <String, List<EngineeringNode>>{};
    for (final node in graph.nodes.values) {
      byCategory.putIfAbsent(node.category.name, () => []).add(node);
    }
    final categories = byCategory.keys.toList()..sort();
    for (final nodes in byCategory.values) {
      nodes.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    return ListView(
      children: [
        for (final category in categories)
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
            key: PageStorageKey('object-explorer-category-$category'),
            initiallyExpanded: true,
            dense: true,
            title: Text(
              '$category (${byCategory[category]!.length})',
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            iconColor: StudioColors.textSecondary,
            collapsedIconColor: StudioColors.textSecondary,
            children: [
              for (final node in byCategory[category]!)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 24, right: 16),
                    selected: selection.containsNode(node.id),
                    selectedTileColor: StudioColors.selection.withValues(alpha: 0.15),
                    title: Text(
                      node.displayName,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    onTap: () => onSelectNode(node.id),
                  ),
                ),
            ],
            ),
          ),
      ],
    );
  }
}
