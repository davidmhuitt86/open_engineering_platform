import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Engineering Graph group
/// (WORK_PACKAGE_024, ENGINE-TASK-000110).
class EngineeringGroupProperties extends StatelessWidget {
  const EngineeringGroupProperties({required this.group, super.key});

  final EngineeringGroup group;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: group.displayName),
        PropertyField(label: 'Group ID', value: group.id, monospace: true),
        PropertyField(label: 'Kind', value: group.kind.name),
        PropertyField(label: 'Members', value: '${group.memberNodeIds.length} node(s)'),
        PropertyField(label: 'Parent Group', value: group.parentGroupId ?? '(top level)'),
        PropertyField(label: 'Locked', value: group.locked ? 'Yes' : 'No'),
      ],
    );
  }
}
