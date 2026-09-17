import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/credential_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../settings/models/settings_entry.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/widgets/settings_rows.dart';
import '../models/acquisition_connection_status.dart';
import '../services/acquisition_api_client.dart';
import '../services/acquisition_runtime_service.dart';
import '../services/acquisition_service_launcher.dart';
import '../services/acquisition_service_launcher_state.dart';
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
    final launcher = ref.watch(acquisitionServiceLauncherProvider);
    final launcherNotifier = ref.read(acquisitionServiceLauncherProvider.notifier);
    final isLocal = isLocalServiceAddress(settings.apiBaseUrl);

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
        SettingsSection(
          title: 'Authentication',
          description:
              'EAM requires a bearer token on every request except its health check (ADR-0002). Stored in the '
              'Windows Credential Manager, the same way AI provider API keys are stored -- never written to a '
              'settings file.',
          children: const [_ApiTokenRow()],
        ),
        if (isLocal)
          SettingsSection(
            title: 'Local EAM Service',
            description:
                'A convenience for local development only -- starts the real, unmodified EAM backend '
                '(oep_acquisition.exe) as a child process of Studio, so a separate terminal is not required. '
                'The service remains reachable only through the REST API above; this does not change the '
                'Service Address or the Acquisition API contract.',
            children: [
              SettingsInfoRow(
                label: 'Status',
                value: switch (launcher.status) {
                  AcquisitionServiceLauncherStatus.stopped => 'Stopped',
                  AcquisitionServiceLauncherStatus.starting => 'Starting',
                  AcquisitionServiceLauncherStatus.running => 'Running',
                  AcquisitionServiceLauncherStatus.error => launcher.errorMessage ?? 'Error',
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (launcher.status == AcquisitionServiceLauncherStatus.running) ...[
                        FilledButton.tonal(
                          onPressed: launcherNotifier.stop,
                          child: const Text('Stop Local Service'),
                        ),
                        OutlinedButton(
                          onPressed: launcherNotifier.restart,
                          child: const Text('Restart Local Service'),
                        ),
                      ] else
                        FilledButton.tonal(
                          onPressed:
                              launcher.status == AcquisitionServiceLauncherStatus.starting ? null : launcherNotifier.start,
                          child: const Text('Start Local Service'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// EAM Bearer token management -- mirrors `_ApiKeyRow`
/// (`settings/pages/ai_settings_page.dart`) exactly: reads/writes
/// `CredentialService.instance` directly (never bound to
/// `AcquisitionSettings`/`AcquisitionSettingsStorage`, which persist to a
/// plaintext JSON file), and never re-displays a saved token's actual
/// value, only whether one is configured.
class _ApiTokenRow extends StatefulWidget {
  const _ApiTokenRow();

  @override
  State<_ApiTokenRow> createState() => _ApiTokenRowState();
}

class _ApiTokenRowState extends State<_ApiTokenRow> {
  final _controller = TextEditingController();
  bool _hasToken = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final token = await CredentialService.instance.readCredential(acquisitionApiTokenCredentialId);
    if (!mounted) return;
    setState(() {
      _hasToken = token != null && token.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await CredentialService.instance.saveCredential(providerId: acquisitionApiTokenCredentialId, secret: value);
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EAM API token saved.')));
    await _refresh();
  }

  Future<void> _remove() async {
    await CredentialService.instance.deleteCredential(acquisitionApiTokenCredentialId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EAM API token removed.')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API Token', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _loading ? 'Checking…' : (_hasToken ? 'A token is configured.' : 'No token configured.'),
                    style: TextStyle(
                      color: _hasToken ? StudioColors.success : StudioColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _controller,
                    obscureText: true,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hasToken ? 'Enter a new token to replace it' : 'Paste the OEP_API_TOKEN value',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasToken) TextButton(onPressed: _remove, child: const Text('Remove')),
                    const SizedBox(width: 4),
                    ElevatedButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
