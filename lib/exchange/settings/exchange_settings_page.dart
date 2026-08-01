import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/models/settings_entry.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/widgets/settings_rows.dart';
import '../models/exchange_connection_status.dart';
import '../services/exchange_runtime_service.dart';
import 'exchange_settings_provider.dart';

/// Settings > Engineering Exchange (WP-EXC-010) -- one more
/// `SettingsProvider`, appended to `StudioRegistry`'s exchange descriptor,
/// mirroring `AcquisitionSettingsProvider`. `pageId` is an
/// Exchange-owned string, not one of `CoreSettingsPageIds`'s core
/// constants, exactly like Acquisition's own `'engineering_acquisition'`
/// id.
class ExchangeSettingsProvider implements SettingsProvider {
  const ExchangeSettingsProvider();

  @override
  String get pageId => 'engineering_exchange';

  @override
  String get label => 'Engineering Exchange';

  @override
  IconData get icon => Icons.storefront_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
        SettingsEntry(
          pageId: 'engineering_exchange',
          name: 'Exchange Service Address',
          description: 'The address of the Engineering Exchange REST API.',
          keywords: ['exchange', 'marketplace', 'api', 'url', 'host', 'port'],
        ),
      ];

  @override
  WidgetBuilder get pageBuilder => (context) => const ExchangeSettingsPage();
}

class ExchangeSettingsPage extends ConsumerWidget {
  const ExchangeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(exchangeSettingsProvider);
    final notifier = ref.read(exchangeSettingsProvider.notifier);
    final runtime = ref.watch(exchangeRuntimeServiceProvider);
    final runtimeNotifier = ref.read(exchangeRuntimeServiceProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Connection',
          description: 'The Engineering Exchange is an autonomous domain service, reached only through '
              'its own REST API -- Studio never accesses its database directly.',
          children: [
            SettingsTextRow(
              label: 'Service Address',
              value: settings.apiBaseUrl,
              onChanged: notifier.setApiBaseUrl,
              hintText: 'http://127.0.0.1:3000/api/v1',
              helper: 'Restart is not required -- takes effect on the next request.',
            ),
            SettingsInfoRow(
              label: 'Status',
              value: switch (runtime.connectionStatus) {
                ExchangeConnectionStatus.notTested => 'Not tested',
                ExchangeConnectionStatus.connected => 'Connected',
                ExchangeConnectionStatus.networkError => 'Network error',
                ExchangeConnectionStatus.serviceError => 'Service error',
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
