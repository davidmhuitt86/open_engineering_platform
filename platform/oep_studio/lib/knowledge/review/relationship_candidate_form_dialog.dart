import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/relationship_type.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/relationship_candidate_form_controller.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/relationship_candidate.dart';

/// The New/Edit Relationship Candidate dialog (Work Package 008
/// STUDIO-TASK-000017: "Support: Create Relationship, Edit
/// Relationship"). [existing] is `null` to create a new relationship
/// candidate, or the one being edited.
Future<void> showRelationshipCandidateFormDialog(BuildContext context, {RelationshipCandidate? existing}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RelationshipCandidateFormDialog(existing: existing),
  );
}

class _RelationshipCandidateFormDialog extends ConsumerStatefulWidget {
  const _RelationshipCandidateFormDialog({required this.existing});

  final RelationshipCandidate? existing;

  @override
  ConsumerState<_RelationshipCandidateFormDialog> createState() => _RelationshipCandidateFormDialogState();
}

class _RelationshipCandidateFormDialogState extends ConsumerState<_RelationshipCandidateFormDialog> {
  late final _form = RelationshipCandidateFormController(
    sourceCandidateId: widget.existing?.sourceCandidateId,
    targetCandidateId: widget.existing?.targetCandidateId,
    type: widget.existing?.type ?? RelationshipType.references,
    description: widget.existing?.description ?? '',
  );
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final sourceId = _form.sourceCandidateId;
    final targetId = _form.targetCandidateId;
    if (sourceId == null || targetId == null) {
      setState(() => _errorMessage = 'Select both a source and a target candidate.');
      return;
    }
    try {
      if (widget.existing == null) {
        notifier.addRelationshipCandidate(
          sourceCandidateId: sourceId,
          targetCandidateId: targetId,
          type: _form.type,
          description: _form.description,
        );
      } else {
        notifier.editRelationshipCandidate(
          widget.existing!.id,
          sourceCandidateId: sourceId,
          targetCandidateId: targetId,
          type: _form.type,
          description: _form.description,
        );
      }
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(foundationRuntimeServiceProvider.select((state) => state.candidates));
    final isEditing = widget.existing != null;
    final isDuplicate = ref
        .read(foundationRuntimeServiceProvider.notifier)
        .isDuplicateRelationshipCandidate(
          sourceCandidateId: _form.sourceCandidateId,
          targetCandidateId: _form.targetCandidateId,
          type: _form.type,
          excludingId: widget.existing?.id,
        );

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(isEditing ? 'Edit Relationship Candidate' : 'New Relationship Candidate'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CandidateDropdown(
              label: 'Source Candidate',
              candidates: candidates,
              valueNotifier: _form.sourceCandidateIdNotifier,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _CandidateDropdown(
              label: 'Target Candidate',
              candidates: candidates,
              valueNotifier: _form.targetCandidateIdNotifier,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('Relationship Type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            ValueListenableBuilder<RelationshipType>(
              valueListenable: _form.typeNotifier,
              builder: (context, type, _) => DropdownButtonHideUnderline(
                child: DropdownButton<RelationshipType>(
                  value: type,
                  isExpanded: true,
                  dropdownColor: StudioColors.surfaceRaised,
                  style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                  items: [
                    for (final option in RelationshipType.values)
                      DropdownMenuItem(value: option, child: Text(option.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _form.typeNotifier.value = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _form.descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            if (isDuplicate) ...[
              const SizedBox(height: 12),
              const Text(
                'A relationship of this type already exists between these candidates.',
                style: TextStyle(color: StudioColors.warning, fontSize: 12),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Add Relationship')),
      ],
    );
  }
}

class _CandidateDropdown extends StatelessWidget {
  const _CandidateDropdown({
    required this.label,
    required this.candidates,
    required this.valueNotifier,
    required this.onChanged,
  });

  final String label;
  final List<KnowledgeCandidate> candidates;
  final ValueNotifier<String?> valueNotifier;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        ValueListenableBuilder<String?>(
          valueListenable: valueNotifier,
          builder: (context, value, _) => DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: candidates.any((candidate) => candidate.id == value) ? value : null,
              isExpanded: true,
              hint: const Text('Select a candidate…', style: TextStyle(color: StudioColors.textDisabled, fontSize: 13)),
              dropdownColor: StudioColors.surfaceRaised,
              style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
              items: [
                for (final candidate in candidates)
                  DropdownMenuItem(value: candidate.id, child: Text(candidate.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (newValue) {
                valueNotifier.value = newValue;
                onChanged();
              },
            ),
          ),
        ),
      ],
    );
  }
}
