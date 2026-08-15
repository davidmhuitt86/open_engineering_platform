import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/dashboard_card.dart';
import '../../shared/widgets/responsive_card_grid.dart';
import 'widgets/getting_started_strip.dart';

/// The Dashboard (SDD-007), the engineer's landing page.
///
/// Matches the approved 001-OEP-STUDIO-DASHBOARD-v1.0.png mockup.
/// Repository Status, Foundation Version, and Installed Packages reflect
/// live Foundation state via [foundationRuntimeServiceProvider]
/// (STUDIO-TASK-000004); Recent Repositories remains placeholder — no
/// persistence layer exists yet.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              color: StudioColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Welcome to OEP Studio',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const ResponsiveCardGrid(
            children: [
              _OpenRepositoryCard(),
              _CreateRepositoryCard(),
              _RepositoryStatusCard(),
            ],
          ),
          const SizedBox(height: 16),
          const ResponsiveCardGrid(
            children: [
              _RecentRepositoriesCard(),
              _FoundationVersionCard(),
              _InstalledPackagesCard(),
            ],
          ),
          const SizedBox(height: 16),
          const GettingStartedStrip(),
        ],
      ),
    );
  }
}

class _OpenRepositoryCard extends ConsumerWidget {
  const _OpenRepositoryCard();

  Future<void> _openRepository(BuildContext context, WidgetRef ref) async {
    final directoryPath = await getDirectoryPath(confirmButtonText: 'Open Repository');
    if (directoryPath == null) return;
    if (!context.mounted) return;

    try {
      ref.read(foundationRuntimeServiceProvider.notifier).openRepository(directoryPath);
    } on FoundationBridgeException catch (error) {
      if (!context.mounted) return;
      await showFoundationErrorDialog(context, title: 'Couldn\'t Open Repository', error: error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      foundationRuntimeServiceProvider.select((state) => state.phase == FoundationConnectionPhase.connected),
    );

    return DashboardCard(
      title: 'Open Repository',
      icon: Icons.folder_open_outlined,
      iconColor: StudioColors.selection,
      iconBackground: StudioColors.selection.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open an existing OEP repository from your system.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: connected ? () => _openRepository(context, ref) : null,
              child: const Text('Open Repository'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a professional error dialog for a Foundation failure. Only
/// [FoundationBridgeException.message] (the curated, translated text) is
/// ever displayed — never [FoundationBridgeException.technicalDetail],
/// which may reference internal Foundation implementation details.
Future<void> showFoundationErrorDialog(
  BuildContext context, {
  required String title,
  required FoundationBridgeException error,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(title),
      content: Text(error.message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
      ],
    ),
  );
}

class _CreateRepositoryCard extends StatelessWidget {
  const _CreateRepositoryCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Create Repository',
      icon: Icons.note_add_outlined,
      iconColor: StudioColors.success,
      iconBackground: StudioColors.success.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a new OEP repository in a few simple steps.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // The Public C API does not yet expose repository creation
              // (only open/close) — this stays a placeholder until it does.
              onPressed: null,
              style: ElevatedButton.styleFrom(backgroundColor: StudioColors.success),
              child: const Text('Create Repository'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepositoryStatusCard extends ConsumerWidget {
  const _RepositoryStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final status = foundation.repositoryStatus;
    final statistics = foundation.repositoryStatistics;
    final connected = foundation.phase == FoundationConnectionPhase.connected;

    // Repository Statistics (Work Package 004) is the live, Foundation-
    // computed source for identity fields too — fall back to Repository
    // Status (Work Package 002) only if statistics haven't loaded yet.
    final repositoryName = statistics?.repositoryName ?? status?.repositoryName;
    final repositoryVersion = statistics?.repositoryVersion ?? status?.repositoryVersion;
    final repositoryId = statistics?.repositoryId ?? status?.repositoryId;

    return DashboardCard(
      title: 'Repository Status',
      icon: Icons.dns_outlined,
      iconColor: const Color(0xFFB794F6),
      iconBackground: const Color(0xFFB794F6).withValues(alpha: 0.14),
      child: Column(
        children: [
          _StatusRow(
            icon: Icons.check_circle_outline,
            label: 'Repository Name',
            value: repositoryName ?? 'None',
          ),
          _StatusRow(
            icon: Icons.dns_outlined,
            label: 'Runtime State',
            value: _runtimeStateLabel(foundation),
            valueColor: connected ? StudioColors.success : StudioColors.warning,
          ),
          _StatusRow(icon: Icons.new_releases_outlined, label: 'Repository Version', value: repositoryVersion ?? '—'),
          _StatusRow(icon: Icons.fingerprint, label: 'Repository ID', value: repositoryId ?? '—'),
          _StatusRow(
            icon: Icons.category_outlined,
            label: 'Total Objects',
            value: statistics != null ? '${statistics.totalObjectCount}' : '—',
          ),
          _StatusRow(
            icon: Icons.hub_outlined,
            label: 'Relationship Count',
            value: statistics != null ? '${statistics.relationshipCount}' : '—',
          ),
          _StatusRow(
            icon: Icons.inventory_2_outlined,
            label: 'Package Count',
            value: statistics != null ? '${statistics.packageCount}' : '—',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  String _runtimeStateLabel(FoundationServiceState foundation) {
    if (foundation.phase == FoundationConnectionPhase.error) return 'Error';
    if (foundation.phase == FoundationConnectionPhase.connecting) return 'Connecting…';
    return foundation.runtimeState.displayLabel;
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: StudioColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? StudioColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _RecentRepositoriesCard extends StatelessWidget {
  const _RecentRepositoriesCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Recent Repositories',
      icon: Icons.history,
      trailing: const ViewAllLink(),
      child: const _EmptyState(
        icon: Icons.folder_outlined,
        title: 'No recent repositories',
        description: 'Repositories you open will appear here.',
      ),
    );
  }
}

class _FoundationVersionCard extends ConsumerWidget {
  const _FoundationVersionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final connected = foundation.phase == FoundationConnectionPhase.connected;

    return DashboardCard(
      title: 'Foundation Version',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            connected ? 'Connected' : 'Not Connected',
            style: TextStyle(
              color: connected ? StudioColors.success : StudioColors.warning,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            connected
                ? 'OEP Foundation Runtime is initialized and ready.'
                : 'Connect to a repository to see Foundation version information.',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioColors.surfaceSunken,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: StudioColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LabeledValue(label: 'Foundation Version', value: foundation.foundationVersion ?? '—'),
                ),
                Expanded(
                  child: _LabeledValue(
                    label: 'API Version',
                    value: foundation.apiVersion != null ? '${foundation.apiVersion}' : '—',
                  ),
                ),
                Expanded(
                  child: _LabeledValue(
                    label: 'ABI Version',
                    value: foundation.abiVersion != null ? '${foundation.abiVersion}' : '—',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InstalledPackagesCard extends ConsumerWidget {
  const _InstalledPackagesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(foundationRuntimeServiceProvider.select((state) => state.repositoryStatus));

    if (status == null) {
      return const DashboardCard(
        title: 'Installed Packages',
        icon: Icons.inventory_2_outlined,
        trailing: ViewAllLink(),
        child: _EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No packages installed',
          description: 'Installed packages will appear here.',
        ),
      );
    }

    return DashboardCard(
      title: 'Installed Packages',
      icon: Icons.inventory_2_outlined,
      trailing: const ViewAllLink(),
      child: status.loadedPackageCount == 0
          ? const _EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No packages installed',
              description: 'This repository has no packages loaded.',
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    '${status.loadedPackageCount}',
                    style: const TextStyle(color: StudioColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'packages loaded',
                    style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: StudioColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
