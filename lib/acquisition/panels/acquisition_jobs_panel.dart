import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../../shared/widgets/oep_list_view.dart';
import '../models/acquisition_job.dart';
import '../models/official_source.dart';
import '../services/acquisition_api_exception.dart';
import '../services/acquisition_runtime_service.dart';
import '../services/acquisition_selection.dart';

/// The Acquisition Job panel (WP-PLAT-020 Phase 4/12 — Acquire,
/// Import). Lists every Acquisition Job, lets the engineer create one
/// against a registered Source, and advance it (Execute/Cancel).
/// Selecting a row drives the Pipeline panel's drill-down.
class AcquisitionJobsPanel extends ConsumerWidget {
  const AcquisitionJobsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(acquisitionRuntimeServiceProvider);
    final notifier = ref.read(acquisitionRuntimeServiceProvider.notifier);

    return KnowledgePanel(
      title: 'Acquisition Jobs',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: state.sources.isEmpty ? null : () => _showCreateDialog(context, ref, state.sources),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Job'),
            ),
          ),
          Expanded(
            child: OEPListView(
              items: state.jobs,
              emptyMessage: 'No jobs yet.',
              itemBuilder: (context, job) {
                final selected = job.id == state.selectedJobId;
                return _JobRow(
                  job: job,
                  selected: selected,
                  onSelect: () {
                    // Two distinct concerns from one click: the
                    // Pipeline panel's drill-down (existing) and
                    // the Property Inspector's Job mode (new).
                    notifier.selectJob(job.id);
                    ref.read(acquisitionSelectionProvider.notifier).selectJob(job);
                  },
                  onAcquire: () => _acquire(context, ref, job),
                  onExecute: () => notifier.executeJob(job.id),
                  onCancel: () => notifier.cancelJob(job.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref, List<OfficialSource> sources) async {
    final nameController = TextEditingController();
    var selectedSourceId = sources.first.id;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Acquisition Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String>(
                initialValue: selectedSourceId,
                decoration: const InputDecoration(labelText: 'Source'),
                items: [
                  for (final source in sources) DropdownMenuItem(value: source.id, child: Text(source.name)),
                ],
                onChanged: (value) => setState(() => selectedSourceId = value ?? selectedSourceId),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (created != true) return;
    await ref.read(acquisitionRuntimeServiceProvider.notifier).createJob({
      'name': nameController.text,
      'source_id': selectedSourceId,
      'priority': 1,
    });
  }

  /// Runs a real, complete acquisition for [job] -- the whole
  /// download -> verify -> metadata -> Vault chain in one action, no
  /// repeated button presses. Prompts for the artifact URL because an
  /// Acquisition Job carries no source URI of its own (see
  /// `AcquisitionRuntimeNotifier.acquireForJob`).
  Future<void> _acquire(BuildContext context, WidgetRef ref, AcquisitionJob job) async {
    // Captured before the first await -- the dialog below is an async
    // gap, after which `context` may no longer be safe to use.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final urlController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Acquire artifact for "${job.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OEP will download this artifact, verify its SHA-256, extract its metadata, and publish it '
              'to the Reference Vault — automatically, in one step.',
              style: TextStyle(fontSize: 12, color: StudioColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Artifact URL', hintText: 'https://…'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Acquire')),
        ],
      ),
    );

    if (confirmed != true) return;
    final url = urlController.text.trim();
    if (url.isEmpty) return;

    try {
      await ref.read(acquisitionRuntimeServiceProvider.notifier).acquireForJob(jobId: job.id, sourceUri: url);
      messenger?.showSnackBar(const SnackBar(content: Text('Artifact acquired and published to the Reference Vault.')));
    } on AcquisitionApiException catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.selected,
    required this.onSelect,
    required this.onAcquire,
    required this.onExecute,
    required this.onCancel,
  });

  final AcquisitionJob job;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onAcquire;
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  bool get _isTerminal => job.status == 'completed' || job.status == 'failed' || job.status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: StudioColors.surfaceRaised,
      onTap: onSelect,
      title: Text(job.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(job.status, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
      trailing: _isTerminal
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Acquire artifact… (downloads, verifies, and publishes to the Vault)',
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  onPressed: onAcquire,
                ),
                IconButton(
                  // Renamed from a bare "Execute": this only advances the
                  // Job's own status one step and acquires nothing. See
                  // `AcquisitionRuntimeNotifier.acquireForJob`'s doc
                  // comment for why the two are genuinely different
                  // actions rather than one.
                  tooltip: 'Advance job status (bookkeeping only — acquires nothing)',
                  icon: const Icon(Icons.skip_next_outlined, size: 18),
                  onPressed: onExecute,
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.stop_outlined, size: 18),
                  onPressed: onCancel,
                ),
              ],
            ),
    );
  }
}
