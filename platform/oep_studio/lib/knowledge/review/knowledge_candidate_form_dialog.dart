import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/knowledge_candidate_form_controller.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_validation_exception.dart';

/// The New/Edit Knowledge Candidate dialog (Work Package 007: "The
/// engineer shall be able to create manual proposals ... Edit").
/// [existing] is `null` to create a new candidate, or the candidate
/// being edited.
///
/// [initialName]/[initialDescription]/[initialType] pre-fill a new
/// candidate's form — used by Work Package 010's "Create Knowledge
/// Candidate from Source Material/Page Selection/Evidence Region" entry
/// points to seed a sensible starting name (e.g. from a source file
/// name) without forcing the engineer to retype it. [linkToRegionId],
/// if given, links the newly-created candidate to that Evidence Region
/// immediately after creation (the "create from Evidence Region" path)
/// — see `docs/KNOWLEDGE_CANDIDATES.md` § Architectural Observations
/// for why only the Evidence Region origin produces a real
/// `EvidenceLink` and Source Material/Page Selection do not.
Future<void> showKnowledgeCandidateFormDialog(
  BuildContext context, {
  KnowledgeCandidate? existing,
  String? initialName,
  String? initialDescription,
  KnowledgeCandidateType? initialType,
  String? linkToRegionId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _KnowledgeCandidateFormDialog(
      existing: existing,
      initialName: initialName,
      initialDescription: initialDescription,
      initialType: initialType,
      linkToRegionId: linkToRegionId,
    ),
  );
}

class _KnowledgeCandidateFormDialog extends ConsumerStatefulWidget {
  const _KnowledgeCandidateFormDialog({
    required this.existing,
    this.initialName,
    this.initialDescription,
    this.initialType,
    this.linkToRegionId,
  });

  final KnowledgeCandidate? existing;
  final String? initialName;
  final String? initialDescription;
  final KnowledgeCandidateType? initialType;
  final String? linkToRegionId;

  @override
  ConsumerState<_KnowledgeCandidateFormDialog> createState() => _KnowledgeCandidateFormDialogState();
}

class _KnowledgeCandidateFormDialogState extends ConsumerState<_KnowledgeCandidateFormDialog> {
  // Owned by this State — see `_NewSessionDialogState`'s note on why
  // this must not be disposed via the showDialog Future instead.
  late final _form = KnowledgeCandidateFormController(
    name: widget.existing?.name ?? widget.initialName ?? '',
    type: widget.existing?.type ?? widget.initialType ?? KnowledgeCandidateType.component,
    description: widget.existing?.description ?? widget.initialDescription ?? '',
    notes: widget.existing?.notes ?? '',
    author: widget.existing?.author ?? '',
    tags: widget.existing?.tags ?? const [],
  );
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    try {
      if (widget.existing == null) {
        final created = notifier.addKnowledgeCandidate(
          type: _form.type,
          name: _form.name,
          description: _form.description,
          notes: _form.notes,
          author: _form.author,
          tags: _form.tags,
        );
        if (widget.linkToRegionId != null) {
          notifier.linkEvidence(candidateId: created.id, regionId: widget.linkToRegionId!);
        }
      } else {
        notifier.editKnowledgeCandidate(
          widget.existing!.id,
          type: _form.type,
          name: _form.name,
          description: _form.description,
          notes: _form.notes,
          author: _form.author,
          tags: _form.tags,
        );
      }
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(isEditing ? 'Edit Knowledge Candidate' : 'New Knowledge Candidate'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              ValueListenableBuilder<KnowledgeCandidateType>(
                valueListenable: _form.typeNotifier,
                builder: (context, type, _) => DropdownButtonHideUnderline(
                  child: DropdownButton<KnowledgeCandidateType>(
                    value: type,
                    isExpanded: true,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                    items: [
                      for (final option in KnowledgeCandidateType.values)
                        DropdownMenuItem(value: option, child: Text(option.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) _form.typeNotifier.value = value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _form.nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: _form.descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _form.notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(controller: _form.authorController, decoration: const InputDecoration(labelText: 'Author')),
              const SizedBox(height: 12),
              TextField(
                controller: _form.tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Add Candidate')),
      ],
    );
  }
}
