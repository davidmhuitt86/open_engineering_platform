import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Diagram Layout annotation
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). Annotations belong to Diagram
/// Layout, never the Engineering Graph — see `oep_engine/docs/
/// ANNOTATION_SYSTEM.md`.
class DiagramAnnotationProperties extends StatelessWidget {
  const DiagramAnnotationProperties({required this.annotation, super.key});

  final DiagramAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Text', value: annotation.text),
        PropertyField(label: 'Annotation ID', value: annotation.id, monospace: true),
        PropertyField(label: 'Type', value: annotation.type.name),
        PropertyField(label: 'Rotation', value: '${annotation.rotation}°'),
        PropertyField(label: 'Anchor Node', value: annotation.anchorNodeId ?? '(unanchored)'),
        PropertyField(
          label: 'Anchor Relationship',
          value: annotation.anchorRelationshipId ?? '(unanchored)',
        ),
      ],
    );
  }
}
