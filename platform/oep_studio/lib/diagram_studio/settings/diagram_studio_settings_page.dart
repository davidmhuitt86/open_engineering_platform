import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../settings/models/settings_entry.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/widgets/settings_rows.dart';
import '../instruments_host/instrument_bridge_provider.dart';
import 'diagram_studio_settings_provider.dart';

/// Settings > Diagram Studio (WORK_PACKAGE_024, ENGINE-TASK-000108) —
/// one more `SettingsProvider`, appended to `SettingsRegistry`.
/// `pageId` is a Diagram-Studio-owned string, not one of
/// `CoreSettingsPageIds`'s eleven core constants (`SettingsProvider`'s
/// own doc comment: "or a future provider's own unique id").
class DiagramStudioSettingsProvider implements SettingsProvider {
  const DiagramStudioSettingsProvider();

  @override
  String get pageId => 'diagram_studio';

  @override
  String get label => 'Diagram Studio';

  @override
  IconData get icon => Icons.polyline_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Grid',
          description: 'Whether new diagrams start with the grid visible.',
        ),
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Snap',
          description: 'Whether new diagrams start with snap-to-grid enabled.',
        ),
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Guides',
          description: 'Whether new diagrams start with smart alignment guides visible.',
        ),
      ];

  @override
  WidgetBuilder get pageBuilder => (context) => const DiagramStudioSettingsPage();
}

class DiagramStudioSettingsPage extends ConsumerWidget {
  const DiagramStudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(diagramStudioSettingsProvider);
    final notifier = ref.read(diagramStudioSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'New Document Defaults',
          description: 'Applied to every new diagram\'s ViewState; does not affect already-open documents.',
          children: [
            SettingsSwitchRow(
              label: 'Show Grid by Default',
              value: settings.defaultGridVisible,
              onChanged: notifier.setDefaultGridVisible,
            ),
            SettingsSwitchRow(
              label: 'Snap to Grid by Default',
              value: settings.defaultSnapEnabled,
              onChanged: notifier.setDefaultSnapEnabled,
            ),
            SettingsSwitchRow(
              label: 'Show Alignment Guides by Default',
              value: settings.defaultGuidesVisible,
              onChanged: notifier.setDefaultGuidesVisible,
            ),
          ],
        ),
        const _InstrumentBridgeSection(),
      ],
    );
  }
}

/// Settings > Diagram Studio > Connections — the control surface for
/// [OipHostBridgeService] (`OipHostBridgeService`'s own doc comment),
/// which lets companion apps (e.g. the OEP Digital Multimeter Android
/// app) connect over Wi-Fi and request live measurements against the
/// currently open diagram. Deliberately placed in Settings rather than as
/// a Diagram Studio toolbar icon: starting a network listener is
/// connection/network-exposure configuration, the same category as every
/// other control already on this page, not a per-document editing
/// action a toolbar's icon row is for.
class _InstrumentBridgeSection extends ConsumerStatefulWidget {
  const _InstrumentBridgeSection();

  @override
  ConsumerState<_InstrumentBridgeSection> createState() => _InstrumentBridgeSectionState();
}

class _InstrumentBridgeSectionState extends ConsumerState<_InstrumentBridgeSection> {
  final _portController = TextEditingController(text: '9411');
  List<String> _localAddresses = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalAddresses());
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      final addresses = [for (final interface in interfaces) for (final address in interface.addresses) address.address];
      if (mounted) setState(() => _localAddresses = addresses);
    } catch (_) {
      // Address discovery is a convenience only -- if it fails, the user
      // can still find their IP themselves (e.g. `ipconfig`) and the
      // Start/Stop control below still works.
    }
  }

  Future<void> _start() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _error = 'Enter a valid port (1-65535).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final bridge = ref.read(instrumentBridgeServiceProvider);
    try {
      await bridge.start(graphProvider: () => currentInstrumentBridgeGraph(ref), port: port);
    } catch (error) {
      _error = 'Could not start: $error';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await ref.read(instrumentBridgeServiceProvider).stop();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final bridge = ref.watch(instrumentBridgeServiceProvider);
    final running = bridge.isRunning;

    return SettingsSection(
      title: 'Connections',
      description: 'Lets companion apps (e.g. the OEP Digital Multimeter Android app) connect over '
          'Wi-Fi and request live measurements against the currently open diagram. No engineering '
          'computation runs on the companion device -- every value comes from this Studio\'s own '
          'Simulation Engine.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                size: 16,
                color: running ? StudioColors.success : StudioColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                running ? 'Instrument Bridge running on port ${bridge.port}' : 'Instrument Bridge stopped',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (_localAddresses.isNotEmpty)
          SettingsInfoRow(
            label: 'This PC\'s address',
            value: '${_localAddresses.first}:${bridge.port ?? _portController.text}',
          ),
        SettingsTextRow(
          label: 'Port',
          value: _portController.text,
          onChanged: (value) => _portController.text = value,
          helper: running ? 'Stop the bridge to change the port.' : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(_error!, style: const TextStyle(color: StudioColors.error, fontSize: 11.5)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : (running ? _stop : _start),
              child: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(running ? 'Stop' : 'Start'),
            ),
          ),
        ),
      ],
    );
  }
}
