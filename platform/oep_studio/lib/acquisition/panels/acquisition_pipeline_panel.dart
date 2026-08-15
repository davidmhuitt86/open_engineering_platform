import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../services/acquisition_runtime_service.dart';

/// The Pipeline panel (WP-PLAT-020 Phase 4/12 — Import, OCR, Evidence
/// Review, Knowledge Extraction, mapped onto EAM's own pipeline stages).
/// Shows Downloads -> Verifications -> Metadata for whichever job is
/// currently selected in the Jobs panel — EAM's pipeline is
/// (per ADR-0008) Downloader -> Integrity Verification -> Metadata
/// Extraction -> Reference Vault, so this panel's three columns walk
/// that chain one job at a time.
class AcquisitionPipelinePanel extends ConsumerWidget {
  const AcquisitionPipelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(acquisitionRuntimeServiceProvider);
    final notifier = ref.read(acquisitionRuntimeServiceProvider.notifier);

    if (state.selectedJobId == null) {
      return const KnowledgePanel(
        title: 'Pipeline',
        icon: Icons.linear_scale_outlined,
        child: Center(
          child: Text('Select a job to view its pipeline.', style: TextStyle(color: StudioColors.textSecondary)),
        ),
      );
    }

    return KnowledgePanel(
      title: 'Pipeline',
      icon: Icons.linear_scale_outlined,
      child: Row(
        children: [
          Expanded(
            child: _PipelineColumn(
              title: 'Downloads',
              itemCount: state.downloads.length,
              itemBuilder: (index) {
                final download = state.downloads[index];
                return ListTile(
                  dense: true,
                  title: Text(download.fileName.isEmpty ? download.id : download.fileName,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                  subtitle: Text(download.status, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10)),
                  trailing: download.status == 'completed'
                      ? IconButton(
                          tooltip: 'Verify',
                          icon: const Icon(Icons.verified_outlined, size: 16),
                          onPressed: () => notifier.verify(download.id),
                        )
                      : null,
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _PipelineColumn(
              title: 'Verifications',
              itemCount: state.verifications.length,
              itemBuilder: (index) {
                final verification = state.verifications[index];
                return ListTile(
                  dense: true,
                  title: Text(verification.status, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                  subtitle: Text(
                    verification.sha256Hash.isEmpty ? '' : '${verification.sha256Hash.substring(0, 12)}…',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10),
                  ),
                  trailing: verification.status == 'verified'
                      ? IconButton(
                          tooltip: 'Extract Metadata',
                          icon: const Icon(Icons.description_outlined, size: 16),
                          onPressed: () => notifier.extractMetadata(verification.id),
                        )
                      : null,
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _PipelineColumn(
              title: 'Metadata',
              itemCount: state.metadata.length,
              itemBuilder: (index) {
                final metadata = state.metadata[index];
                return ListTile(
                  dense: true,
                  title: Text(metadata.fileName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                  subtitle: Text(metadata.status, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10)),
                  trailing: metadata.status == 'extracted'
                      ? IconButton(
                          tooltip: 'Publish to Vault',
                          icon: const Icon(Icons.inventory_2_outlined, size: 16),
                          onPressed: () => notifier.publish(metadata.id),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  const _PipelineColumn({required this.title, required this.itemCount, required this.itemBuilder});

  final String title;
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: itemCount == 0
              ? const Center(child: Text('—', style: TextStyle(color: StudioColors.textDisabled)))
              : ListView.builder(itemCount: itemCount, itemBuilder: (context, index) => itemBuilder(index)),
        ),
      ],
    );
  }
}
