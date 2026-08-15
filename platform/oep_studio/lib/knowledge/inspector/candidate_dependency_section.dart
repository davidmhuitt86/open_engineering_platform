import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/candidate_validation_result.dart';

/// The Candidate Dependency Viewer (Work Package 011
/// STUDIO-TASK-000028): "Referenced By, References, Relationships,
/// Procedure Usage, Specification Usage, Evidence Count, Validation
/// Status" — the Property Inspector's Dependencies tab within
/// Knowledge Candidate mode (`knowledge_candidate_properties.dart`).
/// Every candidate/relationship entry is tappable, selecting it via
/// the existing Connection Manager selection methods.
class CandidateDependencySection extends ConsumerWidget {
  const CandidateDependencySection({required this.candidateId, super.key});

  final String candidateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final info = foundation.dependencyFor(candidateId);

    if (info == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This candidate is no longer available.',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Referenced By',
          empty: 'No other candidate\'s Procedure Steps reference this one.',
          children: [
            for (final candidate in info.referencedBy)
              _EntryTile(label: candidate.name, onTap: () => notifier.selectKnowledgeCandidate(candidate)),
          ],
        ),
        _Section(
          title: 'References',
          empty: 'This candidate\'s Procedure Steps (if any) reference nothing yet.',
          children: [
            for (final candidate in info.references)
              _EntryTile(label: candidate.name, onTap: () => notifier.selectKnowledgeCandidate(candidate)),
            for (final region in info.referencedRegions)
              _EntryTile(label: '${region.label} (Evidence Region)', onTap: () => notifier.selectEvidenceRegion(region)),
          ],
        ),
        _Section(
          title: 'Relationships',
          empty: 'No Relationship Candidates connect to this one.',
          children: [
            for (final entry in info.relationships)
              _EntryTile(
                label: '${entry.sourceName} —${entry.relationship.type.label}→ ${entry.targetName}',
                onTap: () => notifier.selectRelationshipCandidate(entry.relationship),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Procedure Usage', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                info.procedureStepCount == null
                    ? 'Not a Procedure candidate.'
                    : '${info.procedureStepCount} step${info.procedureStepCount == 1 ? '' : 's'}',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Specification Usage', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                info.specification == null
                    ? 'Not a Specification candidate, or not yet specified.'
                    : '${info.specification!.specType.label}: ${info.specification!.value} ${info.specification!.unit}',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evidence Count', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              Text('${info.evidenceCount}', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
            ],
          ),
        ),
        if (info.validation != null) _ValidationSummary(validation: info.validation!),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.empty, required this.children});

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (children.isEmpty)
            Text(empty, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
          else
            ...children,
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: StudioColors.selection, fontSize: 12, decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.validation});

  final CandidateValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (validation.severity) {
      ValidationSeverity.error => (Icons.error_outline, StudioColors.error, 'Error'),
      ValidationSeverity.warning => (Icons.warning_amber_outlined, StudioColors.warning, 'Warning'),
      ValidationSeverity.ok => (Icons.check_circle_outline, StudioColors.success, 'OK'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validation Status', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
