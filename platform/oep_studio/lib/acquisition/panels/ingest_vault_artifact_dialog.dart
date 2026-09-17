import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';
import '../models/vault_entry_record.dart';
import '../services/acquisition_runtime_service.dart';

/// The production entry point WP-INGEST-004 § 8 requires: "Reference
/// Vault artifact -> 'Ingest into Knowledge Studio' -> ingestion
/// progress/result -> Knowledge Studio session." Reached from the
/// Reference Vault panel's own "Ingest into Knowledge Studio" action
/// (`AcquisitionVaultPanel`) — the existing Reference Vault surface,
/// per WP-INGEST-004 § 8's "Use an existing appropriate Knowledge
/// Studio / Reference Vault surface if one exists. Do NOT create an
/// entire new Studio."
///
/// This dialog only orchestrates user interaction (naming the new
/// session, showing progress, and — on success — handing the result to
/// `FoundationRuntimeNotifier` and switching to Knowledge Studio); all
/// actual ingestion coordination happens in
/// `AcquisitionRuntimeNotifier.ingestVaultArtifact` ->
/// `ReferenceVaultIngestionWorkflow`, never chained here directly
/// (WP-INGEST-004 § 8: "UI should orchestrate user interaction. The
/// workflow service should orchestrate ingestion.").
Future<void> showIngestVaultArtifactDialog(BuildContext context, WidgetRef ref, VaultEntryRecord artifact) {
  return showDialog<void>(
    context: context,
    builder: (context) => _IngestVaultArtifactDialog(artifact: artifact),
  );
}

class _IngestVaultArtifactDialog extends ConsumerStatefulWidget {
  const _IngestVaultArtifactDialog({required this.artifact});

  final VaultEntryRecord artifact;

  @override
  ConsumerState<_IngestVaultArtifactDialog> createState() => _IngestVaultArtifactDialogState();
}

class _IngestVaultArtifactDialogState extends ConsumerState<_IngestVaultArtifactDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: 'Reference Vault ${_shortId(widget.artifact)}',
  );
  final TextEditingController _repositoryController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  static String _shortId(VaultEntryRecord artifact) =>
      artifact.sha256Hash.isEmpty ? artifact.id : artifact.sha256Hash.substring(0, 12);

  @override
  void dispose() {
    _nameController.dispose();
    _repositoryController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _ingest() async {
    final sessionName = _nameController.text.trim();
    final repositoryName = _repositoryController.text.trim();
    final author = _authorController.text.trim();
    if (sessionName.isEmpty) {
      setState(() => _errorMessage = 'Session name cannot be empty.');
      return;
    }
    if (repositoryName.isEmpty) {
      setState(() => _errorMessage = 'Select a repository for this session before creating it.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final outcome = await ref.read(acquisitionRuntimeServiceProvider.notifier).ingestVaultArtifact(
          vaultObjectId: widget.artifact.id,
          sessionName: sessionName,
          repositoryName: repositoryName,
          author: author,
        );

    if (!mounted) return;

    if (outcome.isFailed) {
      setState(() {
        _submitting = false;
        _errorMessage = outcome.errorMessage ?? 'Ingestion failed.';
      });
      return;
    }

    // COMPLETED/PARTIAL both make the resulting session available to
    // Knowledge Studio (WP-INGEST-004 § 6/§ 18) — PARTIAL is never
    // silently presented as COMPLETED; the confirmation below names it
    // explicitly.
    await ref.read(foundationRuntimeServiceProvider.notifier).loadKnowledgeSessionRecord(outcome.sessionRecord!);
    if (!mounted) return;

    Navigator.of(context).pop();
    openOrActivateDestination(context, ref, StudioDestination.knowledge);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          outcome.isPartial
              ? 'Ingested "$sessionName" with partial results — some stages did not fully succeed. Review in '
                  'Knowledge Studio.'
              : 'Ingested "$sessionName" into Knowledge Studio.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Ingest into Knowledge Studio'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reference Vault artifact ${_shortId(widget.artifact)} (${widget.artifact.mimeType}) will be '
              'processed through the Universal Ingestion Framework and opened as a new Knowledge Curation '
              'Session for review. Nothing is committed to the repository automatically.',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Session Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repositoryController,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Repository'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorController,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            if (_submitting) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Ingesting…', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                ],
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
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _ingest,
          child: const Text('Ingest'),
        ),
      ],
    );
  }
}
