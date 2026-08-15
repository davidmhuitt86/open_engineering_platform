import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/models/settings_entry.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/widgets/settings_rows.dart';
import '../models/acquisition_connection_status.dart';
import '../services/acquisition_runtime_service.dart';
import 'acquisition_settings_provider.dart';

/// Settings > Engineering Acquisition (WP-PLAT-020) — one more
/// `SettingsProvider`, appended to `SettingsRegistry`, mirroring
/// `DiagramStudioSettingsProvider`. `pageId` is an Acquisition-owned
/// string, not one of `CoreSettingsPageIds`'s core constants, exactly
/// like Diagram Studio's own `'diagram_studio'` id.
class AcquisitionSettingsProvider implements SettingsProvider {
  const AcquisitionSettingsProvider();

  @override
  String get pageId => 'engineering_acquisition';

  @override
  String get label => 'Engineering Acquisition';

  @override
  IconData get icon => Icons.cloud_download_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
        SettingsEntry(
          pageId: 'engineering_acquisition',
          name: 'Acquisition Service Address',
          description: 'The address of the Engineering Acquisition Management REST API.',
          keywords: ['eam', 'acquisition', 'api', 'url', 'host', 'port'],
        ),
      ];

  @override
  WidgetBuilder get pageBuilder => (context) => const AcquisitionSettingsPage();
}

class AcquisitionSettingsPage extends ConsumerWidget {
  const AcquisitionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(acquisitionSettingsProvider);
    final notifier = ref.read(acquisitionSettingsProvider.notifier);
    final runtime = ref.watch(acquisitionRuntimeServiceProvider);
    final runtimeNotifier = ref.read(acquisitionRuntimeServiceProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Connection',
          description:
              'Engineering Acquisition Management (EAM) is an autonomous domain service, reached only through '
              'its own REST API -- Studio never accesses its database directly.',
          children: [
            SettingsTextRow(
              label: 'Service Address',
              value: settings.apiBaseUrl,
              onChanged: notifier.setApiBaseUrl,
              hintText: 'http://127.0.0.1:8080',
              helper: 'Restart is not required -- takes effect on the next request.',
            ),
            SettingsInfoRow(
              label: 'Status',
              value: switch (runtime.connectionStatus) {
                AcquisitionConnectionStatus.notTested => 'Not tested',
                AcquisitionConnectionStatus.connected => 'Connected',
                AcquisitionConnectionStatus.networkError => 'Network error',
                AcquisitionConnectionStatus.serviceError => 'Service error',
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: runtime.loading ? null : runtimeNotifier.testConnection,
                  child: const Text('Test Connection'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
