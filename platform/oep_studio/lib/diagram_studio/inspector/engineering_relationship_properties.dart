import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/engineering_inspectable.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/explorer_navigation.dart';
import '../../shared/navigation/unified_navigation.dart';
import '../../shared/widgets/property_field.dart';
import '../../shared/widgets/validation_findings_list.dart';
import '../bridge/diagram_repository_commit_action.dart';

/// Property Inspector mode for a selected Engineering Graph relationship
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). As of WORK_PACKAGE_025
/// (ENGINE-TASK-000122), see `EngineeringNodeProperties`'s doc comment
/// for why evidence links are tappable rows rather than a bare count.
///
/// AP-OEP-DIAGRAM-VALIDATION-001 — see `EngineeringNodeProperties`'s own
/// doc comment for the "Validation Findings" section this mirrors
/// exactly, matched here on `ValidationFinding.subjectId == relationship.id`.
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
    final report = ref.watch(engineeringProjectServiceProvider).validationReport;
    final findings = (report?.findings ?? const []).where((f) => f.subjectId == relationship.id).toList();

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
        // AP-OEP-DIAGRAM-REPOSITORY-001 — see `EngineeringNodeProperties`'s
        // own doc comment on this same action: commits the whole current
        // diagram, not just this relationship.
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: relationship.repositoryRelationshipId == null
              ? OutlinedButton(
                  onPressed: () => commitDiagramToRepository(context, ref),
                  child: const Text('Commit Diagram to Repository', style: TextStyle(fontSize: 12)),
                )
              : InkWell(
                  onTap: () => goToRelationship(context, ref, relationship.repositoryRelationshipId!),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 13, color: StudioColors.selection),
                      SizedBox(width: 4),
                      Text('Go to Repository Relationship', style: TextStyle(color: StudioColors.selection, fontSize: 12)),
                    ],
                  ),
                ),
        ),
        if (findings.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Validation Findings', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          ),
          for (final finding in findings)
            ValidationFindingTile(finding: finding, onTap: () => goToValidationResult(context, ref, finding)),
          const SizedBox(height: 12),
        ],
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
