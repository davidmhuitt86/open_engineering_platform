import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../../shared/widgets/oep_list_view.dart';
import '../services/acquisition_runtime_service.dart';
import '../services/acquisition_selection.dart';
import 'ingest_vault_artifact_dialog.dart';

/// The Reference Vault panel (WP-PLAT-020 Phase 4 — Evidence Review /
/// published evidence). Read-only with respect to the Vault itself:
/// vault entries are immutable once published (WORK_PACKAGE-009), so
/// this panel has no create/edit actions, matching `IVaultRepository`'s
/// own lack of an `update` method on the EAM side. Its one action,
/// "Ingest into Knowledge Studio" (WP-INGEST-004 § 8), does not mutate
/// the Vault at all — it only reads a published artifact and starts the
/// Reference Vault ingestion workflow.
class AcquisitionVaultPanel extends ConsumerWidget {
  const AcquisitionVaultPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultEntries = ref.watch(acquisitionRuntimeServiceProvider).vaultEntries;
    final selectedArtifact = ref.watch(acquisitionSelectionProvider).artifact;

    return KnowledgePanel(
      title: 'Reference Vault',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: selectedArtifact == null
                    ? null
                    : () => showIngestVaultArtifactDialog(context, ref, selectedArtifact),
                icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                label: const Text('Ingest into Knowledge Studio'),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: OEPListView(
              items: vaultEntries,
              emptyMessage: 'No published artifacts yet.',
              itemBuilder: (context, entry) => ListTile(
                dense: true,
                selected: entry.id == selectedArtifact?.id,
                selectedTileColor: StudioColors.selectedRowBackground,
                onTap: () => ref.read(acquisitionSelectionProvider.notifier).selectArtifact(entry),
                title: Text(
                  entry.sha256Hash.isEmpty ? entry.id : entry.sha256Hash.substring(0, 16),
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                ),
                subtitle: Text(
                  '${entry.mimeType} · ${entry.fileSizeBytes} bytes · published ${entry.publishedAt}',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
