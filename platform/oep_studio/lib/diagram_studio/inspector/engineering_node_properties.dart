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

/// Property Inspector mode for a selected Engineering Graph node
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). Display only, exactly like
/// every other Property Inspector mode (`_ObjectProperties`,
/// `_RelationshipProperties`, ...) — editing goes through Diagram
/// Studio's own toolbar/canvas actions, which execute Engine Commands.
///
/// As of WORK_PACKAGE_025 (ENGINE-TASK-000122), each evidence link is
/// its own tappable row rather than a bare count — tapping one selects
/// it, switching the Property Inspector to
/// `EngineeringEvidenceLinkProperties`, which offers "Go to Evidence"
/// (ENGINE-TASK-000123).
///
/// AP-OEP-DIAGRAM-VALIDATION-001 — a "Validation Findings" section is
/// shown between Ports and Evidence Links, but only when the live
/// `ValidationReport` (`engineeringProjectServiceProvider`, the same
/// app-wide, auto-recomputed authority the global Validation Surface
/// itself reads — no second validation state, nothing cached here)
/// contains at least one finding whose `subjectId` exactly equals this
/// node's own canonical `id`. Activating a finding goes through the
/// existing, already-Workspace-aware `goToValidationResult` — the same
/// helper the Validation Surface and Search already use — never a new
/// navigation path.
class EngineeringNodeProperties extends ConsumerWidget {
  const EngineeringNodeProperties({required this.node, this.symbolName, super.key});

  final EngineeringNode node;
  final String? symbolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(engineeringProjectServiceProvider).validationReport;
    final findings = (report?.findings ?? const []).where((f) => f.subjectId == node.id).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: node.displayName),
        PropertyField(label: 'Node ID', value: node.id, monospace: true),
        PropertyField(label: 'Category', value: node.category.name),
        PropertyField(label: 'Symbol', value: symbolName ?? node.symbolId ?? '—'),
        PropertyField(
          label: 'Repository Object',
          value: node.repositoryObjectId ?? '(unsaved to Repository)',
        ),
        // AP-OEP-DIAGRAM-REPOSITORY-001 — the Repository action lives
        // right next to the field that already shows whether this node
        // is in the Repository, the same discoverability reasoning the
        // Evidence Links section below already uses for its own tappable
        // rows. Committing here commits the *whole* current diagram (the
        // underlying service has no per-node commit — see
        // `EngineGraphCommitService`'s own doc comment), so the action
        // label says "Diagram," not "Node," to avoid implying otherwise.
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: node.repositoryObjectId == null
              ? OutlinedButton(
                  onPressed: () => commitDiagramToRepository(context, ref),
                  child: const Text('Commit Diagram to Repository', style: TextStyle(fontSize: 12)),
                )
              : InkWell(
                  onTap: () => goToObject(context, ref, node.repositoryObjectId!),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 13, color: StudioColors.selection),
                      SizedBox(width: 4),
                      Text('Go to Repository Object', style: TextStyle(color: StudioColors.selection, fontSize: 12)),
                    ],
                  ),
                ),
        ),
        PropertyField(label: 'Ports', value: node.ports.isEmpty ? '—' : node.ports.map((p) => p.name).join(', ')),
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
        if (node.evidenceLinks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('—', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
          )
        else
          for (final link in node.evidenceLinks)
            InkWell(
              onTap: () => ref
                  .read(foundationRuntimeServiceProvider.notifier)
                  .selectEngineeringInspectable(EngineeringInspectable.evidenceLink(node.id, link)),
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
