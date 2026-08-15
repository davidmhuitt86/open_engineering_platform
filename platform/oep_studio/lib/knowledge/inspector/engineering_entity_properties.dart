import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/candidate_validation_result.dart';
import '../models/engineering_entity.dart';
import '../models/engineering_pattern.dart';
import '../models/entity_validation_result.dart';

/// Property Inspector's Engineering Entity mode (Work Package 014:
/// "Extend support for: Engineering Entity, Pattern Match, Validation,
/// Source Context").
class EngineeringEntityProperties extends StatelessWidget {
  const EngineeringEntityProperties({
    required this.entity,
    required this.sourceName,
    this.pattern,
    this.validation,
    super.key,
  });

  final EngineeringEntity entity;
  final String sourceName;

  /// The pattern that produced this entity (Work Package 014 Connection
  /// Manager: "Current Pattern"), `null` only defensively.
  final EngineeringPattern? pattern;

  /// This entity's computed validation (Work Package 014 Connection
  /// Manager: "Current Validation"), `null` only defensively.
  final EntityValidationResult? validation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Entity ID', value: entity.id, monospace: true),
        PropertyField(label: 'Entity Type', value: entity.type.label),
        PropertyField(label: 'Extracted Text', value: entity.extractedText),
        PropertyField(label: 'Normalized Value', value: entity.normalizedValue),
        PropertyField(label: 'Confidence', value: '${(entity.confidence * 100).round()}%'),
        PropertyField(label: 'Status', value: _statusLabel(entity)),
        if (entity.createdCandidateId != null)
          PropertyField(label: 'Knowledge Candidate', value: entity.createdCandidateId!, monospace: true),
        const SizedBox(height: 8),
        const Text('Pattern Match', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Matched Pattern', value: pattern?.label ?? entity.matchedPatternId),
        PropertyField(label: 'Character Range', value: '${entity.characterStart}–${entity.characterEnd}'),
        const SizedBox(height: 8),
        const Text('Source Context', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Source Material', value: sourceName),
        PropertyField(label: 'Page', value: '${entity.page}'),
        PropertyField(label: 'Extracted', value: formatDateTime(entity.extractedTime)),
        if (validation != null && validation!.issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Validation',
            style: TextStyle(
              color: validation!.severity == ValidationSeverity.error ? StudioColors.error : StudioColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final issue in validation!.issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    validation!.severity == ValidationSeverity.error ? Icons.error_outline : Icons.warning_amber_outlined,
                    size: 14,
                    color: validation!.severity == ValidationSeverity.error ? StudioColors.error : StudioColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      issue,
                      style: TextStyle(
                        color: validation!.severity == ValidationSeverity.error ? StudioColors.error : StudioColors.warning,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static String _statusLabel(EngineeringEntity entity) {
    if (entity.isAccepted) return 'Accepted';
    if (entity.isIgnored) return 'Ignored';
    return 'Pending';
  }
}
