import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/evidence_region.dart';
import 'evidence_link_entries.dart';
import 'link_evidence_dialog.dart';

/// Property Inspector's Evidence Region mode (Work Package 009
/// STUDIO-TASK-000021 Property Inspector: "Extend support for: Evidence
/// Region, Evidence Links, Source Metadata"). Read-only except for the
/// Evidence Links list's own Unlink buttons and the "Link Knowledge
/// Candidate" action — consistent with every other Property Inspector
/// mode (SDD-011: the Property Inspector never edits *fields*; renaming
/// a region happens through the Evidence Browser).
class EvidenceRegionProperties extends ConsumerWidget {
  const EvidenceRegionProperties({required this.region, required this.sourceName, required this.links, super.key});

  final EvidenceRegion region;
  final String sourceName;
  final List<LinkedCandidateEntry> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Region ID', value: region.id, monospace: true),
        PropertyField(label: 'Label', value: region.label),
        PropertyField(label: 'Source', value: sourceName),
        PropertyField(label: 'Page', value: '${region.page}'),
        PropertyField(label: 'Type', value: 'Rectangle'),
        PropertyField(
          label: 'Position',
          value: '${(region.x * 100).toStringAsFixed(1)}%, ${(region.y * 100).toStringAsFixed(1)}%',
        ),
        PropertyField(
          label: 'Size',
          value: '${(region.width * 100).toStringAsFixed(1)}% × ${(region.height * 100).toStringAsFixed(1)}%',
        ),
        PropertyField(label: 'Notes', value: region.notes.isEmpty ? '—' : region.notes),
        PropertyField(label: 'Created', value: formatDateTime(region.createdTime)),
        PropertyField(
          label: 'Modified',
          value: region.modifiedTime == null ? '—' : formatDateTime(region.modifiedTime!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Evidence Links',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Link Knowledge Candidate',
              icon: const Icon(Icons.add_link, size: 16),
              onPressed: () => showLinkKnowledgeCandidatesDialog(context, regionId: region.id),
            ),
          ],
        ),
        if (links.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No linked candidates.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          )
        else
          for (final entry in links)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.candidate.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off, size: 15),
                    onPressed: () => notifier.unlinkEvidence(entry.link.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
