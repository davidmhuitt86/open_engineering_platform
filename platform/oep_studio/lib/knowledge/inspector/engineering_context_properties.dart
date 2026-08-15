import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/property_field.dart';
import '../models/candidate_validation_result.dart';
import '../models/context_statistics.dart';
import '../models/context_validation_result.dart';
import '../models/engineering_context.dart';
import '../models/engineering_entity.dart';

/// Property Inspector's Engineering Context mode (Work Package 015:
/// "Extend support for: Engineering Context, Context Statistics, Child
/// Entities, Parent Context").
class EngineeringContextProperties extends StatelessWidget {
  const EngineeringContextProperties({
    required this.context,
    required this.sourceName,
    this.statistics,
    this.childEntities = const [],
    this.parentContext,
    this.validation,
    super.key,
  });

  final EngineeringContext context;
  final String sourceName;

  /// Computed child-entity statistics (Connection Manager derived
  /// getter), `null` only defensively.
  final ContextStatistics? statistics;

  /// Resolved from [EngineeringContext.childEntityIds].
  final List<EngineeringEntity> childEntities;

  /// Resolved from [EngineeringContext.parentContextId], `null` for a
  /// top-level context.
  final EngineeringContext? parentContext;

  final ContextValidationResult? validation;

  @override
  Widget build(BuildContext buildContext) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Context ID', value: context.id, monospace: true),
        PropertyField(label: 'Context Type', value: context.type.label),
        PropertyField(label: 'Title', value: context.title),
        PropertyField(label: 'Status', value: _statusLabel(context)),
        const SizedBox(height: 8),
        const Text('Source Context', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Source Material', value: sourceName),
        PropertyField(label: 'Page Range', value: '${context.pageStart}-${context.pageEnd}'),
        PropertyField(label: 'Confidence', value: '${(context.confidence * 100).round()}%'),
        const SizedBox(height: 8),
        const Text('Context Statistics', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Child Entity Count', value: '${statistics?.childEntityCount ?? 0}'),
        PropertyField(
          label: 'Average Child Confidence',
          value: '${((statistics?.averageChildConfidence ?? 0) * 100).round()}%',
        ),
        if (statistics != null && statistics!.entityCountByType.isNotEmpty)
          PropertyField(
            label: 'By Type',
            value: statistics!.entityCountByType.entries.map((e) => '${e.key.label} (${e.value})').join(', '),
          ),
        const SizedBox(height: 8),
        const Text('Parent Context', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(
          label: 'Parent',
          value: parentContext == null ? 'None (top-level)' : '${parentContext!.title} (${parentContext!.type.label})',
        ),
        const SizedBox(height: 8),
        const Text('Child Entities', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (childEntities.isEmpty)
          const Text('No child entities.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
        else
          for (final entity in childEntities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${entity.normalizedValue} (${entity.type.label}, page ${entity.page})',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5),
              ),
            ),
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

  static String _statusLabel(EngineeringContext context) {
    if (context.isAccepted) return 'Accepted';
    if (context.isIgnored) return 'Ignored';
    return 'Pending';
  }
}
