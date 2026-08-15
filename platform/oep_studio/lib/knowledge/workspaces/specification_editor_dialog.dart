import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../inspector/link_evidence_dialog.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/specification_type.dart';

/// The Specification Editor (Work Package 010 STUDIO-TASK-000024):
/// "Provide manual authoring for Specification Knowledge Candidates ...
/// Each Specification supports: Type, Value, Unit, Notes, Linked
/// Evidence."
///
/// "Linked Evidence" is not a field this dialog owns — it is the same
/// `EvidenceLink` list every other Knowledge Candidate already uses
/// (Work Package 009), read and edited here through the existing
/// `linkEvidence`/`unlinkEvidence`/`showLinkEvidenceRegionsDialog`
/// mechanism rather than a Specification-specific one. See
/// `docs/KNOWLEDGE_CANDIDATES.md` § Specification Model.
Future<void> showSpecificationEditorDialog(BuildContext context, {required String candidateId}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SpecificationEditorDialog(candidateId: candidateId),
  );
}

class _SpecificationEditorDialog extends ConsumerStatefulWidget {
  const _SpecificationEditorDialog({required this.candidateId});

  final String candidateId;

  @override
  ConsumerState<_SpecificationEditorDialog> createState() => _SpecificationEditorDialogState();
}

class _SpecificationEditorDialogState extends ConsumerState<_SpecificationEditorDialog> {
  late final _existing = ref.read(foundationRuntimeServiceProvider).specificationDetailsFor(widget.candidateId);
  late final _valueController = TextEditingController(text: _existing?.value ?? '');
  late final _unitController = TextEditingController(text: _existing?.unit ?? '');
  late final _notesController = TextEditingController(text: _existing?.notes ?? '');
  late final _typeNotifier = ValueNotifier<SpecificationType>(_existing?.specType ?? SpecificationType.torque);
  String? _errorMessage;

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    _typeNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      ref
          .read(foundationRuntimeServiceProvider.notifier)
          .setSpecificationDetails(
            candidateId: widget.candidateId,
            specType: _typeNotifier.value,
            value: _valueController.text,
            unit: _unitController.text,
            notes: _notesController.text,
          );
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final candidateMatches = foundation.candidates.where((entry) => entry.id == widget.candidateId);
    final candidate = candidateMatches.isEmpty ? null : candidateMatches.first;
    final links = foundation.evidenceLinks.where((link) => link.candidateId == widget.candidateId).toList();

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text('Specification Editor — ${candidate?.name ?? widget.candidateId}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              ValueListenableBuilder<SpecificationType>(
                valueListenable: _typeNotifier,
                builder: (context, type, _) => DropdownButtonHideUnderline(
                  child: DropdownButton<SpecificationType>(
                    value: type,
                    isExpanded: true,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                    items: [
                      for (final option in SpecificationType.values)
                        DropdownMenuItem(value: option, child: Text(option.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) _typeNotifier.value = value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _valueController, decoration: const InputDecoration(labelText: 'Value')),
              const SizedBox(height: 12),
              TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Unit')),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Linked Evidence',
                      style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Link Evidence Region',
                    icon: const Icon(Icons.add_link, size: 16),
                    onPressed: () => showLinkEvidenceRegionsDialog(context, candidateId: widget.candidateId),
                  ),
                ],
              ),
              if (links.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No linked evidence.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                )
              else
                for (final link in links)
                  Builder(
                    builder: (context) {
                      final regionMatches = foundation.evidenceRegions.where((entry) => entry.id == link.regionId);
                      final region = regionMatches.isEmpty ? null : regionMatches.first;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                region?.label ?? link.regionId,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Unlink',
                              icon: const Icon(Icons.link_off, size: 15),
                              onPressed: () =>
                                  ref.read(foundationRuntimeServiceProvider.notifier).unlinkEvidence(link.id),
                            ),
                          ],
                        ),
                      );
                    },
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
        ElevatedButton(onPressed: _submit, child: const Text('Save Specification')),
      ],
    );
  }
}
