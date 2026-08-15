import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/engineering_inspectable.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Engineering Graph relationship
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). As of WORK_PACKAGE_025
/// (ENGINE-TASK-000122), see `EngineeringNodeProperties`'s doc comment
/// for why evidence links are tappable rows rather than a bare count.
class EngineeringRelationshipProperties extends ConsumerWidget {
  const EngineeringRelationshipProperties({
    required this.relationship,
    required this.sourceNodeName,
    required this.targetNodeName,
    super.key,
  });

  final EngineeringRelationship relationship;
  final String sourceNodeName;
  final String targetNodeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship ID', value: relationship.id, monospace: true),
        PropertyField(label: 'Relationship Type', value: relationship.relationshipType.name),
        PropertyField(label: 'Source Node', value: sourceNodeName),
        PropertyField(label: 'Target Node', value: targetNodeName),
        PropertyField(
          label: 'Repository Relationship',
          value: relationship.repositoryRelationshipId ?? '(unsaved to Repository)',
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Evidence Links', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        ),
        if (relationship.evidenceLinks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('—', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
          )
        else
          for (final link in relationship.evidenceLinks)
            InkWell(
              onTap: () => ref
                  .read(foundationRuntimeServiceProvider.notifier)
                  .selectEngineeringInspectable(EngineeringInspectable.evidenceLink(relationship.id, link)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 14, color: StudioColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${link.kind.name}: ${link.sourceReference}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: StudioColors.selection, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
