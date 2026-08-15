import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/procedure_step.dart';

/// Property Inspector's Procedure Step mode (Work Package 010: "Extend
/// support for: ... Procedure Step" — the one new top-level mode this
/// work package adds; see `KnowledgeCandidateProperties`'s doc comment
/// for why Specification/Validation Status are sections instead).
/// Read-only, like every other Property Inspector mode — editing a step
/// happens through the Procedure Builder, not here.
class ProcedureStepProperties extends ConsumerWidget {
  const ProcedureStepProperties({required this.step, super.key});

  final ProcedureStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final siblings = foundation.procedureStepsFor(step.candidateId);
    final stepNumber = siblings.indexWhere((entry) => entry.id == step.id) + 1;
    final parentName = _candidateName(foundation.candidates, step.candidateId);
    final referencedCandidateNames = [
      for (final id in step.referencedCandidateIds) _candidateName(foundation.candidates, id),
    ];
    final referencedRegionLabels = [
      for (final id in step.referencedRegionIds) _regionLabel(foundation.evidenceRegions, id),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Step ID', value: step.id, monospace: true),
        PropertyField(label: 'Procedure', value: parentName),
        PropertyField(label: 'Step Number', value: stepNumber > 0 ? '$stepNumber' : '—'),
        PropertyField(label: 'Title', value: step.title),
        PropertyField(label: 'Description', value: step.description.isEmpty ? '—' : step.description),
        PropertyField(label: 'Notes', value: step.notes.isEmpty ? '—' : step.notes),
        PropertyField(
          label: 'Referenced Knowledge Candidates',
          value: referencedCandidateNames.isEmpty ? '—' : referencedCandidateNames.join(', '),
        ),
        PropertyField(
          label: 'Referenced Evidence Regions',
          value: referencedRegionLabels.isEmpty ? '—' : referencedRegionLabels.join(', '),
        ),
        PropertyField(label: 'Created', value: formatDateTime(step.createdTime)),
        PropertyField(label: 'Modified', value: step.modifiedTime == null ? '—' : formatDateTime(step.modifiedTime!)),
      ],
    );
  }

  static String _candidateName(List<KnowledgeCandidate> candidates, String candidateId) {
    for (final candidate in candidates) {
      if (candidate.id == candidateId) return candidate.name;
    }
    return candidateId;
  }

  static String _regionLabel(List<EvidenceRegion> regions, String regionId) {
    for (final region in regions) {
      if (region.id == regionId) return region.label;
    }
    return regionId;
  }
}
