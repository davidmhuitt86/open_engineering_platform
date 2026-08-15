import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_validation_exception.dart';
import '../review/knowledge_candidate_form_dialog.dart';

/// The Evidence Browser (Work Package 009 STUDIO-TASK-000020): "Display:
/// Region Name, Page, Type, Linked Candidate Count. Support: Rename,
/// Delete, Navigate." Scoped to the Evidence Regions of one Source
/// Material — opened from that source's Source Viewer toolbar, since
/// "Navigate" only means something relative to whichever PDF is
/// currently open.
///
/// "Type" always reads "Rectangle" — STUDIO-TASK-000020's Requirements
/// list only "Rectangle Regions" as a supported shape; the column exists
/// for when a future work package adds another Evidence Region shape,
/// not because more than one exists today.
Future<void> showEvidenceBrowserDialog(BuildContext context, {required String sourceId, required String sourceName}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _EvidenceBrowserDialog(sourceId: sourceId, sourceName: sourceName),
  );
}

class _EvidenceBrowserDialog extends ConsumerWidget {
  const _EvidenceBrowserDialog({required this.sourceId, required this.sourceName});

  final String sourceId;
  final String sourceName;

  Future<void> _rename(BuildContext context, EvidenceRegion region) async {
    await showDialog<void>(context: context, builder: (context) => _RenameRegionDialog(region: region));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, EvidenceRegion region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Delete Evidence Region'),
        content: Text('Delete "${region.label}"? Any links to Knowledge Candidates are removed too.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: StudioColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(foundationRuntimeServiceProvider.notifier).deleteEvidenceRegion(region.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final regions = foundation.evidenceRegions.where((region) => region.sourceId == sourceId).toList()
      ..sort((a, b) => a.page != b.page ? a.page.compareTo(b.page) : a.createdTime.compareTo(b.createdTime));

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text('Evidence Browser — $sourceName'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: regions.isEmpty
            ? const Center(
                child: Text(
                  'No Evidence Regions yet. Use the PDF viewer\'s region tool to draw one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              )
            : ListView.separated(
                itemCount: regions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final region = regions[index];
                  return ListTile(
                    dense: true,
                    selected: foundation.selectedEvidenceRegion?.id == region.id,
                    title: Text(
                      region.label,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    subtitle: Text(
                      'Page ${region.page} · Rectangle · ${formatLinkedCount(foundation.linkedCandidateCountFor(region.id))}',
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Navigate',
                          icon: const Icon(Icons.open_in_new, size: 16),
                          onPressed: () {
                            notifier.selectEvidenceRegion(region);
                            Navigator.of(context).pop();
                          },
                        ),
                        IconButton(
                          tooltip: 'Create Knowledge Candidate from Region',
                          icon: const Icon(Icons.add_box_outlined, size: 16),
                          onPressed: () => showKnowledgeCandidateFormDialog(
                            context,
                            initialName: region.label,
                            initialDescription: 'Created from Evidence Region "${region.label}" (page ${region.page}) of "$sourceName".',
                            linkToRegionId: region.id,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _rename(context, region),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => _confirmDelete(context, ref, region),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

/// The Rename dialog, split out as its own `StatefulWidget` so its
/// `TextEditingController` is owned and disposed by this dialog's own
/// `State` — not by the caller after `showDialog` resolves. Disposing
/// via the caller crashes with "A TextEditingController was used after
/// being disposed": `showDialog`'s `Future` completes as soon as
/// `Navigator.pop()` is called, which is *before* the dialog's exit
/// animation finishes rebuilding the still-visible, still-attached
/// `TextField` — the same dialog-lifecycle bug Work Package 007
/// documented and fixed for the New Session/New Candidate dialogs,
/// reintroduced here and fixed the same way.
class _RenameRegionDialog extends ConsumerStatefulWidget {
  const _RenameRegionDialog({required this.region});

  final EvidenceRegion region;

  @override
  ConsumerState<_RenameRegionDialog> createState() => _RenameRegionDialogState();
}

class _RenameRegionDialogState extends ConsumerState<_RenameRegionDialog> {
  late final _controller = TextEditingController(text: widget.region.label);
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).renameEvidenceRegion(widget.region.id, _controller.text);
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Rename Evidence Region'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Label')),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}
