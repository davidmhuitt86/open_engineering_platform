import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/relationship_candidate.dart';

/// Property Inspector's Relationship Candidate mode (Work Package 008
/// Property Inspector: "Display: ... Relationship Candidate").
class RelationshipCandidateProperties extends StatelessWidget {
  const RelationshipCandidateProperties({
    required this.relationship,
    required this.sourceName,
    required this.targetName,
    super.key,
  });

  final RelationshipCandidate relationship;
  final String sourceName;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship Candidate ID', value: relationship.id, monospace: true),
        PropertyField(label: 'Relationship Type', value: relationship.type.label),
        PropertyField(label: 'Source Candidate', value: sourceName),
        PropertyField(label: 'Target Candidate', value: targetName),
        PropertyField(
          label: 'Description',
          value: relationship.description.isEmpty ? '—' : relationship.description,
        ),
        PropertyField(label: 'Created', value: formatDateTime(relationship.createdTime)),
        PropertyField(
          label: 'Modified',
          value: relationship.modifiedTime == null ? '—' : formatDateTime(relationship.modifiedTime!),
        ),
      ],
    );
  }
}
