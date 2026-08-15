import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Provenance Explorer (Work Package 011 STUDIO-TASK-000027):
/// "Knowledge Candidate → Evidence Region(s) → Page Selection → Source
/// Material. Display all supporting evidence. Support navigation in
/// both directions." — the Property Inspector's Provenance tab within
/// Knowledge Candidate mode (`knowledge_candidate_properties.dart`).
///
/// "Both directions" is satisfied by two halves working together: this
/// section navigates *down* the chain (tapping a region/source selects
/// it); the Evidence Region's own Property Inspector view
/// (`evidence_region_properties.dart`, Work Package 009) already lists
/// and navigates *up* to every linked Knowledge Candidate.
class CandidateProvenanceSection extends ConsumerWidget {
  const CandidateProvenanceSection({required this.candidateId, super.key});

  final String candidateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final provenance = foundation.provenanceFor(candidateId);

    if (!provenance.hasEvidence) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No supporting evidence yet. Link an Evidence Region from the Properties tab to build this candidate\'s provenance chain.',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in provenance.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: StudioColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChainStep(
                    icon: Icons.crop_din,
                    label: 'Evidence Region',
                    value: '${entry.region.label} (page ${entry.region.page})',
                    onTap: () => notifier.selectEvidenceRegion(entry.region),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Icon(Icons.arrow_downward, size: 14, color: StudioColors.textSecondary),
                  ),
                  _ChainStep(
                    icon: Icons.check_box_outlined,
                    label: 'Page Selection',
                    value: entry.pageSelection == null ? 'Not selected as a page' : 'Page ${entry.pageSelection!.page}',
                    onTap: null,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Icon(Icons.arrow_downward, size: 14, color: StudioColors.textSecondary),
                  ),
                  _ChainStep(
                    icon: Icons.description_outlined,
                    label: 'Source Material',
                    value: entry.source?.originalFileName ?? 'Missing — this source was removed.',
                    onTap: entry.source == null ? null : () => notifier.selectSourceMaterial(entry.source!),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChainStep extends StatelessWidget {
  const _ChainStep({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, size: 14, color: StudioColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5)),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onTap == null ? StudioColors.textSecondary : StudioColors.selection,
                  fontSize: 12,
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
