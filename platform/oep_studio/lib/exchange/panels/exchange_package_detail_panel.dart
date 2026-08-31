import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/platform_notification_service.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';
import '../models/exchange_package.dart';
import '../models/installation.dart';
import '../services/exchange_runtime_service.dart';

/// Package Detail, with inline Installation Progress (WP-EXC-010 §5), and
/// Repository/Workspace Integration (§6/§7). Mirrors
/// `apps/publisher-portal`'s `PackageDetailPage` ("Download + Install
/// actions, Installation Progress") plus the two Studio-only additions
/// this Work Package adds on top: "Open Installed Package"/"Refresh
/// Repository" (both delegate to `FoundationRuntimeNotifier`, the
/// Repository's own approved public interface) and "Open in Engineering
/// Workspace".
///
/// "Open Installed Package" and "Open in Engineering Workspace" are
/// implemented as best-effort navigation to the existing Repository
/// (`/repository`) and Project Explorer (`/project`) destinations rather
/// than a generic asset-type dispatch, because no such dispatch bridge
/// exists anywhere in Studio today (`EngineeringObjectRuntime` is
/// read-only, `WorkspaceManager` is Diagram-only) and building one would
/// be a Foundation-side architectural addition outside this Work
/// Package's "no architectural redesign" mandate -- see the Studio
/// Integration Guide's Outstanding Issues.
class ExchangePackageDetailPanel extends ConsumerWidget {
  const ExchangePackageDetailPanel({required this.package, super.key});

  final ExchangePackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangeRuntimeServiceProvider);
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);
    final installation = state.selectedPackageInstallation;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: notifier.clearSelectedPackage,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  package.displayName,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text(package.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(package.description, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${package.packageId} -- current version ${package.currentVersion ?? 'unset'}',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          // Pricing and Reviews & Ratings (Phase 7): the approved render
          // shows both prominently, but neither field exists anywhere in
          // `ExchangePackage`, the Exchange REST client, or Foundation --
          // shown honestly as not-yet-available rather than a fabricated
          // price or rating.
          const Wrap(
            spacing: 8,
            children: [
              _UnavailableChip(icon: Icons.sell_outlined, label: 'Pricing not yet available'),
              _UnavailableChip(icon: Icons.star_border, label: 'Reviews & ratings not yet available'),
            ],
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: state.loading ? null : () => notifier.installPackage(package.id, package.displayName),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Install'),
              ),
              OutlinedButton.icon(
                onPressed: state.loading ? null : () => _download(context, ref, package),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Download'),
              ),
              if (installation != null && installation.isCompleted) ...[
                OutlinedButton.icon(
                  onPressed: () => _openInstalledPackage(context, ref),
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Open Installed Package'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openOrActivateDestination(context, ref, StudioDestination.projectExplorer),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Engineering Workspace'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (installation != null) _InstallationProgress(installation: installation, onRefresh: () => notifier.refreshInstallationStatus(installation.id)),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.lastError!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref, ExchangePackage package) async {
    final location = await getSaveLocation(suggestedName: '${package.packageId}-${package.currentVersion ?? 'latest'}.oep');
    if (location == null) return;
    await ref.read(exchangeRuntimeServiceProvider.notifier).downloadPackage(package.id, package.displayName, location.path);
    if (context.mounted) {
      final error = ref.read(exchangeRuntimeServiceProvider).lastError;
      if (error == null) {
        PlatformNotificationService.success(context, 'Downloaded ${package.displayName} to ${location.path}.');
      }
    }
  }

  void _openInstalledPackage(BuildContext context, WidgetRef ref) {
    ref.read(foundationRuntimeServiceProvider.notifier).refreshRepository();
    openOrActivateDestination(context, ref, StudioDestination.repository);
  }
}

class _UnavailableChip extends StatelessWidget {
  const _UnavailableChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: StudioColors.textDisabled),
      label: Text(label, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
      backgroundColor: StudioColors.surfaceSunken,
      side: const BorderSide(color: StudioColors.borderSubtle),
    );
  }
}

class _InstallationProgress extends StatelessWidget {
  const _InstallationProgress({required this.installation, required this.onRefresh});

  final Installation installation;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = switch (installation.status) {
      'completed' => Colors.green.shade700,
      'failed' => StudioColors.error,
      _ => StudioColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: StudioColors.surfaceRaised, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(
            switch (installation.status) {
              'completed' => Icons.check_circle_outline,
              'failed' => Icons.error_outline,
              _ => Icons.hourglass_empty,
            },
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Installation ${installation.status}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                if (installation.errorMessage != null)
                  Text(installation.errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 11)),
                if (installation.repositoryPackageId != null)
                  Text(
                    'Repository package id: ${installation.repositoryPackageId}',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onRefresh, child: const Text('Refresh Status')),
        ],
      ),
    );
  }
}
