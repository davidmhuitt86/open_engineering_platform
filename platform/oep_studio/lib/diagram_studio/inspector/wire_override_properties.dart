import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a relationship whose wire route has a
/// manual override (WORK_PACKAGE_024, ENGINE-TASK-000110) — shown while
/// "Edit Route" mode is active (`oep_engine/docs/WIRE_EDITING.md`).
class WireOverrideProperties extends StatelessWidget {
  const WireOverrideProperties({
    required this.relationshipId,
    required this.points,
    super.key,
  });

  final String relationshipId;
  final List<Point2D> points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship', value: relationshipId, monospace: true),
        PropertyField(label: 'Vertices', value: '${points.length}'),
        PropertyField(
          label: 'Route',
          value: points.map((p) => '(${p.dx.toStringAsFixed(0)}, ${p.dy.toStringAsFixed(0)})').join(' → '),
        ),
      ],
    );
  }
}
