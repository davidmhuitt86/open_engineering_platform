import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// Layer panel — list, create, delete, and toggle visibility/lock for
/// Diagram Layout layers (WORK_PACKAGE_024, ENGINE-TASK-000114). A
/// Studio-styled port of the Demonstration Host's Layer Panel dialog
/// (`oep_engine/docs/LAYER_SYSTEM.md`); layers belong to Diagram Layout,
/// never the Engineering Graph.
class DiagramLayerPanel extends StatelessWidget {
  const DiagramLayerPanel({
    required this.layers,
    required this.onSelectLayer,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onCreateLayer,
    required this.onDeleteLayer,
    super.key,
  });

  final List<DiagramLayer> layers;
  final void Function(DiagramLayer layer) onSelectLayer;
  final void Function(String layerId) onToggleVisible;
  final void Function(String layerId) onToggleLocked;
  final VoidCallback onCreateLayer;
  final void Function(String layerId) onDeleteLayer;

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(layers)..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sorted.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No layers yet.',
                      style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final layer = sorted[index];
                    return ListTile(
                      dense: true,
                      onTap: () => onSelectLayer(layer),
                      title: Text(
                        layer.name,
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            iconSize: 16,
                            tooltip: layer.visible ? 'Hide layer' : 'Show layer',
                            icon: Icon(
                              layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: StudioColors.textSecondary,
                            ),
                            onPressed: () => onToggleVisible(layer.id),
                          ),
                          IconButton(
                            iconSize: 16,
                            tooltip: layer.locked ? 'Unlock layer' : 'Lock layer',
                            icon: Icon(
                              layer.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                              color: StudioColors.textSecondary,
                            ),
                            onPressed: () => onToggleLocked(layer.id),
                          ),
                          IconButton(
                            iconSize: 16,
                            tooltip: 'Delete layer',
                            icon: const Icon(Icons.delete_outline, color: StudioColors.error),
                            onPressed: () => onDeleteLayer(layer.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: onCreateLayer,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Layer'),
          ),
        ),
      ],
    );
  }
}
