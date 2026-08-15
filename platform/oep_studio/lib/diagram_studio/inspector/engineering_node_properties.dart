import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/engineering_inspectable.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/property_field.dart';

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
class EngineeringNodeProperties extends ConsumerWidget {
  const EngineeringNodeProperties({required this.node, this.symbolName, super.key});

  final EngineeringNode node;
  final String? symbolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        PropertyField(label: 'Ports', value: node.ports.isEmpty ? '—' : node.ports.map((p) => p.name).join(', ')),
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
