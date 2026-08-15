import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Diagram Layout layer
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). Layers belong to Diagram
/// Layout, never the Engineering Graph — see `oep_engine/docs/
/// LAYER_SYSTEM.md`.
class DiagramLayerProperties extends StatelessWidget {
  const DiagramLayerProperties({required this.layer, super.key});

  final DiagramLayer layer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: layer.name),
        PropertyField(label: 'Layer ID', value: layer.id, monospace: true),
        PropertyField(label: 'Order', value: '${layer.order}'),
        PropertyField(label: 'Visible', value: layer.visible ? 'Yes' : 'No'),
        PropertyField(label: 'Locked', value: layer.locked ? 'Yes' : 'No'),
        PropertyField(label: 'Print Visible', value: layer.printVisible ? 'Yes' : 'No'),
      ],
    );
  }
}
