import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Symbol/Node port
/// (WORK_PACKAGE_024, ENGINE-TASK-000110).
class EngineeringPortProperties extends StatelessWidget {
  const EngineeringPortProperties({required this.port, required this.ownerNodeId, super.key});

  final Port port;
  final String ownerNodeId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: port.name),
        PropertyField(label: 'Port ID', value: port.id, monospace: true),
        PropertyField(label: 'Owner Node', value: ownerNodeId, monospace: true),
        PropertyField(label: 'Direction', value: port.direction.name),
        PropertyField(label: 'Type', value: port.type),
      ],
    );
  }
}
