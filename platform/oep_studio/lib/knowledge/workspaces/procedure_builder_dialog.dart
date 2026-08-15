import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/procedure_step.dart';

/// The Procedure Builder (Work Package 010 STUDIO-TASK-000023): "Provide
/// a dedicated editor for Procedure Knowledge Candidates ... Ordered
/// procedure steps, Insert step, Delete step, Duplicate step,
/// Drag-and-drop reordering."
///
/// Reads whichever candidate is currently open
/// (`FoundationServiceState.openProcedure`, Work Package 010's "Current
/// Procedure") rather than taking a candidate directly — the caller sets
/// that via `FoundationRuntimeNotifier.openProcedureBuilder` immediately
/// before calling this, and clears it via `closeProcedureBuilder` once
/// this dialog's `Future` resolves, so the docked Property Inspector can
/// keep reflecting whichever step is selected inside this (non-blocking)
/// dialog — see `openProcedure`'s doc comment for the full rationale.
Future<void> showProcedureBuilderDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _ProcedureBuilderDialog());
}

class _ProcedureBuilderDialog extends ConsumerWidget {
  const _ProcedureBuilderDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final candidate = foundation.openProcedure;
    if (candidate == null) {
      // Defensive only — the caller always sets `openProcedure` before
      // showing this dialog. Nothing meaningful to display if it's gone
      // (e.g. the candidate was deleted from another window mid-dialog).
      return AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Procedure Builder'),
        content: const Text(
          'This Procedure Knowledge Candidate is no longer available.',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
    }

    final steps = foundation.procedureStepsFor(candidate.id);

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text('Procedure Builder — ${candidate.name}'),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => showStepEditDialog(context, candidateId: candidate.id),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Insert Step'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: steps.isEmpty
                  ? const Center(
                      child: Text(
                        'No steps yet. Use "Insert Step" to begin the procedure.',
                        style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: steps.length,
                      itemBuilder: (context, index) {
                        final step = steps[index];
                        return _StepTile(
                          key: ValueKey(step.id),
                          index: index,
                          step: step,
                          selected: foundation.selectedProcedureStep?.id == step.id,
                          onTap: () => notifier.selectProcedureStep(step),
                          onEdit: () => showStepEditDialog(context, candidateId: candidate.id, existing: step),
                          onDuplicate: () => notifier.duplicateProcedureStep(step.id),
                          onDelete: () => notifier.deleteProcedureStep(step.id),
                        );
                      },
                      onReorderItem: (oldIndex, newIndex) {
                        final step = steps[oldIndex];
                        notifier.reorderProcedureStep(step.id, newIndex);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final int index;
  final ProcedureStep step;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('${step.id}-material'),
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: StudioColors.surfaceSunken,
                child: Text('${index + 1}', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    if (step.description.isNotEmpty)
                      Text(
                        step.description,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 15), onPressed: onEdit),
              IconButton(
                tooltip: 'Duplicate',
                icon: const Icon(Icons.copy_outlined, size: 15),
                onPressed: onDuplicate,
              ),
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 15), onPressed: onDelete),
              const Icon(Icons.drag_handle, size: 16, color: StudioColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The New/Edit Step dialog. [existing] is `null` to insert a new step.
/// Owns its own controllers per the dialog-controller-lifecycle rule
/// (Work Package 007, reconfirmed Work Package 009's Evidence Browser).
Future<void> showStepEditDialog(BuildContext context, {required String candidateId, ProcedureStep? existing}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _StepEditDialog(candidateId: candidateId, existing: existing),
  );
}

class _StepEditDialog extends ConsumerStatefulWidget {
  const _StepEditDialog({required this.candidateId, required this.existing});

  final String candidateId;
  final ProcedureStep? existing;

  @override
  ConsumerState<_StepEditDialog> createState() => _StepEditDialogState();
}

class _StepEditDialogState extends ConsumerState<_StepEditDialog> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late final _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  late final Set<String> _referencedCandidateIds = {...?widget.existing?.referencedCandidateIds};
  late final Set<String> _referencedRegionIds = {...?widget.existing?.referencedRegionIds};
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    try {
      if (widget.existing == null) {
        final step = notifier.addProcedureStep(
          candidateId: widget.candidateId,
          title: _titleController.text,
          description: _descriptionController.text,
          notes: _notesController.text,
        );
        notifier.setProcedureStepReferences(
          step.id,
          referencedCandidateIds: _referencedCandidateIds.toList(),
          referencedRegionIds: _referencedRegionIds.toList(),
        );
      } else {
        notifier.updateProcedureStep(
          widget.existing!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          notes: _notesController.text,
        );
        notifier.setProcedureStepReferences(
          widget.existing!.id,
          referencedCandidateIds: _referencedCandidateIds.toList(),
          referencedRegionIds: _referencedRegionIds.toList(),
        );
      }
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final candidates = foundation.candidates.where((candidate) => candidate.id != widget.candidateId).toList();
    final regions = foundation.evidenceRegions;
    final isEditing = widget.existing != null;

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(isEditing ? 'Edit Step' : 'Insert Step'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Referenced Knowledge Candidates',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No other candidates in this session.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                )
              else
                for (final candidate in candidates)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(candidate.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                    value: _referencedCandidateIds.contains(candidate.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _referencedCandidateIds.add(candidate.id);
                      } else {
                        _referencedCandidateIds.remove(candidate.id);
                      }
                    }),
                  ),
              const SizedBox(height: 12),
              const Text(
                'Referenced Evidence Regions',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (regions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No Evidence Regions in this session.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                )
              else
                for (final region in regions)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(region.label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                    value: _referencedRegionIds.contains(region.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _referencedRegionIds.add(region.id);
                      } else {
                        _referencedRegionIds.remove(region.id);
                      }
                    }),
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
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Insert')),
      ],
    );
  }
}
