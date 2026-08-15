import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import '../review/knowledge_candidate_form_dialog.dart';
import '../widgets/knowledge_placeholder.dart';

/// The Import Queue panel (Work Package 008 STUDIO-TASK-000016): attach
/// Source Material via the native file picker and browse what's already
/// attached to the active session. "No OCR. No parsing." — this panel
/// only manages files and their metadata; it never reads a source's
/// contents (see `SourceMaterialService`).
class ImportQueuePanel extends ConsumerWidget {
  const ImportQueuePanel({super.key});

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final picked = await openFile();
    if (picked == null) return;
    if (!context.mounted) return;
    try {
      await ref.read(foundationRuntimeServiceProvider.notifier).attachSourceMaterial(picked.path);
    } on KnowledgeValidationException catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text("Couldn't Attach Source"),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final session = foundation.knowledgeSession;

    if (session == null) {
      return const KnowledgePlaceholder(message: 'Create a Knowledge Curation Session to attach source material.');
    }

    final sources = foundation.sourceMaterials;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _attach(context, ref),
              icon: const Icon(Icons.upload_file_outlined, size: 14),
              label: const Text('Attach Source'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: sources.isEmpty
              ? const KnowledgePlaceholder(message: 'No source material yet. Use "Attach Source" to add evidence.')
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return _SourceRow(
                      source: source,
                      selected: foundation.selectedSourceMaterial?.id == source.id,
                      onTap: () => notifier.selectSourceMaterial(source),
                      onRemove: () => notifier.removeSourceMaterial(source.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.selected, required this.onTap, required this.onRemove});

  final SourceMaterial source;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(source.type.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.originalFileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Text(
                      '${source.type.label} · ${formatFileSize(source.sizeBytes)}',
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Create Knowledge Candidate from Source Material',
                icon: const Icon(Icons.add_box_outlined, size: 16),
                onPressed: () => showKnowledgeCandidateFormDialog(
                  context,
                  initialName: source.originalFileName,
                  initialDescription: 'Created from Source Material "${source.originalFileName}".',
                ),
              ),
              IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline, size: 16), onPressed: onRemove),
            ],
          ),
        ),
      ),
    );
  }
}
