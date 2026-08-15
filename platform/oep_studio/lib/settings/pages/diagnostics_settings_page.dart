import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Diagnostics (SDD-023; STUDIO-TASK-000052). "Foundation
/// Runtime"/"Studio Runtime" are live, read-only values sourced
/// directly from the Connection Manager — not stored settings.
class DiagnosticsSettingsProvider implements SettingsProvider {
  const DiagnosticsSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.diagnostics;

  @override
  String get label => 'Diagnostics';

  @override
  IconData get icon => Icons.monitor_heart_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(pageId: CoreSettingsPageIds.diagnostics, name: 'Performance', description: 'Performance monitoring.'),
    SettingsEntry(pageId: CoreSettingsPageIds.diagnostics, name: 'Memory', description: 'Memory monitoring.'),
    SettingsEntry(pageId: CoreSettingsPageIds.diagnostics, name: 'GPU', description: 'GPU monitoring.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.diagnostics,
      name: 'Foundation Runtime',
      description: 'Foundation version and connection info.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.diagnostics, name: 'Studio Runtime', description: 'Studio runtime info.'),
    SettingsEntry(pageId: CoreSettingsPageIds.diagnostics, name: 'Reset Studio', description: 'Reset all local Studio state.'),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const DiagnosticsSettingsPage();
}

class DiagnosticsSettingsPage extends ConsumerWidget {
  const DiagnosticsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final diagnostics = ref.watch(settingsControllerProvider.select((state) => state.configuration.diagnostics));
    final general = ref.watch(settingsControllerProvider.select((state) => state.configuration.general));
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Monitoring',
          children: [
            SettingsSwitchRow(
              label: 'Performance Monitoring',
              helper: 'Not yet implemented.',
              value: diagnostics.performanceMonitoringEnabled,
              onChanged: controller.setPerformanceMonitoringEnabled,
            ),
            SettingsSwitchRow(
              label: 'Memory Monitoring',
              helper: 'Not yet implemented.',
              value: diagnostics.memoryMonitoringEnabled,
              onChanged: controller.setMemoryMonitoringEnabled,
            ),
            SettingsSwitchRow(
              label: 'GPU Monitoring',
              helper: 'Not yet implemented.',
              value: diagnostics.gpuMonitoringEnabled,
              onChanged: controller.setGpuMonitoringEnabled,
            ),
            SettingsInfoRow(label: 'Logging Level', value: general.logging.name),
          ],
        ),
        SettingsSection(
          title: 'Runtime',
          children: [
            SettingsInfoRow(label: 'Foundation Version', value: foundation.foundationVersion ?? 'Not connected'),
            SettingsInfoRow(label: 'Public API Version', value: foundation.apiVersion?.toString() ?? '—'),
            SettingsInfoRow(label: 'ABI Version', value: foundation.abiVersion?.toString() ?? '—'),
            SettingsInfoRow(label: 'Repository Open', value: foundation.isRepositoryOpen ? 'Yes' : 'No'),
          ],
        ),
        const SettingsSection(
          title: 'Reset',
          children: [
            SettingsPlaceholderRow(
              label: 'Reset Studio',
              helper: 'Resetting all local Studio state is not implemented; use "Reset Defaults" on this Workspace for Settings only.',
            ),
          ],
        ),
      ],
    );
  }
}
