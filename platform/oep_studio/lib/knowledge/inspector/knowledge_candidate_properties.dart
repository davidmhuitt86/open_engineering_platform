import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/candidate_validation_result.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../workspaces/procedure_builder_dialog.dart';
import '../workspaces/specification_editor_dialog.dart';
import 'candidate_dependency_section.dart';
import 'candidate_provenance_section.dart';
import 'evidence_link_entries.dart';
import 'link_evidence_dialog.dart';

enum _CandidateTab { properties, provenance, dependencies }

/// Property Inspector's Knowledge Candidate mode (Work Package 007/008
/// Property Inspector: "Display: ... Knowledge Candidate"; Work Package
/// 009: "Knowledge Candidate Evidence"; Work Package 010: extended with
/// Notes/Author/Tags, a Validation Status section, and — conditional on
/// [KnowledgeCandidate.type] — a Specification fields section or a
/// Procedure step-count summary with an "Open Procedure Builder"
/// action; Work Package 011: extended with a local Properties/
/// Provenance/Dependencies tab switch, "Extend support for: ...
/// Provenance, Dependency information").
///
/// "Specification" and "Validation Status" (Work Package 010) are
/// sections *within* the Properties tab rather than separate top-level
/// Property Inspector modes — see `docs/KNOWLEDGE_CANDIDATES.md` §
/// Architectural Observations for why. Provenance and Dependencies
/// (Work Package 011) are **tabs**, not separate top-level modes
/// either, and not sections mixed into Properties — see
/// `docs/KNOWLEDGE_GRAPH.md` § Property Inspector for the reasoning:
/// neither has its own Connection Manager selection field (this work
/// package's own Connection Manager section calls them "Current
/// Provenance View"/"Current Dependency View" — derived getters, not
/// selection state), but unlike Specification/Validation, both can be
/// substantial enough content that folding them permanently into the
/// same scroll as core fields would bury the core fields.
///
/// Read-only except for the Evidence section's own Unlink buttons and
/// "Link Evidence Region" action, and the Procedure/Specification
/// "Open ... Editor" buttons that launch their own dedicated dialogs —
/// editing the candidate's own core fields happens through the
/// Engineering Review panel's Edit action, not here (SDD-011: the
/// Property Inspector never edits in place).
class KnowledgeCandidateProperties extends ConsumerStatefulWidget {
  const KnowledgeCandidateProperties({required this.candidate, required this.links, super.key});

  final KnowledgeCandidate candidate;
  final List<LinkedRegionEntry> links;

  @override
  ConsumerState<KnowledgeCandidateProperties> createState() => _KnowledgeCandidatePropertiesState();
}

class _KnowledgeCandidatePropertiesState extends ConsumerState<KnowledgeCandidateProperties> {
  _CandidateTab _tab = _CandidateTab.properties;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CandidateTabButton(
                  label: 'Properties',
                  selected: _tab == _CandidateTab.properties,
                  onTap: () => setState(() => _tab = _CandidateTab.properties),
                ),
                const SizedBox(width: 6),
                _CandidateTabButton(
                  label: 'Provenance',
                  selected: _tab == _CandidateTab.provenance,
                  onTap: () => setState(() => _tab = _CandidateTab.provenance),
                ),
                const SizedBox(width: 6),
                _CandidateTabButton(
                  label: 'Dependencies',
                  selected: _tab == _CandidateTab.dependencies,
                  onTap: () => setState(() => _tab = _CandidateTab.dependencies),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_tab) {
            _CandidateTab.properties => _PropertiesTab(candidate: widget.candidate, links: widget.links),
            _CandidateTab.provenance => CandidateProvenanceSection(candidateId: widget.candidate.id),
            _CandidateTab.dependencies => CandidateDependencySection(candidateId: widget.candidate.id),
          },
        ),
      ],
    );
  }
}

class _CandidateTabButton extends StatelessWidget {
  const _CandidateTabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? StudioColors.selection : StudioColors.textSecondary,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Properties tab — this mode's original (Work Package 007–010)
/// content, unchanged except for being extracted so
/// [KnowledgeCandidateProperties] could gain the Provenance/
/// Dependencies tabs (Work Package 011) around it.
class _PropertiesTab extends ConsumerWidget {
  const _PropertiesTab({required this.candidate, required this.links});

  final KnowledgeCandidate candidate;
  final List<LinkedRegionEntry> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final validation = foundation.candidateValidation[candidate.id];
    final specification = foundation.specificationDetailsFor(candidate.id);
    final procedureStepCount = foundation.procedureStepsFor(candidate.id).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Knowledge Candidate ID', value: candidate.id, monospace: true),
        PropertyField(label: 'Type', value: candidate.type.label),
        PropertyField(label: 'Name', value: candidate.name),
        PropertyField(label: 'Status', value: candidate.status.label),
        PropertyField(label: 'Description', value: candidate.description.isEmpty ? '—' : candidate.description),
        PropertyField(label: 'Notes', value: candidate.notes.isEmpty ? '—' : candidate.notes),
        PropertyField(label: 'Author', value: candidate.author.isEmpty ? '—' : candidate.author),
        PropertyField(label: 'Tags', value: candidate.tags.isEmpty ? '—' : candidate.tags.join(', ')),
        PropertyField(label: 'Created', value: formatDateTime(candidate.createdTime)),
        PropertyField(
          label: 'Modified',
          value: candidate.modifiedTime == null ? '—' : formatDateTime(candidate.modifiedTime!),
        ),
        if (validation != null) _ValidationSection(validation: validation),
        if (candidate.type == KnowledgeCandidateType.specification) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Specification',
                  style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open Specification Editor',
                icon: const Icon(Icons.open_in_new, size: 15),
                onPressed: () => showSpecificationEditorDialog(context, candidateId: candidate.id),
              ),
            ],
          ),
          if (specification == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Not yet specified. Use "Open Specification Editor" to add Type/Value/Unit.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
              ),
            )
          else ...[
            PropertyField(label: 'Spec Type', value: specification.specType.label),
            PropertyField(label: 'Value', value: specification.value.isEmpty ? '—' : specification.value),
            PropertyField(label: 'Unit', value: specification.unit.isEmpty ? '—' : specification.unit),
            PropertyField(label: 'Spec Notes', value: specification.notes.isEmpty ? '—' : specification.notes),
          ],
        ],
        if (candidate.type == KnowledgeCandidateType.procedure) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Procedure — $procedureStepCount step${procedureStepCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open Procedure Builder',
                icon: const Icon(Icons.open_in_new, size: 15),
                onPressed: () async {
                  notifier.openProcedureBuilder(candidate.id);
                  await showProcedureBuilderDialog(context);
                  notifier.closeProcedureBuilder();
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Evidence',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Link Evidence Region',
              icon: const Icon(Icons.add_link, size: 16),
              onPressed: () => showLinkEvidenceRegionsDialog(context, candidateId: candidate.id),
            ),
          ],
        ),
        if (links.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No linked evidence.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          )
        else
          for (final entry in links)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.sourceName} — ${entry.region.label} (p. ${entry.region.page})',
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

/// The Validation Status section (Work Package 010 STUDIO-TASK-000025:
/// "Display validation status for every Knowledge Candidate."). Not a
/// selectable field — see this file's top doc comment — just a display
/// of the candidate's current [CandidateValidationResult].
class _ValidationSection extends StatelessWidget {
  const _ValidationSection({required this.validation});

  final CandidateValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (validation.severity) {
      ValidationSeverity.error => (Icons.error_outline, StudioColors.error, 'Error'),
      ValidationSeverity.warning => (Icons.warning_amber_outlined, StudioColors.warning, 'Warning'),
      ValidationSeverity.ok => (Icons.check_circle_outline, StudioColors.success, 'OK'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
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
          for (final issue in validation.issues)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $issue', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
